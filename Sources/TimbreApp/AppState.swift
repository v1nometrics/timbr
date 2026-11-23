// SPDX-License-Identifier: MPL-2.0
import Foundation
import AppKit
import Carbon
import Combine
import TimbreCore
import TimbreEngine
import TimbreDesignSystem

@MainActor
public final class GlobalHotKeyManager {
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandler: EventHandlerRef?
    private var callbacks: [UInt32: @MainActor () -> Void] = [:]
    private static weak var activeInstance: GlobalHotKeyManager?

    public init() {}

    public func registerDefaults(
        onToggleExpanded: @escaping @MainActor () -> Void,
        onToggleBypass: @escaping @MainActor () -> Void,
        onToggleAB: @escaping @MainActor () -> Void,
        onNextOutput: @escaping @MainActor () -> Void,
        onToggleMicMute: @escaping @MainActor () -> Void,
        onOpenStudio: @escaping @MainActor () -> Void
    ) {
        unregisterAll()
        Self.activeInstance = self

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                guard let event else { return noErr }
                var hotKeyID = EventHotKeyID()
                let err = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if err == noErr {
                    let id = hotKeyID.id
                    Task { @MainActor in
                        GlobalHotKeyManager.activeInstance?.callbacks[id]?()
                    }
                }
                return noErr
            },
            1,
            &spec,
            nil,
            &eventHandler
        )
        guard status == noErr else { return }

        let mods = UInt32(optionKey | cmdKey)
        register(id: 1, keyCode: UInt32(kVK_ANSI_V), modifiers: mods, action: onToggleExpanded)
        register(id: 2, keyCode: UInt32(kVK_ANSI_B), modifiers: mods, action: onToggleBypass)
        register(id: 3, keyCode: UInt32(kVK_ANSI_A), modifiers: mods, action: onToggleAB)
        register(id: 4, keyCode: UInt32(kVK_ANSI_O), modifiers: mods, action: onNextOutput)
        register(id: 5, keyCode: UInt32(kVK_ANSI_M), modifiers: mods, action: onToggleMicMute)
        register(id: 6, keyCode: UInt32(kVK_ANSI_Comma), modifiers: mods, action: onOpenStudio)
    }

    private func register(id: UInt32, keyCode: UInt32, modifiers: UInt32, action: @escaping @MainActor () -> Void) {
        callbacks[id] = action
        var hotKeyRef: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: OSType(0x544D4252), id: id) // 'TMBR'
        let status = RegisterEventHotKey(keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status == noErr {
            hotKeyRefs.append(hotKeyRef)
        }
    }

    public func unregisterAll() {
        for ref in hotKeyRefs {
            if let ref { UnregisterEventHotKey(ref) }
        }
        hotKeyRefs.removeAll()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        callbacks.removeAll()
    }
}

public enum HUDKind: String, Sendable { case volume, brightness }

public enum NotchState: String, Sendable {
    case resting
    case compact
    case hud
    case peek
    case expanded
}

public enum StudioTab: String, CaseIterable, Identifiable {
    case mixer
    case equalizer
    case observatory
    case settings
    case support

    public var id: String { rawValue }
}

@MainActor
public final class AppState: ObservableObject {
    // Subsystems
    public let halManager = HALManager()
    /// Review, smoke and self-test instances run next to the real app: they get no mute keeper, so they
    /// can never rewrite or release the mutes the real instance holds (ADR-0017).
    nonisolated static let isAuxiliaryInstance: Bool = {
        let aux = ["--review-empty", "--review-multi", "--smoke-check", "--demo", "--notch", "--studio", "--panel-preview", "--onboarding"]
        return ProcessInfo.processInfo.arguments.contains { aux.contains($0) || $0.hasPrefix("--selftest") }
    }()
    public let tapEngine = ProcessTapEngine(muteKeeper: AppState.isAuxiliaryInstance ? nil : MuteKeeperClient())
    public let m4Driver = Momentum4Driver()
    public let airPodsAdapter = AirPodsProAdapter()
    public let mediaKeyTap = MediaKeyTap()
    public let hotKeyManager = GlobalHotKeyManager()
    public let gpTrainer = PairwiseGPTrainer()
    public private(set) var store: SQLiteStore?
    public private(set) var ipcServer: ExtensionIPCServer?

    // Localization & UI Surface
    @Published public var language: TimbreLanguage = .ptBR {
        didSet { try? store?.setKV("language", value: language.rawValue) }
    }
    @Published public var selectedTab: StudioTab = .mixer
    @Published public var useLightSurface: Bool = false

    // Notch State
    @Published public var notchState: NotchState = .resting
    @Published public var notchEnabled: Bool = true
    @Published public var showCompactActivity: Bool = true
    @Published public var hideNotchInFullscreen: Bool = true
    @Published public private(set) var isFullscreenActive: Bool = false
    @Published public var menuBarOnlyMode: Bool = false
    /// User preference: also show the icon in the menu bar while the notch is active (default off —
    /// the notch is the app's home; right-click it for Studio, Settings and Quit).
    @Published public var showMenuBarIcon: Bool = false
    /// Some connected screen has a camera housing (notch).
    @Published public private(set) var notchScreenAvailable: Bool = NSScreen.screens.contains { $0.safeAreaInsets.top > 0 }
    /// The menu bar icon is needed whenever the notch is not the way in: no notch screen, notch
    /// turned off, menu-bar-only mode — or the person asked for it.
    public var menuBarIconVisible: Bool { showMenuBarIcon || menuBarOnlyMode || !notchEnabled || !notchScreenAvailable }
    private var screenWatch: AnyCancellable?
    @Published public var competingNotchApps: [String] = []
    @Published public var hudTitle: String = ""
    @Published public var hudValue: Double = 0.0
    @Published public var hudMuted: Bool = false
    /// What the HUD is showing (volume or display brightness).
    @Published public var hudKind: HUDKind = .volume

    // Audio Devices & Sources
    @Published public var devices: [AudioDeviceDescriptor] = []
    @Published public var sources: [AudioSourceDescriptor] = []
    @Published public var tabUpdates: [TabAudioUpdate] = []
    @Published public var globalMicMuted: Bool = false
    @Published public var isProcessingBypassed: Bool = false
    @Published public var autoDuckOnCall: Bool = true
    @Published public var mirrorOutputUIDs: Set<String> = []
    @Published public var outputDelaysMs: [String: Double] = [:]

    // EQ & Presets
    @Published public var activePreset: TimbrePreset
    @Published public var savedPresets: [TimbrePreset] = []
    @Published public var abMode: ABCompareMode = .full
    @Published public var blindABActive: Bool = false
    @Published public var blindXIsFull: Bool = Bool.random()
    @Published public var blindCurrentIsX: Bool = true
    @Published public var blindRevealed: Bool = false
    @Published public var undoTasteStack: [[EQBand]] = []

