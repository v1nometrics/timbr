// SPDX-License-Identifier: MPL-2.0
import Foundation

public struct GuardianContext: Sendable {
    public let activeOutput: AudioDeviceDescriptor?
    public let activeInput: AudioDeviceDescriptor?
    public let sources: [AudioSourceDescriptor]
    public let knownSourceSampleRate: Double?
    public let limiterClipCountRecent: UInt64
    public let correctionActive: Bool
    public let driverTelemetry: HardwareDriverTelemetry?
    public let softwareVolumeAppliedOnOutput: Bool
    public let expectedOutputUID: String?
    public let competingCaptureApps: [String]

    public init(
        activeOutput: AudioDeviceDescriptor? = nil,
        activeInput: AudioDeviceDescriptor? = nil,
        sources: [AudioSourceDescriptor] = [],
        knownSourceSampleRate: Double? = nil,
        limiterClipCountRecent: UInt64 = 0,
        correctionActive: Bool = false,
        driverTelemetry: HardwareDriverTelemetry? = nil,
        softwareVolumeAppliedOnOutput: Bool = false,
        expectedOutputUID: String? = nil,
        competingCaptureApps: [String] = []
    ) {
        self.activeOutput = activeOutput
        self.activeInput = activeInput
        self.sources = sources
        self.knownSourceSampleRate = knownSourceSampleRate
        self.limiterClipCountRecent = limiterClipCountRecent
        self.correctionActive = correctionActive
        self.driverTelemetry = driverTelemetry
        self.softwareVolumeAppliedOnOutput = softwareVolumeAppliedOnOutput
        self.expectedOutputUID = expectedOutputUID
        self.competingCaptureApps = competingCaptureApps
    }
}

public enum GuardianAnalyzer {
    // C-02: Default safe ignore list for VoIP & exclusive DAWs to prevent gain/echo issues in Process Taps
    public static let defaultSafeIgnoreBundleIDs: Set<String> = [
        "us.zoom.xos",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.apple.FaceTime",
        "timbr.system.calls",            // FaceTime/phone daemons (SystemAudioClient.calls)
        "com.hnc.Discord",
        "com.cisco.webexmeetingsapp",
        "com.google.Chrome.app.kjgfgldnnfoeklkmfkjfagphfepbbdan", // Meet PWA
        "com.apple.logic10",
        "com.ableton.live",
        "com.cockos.reaper"
    ]

    public static func isVoIPOrDAWProtected(bundleID: String) -> Bool {
        defaultSafeIgnoreBundleIDs.contains(bundleID)
    }

    public static func evaluate(
        _ ctx: GuardianContext,
        mutedPairs: Set<String> = [],
        silentStudioMode: Bool = false
    ) -> [GuardianAlert] {
        var alerts: [GuardianAlert] = []

        // G-01: Bluetooth HFP drop detection
        if let out = ctx.activeOutput,
           out.transport == .bluetoothHFP || (out.transport.isBluetooth && out.sampleRate <= 16000) {
            alerts.append(GuardianAlert(
                ruleID: .g01HFP,
                severity: .warning,
                titleKey: "guard.g01",
                detail: "\(out.name) @ \(Int(out.sampleRate)) Hz",
                deviceUID: out.uid,
                suggestedActionKey: "guard.action.mic_internal"
            ))
        }

        // G-02: Sample rate mismatch
        if let srcSR = ctx.knownSourceSampleRate, let out = ctx.activeOutput,
           srcSR > 0, abs(srcSR - out.sampleRate) > 1.0 {
            alerts.append(GuardianAlert(
                ruleID: .g02Resampling,
                severity: .info,
                titleKey: "guard.g02",
                detail: "Fonte \(Int(srcSR)) Hz → \(out.name) \(Int(out.sampleRate)) Hz",
                deviceUID: out.uid
            ))
        }

        // G-03: Frequent true-peak limiter engagement
        if ctx.limiterClipCountRecent > 12 {
            alerts.append(GuardianAlert(
                ruleID: .g03Clipping,
                severity: .warning,
                titleKey: "guard.g03",
                detail: "\(ctx.limiterClipCountRecent) picos contidos",
                deviceUID: ctx.activeOutput?.uid,
                suggestedActionKey: "guard.action.increase_headroom"
            ))
        }

        // G-04: Double EQ active (headphone internal EQ != flat + Correction active)
        if ctx.correctionActive, ctx.driverTelemetry?.internalEQNonFlat == true {
            alerts.append(GuardianAlert(
                ruleID: .g04DuplicateEQ,
                severity: .warning,
                titleKey: "guard.g04",
                detail: ctx.driverTelemetry?.driverName ?? "Headphone",
                deviceUID: ctx.activeOutput?.uid
            ))
        }

        // G-05: Avoidable software volume on HW-capable DAC/speakers
        if ctx.softwareVolumeAppliedOnOutput, let out = ctx.activeOutput, out.supportsAnyHWVolume {
            alerts.append(GuardianAlert(
                ruleID: .g05AvoidableSWVolume,
                severity: .info,
                titleKey: "guard.g05",
                detail: out.name,
                deviceUID: out.uid
            ))
        }

        // G-06: Unexpected default output switch
        if let expected = ctx.expectedOutputUID, let out = ctx.activeOutput, expected != out.uid {
            alerts.append(GuardianAlert(
                ruleID: .g06UnexpectedSwitch,
                severity: .info,
                titleKey: "guard.g06",
                detail: out.name,
                deviceUID: out.uid
            ))
        }

        // G-07: Competing capture/loopback app
        if !ctx.competingCaptureApps.isEmpty {
            alerts.append(GuardianAlert(
                ruleID: .g07TapConflict,
                severity: .warning,
                titleKey: "guard.g07",
                detail: ctx.competingCaptureApps.joined(separator: ", "),
                deviceUID: ctx.activeOutput?.uid
            ))
        }

        if silentStudioMode {
            // C-07: In Silent Studio Mode, only critical/HFP alerts surface as popups; timeline logs all
            return alerts.filter { $0.severity == .critical }
        }

        return alerts.filter { alert in
            let pairKey = "\(alert.ruleID.rawValue)|\(alert.appBundleID ?? "*")|\(alert.deviceUID ?? "*")"
            return !mutedPairs.contains(pairKey)
        }
    }
}
