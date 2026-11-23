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
        return visible.sorted(by: AudioSourceDescriptor.displayOrder)
    }

    /// Sources actively outputting audio right now, in stable display order (newest run first).
    var playingSources: [AudioSourceDescriptor] {
        mixerSources.filter(\.isPlaying)
    }

    /// Up to 2 distinct playing sources for the Compact indicator (lead in front, second behind).
    var compactPair: (lead: AudioSourceDescriptor, second: AudioSourceDescriptor?)? {
        let p = playingSources
        guard !p.isEmpty else { return nil }
        let lead = p.first(where: { !$0.isVoIPExcluded }) ?? p[0]
        let second = p.first(where: { $0.bundleID != lead.bundleID })
        return (lead, second)
    }

    /// What hover-without-click (Peek) controls: Output (0), Single App (1), or Master + all playing apps (2+).
    var peekTarget: NotchPeekTarget {
        NotchPeekTarget.resolve(from: mixerSources)
    }

    /// What the Expanded console leads with, unifying spotlight priority with Peek:
    /// Empty (0 playing & 0 recent), Single App (1 playing), or Master/Geral + equal apps (2+ playing or paused-only).
    var expandedTarget: NotchExpandedTarget {
        NotchExpandedTarget.resolve(from: mixerSources)
    }

    /// Legacy focus helper kept for single-source convenience.
    var focusSource: AudioSourceDescriptor? {
        let list = mixerSources
        return list.first(where: { $0.isPlaying && !$0.isVoIPExcluded })
            ?? list.first(where: { $0.isPlaying })
            ?? list.first(where: { !$0.isVoIPExcluded })
            ?? list.first
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