    // AI & Bayesian Taste Trainer
    @Published public var aiPromptText: String = ""
    @Published public var aiProposals: [EQDeltaProposal] = []
    @Published public var aiStatusMessage: String = ""
    @Published public var trainerHistory: [PairwiseComparison] = []
    @Published public var trainerPair: (TasteVector, TasteVector)
    @Published public var trainerListeningB: Bool = false

    // Telemetry, Observatory & Guardian
    @Published public var telemetry: DSPTelemetrySnapshot = .idle
    @Published public var meterBallisticsL = AudioMeterBallistics()
    @Published public var meterBallisticsR = AudioMeterBallistics()
    /// Hardware volume of the active output (0…1), nil when the device has no settable volume.
    @Published public private(set) var activeOutputVolume: Double?
    /// The active output is muted at the device (the master mute macOS shows in Control Center).
    @Published public private(set) var activeOutputMuted: Bool = false
    /// Nothing can be heard from any app: master muted or at zero. Per-app controls are then moot.
    public var outputSilenced: Bool { activeOutputMuted || (activeOutputVolume.map { $0 < OutputVolumeBehavior.zeroThreshold } ?? false) }
    /// Per-app limiter reduction (dB, rounded to 0.5), only for apps the limiter is actually holding.
    @Published public private(set) var sourceLimiterDB: [String: Double] = [:]
    private var telemetryTick = 0
    @Published public var driverTelemetry: HardwareDriverTelemetry?
    @Published public var guardianAlerts: [GuardianAlert] = []
    @Published public var mutedGuardianPairs: Set<String> = []
    @Published public var silentStudioMode: Bool = false
    @Published public var recentEvents: [ObservatoryEvent] = []
    @Published public var statusBanner: String?

    // Permissions status
    @Published public var accessibilityGranted: Bool = false
    private var accessibilityPromptedThisLaunch = false
    @Published public var ipcPortActive: Bool = false

    // First-run onboarding (RF-1401)
    @Published public var needsOnboarding: Bool = true
    @Published public var showOnboarding: Bool = false

    private var refreshTimer: Timer?
    private let processMonitor = AudioProcessMonitor()
    private var lastLoggedTapFailure: String?
    /// Last time any source was playing; the global EQ tap is torn down this long after silence.
    private var lastAudioActivityAt = Date.distantPast
    static let globalTapGraceSeconds: TimeInterval = 10
    private var telemetryTimer: Timer?
    private var hudDismissWorkItem: DispatchWorkItem?
    private var compactDismissWorkItem: DispatchWorkItem?
    private var expectedOutputUID: String?
    private var started = false

    public var openStudioHandler: (() -> Void)?
    public var presentOnboardingHandler: (() -> Void)?
    public var dismissOnboardingHandler: (() -> Void)?

    public init() {
        let defaultPreset = TimbrePreset(
            name: "Neutral Studio",
            simpleTaste: .neutral,
            useAdvancedPEQ: false,
            crossfeedEnabled: false,
            limiterCeilingDBTP: -0.3
        )
        self.activePreset = defaultPreset
        self.trainerPair = gpTrainer.proposeNextPair(history: [], seed: 42)
        self.language = TimbreLanguage.fromSystemLocale()
    }

    public func t(_ key: String) -> String {
        TimbreStrings.get(key, lang: language)
    }

    public var activeOutputDevice: AudioDeviceDescriptor? {
        devices.first(where: { $0.isDefaultOutput && $0.outputChannels > 0 })
            ?? devices.first(where: { $0.outputChannels > 0 })
    }

    public var activeInputDevice: AudioDeviceDescriptor? {
        devices.first(where: { $0.isDefaultInput && $0.inputChannels > 0 })
            ?? devices.first(where: { $0.inputChannels > 0 })
    }

    public var outputDevices: [AudioDeviceDescriptor] {
        devices.filter { $0.outputChannels > 0 }
    }

    public var inputDevices: [AudioDeviceDescriptor] {
        devices.filter { $0.inputChannels > 0 }
    }

    public var activeTapsCount: Int {
        guard !isProcessingBypassed else { return 0 }
        let engineCount = tapEngine.activeTapCount
        if engineCount > 0 { return engineCount }
        let eqActive = activePreset.allEffectiveBands.contains { $0.enabled && abs($0.gainDB) > 0.01 }
        let anySourceTap = sources.contains { $0.needsProcessingTap && !$0.isVoIPExcluded }
        let anyMirror = !mirrorOutputUIDs.isEmpty
        return (eqActive || activePreset.crossfeedEnabled || anySourceTap || anyMirror) ? 1 : 0
    }

    public var isVoIPCallActive: Bool {
        sources.contains { $0.isVoIPExcluded && $0.isPlaying }
    }

