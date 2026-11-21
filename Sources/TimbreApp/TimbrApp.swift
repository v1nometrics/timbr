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
    private var onboardingWindow: NSWindow?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        appState.openStudioHandler = { [weak self] in
            self?.openStudio()
        }
        appState.presentOnboardingHandler = { [weak self] in
            self?.openOnboarding()
        }
        appState.dismissOnboardingHandler = { [weak self] in
            self?.closeOnboarding()
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
        closeOnboarding()
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

    public func openOnboarding() {
        if onboardingWindow == nil {
            let view = OnboardingWindow(appState: appState)
            let hosting = NSHostingController(rootView: view)
            let win = NSWindow(contentViewController: hosting)
            win.title = "timbr."
            win.styleMask = [.titled, .closable]
            win.setContentSize(NSSize(width: 720, height: 520))
            win.center()
            win.isReleasedWhenClosed = false
            win.isMovableByWindowBackground = true
            onboardingWindow = win
        }
        NSApp.setActivationPolicy(.regular)
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func closeOnboarding() {
        onboardingWindow?.orderOut(nil)
        if studioWindow == nil || !(studioWindow?.isVisible ?? false) {
            NSApp.setActivationPolicy(.accessory)
        }
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
        if appState.needsOnboarding || appState.showOnboarding {
            Button(appState.t("onboard.kicker") + "…") {
                delegate.openOnboarding()
            }
            Divider()
        }
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
