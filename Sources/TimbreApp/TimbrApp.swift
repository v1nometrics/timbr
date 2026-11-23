// SPDX-License-Identifier: MPL-2.0
import SwiftUI
import AppKit
import Combine
import TimbreCore
import TimbreEngine
import TimbreDesignSystem

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    public let appState = AppState()
    private var notchController: NotchPanelController?
    private var menuBarIcon: MenuBarIconController?
    private var studioWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var reviewWindow: NSWindow?
    private var cancellables: Set<AnyCancellable> = []

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // End-to-end audio measurement (no UI, no AppState): `Timbr --selftest-audio <report.json>`.
        let launchArgs = ProcessInfo.processInfo.arguments
        if let i = launchArgs.firstIndex(of: "--selftest-audio") {
            let url = URL(fileURLWithPath: i + 1 < launchArgs.count ? launchArgs[i + 1] : NSTemporaryDirectory() + "timbr-selftest.json")
            Task { @MainActor in
                let r = await AudioSelfTest.run(reportURL: url)
                print("[selftest-audio] allPassed=\(r.allPassed) → \(url.path)")
                NSApp.terminate(nil)
            }
            return
        }
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
        menuBarIcon = MenuBarIconController(delegate: self, appState: appState)
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

        if args.contains("--demo") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.notchController?.runDemo() }
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

    /// Launching the app again (Finder, Spotlight, Dock) while it runs opens the Studio — the way
    /// back in when there is no menu bar icon.
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openStudio()
        return true
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
            win.delegate = self
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
            win.setContentSize(NSSize(width: 720, height: OnboardingWindow.windowHeight))
            win.center()
            win.isReleasedWhenClosed = false
            win.isMovableByWindowBackground = true
            win.delegate = self
            onboardingWindow = win
        }
        NSApp.setActivationPolicy(.regular)
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func closeOnboarding() {
        onboardingWindow?.orderOut(nil)
        restoreAccessoryPolicyIfIdle(excluding: onboardingWindow)
    }

    public func windowWillClose(_ notification: Notification) {
        let closing = notification.object as? NSWindow
        restoreAccessoryPolicyIfIdle(excluding: closing)
    }

    private func restoreAccessoryPolicyIfIdle(excluding closing: NSWindow? = nil) {
        let studioOpen = (studioWindow !== closing) && (studioWindow?.isVisible ?? false)
        let onboardingOpen = (onboardingWindow !== closing) && (onboardingWindow?.isVisible ?? false)
        if !studioOpen && !onboardingOpen {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

@main
public struct TimbrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    public init() {}

    public var body: some Scene {
        // The menu bar icon is an AppKit NSStatusItem owned by MenuBarIconController, not a SwiftUI
        // MenuBarExtra: toggling MenuBarExtra(isInserted:) from app state sent SwiftUI into an endless
        // main-menu rebuild (measured: 100% CPU, the app never quit). This scene is never shown.
        Settings { EmptyView() }
            .commands {
                // ⌘, opens the Studio's settings page, never the empty Settings scene.
                CommandGroup(replacing: .appSettings) {
                    Button(delegate.appState.t("ui.ctx.settings")) {
                        delegate.appState.selectedTab = .settings
                        delegate.openStudio()
                    }
                    .keyboardShortcut(",")
                }
            }
    }
}
