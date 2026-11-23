// SPDX-License-Identifier: MPL-2.0
// Pure, testable math & geometry rules for the notch compact indicator and fullscreen auto-hide.
import Foundation

// MARK: - Timbre harmonic mark math

/// Drives `MiniMeter` in the notch compact ear using `timbr.`'s 5-bar symmetric harmonic silhouette.
/// When audio is active without DSP measurement (zero-tap native pass-through), it renders a calm,
/// slow harmonic breathing (~2.6 s period) instead of faking level peaks; when DSP telemetry exists,
/// measured loudness gently lifts the harmonic envelope within a restrained ceiling.
public enum TimbreHarmonicMath: Sendable {
    public struct BarSample: Equatable, Sendable {
        public let height: Double
        public let opacity: Double

        public init(height: Double, opacity: Double) {
            self.height = height
            self.opacity = opacity
        }
    }

    public static let barCount = 5
    /// Matches `scripts/generate_icns.py` (`0.18 : 0.34 : 0.50` symmetric ratios) scaled to 14 pt ear height.
    public static let baseHeights: [Double] = [4.0, 7.4, 10.8, 7.4, 4.0]
    public static let idleDotHeight: Double = 2.5
    public static let idleOpacity: Double = 0.45
    public static let reducedMotionOpacity: Double = 0.82
    public static let cycleSeconds: Double = 2.6

    private static let freqMultipliers: [Double] = [1.45, 1.15, 1.0, 1.15, 1.45]
    private static let phaseOffsets: [Double] = [1.25, 0.62, 0.0, -0.62, -1.25]
    private static let nativeAmplitudes: [Double] = [0.75, 1.05, 0.70, 1.05, 0.75]
    private static let liveAmplitudes: [Double] = [0.65, 0.95, 0.55, 0.95, 0.65]

    public static func samples(active: Bool, level: Double?, time: TimeInterval, reduceMotion: Bool) -> [BarSample] {
        guard active else {
            return Array(repeating: BarSample(height: idleDotHeight, opacity: idleOpacity), count: barCount)
        }
        guard !reduceMotion else {
            return baseHeights.map { BarSample(height: $0, opacity: reducedMotionOpacity) }
        }

        let phase = time * (2.0 * .pi / cycleSeconds)
        var result: [BarSample] = []
        result.reserveCapacity(barCount)

        if let rawLevel = level {
            let clamped = min(1.0, max(0.0, rawLevel))
            let energy = pow(clamped, 0.75)
            let scale = 0.78 + 0.30 * energy
            for i in 0..<barCount {
                let wave = sin(phase * freqMultipliers[i] + phaseOffsets[i])
                let ripple = liveAmplitudes[i] * (0.45 + 0.55 * energy) * wave
                let height = min(13.0, max(3.0, baseHeights[i] * scale + ripple))
                let opacity = 0.72 + 0.18 * (0.45 * energy + 0.55 * (0.5 + 0.5 * wave))
                result.append(BarSample(height: height, opacity: opacity))
            }
        } else {
            for i in 0..<barCount {
                let wave = sin(phase * freqMultipliers[i] + phaseOffsets[i])
                let height = min(13.0, max(3.0, baseHeights[i] + nativeAmplitudes[i] * wave))
                let opacity = 0.70 + 0.16 * (0.5 + 0.5 * wave)
                result.append(BarSample(height: height, opacity: opacity))
            }
        }
        return result
    }
}

// MARK: - Fullscreen detection (pure geometry & visibility rules)

public struct FullscreenScreenSpec: Equatable, Sendable {
    public let minX: Double
    public let minY: Double
    public let width: Double
    public let height: Double
    public let topInset: Double
    public let hasPhysicalNotch: Bool

    public init(minX: Double, minY: Double, width: Double, height: Double, topInset: Double, hasPhysicalNotch: Bool) {
        self.minX = minX
        self.minY = minY
        self.width = width
        self.height = height
        self.topInset = topInset
        self.hasPhysicalNotch = hasPhysicalNotch
    }

    public var maxX: Double { minX + width }
    public var maxY: Double { minY + height }
}

public struct FullscreenWindowSnapshot: Equatable, Sendable {
    public let ownerPID: Int32
    public let ownerName: String
    public let layer: Int
    public let minX: Double
    public let minY: Double
    public let width: Double
    public let height: Double

    public init(ownerPID: Int32, ownerName: String, layer: Int, minX: Double, minY: Double, width: Double, height: Double) {
        self.ownerPID = ownerPID
        self.ownerName = ownerName
        self.layer = layer
        self.minX = minX
        self.minY = minY
        self.width = width
        self.height = height
    }

    public var maxX: Double { minX + width }
    public var maxY: Double { minY + height }
}

public enum FullscreenEvaluator: Sendable {
    public static let ignoredOwners: Set<String> = [
        "Dock",
        "Window Server",
        "SystemUIServer",
        "Control Center",
        "ControlCenter",
        "Notification Center",
        "NotificationCenter",
        "Spotlight",
        "Wallpaper",
        "loginwindow"
    ]

