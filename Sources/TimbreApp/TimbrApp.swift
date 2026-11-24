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
    private var selfTestMuteHolder: MuteKeeperClient?
    private var selfTestTone: NSSound?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // `Timbr.icns` uses an opaque full-bleed canvas so macOS 26+ applies the native continuous
        // Liquid Glass squircle mask cleanly without auto-embossing the black pill; on macOS 15,
        // keep the pre-masked rounded squircle for the running Dock icon.
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26,
           let iconURL = Bundle.main.url(forResource: "TimbrBrandIcon", withExtension: "png"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
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
        // Emergency exit for the fail-closed mute (ADR-0017): unmutes every app timbr ever muted, even
        // after timbr crashed or was removed. `Timbr --release-all-mutes`
        if launchArgs.contains("--release-all-mutes") {
            let dir = launchArgs.firstIndex(of: "--mute-dir").flatMap { $0 + 1 < launchArgs.count ? URL(fileURLWithPath: launchArgs[$0 + 1]) : nil }
            let client = MuteKeeperClient(directory: dir ?? MuteKeeperProtocol.defaultDirectory())
            let held = client.survivingMutes().map(\.bundleID)
            client.releaseAll()
            print("[release-all-mutes] unmuted \(held.count): \(held.joined(separator: ", "))")
            exit(0)
        }
        // Fail-closed mute proof (ADR-0017): `Timbr --selftest-mute-persistence <report.json>`.
        if let i = launchArgs.firstIndex(of: "--selftest-mute-persistence") {
            let url = URL(fileURLWithPath: i + 1 < launchArgs.count ? launchArgs[i + 1] : NSTemporaryDirectory() + "timbr-mutetest.json")
            Task { @MainActor in
                let r = await MutePersistenceSelfTest.run(reportURL: url)
                print("[selftest-mute-persistence] allPassed=\(r.allPassed) → \(url.path)")
                NSApp.terminate(nil)
            }
            return
        }
        // Child of the test above: a player with a real bundle ID (afplay has none), to prove that a
        // surviving mute follows the app across a relaunch.
        if let i = launchArgs.firstIndex(of: "--selftest-tone"), i + 1 < launchArgs.count,
           let sound = NSSound(contentsOf: URL(fileURLWithPath: launchArgs[i + 1]), byReference: true) {
            sound.loops = true
            sound.play()
            selfTestTone = sound
            // Latency probes: `--pause-after <s> <timestamp file>` pauses (or `--stop-after`) and records the wall clock.
            for (flag, isStop) in [("--pause-after", false), ("--stop-after", true)] {
                if let k = launchArgs.firstIndex(of: flag), k + 2 < launchArgs.count, let secs = Double(launchArgs[k + 1]) {
                    let file = URL(fileURLWithPath: launchArgs[k + 2])
                    DispatchQueue.main.asyncAfter(deadline: .now() + secs) {
                        try? String(format: "%.4f", Date().timeIntervalSince1970).write(to: file, atomically: true, encoding: .utf8)
                        if isStop { sound.stop() } else { sound.pause() }
                    }
                }
            }
            return
        }
        // Child of the test above: holds a mute until it is SIGKILLed.
        if let i = launchArgs.firstIndex(of: "--selftest-mute-holder"), i + 2 < launchArgs.count, let pid = pid_t(launchArgs[i + 1]) {
            let dir = URL(fileURLWithPath: launchArgs[i + 2], isDirectory: true)
            Task { @MainActor in
                self.selfTestMuteHolder = await MutePersistenceSelfTest.runHolder(pid: pid, directory: dir)
                if self.selfTestMuteHolder == nil { exit(2) }
            }
            return
        }
        // Opening a copy on the disk image can grant privileges to the wrong bundle location.
        let bundleURL = Bundle.main.bundleURL
        if bundleURL.path.hasPrefix("/Volumes/"),
           (try? bundleURL.resourceValues(forKeys: [.volumeIsReadOnlyKey]).volumeIsReadOnly) == true,
           !AppState.isAuxiliaryInstance {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.icon = NSApp.applicationIconImage
            alert.messageText = appState.t("onboard.install.title")
            alert.informativeText = appState.t("onboard.install.body")
            alert.addButton(withTitle: appState.t("onboard.install.show_disk"))
            alert.addButton(withTitle: appState.t("onboard.install.close"))
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
            }
            NSApp.terminate(nil)
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
            // Design review: `--studio-scroll <0…1>` scrolls the page to that fraction of its height.
            if let k = args.firstIndex(of: "--studio-scroll"), k + 1 < args.count, let frac = Double(args[k + 1]) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    @MainActor func scrollView(in v: NSView?) -> NSScrollView? {
                        guard let v else { return nil }
                        if let s = v as? NSScrollView, s.documentView != nil { return s }
                        for sub in v.subviews { if let s = scrollView(in: sub) { return s } }
                        return nil
                    }
                    guard let sv = scrollView(in: self?.studioWindow?.contentView), let doc = sv.documentView else { return }
                    let y = max(0, (doc.frame.height - sv.contentView.bounds.height) * CGFloat(frac))
                    doc.scroll(NSPoint(x: 0, y: doc.isFlipped ? y : doc.frame.height - sv.contentView.bounds.height - y))
                }
            }
        }
        // Design review: `--eq-mode four|five|ten|free`, optionally with `--eq-demo` (a few bands moved).
        if let i = args.firstIndex(of: "--eq-mode"), i + 1 < args.count {
            let mode: AppState.EQMode? = ["four": .four, "five": .five, "ten": .ten, "free": .free][args[i + 1]]
            if let mode {
                appState.setEQMode(mode)
                if args.contains("--eq-demo") {
                    switch mode {
                    case .free:
                        for (n, g) in [(0, 4.0), (2, -3.0)] where n < appState.activePreset.tasteBands.count {
                            var b = appState.activePreset.tasteBands[n]; b.gainDB = g; b.freqHz = n == 2 ? 2400 : 90; appState.updateTasteBand(b)
                        }
                    default:
                        for (n, g) in [(0, 3.0), (2, -2.0), (3, 2.5)] { appState.setLayoutGain(g, at: n) }
                    }
                }
            }
        }
        // Design review: `--reduce-motion` behaves as if the system setting were on.
        if args.contains("--reduce-motion") { TimbreMotion.reducedOverride = true }
        // Latency probe: `--review-crossfeed` keeps the global tap (and so the silence measurement) alive while audio plays.
        if let i = args.firstIndex(of: "--feedback-demo"), i + 1 < args.count { appState.feedbackText = args[i + 1]; appState.feedbackCategory = .suggestion }
        if args.contains("--listening-demo") { appState.applyListeningDemo() }
        if args.contains("--review-instant-pause") { appState.instantPauseDetection = true; appState.syncDSPAndTap() }
        if args.contains("--review-crossfeed") { appState.activePreset.crossfeedEnabled = true; appState.syncDSPAndTap() }
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
        if args.contains("--timeline-preview") {
            let win = NSWindow(contentViewController: NSHostingController(rootView: TimelinePreview(appState: appState)))
            win.styleMask = [.titled, .fullSizeContentView]
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.setFrameTopLeftPoint(NSPoint(x: 80, y: (NSScreen.main?.frame.maxY ?? 900) - 80))
            win.orderFrontRegardless()
            reviewWindow = win
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

    /// Quitting from our own UI while apps are muted asks whether the silence should outlive timbr
    /// (ADR-0017). Logout, restart, shutdown and scripted quits never block: they keep the mutes.
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let muted = appState.persistentlyMutedAppNames
        guard !muted.isEmpty, NSAppleEventManager.shared().currentAppleEvent == nil else { return .terminateNow }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = appState.t("ui.quit_mute.title")
        alert.informativeText = String(format: appState.t("ui.quit_mute.body"), muted.joined(separator: ", "))
        alert.addButton(withTitle: appState.t("ui.quit_mute.keep"))       // default: the safe choice
        alert.addButton(withTitle: appState.t("ui.quit_mute.restore"))
        alert.addButton(withTitle: appState.t("ui.quit_mute.cancel"))
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .terminateNow
        case .alertSecondButtonReturn:
            appState.releasePersistentMutes()
            return .terminateNow
        default:
            return .terminateCancel
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
            win.title = "timbr"
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
            win.title = "timbr"
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
