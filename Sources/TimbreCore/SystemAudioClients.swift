// SPDX-License-Identifier: MPL-2.0
// macOS plays a lot of audio from daemons that have no app and no icon (systemsoundserverd,
// PowerChime, corespeechd, avconferenced…). Showing "systemsoundser…" with a letter "S" is
// meaningless to a person. This catalog groups them into a few sources people recognise, each with
// a localized name and a real icon.
import Foundation

public enum SystemAudioClient: String, CaseIterable, Sendable {
    case systemSounds = "timbr.system.sounds"
    case siri = "timbr.system.siri"
    case calls = "timbr.system.calls"
    case spokenContent = "timbr.system.spoken"
    case quickLook = "timbr.system.quicklook"
    case otherSystem = "timbr.system.other"

    public init?(bundleID: String) { self.init(rawValue: bundleID) }

    /// Localization key (TimbreStrings.uiTable).
    public var nameKey: String {
        switch self {
        case .systemSounds: return "src.system_sounds"
        case .siri: return "src.siri"
        case .calls: return "src.calls"
        case .spokenContent: return "src.spoken"
        case .quickLook: return "src.quicklook"
        case .otherSystem: return "src.other_system"
        }
    }

    /// English fallback used before the UI localizes it.
    public var defaultName: String {
        switch self {
        case .systemSounds: return "System sounds"
        case .siri: return "Siri & Dictation"
        case .calls: return "Calls"
        case .spokenContent: return "Spoken content"
        case .quickLook: return "Quick Look"
        case .otherSystem: return "Other macOS audio"
        }
    }

    /// An installed app whose icon represents this group (resolved with NSWorkspace by the UI).
    public var iconBundleID: String {
        switch self {
        case .systemSounds, .otherSystem: return "com.apple.systempreferences"
        case .siri: return "com.apple.Siri"
        case .calls: return "com.apple.FaceTime"
        case .spokenContent: return "com.apple.VoiceOverUtility"
        case .quickLook: return "com.apple.finder"
        }
    }

    /// Where clicking the source takes the person: the settings pane that controls these sounds.
    public var settingsURL: URL? {
        switch self {
        case .systemSounds, .otherSystem: return URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension")
        case .siri: return URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")
        case .spokenContent: return URL(string: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension")
        case .calls, .quickLook: return nil
        }
    }

    private static let exact: [String: SystemAudioClient] = [
        // Alerts, notification sounds, charger chime, AirPods connect chimes, login sound.
        "systemsoundserverd": .systemSounds, "com.apple.systemsoundserverd": .systemSounds,
        "com.apple.PowerChime": .systemSounds, "com.apple.notificationcenterui": .systemSounds,
        "com.apple.loginwindow": .systemSounds, "com.apple.controlcenter": .systemSounds,
        "com.apple.audiomxd": .systemSounds, "com.apple.mediaremoted": .systemSounds,
        "com.apple.cloudpaird": .systemSounds,
        // Siri and dictation.
        "com.apple.Siri": .siri, "com.apple.SiriNCService": .siri, "com.apple.assistantd": .siri,
        "com.apple.CoreSpeech": .siri, "com.apple.corespeechd_system": .siri,
        // FaceTime / phone / Continuity calls (protected like any call app).
        "com.apple.avconferenced": .calls, "com.apple.TelephonyUtilities": .calls,
        // VoiceOver, Spoken Content, hearing features.
        "com.apple.universalaccessd": .spokenContent, "com.apple.accessibility.heard": .spokenContent,
        "com.apple.VoiceOver": .spokenContent, "com.apple.SpeechSynthesisServerXPC": .spokenContent,
    ]

    /// Classifies a process that has no visible app. Returns nil for anything that belongs to an app.
    public static func classify(reportedBundleID: String?, executablePath: String?) -> SystemAudioClient? {
        if let b = reportedBundleID, !b.isEmpty {
            if let hit = exact[b] { return hit }
            if b.hasPrefix("com.apple.speech.") { return .spokenContent }
            if b.hasPrefix("com.apple.quicklook.") { return .quickLook }
        }
        if let p = executablePath {
            let name = (p as NSString).lastPathComponent
            if let hit = exact[name] { return hit }
        }
        return nil
    }

    /// Last resort for daemons we do not know but that clearly belong to macOS.
    public static func isSystemExecutable(_ path: String?) -> Bool {
        guard let p = path else { return false }
        return p.hasPrefix("/usr/") || p.hasPrefix("/System/") || p.hasPrefix("/Library/Apple/")
    }
}

/// What counts as "something is playing" for the notch (compact indicator, peek, expanded lead).
///
/// macOS daemons play short sounds: the error click when you press something that cannot be pressed,
/// alerts, the charger chime. They are not media the person is listening to or wants to control, and
/// the notch used to answer each one by opening the compact view with System Settings' icon for three
/// seconds. They stay in the Mixer and in the Studio (where their volume can still be set); they just
/// do not wake the notch.
public enum NotchActivityPolicy {
    public static func isTransientSystemSound(bundleID: String) -> Bool {
        switch SystemAudioClient(bundleID: bundleID) {
        case .systemSounds, .otherSystem: return true
        default: return false
        }
    }

    /// The sources as the notch should see them: transient system sounds are never "playing", and
    /// neither is an app whose own signal has been measured silent (`silent`, see `SilenceTracker`):
    /// macOS keeps "running output" on for seconds after a pause (measured 2026-11-23: 2.1 s after a
    /// stop, 3.7–7.4 s after a pause), and the notch must not wait for it when we can hear the silence.
    public static func forNotch(_ sources: [AudioSourceDescriptor], silent: Set<String> = []) -> [AudioSourceDescriptor] {
        sources.map { src in
            guard src.isPlaying, isTransientSystemSound(bundleID: src.bundleID) || silent.contains(src.bundleID) else { return src }
            var quiet = src
            quiet.isPlaying = false
            quiet.playingSince = nil
            return quiet
        }
    }
}

/// Apps that keep an audio *output* engine running while producing no sound (dictation and
/// transcription tools keep it warm for their start/stop chimes). Core Audio reports them as
/// "running output", but they are not playing anything a person would want to see or control.
/// superwhisper verified on 2026-11-22 (IsRunningOutput = 1 for minutes, no audible output).
public enum SilentOutputApps {
    public static let bundleIDs: Set<String> = [
        "com.superduper.superwhisper",
        "com.electron.wispr-flow",       // Wispr Flow
        "com.goodsnooze.MacWhisper",     // MacWhisper
    ]

    public static func contains(_ bundleID: String) -> Bool { bundleIDs.contains(bundleID) }
}
