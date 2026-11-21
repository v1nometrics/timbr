// SPDX-License-Identifier: MPL-2.0
// Presentation-only derivations used by every surface (notch, menu bar, Studio).
// Keeping ordering rules here guarantees the notch and the Studio never disagree (spec §4).
import Foundation
import TimbreCore
import TimbreEngine

@MainActor
extension AppState {
    /// Spec §4: playing now (most recent first) → manually muted → active in the last 10 minutes.
    var mixerSources: [AudioSourceDescriptor] {
        let horizon = Date().addingTimeInterval(-600)
        let visible = sources.filter { $0.isPlaying || $0.isMuted || $0.lastActiveAt > horizon }
        return visible.sorted { a, b in
            if a.isPlaying != b.isPlaying { return a.isPlaying }
            if a.isMuted != b.isMuted { return a.isMuted }
            return a.lastActiveAt > b.lastActiveAt
        }
    }

    /// The source the notch talks about: first playing non-call app, else the most recent one.
    var focusSource: AudioSourceDescriptor? {
        let list = mixerSources
        return list.first(where: { $0.isPlaying && !$0.isVoIPExcluded }) ?? list.first(where: { !$0.isVoIPExcluded }) ?? list.first
    }

    var playingCount: Int { sources.filter(\.isPlaying).count }

    /// One sentence that tells the whole signal-path story (ronda headline pattern).
    var signalSummary: String {
        let device = activeOutputDevice?.name ?? "—"
        if isProcessingBypassed { return String(format: t("ui.summary.bypassed"), device) }
        let taps = activeTapsCount
        if taps == 0 { return String(format: t("ui.summary.native"), device) }
        return String(format: t("ui.summary.processing"), device, Fmt.db(telemetry.preampDB))
    }

    /// RF-0404 / RF-0607: when the output changes, load the preset saved for that device UID.
    func applyPresetForActiveDevice() {
        guard let uid = activeOutputDevice?.uid,
              let match = savedPresets.first(where: { $0.deviceUID == uid }),
              match.id != activePreset.id else { return }
        activePreset = match
        syncDSPAndTap()
        logEvent(category: "preset", message: "\(match.name) → \(activeOutputDevice?.name ?? uid)", badge: .reported)
    }

    func selectDefaultInput(_ device: AudioDeviceDescriptor) {
        if halManager.setDefaultInput(uid: device.uid) { refreshSystemState() }
    }

    /// True only while audio is actually flowing through our DSP; otherwise meters show "—" (P4).
    var hasLiveSignal: Bool { !pathIsNative && playingCount > 0 }

    var pathIsNative: Bool { isProcessingBypassed || activeTapsCount == 0 }
}
