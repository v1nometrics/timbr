// SPDX-License-Identifier: MPL-2.0
import SwiftUI
import AppKit
import TimbreCore
import TimbreEngine
import TimbreDesignSystem

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public let appState = AppState()
    private var notchController: NotchPanelController?
    private var studioWindow: NSWindow?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        appState.openStudioHandler = { [weak self] in
            self?.openStudio()
        }
        appState.start()
        notchController = NotchPanelController(appState: appState)

        // Headless smoke mode for automated verification: exits cleanly after initialization + tap check
        if ProcessInfo.processInfo.arguments.contains("--smoke-check") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.appState.shutdown()
                self?.notchController?.teardown()
                NSApp.terminate(nil)
            }
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        notchController?.teardown()
        appState.shutdown()
    }

    public func openStudio() {
        if studioWindow == nil {
            let view = StudioWindow(appState: appState)
            let hosting = NSHostingController(rootView: view)
            let win = NSWindow(contentViewController: hosting)
            win.title = "timbr. Studio"
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.setContentSize(NSSize(width: 1020, height: 680))
            win.center()
            win.isReleasedWhenClosed = false
            studioWindow = win
        }
        NSApp.setActivationPolicy(.regular)
        studioWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
public struct TimbrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    public init() {}

    public var body: some Scene {
        MenuBarExtra("timbr.", systemImage: delegate.appState.isProcessingBypassed ? "waveform.slash" : "waveform.path.ecg") {
            MenuBarContent(delegate: delegate, appState: delegate.appState)
        }
    }
}

private struct MenuBarContent: View {
    let delegate: AppDelegate
    @ObservedObject var appState: AppState

    var body: some View {
        Text("timbr. — \(appState.activeOutputDevice?.name ?? "—")")
        Divider()
        Button(appState.t("notch.open_studio") + " (⌥⌘,)") {
            delegate.openStudio()
        }
        Button(appState.notchState == .expanded ? "Close Notch (⌥⌘V)" : "Expand Notch (⌥⌘V)") {
            appState.toggleExpandedNotch()
        }
        Button(appState.isProcessingBypassed ? "Enable DSP (⌥⌘B)" : "Bypass (0 taps) (⌥⌘B)") {
            appState.toggleBypass()
        }
        Button(appState.t("notch.ab_neutral") + " (⌥⌘A)") {
            appState.toggleABNeutral()
        }
        Divider()
        Menu(appState.t("mixer.destinations")) {
            ForEach(appState.outputDevices) { dev in
                Button(dev.isDefaultOutput ? "✓ \(dev.name)" : dev.name) {
                    appState.selectDefaultOutput(dev)
                }
            }
        }
        Divider()
        Button("Quit timbr.") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
