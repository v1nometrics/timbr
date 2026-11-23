// SPDX-License-Identifier: MPL-2.0
// Pure audio UI metrology, taper, ballistics, LCD quantization, and rotary knob arc math.
// Modeled after audiocn (@audiocn/core, MIT) and AES/EBU digital metering conventions.
import Foundation

// MARK: - Decibel Zones & Conversions

public enum AudioMeterZone: String, Equatable, Sendable {
    case silent
    case normal
    case warning
    case clip
}

public enum AudioDecibelMath: Sendable {
    public static let defaultFloorDB: Double = -60.0
    public static let defaultWarningDB: Double = -12.0
    public static let defaultClipDB: Double = -1.0

    public static func dbToGain(_ db: Double, floorDB: Double = defaultFloorDB) -> Double {
        guard db.isFinite, db > floorDB else { return 0.0 }
        return pow(10.0, db / 20.0)
    }

    public static func gainToDB(_ gain: Double, floorDB: Double = defaultFloorDB) -> Double {
        guard gain > 0.0001 else { return -.infinity }
        let db = 20.0 * log10(gain)
        return db <= floorDB ? -.infinity : db
    }

    /// Maps a dB value in `[minDB, maxDB]` to normalized `[0, 1]` using either linear-in-dB or console audio taper (`exponent = 1.65` gives the loud top of the range wider travel).
    public static func dbToNormalized(
        _ db: Double,
        minDB: Double = -60.0,
        maxDB: Double = 0.0,
        audioTaper: Bool = true
    ) -> Double {
        guard db.isFinite, maxDB > minDB else { return 0.0 }
        let clamped = min(max(db, minDB), maxDB)
        let lin = (clamped - minDB) / (maxDB - minDB)
        return audioTaper ? pow(lin, 1.65) : lin
    }

    public static func normalizedToDB(
        _ norm: Double,
        minDB: Double = -60.0,
        maxDB: Double = 0.0,
        audioTaper: Bool = true
    ) -> Double {
        guard maxDB > minDB else { return minDB }
        let p = min(max(norm, 0.0), 1.0)
        let uncurved = audioTaper ? pow(p, 1.0 / 1.65) : p
        return minDB + uncurved * (maxDB - minDB)
    }

    public static func zone(
        forDB db: Double,
        floorDB: Double = defaultFloorDB,
        warningDB: Double = defaultWarningDB,
        clipDB: Double = defaultClipDB
    ) -> AudioMeterZone {
        guard db.isFinite, db > floorDB else { return .silent }
        if db >= clipDB { return .clip }
        if db >= warningDB { return .warning }
        return .normal
    }
}

// MARK: - Meter Ballistics & Peak Hold

public struct AudioMeterBallistics: Equatable, Sendable {
    public var smoothedDB: Double
    public var heldPeakDB: Double
    public var peakHoldRemainingSeconds: Double
    public var isClipLatched: Bool
    public var clipEventCount: Int
    private var wasAboveClipThreshold: Bool

    public let floorDB: Double
    public let clipThresholdDB: Double
    public let holdDurationSeconds: Double
    public let releaseDBPerSecond: Double

    public init(
        floorDB: Double = -60.0,
        clipThresholdDB: Double = -1.0,
        holdDurationSeconds: Double = 1.5,
        releaseDBPerSecond: Double = 24.0
    ) {
        self.floorDB = floorDB
        self.clipThresholdDB = clipThresholdDB
        self.holdDurationSeconds = holdDurationSeconds
        self.releaseDBPerSecond = releaseDBPerSecond
        self.smoothedDB = floorDB
        self.heldPeakDB = floorDB
        self.peakHoldRemainingSeconds = 0.0
        self.isClipLatched = false
        self.clipEventCount = 0
        self.wasAboveClipThreshold = false
    }

    public mutating func step(sampleDB: Double, dtSeconds: Double) {
        let dt = max(0.0, dtSeconds)
        let clampedSample = sampleDB.isFinite ? max(sampleDB, floorDB) : floorDB

        // Fast attack, steady release (IEC 60268-18 / audiocn peak ballistics)
        if clampedSample >= smoothedDB {
            smoothedDB = clampedSample
        } else {
            smoothedDB = max(clampedSample, smoothedDB - releaseDBPerSecond * dt)
        }

        // Peak hold with hold timer then falloff
        if clampedSample >= heldPeakDB {
            heldPeakDB = clampedSample
            peakHoldRemainingSeconds = holdDurationSeconds
        } else if peakHoldRemainingSeconds > dt {
            peakHoldRemainingSeconds -= dt
        } else {
            let leftover = max(0.0, dt - peakHoldRemainingSeconds)
            peakHoldRemainingSeconds = 0.0
            heldPeakDB = max(smoothedDB, max(floorDB, heldPeakDB - releaseDBPerSecond * leftover))
        }

        // Clip latch on rising edge past threshold
        let nowClipping = sampleDB.isFinite && sampleDB >= clipThresholdDB
        if nowClipping {
            isClipLatched = true
            if !wasAboveClipThreshold {
                clipEventCount += 1
            }
        }
        wasAboveClipThreshold = nowClipping
    }

