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

    /// Dedicated media, cinema, and presentation apps that should always suppress the notch in fullscreen.
    public static let cinemaBundleIDs: Set<String> = [
        "com.apple.QuickTimePlayerX",
        "com.apple.TV",
        "com.apple.DVDPlayer",
        "com.apple.iWork.Keynote",
        "com.microsoft.Powerpoint",
        "com.colliderli.iina",
        "org.videolan.vlc",
        "com.firecore.infuse",
        "io.mpv",
        "tv.plex.player",
        "tv.plex.desktop",
        "com.movist.MovistPro",
        "com.eltima.elmedia6",
        "com.apple.FinalCut",
        "com.blackmagic-design.DaVinciResolve"
    ]

    public static let cinemaOwners: Set<String> = [
        "QuickTime Player",
        "IINA",
        "VLC",
        "TV",
        "Apple TV",
        "Infuse",
        "mpv",
        "Movist",
        "Movist Pro",
        "Elmedia Player",
        "Plex",
        "Kodi",
        "Keynote",
        "Microsoft PowerPoint"
    ]

    /// Browsers that draw toolbar + content in separate windows or expose WKFullScreenWindow on HTML5 video.
    public static let multiWindowBrowserOwners: Set<String> = [
        "Google Chrome",
        "Google Chrome Canary",
        "Arc",
        "Brave Browser",
        "Microsoft Edge",
        "Firefox",
        "Vivaldi",
        "Opera",
        "Chromium",
        "Orion",
        "Zen",
        "Zen Browser"
    ]

    public static let multiWindowBrowserBundleIDs: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "company.thebrowser.Browser",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "org.mozilla.firefox",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
        "org.chromium.Chromium",
        "com.kagi.kagimacOS",
        "app.zen-browser.zen"
    ]

    public static let safariBundleID = "com.apple.Safari"

    private static func isCinemaApp(bundleID: String?, ownerName: String?) -> Bool {
        if let bundleID, cinemaBundleIDs.contains(bundleID) { return true }
        if let ownerName, cinemaOwners.contains(ownerName) { return true }
        return false
    }

    private static func isMultiWindowBrowser(bundleID: String?, ownerName: String?) -> Bool {
        if let bundleID, multiWindowBrowserBundleIDs.contains(bundleID) { return true }
        if let ownerName, multiWindowBrowserOwners.contains(ownerName) { return true }
        return false
    }

    private static func isSafari(bundleID: String?, ownerName: String?) -> Bool {
        bundleID == safariBundleID || ownerName == "Safari"
    }

    /// Returns true when the target notch display should suppress notch chrome for immersive fullscreen:
    /// - True top-edge / borderless fullscreen (`minY <= 2`, e.g. games, borderless video, non-notched fullscreen).
    /// - Dedicated cinema / media / presentation apps in native fullscreen (QuickTime, IINA, VLC, TV, Keynote).
    /// - HTML5 video fullscreen inside browsers (Chrome/Chromium full-height without toolbar, Safari WKFullScreenWindow or Safari playing video).
    /// Normal browser Spaces (`Cmd+Ctrl+F`) and productivity apps sitting below the physical notch keep the notch active in the black bezel.
    public static func isFullscreen(
        screen: FullscreenScreenSpec,
        windows: [FullscreenWindowSnapshot],
        menuBarVisible: Bool,
        autoHideMenuBarAlways: Bool,
        frontmostAXFullScreen: Bool,
        ownPID: Int32,
        frontmostBundleID: String? = nil,
        frontmostOwnerName: String? = nil,
        playingBundleIDs: Set<String> = [],
        playingOwnerNames: Set<String> = []
    ) -> Bool {
        guard screen.width > 0, screen.height > 0 else { return false }

        let insetFloor = max(screen.topInset, 24)
        var safariFullHeightCount = 0

        for w in windows {
            guard w.ownerPID != ownPID,
                  w.layer == 0,
                  !ignoredOwners.contains(w.ownerName),
                  w.width > 0, w.height > 0 else { continue }

            let coversWidth = w.minX <= screen.minX + 4 && w.maxX >= screen.maxX - 4
            let coversBottom = w.maxY >= screen.maxY - 4
            let coversTopEdge = w.minY <= screen.minY + 2
            let coversBelowNotch = w.minY <= screen.minY + insetFloor + 4

            // Case A: Borderless / top-edge / non-notched fullscreen covering the physical top edge.
            if coversWidth && coversTopEdge && coversBottom {
                if screen.hasPhysicalNotch || !autoHideMenuBarAlways || !menuBarVisible {
                    return true
                }
            }

            guard coversWidth && coversBelowNotch && coversBottom else { continue }

            let isFrontOwner = (frontmostOwnerName != nil && w.ownerName == frontmostOwnerName)
            let windowBundleID = isFrontOwner ? frontmostBundleID : nil

            // Case B: Dedicated cinema / media / presentation apps in native fullscreen below the notch.
            if isCinemaApp(bundleID: windowBundleID, ownerName: w.ownerName) {
                if (frontmostAXFullScreen && isFrontOwner) || (!autoHideMenuBarAlways && !menuBarVisible) {
                    return true
                }
            }

            // Case C: Multi-window browsers (Chrome, Arc, Brave, Edge, Firefox) only span full height below the notch
            // when toolbar & tab strip are hidden (e.g. HTML5 YouTube/Netflix fullscreen). Normal browsing starts lower (Y >= 100+).
            if isMultiWindowBrowser(bundleID: windowBundleID, ownerName: w.ownerName) {
                if !autoHideMenuBarAlways && !menuBarVisible {
                    return true
                }
                if frontmostAXFullScreen && isFrontOwner {
                    return true
                }
            }

            // Case D: Safari draws toolbar inside its single main window, so distinguish normal browsing from HTML5 video:
            // WKFullScreenWindow stacks a 2nd full-height window OR Safari itself is actively playing media in fullscreen.
            if isSafari(bundleID: windowBundleID, ownerName: w.ownerName) {
                safariFullHeightCount += 1
                let safariPlaying = playingBundleIDs.contains(safariBundleID) || playingOwnerNames.contains("Safari")
                if safariFullHeightCount >= 2 || (safariPlaying && ((!autoHideMenuBarAlways && !menuBarVisible) || (frontmostAXFullScreen && isFrontOwner))) {
                    return true
                }
            }
        }

        // Frontmost dedicated cinema/presentation app in AXFullScreen even if its window is momentarily transitioning.
        if frontmostAXFullScreen && isCinemaApp(bundleID: frontmostBundleID, ownerName: frontmostOwnerName) {
            return true
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

public struct CompactIconPlacement: Equatable, Sendable {
    public let leadCenterX: Double
    public let leadSize: Double
    public let secondCenterX: Double?
    public let secondSize: Double
    public let centerY: Double
    public let visible: Bool

    public init(
        leadCenterX: Double,
        leadSize: Double,
        secondCenterX: Double?,
        secondSize: Double,
        centerY: Double,
        visible: Bool
    ) {
        self.leadCenterX = leadCenterX
        self.leadSize = leadSize
        self.secondCenterX = secondCenterX
        self.secondSize = secondSize
        self.centerY = centerY
        self.visible = visible
    }
}

public enum CompactIconLayoutEvaluator: Sendable {
    /// Computes non-overlapping, balanced positions for 1 or 2 playing app icons across every
    /// measured menu-bar layout (chin or left ear). Dual icons sit strictly side-by-side with
    /// an explicit 3-4 pt gap and >= 4.5 pt side margins — never stacked or clipped.
    public static func layout(
        canvasCenterX: Double,
        notchHalfWidth: Double,
        notchHeight: Double,
        chinHeight: Double,
        leftEar: Double,
        rightEar: Double,
        useChin: Bool,
        hasSecond: Bool
    ) -> CompactIconPlacement {
        if useChin {
            let y = notchHeight + chinHeight / 2.0 - 1.0
            if hasSecond {
                let size = 14.0
                let gap = 4.0
                let secondX = canvasCenterX - notchHalfWidth + 22.0
                let leadX = secondX + size + gap
                return CompactIconPlacement(
                    leadCenterX: leadX,
                    leadSize: size,
                    secondCenterX: secondX,
                    secondSize: size,
                    centerY: y,
                    visible: true
                )
            }
            return CompactIconPlacement(
                leadCenterX: canvasCenterX - notchHalfWidth + 22.0,
                leadSize: 14.0,
                secondCenterX: nil,
                secondSize: 0,
                centerY: y,
                visible: true
            )
        }

        let y = notchHeight / 2.0
        if leftEar > 0 && rightEar > 0 {
            let earMid = canvasCenterX - notchHalfWidth - leftEar / 2.0
            if hasSecond {
                let size: Double
                let gap: Double
                if leftEar >= 42.0 {
                    size = 14.0
                    gap = 4.0
                } else if leftEar >= 38.0 {
                    size = 13.0
                    gap = 3.0
                } else {
                    size = 12.0
                    gap = 3.0
                }
                let step = (size + gap) / 2.0
                return CompactIconPlacement(
                    leadCenterX: earMid + step,
                    leadSize: size,
                    secondCenterX: earMid - step,
                    secondSize: size,
                    centerY: y,
                    visible: true
                )
            }
            return CompactIconPlacement(
                leadCenterX: earMid,
                leadSize: leftEar >= 34.0 ? 16.0 : 15.0,
                secondCenterX: nil,
                secondSize: 0,
                centerY: y,
                visible: true
            )
        }

        return CompactIconPlacement(
            leadCenterX: canvasCenterX - notchHalfWidth + 12.0,
            leadSize: 12.0,
            secondCenterX: nil,
            secondSize: 0,
            centerY: y,
            visible: false
        )
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

    /// True whenever the output device must be completely silent (either HW-muted or at/below the 0% threshold).
    /// Also detects if CoreAudio has drifted into the unmuted 0% state (`scalar < 0.005` with `muted == false`),
    /// which leaks ~-63.5 dB on MacBook speakers and must be healed by engaging hardware mute + zeroing DSP gain.
    public static func isEffectivelySilenced(volume: Double?, muted: Bool) -> Bool {
        if muted { return true }
        guard let v = volume else { return false }
        return v < zeroThreshold
    }

    public static func needsZeroVolumeMuteHeal(volume: Double?, muted: Bool, isHWMuteSettable: Bool) -> Bool {
        guard isHWMuteSettable, !muted, let v = volume else { return false }
        return v < zeroThreshold
    }

    public static func normalizeSourceVolume(_ requested: Double) -> Double {
        let clamped = min(max(requested, 0.0), 4.0)
        return clamped < zeroThreshold ? 0.0 : clamped
    }
}