    public func start() {
        guard !started else { return }
        started = true

        if halManager.recoverLeftoverSnapshotIfPresent() {
            logEvent(category: "recovery", message: "Restored leftover HAL snapshot after unexpected exit (P3)")
        }
        halManager.captureInitialSnapshotIfNeeded()
        halManager.startSystemWatchdog { [weak self] in
            Task { @MainActor in self?.refreshSystemState() }
        }

        let isSmoke = ProcessInfo.processInfo.arguments.contains("--smoke-check")

        if let db = try? SQLiteStore() {
            self.store = db
            if let langStr = db.getKV("language"), let savedLang = TimbreLanguage(rawValue: langStr) {
                self.language = savedLang
            }
            self.mutedGuardianPairs = db.loadMutedPairs()
            self.silentStudioMode = (db.getKV("silentStudioMode") == "1")
            self.showCompactActivity = (db.getKV("showCompactActivity") ?? "1") == "1"
            self.hideNotchInFullscreen = (db.getKV("hideNotchInFullscreen") ?? "1") == "1"
            self.showMenuBarIcon = db.getKV("showMenuBarIcon") == "1"
            self.autoDuckOnCall = (db.getKV("autoDuckOnCall") ?? "1") == "1"
            self.savedPresets = db.loadPresets()
            if let first = self.savedPresets.first {
                self.activePreset = first
            }
            self.recentEvents = db.loadRecentEvents(limit: 80)
            let completed = db.getKV("onboardingCompleted") == "1"
            self.needsOnboarding = !completed && !isSmoke
        } else {
            self.needsOnboarding = !isSmoke
        }

        if isSmoke {
            self.needsOnboarding = false
            self.showOnboarding = false
        }

        let server = ExtensionIPCServer { [weak self] update in
            Task { @MainActor in
                self?.handleTabUpdate(update)
            }
        }
        self.ipcServer = server
        do {
            try server.start(port: 48192)
            self.ipcPortActive = true
        } catch {
            self.ipcPortActive = false
            logEvent(category: "ipc", message: "Extension IPC port 48192 unavailable: \(error.localizedDescription)")
        }

        watchMenuBarIconVisibility()

        // Fail-closed mutes (ADR-0017): apps muted before timbr. last exited — crash, SIGKILL, update —
        // are still held by timbr-mute-keeper. Adopt them before the first reconcile, or it would
        // publish "nothing muted" and the keeper would let them play.
        if let keeper = tapEngine.muteKeeper {
            let survivors = keeper.survivingMutes().map(\.bundleID)
            if !survivors.isEmpty {
                sources = PersistentMutePolicy.mergeSurvivingMutes(survivors, into: sources, displayName: Self.appDisplayName(bundleID:))
                let names = survivors.map { Self.appDisplayName(bundleID: $0) ?? $0 }.joined(separator: ", ")
                logEvent(category: "recovery", message: "Kept muted after timbr. restarted: \(names)")
                statusBanner = String(format: t("ui.mute.survived"), names)
            }
        }

        // Continuity BLE starts only when an Apple accessory is the active output (TCC honesty).
        refreshSystemState()
        setupMediaKeysIfGranted()

        hotKeyManager.registerDefaults(
            onToggleExpanded: { [weak self] in self?.toggleExpandedNotch() },
            onToggleBypass: { [weak self] in self?.toggleBypass() },
            onToggleAB: { [weak self] in self?.toggleABNeutral() },
            onNextOutput: { [weak self] in self?.cycleNextOutput() },
            onToggleMicMute: { [weak self] in self?.toggleGlobalMicMute() },
            onOpenStudio: { [weak self] in self?.openStudioHandler?() }
        )

        // Sources appear/disappear as Core Audio reports them; the timer is only a fallback.
        processMonitor.start { [weak self] in
            Task { @MainActor in self?.refreshSystemState() }
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshSystemState() }
        }
        telemetryTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollTelemetry() }
        }

        logEvent(category: "lifecycle", message: "timbr. started (MPL-2.0, 100% local, 0 telemetry)")

        if needsOnboarding {
            showOnboarding = true
            DispatchQueue.main.async { [weak self] in
                self?.presentOnboardingHandler?()
            }
        }
    }

    public func completeOnboarding(openStudio: Bool) {
        needsOnboarding = false
        showOnboarding = false
        try? store?.setKV("onboardingCompleted", value: "1")
        try? store?.setKV("language", value: language.rawValue)
        dismissOnboardingHandler?()
        logEvent(category: "onboarding", message: "First-run introduction completed")
        if openStudio {
            openStudioHandler?()
        }
    }

    public func replayOnboarding() {
        needsOnboarding = true
        showOnboarding = true
        try? store?.setKV("onboardingCompleted", value: "0")
        presentOnboardingHandler?()
    }

    nonisolated static func appDisplayName(bundleID: String) -> String? {
        if let client = SystemAudioClient(bundleID: bundleID) { return TimbreStrings.get(client.nameKey, lang: .fromSystemLocale()) }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    /// Names of the apps whose mute will outlive timbr. if it quits now (ADR-0017).
    public var persistentlyMutedAppNames: [String] {
        // Only what the keeper confirmed: an app it does not hold would play again on quit.
        guard let held = tapEngine.muteKeeper?.confirmedHeld(), !held.isEmpty else { return [] }
        return sources.filter { PersistentMutePolicy.isSilenced($0) && held.contains($0.bundleID) }.map(\.name)
    }

    /// "Restore sound and quit": the user chose to hear the muted apps again.
    public func releasePersistentMutes() {
        tapEngine.muteKeeper?.releaseAll()
        for i in sources.indices where sources[i].isMuted { sources[i].isMuted = false }
        logEvent(category: "mixer", message: "Released every app mute before quitting")
    }

    public func shutdown() {
        refreshTimer?.invalidate()
        processMonitor.stop()
        telemetryTimer?.invalidate()
        halManager.stopSystemWatchdog()
        hotKeyManager.unregisterAll()
        mediaKeyTap.stop()
        ipcServer?.stop()
        tapEngine.stopAndDestroyTap()
        halManager.restoreSnapshotIfModified()
    }

    public func setupMediaKeysIfGranted() {
        accessibilityGranted = MediaKeyTap.isAccessibilityGranted
        if accessibilityGranted {
            try? store?.setKV("accessibilityWasGranted", value: "1")
            if !mediaKeyTap.isRunning {
                let ok = mediaKeyTap.start { [weak self] action in
                    Task { @MainActor in self?.handleMediaKey(action) }
                }
                logEvent(category: "system", message: ok ? "Volume and brightness keys handled by the notch" : "Could not install the media key tap")
            }
        } else if store?.getKV("accessibilityWasGranted") == "1", !accessibilityPromptedThisLaunch {
            // The grant existed but no longer applies (typically: the app's signature changed after an
            // update). Say so, and ask again, instead of silently falling back to the system HUD.
            accessibilityPromptedThisLaunch = true
            logEvent(category: "system", message: "Accessibility permission no longer applies to this build; volume and brightness keys fall back to macOS")
            let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary   // kAXTrustedCheckOptionPrompt
            _ = AXIsProcessTrustedWithOptions(opts)
        }
    }

    private func handleMediaKey(_ action: MediaKeyAction) {
        switch action {
        case .brightnessUp(let fine), .brightnessDown(let fine):
            let step = fine ? 1.0 / 64.0 : 1.0 / 16.0
            let up: Bool = { if case .brightnessUp = action { return true }; return false }()
            let cur = DisplayBrightness.get() ?? 0.5
            // Snap to the 1/16 grid like macOS so repeated presses land on the same notches.
            let next = min(1, max(0, ((cur + (up ? step : -step)) / step).rounded() * step))
            DisplayBrightness.set(next)
            triggerHUD(title: t("ui.hud.brightness"), value: next, muted: false, kind: .brightness)
            return
        default:
            break
        }
        guard let out = activeOutputDevice else { return }
        let currentVol = Double(halManager.readOutputVolumeScalar(deviceID: out.audioObjectID) ?? 0.5)
        let currentMute = halManager.readOutputMute(deviceID: out.audioObjectID) ?? false

        let stepAction: OutputVolumeBehavior.MediaKeyStepAction
        switch action {
        case .volumeUp(let fine): stepAction = .volumeUp(step: fine ? 0.015625 : 0.0625)
        case .volumeDown(let fine): stepAction = .volumeDown(step: fine ? 0.015625 : 0.0625)
        case .muteToggle: stepAction = .muteToggle
        case .brightnessUp, .brightnessDown: return
        }
        let transition = OutputVolumeBehavior.evaluateMediaKey(
            currentVolume: currentVol,
            currentMuted: currentMute,
            isHWMuteSettable: out.isHWMuteSettable,
            action: stepAction
        )
        if let scalar = transition.scalar {
            _ = halManager.setOutputVolumeScalar(deviceID: out.audioObjectID, value: Float32(scalar))
        }
        let muteApplied = out.isHWMuteSettable ? halManager.setOutputMute(deviceID: out.audioObjectID, muted: transition.muted) : false
        activeOutputVolume = transition.displayVolume
        if muteApplied || !transition.muted {
            activeOutputMuted = transition.muted && out.isHWMuteSettable
        }
        triggerHUD(title: out.name, value: transition.displayVolume, muted: transition.hudMuted)
    }

    public func triggerHUD(title: String, value: Double, muted: Bool, kind: HUDKind = .volume) {
        hudKind = kind
        hudTitle = title
        hudValue = value
        hudMuted = muted
        if notchEnabled && !menuBarOnlyMode && notchState != .expanded {
            notchState = .hud
            hudDismissWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }
                if self.notchState == .hud {
                    self.notchState = self.shouldShowCompact ? .compact : .resting
                }
            }
            hudDismissWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: item)
        }
    }

    public var shouldSuppressNotchChrome: Bool {
        hideNotchInFullscreen && isFullscreenActive
    }

    public var shouldShowCompact: Bool {
        showCompactActivity && !menuBarOnlyMode && notchEnabled && !shouldSuppressNotchChrome && sources.contains(where: { $0.isPlaying })
    }

    public func toggleExpandedNotch() {
        guard notchEnabled && !menuBarOnlyMode else {
            openStudioHandler?()
            return
        }
        if notchState == .expanded {
            notchState = shouldShowCompact ? .compact : .resting
        } else {
            notchState = .expanded
        }
    }

    public func setNotchHover(_ hovering: Bool) {
        guard notchEnabled && !menuBarOnlyMode else { return }
        if hovering {
            if notchState == .resting || notchState == .compact {
                notchState = .peek
            }
        } else {
            if notchState == .peek {
                notchState = shouldShowCompact ? .compact : .resting
            }
        }
    }

    public func refreshSystemState() {
        var newDevices = halManager.enumerateDevices()
        // Preserve Momentum 4 active/passive analog impedance toggle across refreshes
        if let prevImpedance = devices.first(where: { $0.analogImpedanceMode != nil })?.analogImpedanceMode {
            for idx in newDevices.indices where newDevices[idx].name.localizedCaseInsensitiveContains("MOMENTUM 4") {
                newDevices[idx].analogImpedanceMode = prevImpedance
            }
        }
        self.devices = newDevices
        refreshActiveOutputVolume()
        if expectedOutputUID == nil {
            expectedOutputUID = activeOutputDevice?.uid
        }

        // `--review-empty` / `--review-multi`: visual review states without touching live audio taps.
        let launchArgs = ProcessInfo.processInfo.arguments
        if launchArgs.contains("--review-empty") {
            self.sources = []
        } else if launchArgs.contains("--review-multi") {
            if self.sources.isEmpty {
                let now = Date()
                var chrome = AudioSourceDescriptor(bundleID: "com.google.Chrome", name: "Google Chrome", volume: 0.72, isPlaying: true, lastActiveAt: now)
                chrome.playingSince = now
                var spotify = AudioSourceDescriptor(bundleID: "com.spotify.client", name: "Spotify", volume: 1.0, isPlaying: true, lastActiveAt: now.addingTimeInterval(-35))
                spotify.playingSince = now.addingTimeInterval(-35)
                self.sources = [chrome, spotify]
            }
        } else {
            self.sources = tapEngine.enumerateRunningAudioSources(existing: self.sources, recentlyStarted: processMonitor.drainRecentlyStarted()).map { src in
                guard let client = SystemAudioClient(bundleID: src.bundleID) else { return src }
                var s = src
                s.name = t(client.nameKey)
                return s
            }
        }
        self.competingNotchApps = CompetingNotchDetector.detectRunningCompetitors()
        // Permission granted (or regained) while running → take the keys over without a restart.
        if MediaKeyTap.isAccessibilityGranted != accessibilityGranted || (accessibilityGranted && !mediaKeyTap.isRunning) {
            setupMediaKeysIfGranted()
        }

        if let out = activeOutputDevice {
            if m4Driver.matches(device: out) {
                self.driverTelemetry = m4Driver.readTelemetry(for: out)
            } else if airPodsAdapter.matches(device: out) {
                self.driverTelemetry = airPodsAdapter.readTelemetry(for: out)
            } else {
                self.driverTelemetry = nil
            }
        } else {
            self.driverTelemetry = nil
        }

        syncDSPAndTap()
        evaluateGuardian()

        // Transition Compact <-> Resting cleanly when audio starts/stops
        if notchState == .resting && shouldShowCompact {
            notchState = .compact
        } else if notchState == .compact && !shouldShowCompact {
            compactDismissWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }
                if self.notchState == .compact && !self.shouldShowCompact {
                    self.notchState = .resting
                }
            }
            compactDismissWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: item)
        }
    }

    private func pollTelemetry() {
        let snap = tapEngine.readTelemetry()
        self.telemetry = snap
        if hasLiveSignal {
            meterBallisticsL.step(sampleDB: snap.truePeakL, dtSeconds: 1.0 / 30.0)
            meterBallisticsR.step(sampleDB: snap.truePeakR, dtSeconds: 1.0 / 30.0)
        } else if meterBallisticsL.smoothedDB > meterBallisticsL.floorDB || meterBallisticsR.smoothedDB > meterBallisticsR.floorDB {
            meterBallisticsL.clearImmediately()
            meterBallisticsR.clearImmediately()
        }
        telemetryTick &+= 1
        if telemetryTick % 8 == 0 {   // ~4 Hz is plenty for a status line
            let held = tapEngine.limiterReductionByApp()
                .filter { $0.value < -1.0 }
                .mapValues { ($0 * 2).rounded() / 2 }
            if held != sourceLimiterDB { sourceLimiterDB = held }
        }
    }

    public func resetClipLatch() {
        meterBallisticsL.resetClip()
        meterBallisticsR.resetClip()
    }

    public func syncDSPAndTap() {
        let out = activeOutputDevice
        let ceiling = out?.recommendedLimiterCeilingDBTP ?? -0.3
        if abs(activePreset.limiterCeilingDBTP - ceiling) > 0.01 {
            activePreset.limiterCeilingDBTP = ceiling
        }
        let effectiveAB: ABCompareMode = isProcessingBypassed ? .bypassEqualLatency : abMode
        let duckFactor: Double = outputSilenced ? 0.0 : ((autoDuckOnCall && isVoIPCallActive) ? 0.25 : 1.0)
        let mirrorTargets: [MirrorOutputTarget] = outputDevices
            .filter { $0.uid != out?.uid && mirrorOutputUIDs.contains($0.uid) }
            .map { MirrorOutputTarget(device: $0, delayMs: outputDelaysMs[$0.uid] ?? 0.0) }

        let anyNonNeutralBand = activePreset.allEffectiveBands.contains { $0.enabled && abs($0.gainDB) > 0.01 }
        let anySourceTap = sources.contains { $0.needsProcessingTap && !$0.isVoIPExcluded }
        let shouldProcess = !isProcessingBypassed && (
            anyNonNeutralBand || activePreset.crossfeedEnabled || anySourceTap || duckFactor < 0.999 || !mirrorTargets.isEmpty
        )
        let excludedBundles = sources.filter { $0.isVoIPExcluded }.map { $0.bundleID }
        if sources.contains(where: { $0.isPlaying }) { lastAudioActivityAt = Date() }
        let audioActive = Date().timeIntervalSince(lastAudioActivityAt) < Self.globalTapGraceSeconds

        tapEngine.updateDSP(preset: activePreset, outputDevice: out, abMode: effectiveAB, gain: duckFactor)
        tapEngine.reconcileMultiTap(
            processingEnabled: shouldProcess,
            preset: activePreset,
            abMode: effectiveAB,
            outputDevice: out,
            sources: sources,
            excludedBundleIDs: excludedBundles,
            duckFactor: duckFactor,
            mirrorOutputs: mirrorTargets,
            audioActive: audioActive
        )
        // Surface engine failures instead of swallowing them (they used to be silent).
        let failure = tapEngine.lastFailure ?? tapEngine.muteKeeper?.lastFailure
        if failure != lastLoggedTapFailure {
            lastLoggedTapFailure = failure
            if let failure { logEvent(category: "routing", message: "Tap failed: \(failure)") }
        }
    }

    public func toggleMirrorOutput(_ device: AudioDeviceDescriptor) {
        if mirrorOutputUIDs.contains(device.uid) {
            mirrorOutputUIDs.remove(device.uid)
        } else {
            mirrorOutputUIDs.insert(device.uid)
        }
        syncDSPAndTap()
        logEvent(category: "routing", message: "Multi-output mirror \(mirrorOutputUIDs.contains(device.uid) ? "enabled" : "disabled") for \(device.name)")
    }

    public func setOutputDelay(_ device: AudioDeviceDescriptor, delayMs: Double) {
        outputDelaysMs[device.uid] = min(max(delayMs, 0.0), 250.0)
        syncDSPAndTap()
    }

    public func toggleAutoDuck(_ enabled: Bool) {
        autoDuckOnCall = enabled
        try? store?.setKV("autoDuckOnCall", value: enabled ? "1" : "0")
        syncDSPAndTap()
    }

    public func setTabVolume(browser: String, tabID: String, volume: Double) {
        let clamped = min(max(volume, 0.0), 2.0)
        if let idx = tabUpdates.firstIndex(where: { $0.tabID == tabID && $0.browser == browser }) {
            let cur = tabUpdates[idx]
            tabUpdates[idx] = TabAudioUpdate(browser: cur.browser, tabID: cur.tabID, title: cur.title, origin: cur.origin, volume: clamped, isMuted: cur.isMuted)
            ipcServer?.enqueueTabCommand(browser: browser, tabID: tabID, volume: clamped, isMuted: cur.isMuted)
        }
    }

    public func toggleTabMute(browser: String, tabID: String) {
        if let idx = tabUpdates.firstIndex(where: { $0.tabID == tabID && $0.browser == browser }) {
            let cur = tabUpdates[idx]
            let nextMute = !cur.isMuted
            tabUpdates[idx] = TabAudioUpdate(browser: cur.browser, tabID: cur.tabID, title: cur.title, origin: cur.origin, volume: cur.volume, isMuted: nextMute)
            ipcServer?.enqueueTabCommand(browser: browser, tabID: tabID, volume: cur.volume, isMuted: nextMute)
        }
    }

    public func refreshHardwareTelemetryNow() {
        guard let out = activeOutputDevice, m4Driver.matches(device: out) else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = await self.m4Driver.refreshTelemetryNow()
            self.driverTelemetry = self.m4Driver.readTelemetry(for: out)
            self.evaluateGuardian()
            self.logEvent(category: "hardware", message: "Momentum 4 read-only GAIA v3 telemetry refreshed")
        }
    }

    public func evaluateGuardian() {
        let out = activeOutputDevice
        let competingCapture = halManager.detectCompetingCaptureApps(devices: devices)
        let ctx = GuardianContext(
            activeOutput: out,
            activeInput: activeInputDevice,
            sources: sources,
            knownSourceSampleRate: tapEngine.lastSampleRate,
            limiterClipCountRecent: telemetry.clipPreventedCount,
            correctionActive: !activePreset.correctionBands.isEmpty && !isProcessingBypassed,
            driverTelemetry: driverTelemetry,
            softwareVolumeAppliedOnOutput: !(out?.supportsAnyHWVolume ?? true),
            expectedOutputUID: expectedOutputUID,
            competingCaptureApps: competingCapture
        )
        self.guardianAlerts = GuardianAnalyzer.evaluate(
            ctx,
            mutedPairs: mutedGuardianPairs,
            silentStudioMode: silentStudioMode
        )
    }

    // MARK: - User Actions
    public func toggleBypass() {
        isProcessingBypassed.toggle()
        syncDSPAndTap()
        logEvent(category: "dsp", message: isProcessingBypassed ? "Bypass enabled (0 taps)" : "DSP active")
        triggerHUD(title: isProcessingBypassed ? "Bypass (0 taps)" : "EQ Active", value: isProcessingBypassed ? 0.0 : 1.0, muted: isProcessingBypassed)
    }

    public func toggleABNeutral() {
        abMode = (abMode == .full) ? .bypassEqualLatency : .full
        syncDSPAndTap()
        triggerHUD(title: abMode == .full ? "A/B: Full" : "A/B: Neutral", value: abMode == .full ? 1.0 : 0.0, muted: false)
    }

    public func selectDefaultOutput(_ device: AudioDeviceDescriptor) {
        expectedOutputUID = device.uid
        if halManager.setDefaultOutput(uid: device.uid) {
            logEvent(category: "device", message: "Switched output to \(device.name)")
            refreshSystemState()
            let vol = Double(halManager.readOutputVolumeScalar(deviceID: device.audioObjectID) ?? 0.5)
            let muted = halManager.readOutputMute(deviceID: device.audioObjectID) ?? false
            triggerHUD(title: device.name, value: vol, muted: muted || vol < OutputVolumeBehavior.zeroThreshold)
        }
    }

    public func cycleNextOutput() {
        let outs = outputDevices
        guard outs.count > 1 else { return }
        if let idx = outs.firstIndex(where: { $0.uid == activeOutputDevice?.uid }) {
            let next = outs[(idx + 1) % outs.count]
            selectDefaultOutput(next)
        }
    }

    /// `showHUD: false` when the change comes from a control that is already on screen (e.g. the
    /// notch's own fader) — the HUD would replace the very panel the user is dragging in.
    public func setOutputVolume(_ device: AudioDeviceDescriptor, value: Double, showHUD: Bool = true) {
        let t = OutputVolumeBehavior.evaluateSetVolume(requested: value, isHWMuteSettable: device.isHWMuteSettable)
        let prevSilenced = outputSilenced
        if t.muted && device.isHWMuteSettable {
            // Engage hardware mute FIRST before lowering scalar to 0.0 so CoreAudio never sits in (scalar=0.0, mute=0).
            let muteApplied = halManager.setOutputMute(deviceID: device.audioObjectID, muted: true)
            _ = halManager.setOutputVolumeScalar(deviceID: device.audioObjectID, value: Float32(t.scalar))
            if device.uid == activeOutputDevice?.uid {
                activeOutputVolume = t.displayVolume
                if muteApplied { activeOutputMuted = true }
            }
        } else {
            _ = halManager.setOutputVolumeScalar(deviceID: device.audioObjectID, value: Float32(t.scalar))
            let muteApplied = device.isHWMuteSettable ? halManager.setOutputMute(deviceID: device.audioObjectID, muted: t.muted) : false
            if device.uid == activeOutputDevice?.uid {
                activeOutputVolume = t.displayVolume
                if muteApplied {
                    activeOutputMuted = t.muted
                } else if !t.muted {
                    activeOutputMuted = false
                }
            }
        }
        if device.uid == activeOutputDevice?.uid, outputSilenced != prevSilenced {
            syncDSPAndTap()
        }
        if showHUD { triggerHUD(title: device.name, value: t.displayVolume, muted: t.hudMuted) }
    }

    func refreshActiveOutputVolume() {
        let prevSilenced = outputSilenced
        var muted = activeOutputDevice.flatMap { halManager.readOutputMute(deviceID: $0.audioObjectID) } ?? false
        guard let out = activeOutputDevice, out.isHWVolumeMasterSettable || out.isHWVolumeChannelSettable,
              let v = halManager.readOutputVolumeScalar(deviceID: out.audioObjectID) else {
            if muted != activeOutputMuted { activeOutputMuted = muted }
            if activeOutputVolume != nil { activeOutputVolume = nil }
            if outputSilenced != prevSilenced { syncDSPAndTap() }
            return
        }
        let d = Double(v)
        // Self-heal: if CoreAudio or an external control left the device at 0% (< 0.005) with mute=0,
        // engage hardware mute immediately so MacBook speakers never leak their -63.5 dB floor.
        if OutputVolumeBehavior.needsZeroVolumeMuteHeal(volume: d, muted: muted, isHWMuteSettable: out.isHWMuteSettable) {
            if halManager.setOutputMute(deviceID: out.audioObjectID, muted: true) {
                muted = true
            }
        }
        if muted != activeOutputMuted { activeOutputMuted = muted }
        let displayVol = d < OutputVolumeBehavior.zeroThreshold ? 0.0 : d
        if activeOutputVolume.map({ abs($0 - displayVol) > 0.004 }) ?? true { activeOutputVolume = displayVol }
        if outputSilenced != prevSilenced { syncDSPAndTap() }
    }

    public func setSourceVolume(bundleID: String, volume: Double) {
        guard let idx = sources.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        guard !sources[idx].isVoIPExcluded else { return }
        let new = OutputVolumeBehavior.normalizeSourceVolume(volume)
        let raising = new > sources[idx].volume + 0.0001
        sources[idx].volume = new
        // Turning an app up while the master is muted would do nothing audible: bring the master back
        // (and bump master out of 0% so unmuting never exposes CoreAudio's -63.5 dB floor).
        if raising, new >= OutputVolumeBehavior.zeroThreshold, outputSilenced { restoreOutputAudible() }
        syncDSPAndTap()
    }

    public func toggleSourceMute(bundleID: String) {
        guard let idx = sources.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        guard !sources[idx].isVoIPExcluded else { return }
        sources[idx].isMuted.toggle()
        if !sources[idx].isMuted, outputSilenced { restoreOutputAudible() }   // unmuting an app = wanting to hear it
        syncDSPAndTap()
    }

    // MARK: Master (the active output device)

    public func setOutputMuted(_ muted: Bool) {
        guard let out = activeOutputDevice else { return }
        if !muted, OutputVolumeBehavior.shouldRestoreAudibleOnUnmute(activeVolume: activeOutputVolume) {
            setOutputVolume(out, value: 0.25, showHUD: false)
            return
        }
        if halManager.setOutputMute(deviceID: out.audioObjectID, muted: muted) || !out.isHWMuteSettable {
            activeOutputMuted = muted && out.isHWMuteSettable
            syncDSPAndTap()
        }
    }

    public func toggleOutputMute() {
        if outputSilenced {
            restoreOutputAudible()
        } else {
            setOutputMuted(true)
        }
    }

    /// "Make it audible again": raise from 0% before unmuting so CoreAudio never exposes a -63.5 dB floor.
    public func restoreOutputAudible() {
        guard let out = activeOutputDevice else { return }
        if OutputVolumeBehavior.shouldRestoreAudibleOnUnmute(activeVolume: activeOutputVolume) {
            setOutputVolume(out, value: 0.25, showHUD: false)
        } else if activeOutputMuted {
            setOutputMuted(false)
        }
    }

    /// Unity / flat: all controllable app volumes → 1.0, unmuted. VoIP/DAW rows stay untouched.
    public func resetAllSourceVolumesToFlat() {
        var changed = false
        for idx in sources.indices where !sources[idx].isVoIPExcluded {
            if sources[idx].volume != 1.0 || sources[idx].isMuted {
                sources[idx].volume = 1.0
                sources[idx].isMuted = false
                changed = true
            }
        }
        for idx in tabUpdates.indices {
            let cur = tabUpdates[idx]
            if cur.volume != 1.0 || cur.isMuted {
                tabUpdates[idx] = TabAudioUpdate(
                    browser: cur.browser,
                    tabID: cur.tabID,
                    title: cur.title,
                    origin: cur.origin,
                    volume: 1.0,
                    isMuted: false
                )
                ipcServer?.enqueueTabCommand(browser: cur.browser, tabID: cur.tabID, volume: 1.0, isMuted: false)
                changed = true
            }
        }
        guard changed else { return }
        syncDSPAndTap()
        logEvent(category: "mixer", message: "Reset all source volumes to flat (1.0)")
        statusBanner = t("mixer.reset_flat_done")
    }

    public var hasNonFlatSourceVolumes: Bool {
        sources.contains { !$0.isVoIPExcluded && ($0.volume != 1.0 || $0.isMuted) }
            || tabUpdates.contains { $0.volume != 1.0 || $0.isMuted }
    }

    public func toggleGlobalMicMute() {
        globalMicMuted.toggle()
        if let inp = activeInputDevice {
            _ = halManager.setOutputMute(deviceID: inp.audioObjectID, muted: globalMicMuted)
        }
        triggerHUD(title: "Mic", value: globalMicMuted ? 0.0 : 1.0, muted: globalMicMuted)
    }

    public func toggleMomentum4Impedance() {
        guard let idx = devices.firstIndex(where: { $0.name.localizedCaseInsensitiveContains("MOMENTUM 4") }) else { return }
        let current = devices[idx].analogImpedanceMode ?? .active470Ohm
        let next: AnalogImpedanceMode = (current == .active470Ohm) ? .passive60Ohm : .active470Ohm
        devices[idx].analogImpedanceMode = next
        logEvent(category: "device", message: "Momentum 4 impedance hint set to \(next.ohms) Ω")
    }

    // MARK: - EQ & AutoEq & AI & Trainer
    public func updateSimpleTaste(_ taste: SimpleTasteControls) {
        activePreset.simpleTaste = taste
        activePreset.updatedAt = Date()
        syncDSPAndTap()
    }

    public func toggleAdvancedPEQ(_ enabled: Bool) {
        if enabled && activePreset.tasteBands.isEmpty {
            activePreset.tasteBands = activePreset.simpleTaste.toPEQBands()
        }
        activePreset.useAdvancedPEQ = enabled
        syncDSPAndTap()
    }

    public func addTasteBand() {
        guard activePreset.tasteBands.count < 24 else { return }
        activePreset.useAdvancedPEQ = true
        activePreset.tasteBands.append(EQBand(type: .peak, design: .vicanek, layer: .taste, freqHz: 1000, gainDB: 0.0, q: 1.0, enabled: true))
        syncDSPAndTap()
    }

    public func removeTasteBand(id: UUID) {
        activePreset.tasteBands.removeAll { $0.id == id }
        syncDSPAndTap()
    }

    public func updateTasteBand(_ band: EQBand) {
        guard let idx = activePreset.tasteBands.firstIndex(where: { $0.id == band.id }) else { return }
        activePreset.tasteBands[idx] = band
        activePreset.updatedAt = Date()
        syncDSPAndTap()
    }

    public func applyAutoEqEntry(_ entry: AutoEqEntry) {
        Task {
            do {
                let parsed = try await AutoEqService.loadParametricEQ(entry: entry, allowNetwork: true)
                self.activePreset.correctionBands = parsed.parsed.bands
                self.activePreset.correctionMetadata = CorrectionMetadata(
                    headphoneModel: entry.headphoneName,
                    sourceCredit: entry.source,
                    measurementRig: entry.rig,
                    targetCurve: entry.target,
                    transport: activeOutputDevice?.transport ?? .unknown
                )
                self.syncDSPAndTap()
                self.logEvent(category: "autoeq", message: "Applied AutoEq: \(entry.headphoneName) (\(entry.source))")
            } catch {
                self.statusBanner = "AutoEq load failed: \(error.localizedDescription)"
            }
        }
    }

    public func clearCorrection() {
        activePreset.correctionBands = []
        activePreset.correctionMetadata = nil
        syncDSPAndTap()
    }

    public func importEqualizerAPOFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url,
           let content = try? String(contentsOf: url, encoding: .utf8) {
            do {
                let parsed = try EqualizerAPOParser.parse(content, layer: .correction)
                activePreset.correctionBands = parsed.bands
                activePreset.correctionMetadata = CorrectionMetadata(
                    headphoneModel: url.deletingPathExtension().lastPathComponent,
                    sourceCredit: "EqualizerAPO import",
                    measurementRig: "User file",
                    targetCurve: "Custom",
                    transport: activeOutputDevice?.transport ?? .unknown
                )
                syncDSPAndTap()
                logEvent(category: "preset", message: "Imported APO preset (\(parsed.bands.count) bands)")
            } catch {
                statusBanner = "Invalid EqualizerAPO file: \(error)"
            }
        }
    }

    public func exportEqualizerAPOToPanel() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(activePreset.name.replacingOccurrences(of: " ", with: "_")).txt"
        if panel.runModal() == .OK, let url = panel.url {
            let curve = tapEngine.evaluateCurve(bands: activePreset.allEffectiveBands, freqsHz: [1000.0])
            let text = EqualizerAPOParser.export(preampDB: curve.recommendedPreampDB, bands: activePreset.allEffectiveBands)
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    public func saveCurrentPreset() {
        activePreset.updatedAt = Date()
        // RF-0404 / RF-0607: a saved preset belongs to the output it was tuned on (UID, never AudioObjectID).
        if activePreset.deviceUID == nil { activePreset.deviceUID = activeOutputDevice?.uid }
        try? store?.savePreset(activePreset)
        if let idx = savedPresets.firstIndex(where: { $0.id == activePreset.id }) {
            savedPresets[idx] = activePreset
        } else {
            savedPresets.insert(activePreset, at: 0)
        }
    }

    public func submitAIPrompt() {
        let prompt = aiPromptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        Task {
            let proposals = await AIAssistantRouter.proposeVariants(prompt: prompt, language: language)
            self.aiProposals = proposals
            if let first = proposals.first {
                self.aiStatusMessage = "\(first.runtimeUsed.rawValue): \(proposals.count) propostas"
            }
        }
    }

    public func applyAIProposal(_ proposal: EQDeltaProposal) {
        let baseBands = activePreset.effectiveTasteBands
        undoTasteStack.append(baseBands)
        do {
            let updated = try EQDeltaValidator.apply(proposal: proposal, toTasteBands: baseBands)
            activePreset.useAdvancedPEQ = true
            activePreset.tasteBands = updated
            syncDSPAndTap()
            logEvent(category: "ai", message: "Applied AI tweak: \(proposal.label)")
        } catch {
            statusBanner = "AI proposal rejected by safety validator: \(error)"
        }
    }

    public func undoLastAITweak() {
        guard let prev = undoTasteStack.popLast() else { return }
        activePreset.tasteBands = prev
        syncDSPAndTap()
    }

    // MARK: - Blind A/B
    public func startBlindAB() {
        blindABActive = true
        blindXIsFull = Bool.random()
        blindCurrentIsX = true
        blindRevealed = false
        applyBlindMode()
    }

    public func selectBlindSample(isX: Bool) {
        blindCurrentIsX = isX
        applyBlindMode()
    }

    public func revealBlindAB() {
        blindRevealed = true
    }

    public func stopBlindAB() {
        blindABActive = false
        blindRevealed = false
        abMode = .full
        syncDSPAndTap()
    }

    private func applyBlindMode() {
        let useFull = (blindCurrentIsX && blindXIsFull) || (!blindCurrentIsX && !blindXIsFull)
        abMode = useFull ? .full : .bypassEqualLatency
        syncDSPAndTap()
    }

    // MARK: - Pairwise Taste Trainer
    public func auditionTrainerCandidate(isB: Bool) {
        trainerListeningB = isB
        let vec = isB ? trainerPair.1 : trainerPair.0
        updateSimpleTaste(vec.toSimpleTaste())
    }

    public func voteTrainerWinner(isA: Bool) {
        let comp = PairwiseComparison(candidateA: trainerPair.0, candidateB: trainerPair.1, winnerIsA: isA)
        trainerHistory.append(comp)
        trainerPair = gpTrainer.proposeNextPair(history: trainerHistory, seed: UInt64(trainerHistory.count + 42))
        let best = gpTrainer.estimateBest(history: trainerHistory)
        updateSimpleTaste(best.toSimpleTaste())
        logEvent(category: "trainer", message: "Taste Trainer round \(trainerHistory.count) voted \(isA ? "A" : "B")")
    }

    // MARK: - Guardian Actions
    public func runGuardianAction(_ alert: GuardianAlert) {
        switch alert.ruleID {
        case .g01HFP:
            if let builtInMic = inputDevices.first(where: { $0.transport == .builtIn }) {
                _ = halManager.setDefaultInput(uid: builtInMic.uid)
                logEvent(category: "guardian", message: "Forced built-in mic to avoid HFP drop")
                refreshSystemState()
            }
        case .g03Clipping:
            let boosted = activePreset.effectiveTasteBands.map { band in
                var b = band
                if b.gainDB > 0 { b.gainDB = max(0, b.gainDB - 2.0) }
                return b
            }
            activePreset.useAdvancedPEQ = true
            activePreset.tasteBands = boosted
            syncDSPAndTap()
            logEvent(category: "guardian", message: "Reduced positive EQ peaks to restore headroom")
        default:
            break
        }
    }

    public func silenceGuardianPair(_ alert: GuardianAlert) {
        let key = "\(alert.ruleID.rawValue)|\(alert.appBundleID ?? "*")|\(alert.deviceUID ?? "*")"
        mutedGuardianPairs.insert(key)
        try? store?.muteGuardianPair(key)
        evaluateGuardian()
    }

    public func toggleSilentStudio(_ enabled: Bool) {
        silentStudioMode = enabled
        try? store?.setKV("silentStudioMode", value: enabled ? "1" : "0")
        evaluateGuardian()
    }

    public func setShowMenuBarIcon(_ on: Bool) {
        showMenuBarIcon = on
        try? store?.setKV("showMenuBarIcon", value: on ? "1" : "0")
    }

    /// Keeps `notchScreenAvailable` true to the connected screens (MenuBarIconController reacts to it).
    private func watchMenuBarIconVisibility() {
        screenWatch = NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.notchScreenAvailable = NSScreen.screens.contains { $0.safeAreaInsets.top > 0 }
            }
    }

    public func toggleShowCompact(_ enabled: Bool) {
        showCompactActivity = enabled
        try? store?.setKV("showCompactActivity", value: enabled ? "1" : "0")
        if !enabled && notchState == .compact {
            compactDismissWorkItem?.cancel()
            notchState = .resting
        } else if enabled && notchState == .resting && shouldShowCompact {
            notchState = .compact
        }
    }

    public func toggleHideNotchInFullscreen(_ enabled: Bool) {
        hideNotchInFullscreen = enabled
        try? store?.setKV("hideNotchInFullscreen", value: enabled ? "1" : "0")
        syncFullscreenSuppression()
    }

    public func setFullscreenActive(_ active: Bool) {
        guard isFullscreenActive != active else { return }
        isFullscreenActive = active
        syncFullscreenSuppression()
    }

    private func syncFullscreenSuppression() {
        if shouldSuppressNotchChrome {
            compactDismissWorkItem?.cancel()
            if notchState == .compact || notchState == .peek {
                notchState = .resting
            }
        } else if notchState == .resting && shouldShowCompact {
            notchState = .compact
        }
    }

    // MARK: - Extension IPC & Diagnostics
    private func handleTabUpdate(_ update: TabAudioUpdate) {
        if let idx = tabUpdates.firstIndex(where: { $0.tabID == update.tabID && $0.browser == update.browser }) {
            tabUpdates[idx] = update
        } else {
            tabUpdates.append(update)
        }
    }

    public func exportSanitizedDiagnostics() {
        let report = SanitizedDiagnosticReport(
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            devices: devices,
            activeAlerts: guardianAlerts,
            recentEvents: recentEvents
        )
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "timbr-diagnostics-sanitized.json"
        if panel.runModal() == .OK, let url = panel.url, let json = try? report.toJSONPretty() {
            try? json.write(to: url, atomically: true, encoding: .utf8)
            logEvent(category: "diagnostics", message: "Exported sanitized JSON diagnostics")
        }
    }

    public func clearAllLocalHistory() {
        try? store?.clearAllHistory()
        recentEvents = []
        mutedGuardianPairs = []
        trainerHistory = []
    }

    public func openSystemSettingsTCC(_ pane: String) {
        // Prefer modern System Settings deep links; fall back to legacy Security pane URLs.
        let candidates: [String]
        switch pane {
        case "audio":
            candidates = [
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AudioCapture",
                "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
                "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
            ]
        case "accessibility":
            candidates = [
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            ]
        case "bluetooth":
            candidates = [
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Bluetooth",
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth"
            ]
        default:
            candidates = ["x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"]
        }
        for urlStr in candidates {
            if let url = URL(string: urlStr), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    public func logEvent(category: String, message: String, badge: SignalTrustBadge? = nil) {
        let ev = ObservatoryEvent(category: category, message: message, badge: badge, deviceUID: activeOutputDevice?.uid)
        recentEvents.insert(ev, at: 0)
        if recentEvents.count > 120 { recentEvents.removeLast(recentEvents.count - 120) }
        try? store?.saveEvent(ev)
    }
}