    public mutating func resetClip() {
        isClipLatched = false
        clipEventCount = 0
        wasAboveClipThreshold = false
    }

    public mutating func clearImmediately() {
        smoothedDB = floorDB
        heldPeakDB = floorDB
        peakHoldRemainingSeconds = 0.0
        wasAboveClipThreshold = false
    }
}

// MARK: - LCD Whole-Segment Quantization (audiocn LCDMeter)

public struct LCDSegmentLayout: Equatable, Sendable {
    public let totalSegments: Int
    /// Number of lit segments `0...totalSegments` (whole-segment quantized so segments never light partially).
    public let litCount: Int
    /// 0-based index of the held-peak segment, or `nil` when peak is at or below silence floor.
    public let heldPeakIndex: Int?
    /// First segment index in the warning zone (`>= warningDB`).
    public let warningStartIndex: Int
    /// First segment index in the clip zone (`>= clipDB`).
    public let clipStartIndex: Int

    public static func quantize(
        dbfs: Double,
        heldPeakDB: Double? = nil,
        minDB: Double = -60.0,
        maxDB: Double = 0.0,
        warningDB: Double = -12.0,
        clipDB: Double = -1.0,
        segmentCount: Int = 24,
        audioTaper: Bool = true
    ) -> LCDSegmentLayout {
        let n = max(1, segmentCount)
        let norm = AudioDecibelMath.dbToNormalized(dbfs, minDB: minDB, maxDB: maxDB, audioTaper: audioTaper)
        let lit = min(n, max(0, Int((norm * Double(n)).rounded(.down) + (norm > 0.001 ? 1 : 0))))

        let peakIdx: Int? = {
            guard let pk = heldPeakDB, pk.isFinite, pk > minDB + 0.05 else { return nil }
            let pkNorm = AudioDecibelMath.dbToNormalized(pk, minDB: minDB, maxDB: maxDB, audioTaper: audioTaper)
            guard pkNorm > 0.001 else { return nil }
            return min(n - 1, max(0, Int((pkNorm * Double(n - 1)).rounded())))
        }()

        let warnNorm = AudioDecibelMath.dbToNormalized(warningDB, minDB: minDB, maxDB: maxDB, audioTaper: audioTaper)
        let clipNorm = AudioDecibelMath.dbToNormalized(clipDB, minDB: minDB, maxDB: maxDB, audioTaper: audioTaper)
        let warnIdx = min(n - 1, max(0, Int((warnNorm * Double(n)).rounded(.down))))
        let clipIdx = min(n - 1, max(warnIdx, Int((clipNorm * Double(n)).rounded(.down))))

        return LCDSegmentLayout(
            totalSegments: n,
            litCount: dbfs.isFinite && dbfs > minDB + 0.05 ? lit : 0,
            heldPeakIndex: peakIdx,
            warningStartIndex: warnIdx,
            clipStartIndex: clipIdx
        )
    }
}

// MARK: - Rotary Knob Arc & Scale Math (audiocn Knob)

public struct KnobArcGeometry: Equatable, Sendable {
    /// Start of the full travel track in degrees (0° = 12 o'clock, negative = counter-clockwise, positive = clockwise).
    public let trackStartDeg: Double
    public let trackEndDeg: Double
    public let originDeg: Double
    public let valueDeg: Double
    public let normalizedOrigin: Double
    public let normalizedValue: Double

    /// Standard 270° console potentiometer sweep (`-135°` at 7:30 to `+135°` at 4:30, with `0°` at 12 o'clock).
    public static func compute(
        value: Double,
        range: ClosedRange<Double>,
        origin: Double? = nil,
        sweepDegrees: Double = 270.0
    ) -> KnobArcGeometry {
        let span = max(0.000001, range.upperBound - range.lowerBound)
        let clampedVal = min(max(value, range.lowerBound), range.upperBound)
        let clampedOrg = min(max(origin ?? range.lowerBound, range.lowerBound), range.upperBound)

        let normVal = (clampedVal - range.lowerBound) / span
        let normOrg = (clampedOrg - range.lowerBound) / span
        let half = sweepDegrees / 2.0
        let start = -half
        let end = half

        return KnobArcGeometry(
            trackStartDeg: start,
            trackEndDeg: end,
            originDeg: start + normOrg * sweepDegrees,
            valueDeg: start + normVal * sweepDegrees,
            normalizedOrigin: normOrg,
            normalizedValue: normVal
        )
    }

    /// Returns whether a peripheral scale tick at `tickIndex` (`0..<tickCount`) lies inside the active arc between `origin` and `value`.
    public func isTickLit(tickIndex: Int, tickCount: Int) -> Bool {
        guard tickCount > 1 else { return true }
        let t = Double(tickIndex) / Double(tickCount - 1)
        let lo = min(normalizedOrigin, normalizedValue) - 0.001
        let hi = max(normalizedOrigin, normalizedValue) + 0.001
        return t >= lo && t <= hi
    }
}
