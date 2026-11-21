// SPDX-License-Identifier: MPL-2.0
import SwiftUI
import AppKit
import Combine
import TimbreCore
import TimbreEngine
import TimbreDesignSystem

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public let appState = AppState()
    private var notchController: NotchPanelController?
    private var studioWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var reviewWindow: NSWindow?
    private var cancellables: Set<AnyCancellable> = []

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
        appState.$devices
            .map { devs in devs.first(where: { $0.isDefaultOutput && $0.outputChannels > 0 })?.uid }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.appState.applyPresetForActiveDevice() }
            .store(in: &cancellables)

        // Design-review flags (screenshots of each surface without a human driving the UI):
        //   --studio <mixer|equalizer|observatory|settings|support>   --notch <compact|peek|expanded|hud>
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--studio"), i + 1 < args.count, let tab = StudioTab(rawValue: args[i + 1]) {
            appState.needsOnboarding = false
            appState.selectedTab = tab
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.openStudio() }
        }
        if let i = args.firstIndex(of: "--notch"), i + 1 < args.count, let st = NotchState(rawValue: args[i + 1]) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                if st == .hud { self?.appState.triggerHUD(title: "Output", value: 0.62, muted: false) } else { self?.appState.notchState = st }
            }
        }

        if args.contains("--onboarding") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.openOnboarding() }
        }
        if args.contains("--panel-preview") {
            let win = NSWindow(contentViewController: NSHostingController(rootView: MenuBarPanel(delegate: self, appState: appState)))
            win.styleMask = [.titled, .fullSizeContentView]
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.setFrameTopLeftPoint(NSPoint(x: 80, y: (NSScreen.main?.frame.maxY ?? 900) - 80))
            win.orderFrontRegardless()
            reviewWindow = win
        }

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
            win.title = "timbr."
            // Full-size content: the sidebar runs under the traffic lights (no stock title bar).
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.isMovableByWindowBackground = false
            win.setContentSize(NSSize(width: 1180, height: 780))
            win.minSize = NSSize(width: 980, height: 640)
            win.setFrameAutosaveName("timbr.studio")
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
            win.styleMask = [.titled, .closable, .fullSizeContentView]
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
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
        MenuBarExtra {
            MenuBarPanel(delegate: delegate, appState: delegate.appState)
        } label: {
            Image(systemName: delegate.appState.isProcessingBypassed ? "waveform.slash" : "waveform")
                .accessibilityLabel("timbr.")
        }
        .menuBarExtraStyle(.window)
    }
}
