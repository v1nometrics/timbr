// SPDX-License-Identifier: MPL-2.0
// Listening-time awareness (ADR-0023). It counts what the app really knows — how long something has
// played through personal listening gear, and for how long the Mac's volume was high — and never
// claims a dB figure: without the headphone's sensitivity and amplifier gain the level reaching the
// ear is unknown (±6 dB or more), and a wrong "safe" is worse than silence.
//
// The reference is the audiologists' 60/60 rule of thumb (Mayo Clinic): volume at or under 60 % for
// at most 60 minutes, then a 15–20 minute rest. It is a rule of thumb, not the WHO-ITU H.870 standard
// (80 dBA for 40 h/week), which needs a measured level.
import Foundation

public struct ListeningDay: Codable, Equatable, Sendable, Identifiable {
    public var id: String { day }
    public let day: String            // yyyy-MM-dd, local calendar
    public var personalSeconds: Double // playing through headphones, audible
    public var highSeconds: Double     // …of which with the volume at or above the high mark
    public init(day: String, personalSeconds: Double = 0, highSeconds: Double = 0) {
        self.day = day; self.personalSeconds = personalSeconds; self.highSeconds = highSeconds
    }
}

public enum ListeningPolicy {
    /// Volume (the Mac's slider, 0…1) from which listening counts as "high". 60/60 rule of thumb.
    public static let highVolume = 0.60
    /// The volume must fall this far below the mark before the high streak is considered over (no flicker).
    public static let hysteresis = 0.05
    public static let streakLimitSeconds: TimeInterval = 60 * 60
    /// Time not at high volume that counts as a real rest (the rule says 15–20 minutes).
    public static let restSeconds: TimeInterval = 15 * 60
    /// A tick longer than this is a sleep or a stall, not listening: it is not counted.
    public static let maxTick: TimeInterval = 6

    /// Personal listening = headphones, earbuds, a headset: not the Mac's speakers or a display.
    public static func isPersonalListening(_ d: AudioDeviceDescriptor) -> Bool {
        let n = d.name.lowercased()
        let speakerWords = ["speaker", "alto-falante", "altavoz", "display", "monitor", "tv", "hdmi", "homepod", "soundbar"]
        if speakerWords.contains(where: { n.contains($0) }) { return false }
        switch d.transport {
        case .bluetoothA2DP, .bluetoothHFP, .wiredAnalog: return true
        case .usb:
            return ["headphone", "headset", "fone", "auricular", "dac", "buds", "earphone"].contains(where: { n.contains($0) })
        case .builtIn:
            return ["headphone", "fone", "auricular", "auriculares"].contains(where: { n.contains($0) })
        default: return false
        }
    }

    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// "1 h 12 min", "35 min", "< 1 min".
    public static func duration(_ seconds: Double) -> String {
        let m = Int((seconds / 60).rounded(.down))
        if m < 1 { return seconds >= 1 ? "< 1 min" : "0 min" }
        return m >= 60 ? (m % 60 == 0 ? "\(m / 60) h" : "\(m / 60) h \(m % 60) min") : "\(m) min"
    }
}

public struct ListeningTracker: Sendable {
    public private(set) var today: ListeningDay
    /// Continuous high-volume time since the last real rest.
    public private(set) var streakSeconds: Double = 0
    public private(set) var isHigh = false
    private var restSeconds: Double = 0
    /// Seconds accumulated since the last `takePending()`: the caller writes these to disk.
    private var pendingPersonal: Double = 0
    private var pendingHigh: Double = 0
    private var pendingDay: String

    public init(day: String, personalSeconds: Double = 0, highSeconds: Double = 0) {
        today = ListeningDay(day: day, personalSeconds: personalSeconds, highSeconds: highSeconds)
        pendingDay = day
    }

    /// True while the volume has been high long enough that a rest is due.
    public var adviceActive: Bool { isHigh && streakSeconds >= ListeningPolicy.streakLimitSeconds }

    /// One step. `listening`: something audible plays through personal gear. `volume`: nil when unknown.
    public mutating func tick(dayKey: String, dt: TimeInterval, listening: Bool, volume: Double?) {
        if dayKey != today.day {   // midnight: the streak is a state of the ears, it carries over; the day totals do not
            today = ListeningDay(day: dayKey)
        }
        guard dt > 0, dt <= ListeningPolicy.maxTick else { return }
        // High with hysteresis: enters at the mark, leaves five points below it.
        let high: Bool = {
            guard listening, let v = volume else { return false }
            return isHigh ? v >= ListeningPolicy.highVolume - ListeningPolicy.hysteresis : v >= ListeningPolicy.highVolume
        }()
        isHigh = high
        if listening { today.personalSeconds += dt; pendingPersonal += dt }
        if high {
            today.highSeconds += dt; pendingHigh += dt
            streakSeconds += dt
            restSeconds = 0
        } else {
            restSeconds += dt
            if restSeconds >= ListeningPolicy.restSeconds { streakSeconds = 0 }
        }
        if pendingDay != today.day { pendingDay = today.day }
    }

    /// What to add to the stored day, and clear it. Nil when nothing changed.
    public mutating func takePending() -> (day: String, personal: Double, high: Double)? {
        guard pendingPersonal > 0 || pendingHigh > 0 else { return nil }
        defer { pendingPersonal = 0; pendingHigh = 0 }
        return (today.day, pendingPersonal, pendingHigh)
    }
}
