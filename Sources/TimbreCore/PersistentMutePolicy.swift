// SPDX-License-Identifier: MPL-2.0
// Fail-closed mute (ADR-0017): an app the user silenced in timbr stays silent even if timbr dies.
// Pure rules here (testable without Core Audio); the holder is timbr-mute-keeper (MuteKeeperProtocol).
import Foundation

public enum PersistentMutePolicy {
    /// The user silenced this app: muted, or its fader at zero. Both must survive a crash —
    /// a fader pulled to 0 % in a lecture hall is a mute in everything but name.
    public static func isSilenced(_ src: AudioSourceDescriptor) -> Bool {
        !AudioSourceIdentity.isTimbr(src.bundleID) && !src.isVoIPExcluded && (src.isMuted || src.volume < OutputVolumeBehavior.zeroThreshold)
    }

    /// Bundle IDs the tap may follow across relaunches (`processRestoreEnabled`, macOS 26+).
    /// Only the app's own bundle ID and its helpers (`<owner>.…`, e.g. `com.google.Chrome.helper`).
    /// Shared system processes that play on an app's behalf (`com.apple.WebKit.GPU`, XPC audio
    /// services) are left to the per-process list: muting them by bundle ID would also silence
    /// every other app that uses them.
    public static func restorableBundleIDs(owner: String, reported: [String]) -> [String] {
        var out: Set<String> = [owner]
        for id in reported where id == owner || id.hasPrefix(owner + ".") { out.insert(id) }
        return out.sorted()
    }

    /// Rebuild the mixer rows for apps whose mute survived the previous run, so the UI shows them
    /// muted (and lets the user unmute) instead of silently dropping — and later destroying — the mute.
    public static func mergeSurvivingMutes(
        _ bundleIDs: [String],
        into sources: [AudioSourceDescriptor],
        displayName: (String) -> String?
    ) -> [AudioSourceDescriptor] {
        var out = sources.filter { !AudioSourceIdentity.isTimbr($0.bundleID) }
        for bid in bundleIDs where !AudioSourceIdentity.isTimbr(bid) {
            if let i = out.firstIndex(where: { $0.bundleID == bid }) {
                out[i].isMuted = true
            } else {
                out.append(AudioSourceDescriptor(bundleID: bid, name: displayName(bid) ?? bid, volume: 1.0, isMuted: true))
            }
        }
        return out
    }
}