    /// Returns true when the target notch display is occupied by a fullscreen video or app.
    /// Avoids false positives on desktop maximized windows (even when Dock auto-hide is enabled).
    public static func isFullscreen(
        screen: FullscreenScreenSpec,
        windows: [FullscreenWindowSnapshot],
        menuBarVisible: Bool,
        autoHideMenuBarAlways: Bool,
        frontmostAXFullScreen: Bool,
        ownPID: Int32
    ) -> Bool {
        guard screen.width > 0, screen.height > 0 else { return false }
        if frontmostAXFullScreen { return true }

        let insetFloor = max(screen.topInset, 24)
        var splitCoverages: [(Double, Double)] = []

        for w in windows {
            guard w.ownerPID != ownPID,
                  w.layer == 0,
                  !ignoredOwners.contains(w.ownerName),
                  w.width > 0, w.height > 0 else { continue }

            let coversWidth = w.minX <= screen.minX + 4 && w.maxX >= screen.maxX - 4
            let coversBottom = w.maxY >= screen.maxY - 4
            let coversTopEdge = w.minY <= screen.minY + 2
            let coversBelowNotch = w.minY <= screen.minY + insetFloor + 4

            // Case A: Borderless / HTML5 / game fullscreen covering top edge (even under the notch).
            if coversWidth && coversTopEdge && coversBottom {
                if screen.hasPhysicalNotch || !autoHideMenuBarAlways || !menuBarVisible {
                    return true
                }
            }

            // Case B: Native macOS Fullscreen Space (sits directly below the black notch bezel, no Dock, menu bar hidden).
            if coversWidth && coversBelowNotch && coversBottom && !autoHideMenuBarAlways && !menuBarVisible {
                return true
            }

            // Case C: Native macOS Fullscreen Split View (2 side-by-side windows covering full height while menu bar hidden).
            if !autoHideMenuBarAlways && !menuBarVisible && coversBelowNotch && coversBottom {
                let left = max(screen.minX, w.minX)
                let right = min(screen.maxX, w.maxX)
                if right - left >= screen.width * 0.30 {
                    splitCoverages.append((left, right))
                }
            }
        }

        if splitCoverages.count >= 2 {
            let sorted = splitCoverages.sorted { $0.0 < $1.0 }
            var mergedSpan = 0.0
            var curStart = sorted[0].0
            var curEnd = sorted[0].1
            for seg in sorted.dropFirst() {
                if seg.0 <= curEnd + 16 {
                    curEnd = max(curEnd, seg.1)
                } else {
                    mergedSpan += curEnd - curStart
                    curStart = seg.0
                    curEnd = seg.1
                }
            }
            mergedSpan += curEnd - curStart
            if mergedSpan >= screen.width - 16 {
                return true
            }
        }

        return false
    }
}


// MARK: - Menu bar ear space evaluation (pure geometry)

public struct MenuBarItemSpan: Equatable, Sendable {
    public let minX: Double
    public let maxX: Double

    public init(minX: Double, maxX: Double) {
        self.minX = minX
        self.maxX = maxX
    }
}

public enum MenuBarSpaceEvaluator: Sendable {
    public static let earMax: Double = 44
    public static let earMin: Double = 26
    public static let dualIconMinEar: Double = 36
    public static let gap: Double = 8

    /// Computes safe left and right ear widths beside the physical notch, never overlapping either:
    /// - status items (`layer == 25`) on the right, or
    /// - frontmost app menus (`AXMenuBar`) on BOTH the left and wrapped right sides (e.g. Chrome `Janela` / `Ajuda`).
    /// Without Accessibility trust, both sides return `0` so Compact falls back to the safe chin instead of guessing over menus.
    public static func freeEars(
        hasPhysicalNotch: Bool,
        screenWidth: Double,
        notchLeft: Double,
        notchRight: Double,
        axTrusted: Bool,
        appMenuSpans: [MenuBarItemSpan],
        statusItemSpans: [MenuBarItemSpan]
    ) -> (left: Double, right: Double) {
        guard hasPhysicalNotch, axTrusted, screenWidth > 0 else { return (0, 0) }

        var leftOccupiedMaxX = 0.0
        var rightOccupiedMinX = screenWidth

        for span in appMenuSpans where span.maxX > span.minX {
            if span.minX < notchLeft {
                leftOccupiedMaxX = max(leftOccupiedMaxX, min(span.maxX, notchLeft))
            }
            if span.maxX > notchRight {
                rightOccupiedMinX = min(rightOccupiedMinX, max(span.minX, notchRight))
            }
        }

        for span in statusItemSpans where span.maxX > span.minX {
            if span.minX < notchLeft {
                leftOccupiedMaxX = max(leftOccupiedMaxX, min(span.maxX, notchLeft))
            }
            if span.maxX > notchRight {
                rightOccupiedMinX = min(rightOccupiedMinX, max(span.minX, notchRight))
            }
        }

        let rawLeft = notchLeft - leftOccupiedMaxX - gap
        let rawRight = rightOccupiedMinX - notchRight - gap

        func clamp(_ v: Double) -> Double {
            v >= earMin ? min(v, earMax) : 0
        }
        return (clamp(rawLeft), clamp(rawRight))
    }

    /// Consistent bilateral rule ("App(s) always on the left, harmonic mark always on the right"):
    /// Compact uses the ears only when BOTH sides have room (left >= 26 for 1 app or >= 36 for 2+ apps,
    /// and right >= 26 for the 5-bar mark). Otherwise it drops cleanly into the chin beneath the notch
    /// so the app icon never jumps across the camera to the right ear or cramps beside the meter.
    public static func shouldUseChin(ears: (left: Double, right: Double), hasMultipleSources: Bool) -> Bool {
        let minLeft = hasMultipleSources ? dualIconMinEar : earMin
        return ears.left < minLeft || ears.right < earMin
    }
}
// MARK: - Output volume & zero-bleed mute policy

public enum OutputVolumeBehavior: Sendable {
    /// CoreAudio speakers/DACs often have a finite dB floor at scalar 0.0 (e.g. -63.5 dB on MacBook
    /// speakers) that remains audibly faint unless hardware mute is engaged. Anything that formats
    /// as "0%" (< 0.005) therefore snaps scalar to 0.0 and engages hardware mute, matching macOS.
    public static let zeroThreshold: Double = 0.005

    public struct SetVolumeTransition: Equatable, Sendable {
        public let scalar: Float
        public let muted: Bool
        public let displayVolume: Double
        public let hudMuted: Bool

        public init(scalar: Float, muted: Bool, displayVolume: Double, hudMuted: Bool) {
            self.scalar = scalar
            self.muted = muted
            self.displayVolume = displayVolume
            self.hudMuted = hudMuted
        }
    }

    public enum MediaKeyStepAction: Equatable, Sendable {
        case volumeUp(step: Double)
        case volumeDown(step: Double)
        case muteToggle
    }

    public struct MediaKeyTransition: Equatable, Sendable {
        public let scalar: Float?
        public let muted: Bool
        public let displayVolume: Double
        public let hudMuted: Bool

        public init(scalar: Float?, muted: Bool, displayVolume: Double, hudMuted: Bool) {
            self.scalar = scalar
            self.muted = muted
            self.displayVolume = displayVolume
            self.hudMuted = hudMuted
        }
    }

    public static func evaluateSetVolume(requested: Double, isHWMuteSettable: Bool) -> SetVolumeTransition {
        let clamped = min(max(requested, 0.0), 1.0)
        if clamped < zeroThreshold {
            return SetVolumeTransition(
                scalar: 0.0,
                muted: isHWMuteSettable,
                displayVolume: 0.0,
                hudMuted: true
            )
        }
        return SetVolumeTransition(
            scalar: Float(clamped),
            muted: false,
            displayVolume: clamped,
            hudMuted: false
        )
    }

    public static func evaluateMediaKey(
        currentVolume: Double,
        currentMuted: Bool,
        isHWMuteSettable: Bool,
        action: MediaKeyStepAction
    ) -> MediaKeyTransition {
        let clampedCur = min(max(currentVolume, 0.0), 1.0)
        switch action {
        case .volumeUp(let step):
            let t = evaluateSetVolume(requested: clampedCur + step, isHWMuteSettable: isHWMuteSettable)
            return MediaKeyTransition(scalar: t.scalar, muted: t.muted, displayVolume: t.displayVolume, hudMuted: t.hudMuted)
        case .volumeDown(let step):
            let next = max(0.0, clampedCur - step)
            if next < zeroThreshold {
                return MediaKeyTransition(
                    scalar: 0.0,
                    muted: isHWMuteSettable,
                    displayVolume: 0.0,
                    hudMuted: true
                )
            }
            let keepMuted = currentMuted && isHWMuteSettable
            return MediaKeyTransition(
                scalar: Float(next),
                muted: keepMuted,
                displayVolume: next,
                hudMuted: keepMuted
            )
        case .muteToggle:
            if currentMuted {
                if clampedCur < zeroThreshold {
                    // Never unmute into CoreAudio's -63.5 dB zero floor via mute key.
                    return MediaKeyTransition(
                        scalar: 0.0,
                        muted: isHWMuteSettable,
                        displayVolume: 0.0,
                        hudMuted: true
                    )
                }
                return MediaKeyTransition(
                    scalar: nil,
                    muted: false,
                    displayVolume: clampedCur,
                    hudMuted: false
                )
            } else {
                return MediaKeyTransition(
                    scalar: nil,
                    muted: isHWMuteSettable,
                    displayVolume: clampedCur,
                    hudMuted: isHWMuteSettable || clampedCur < zeroThreshold
                )
            }
        }
    }

    public static func shouldRestoreAudibleOnUnmute(activeVolume: Double?) -> Bool {
        (activeVolume ?? 0.0) < zeroThreshold
    }

    public static func normalizeSourceVolume(_ requested: Double) -> Double {
        let clamped = min(max(requested, 0.0), 4.0)
        return clamped < zeroThreshold ? 0.0 : clamped
    }
}
