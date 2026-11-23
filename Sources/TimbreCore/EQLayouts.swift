// SPDX-License-Identifier: MPL-2.0
// How many EQ "channels" the user sees (ADR-0019): 4, 5 or 10 fixed bands where only the gain moves
// (graphic style), or the free parametric EQ where every band has type, frequency, gain and Q.
// Pure data and rules, so they can be tested without a window.
import Foundation

public struct EQLayoutSlot: Equatable, Sendable {
    public let type: EQFilterType
    public let freqHz: Double
    public let q: Double
    /// Localization key of the region name, "Graves (Bass)": Portuguese first, the audiophile term in
    /// parentheses. `<key>.hint` is the one-line explanation shown on hover.
    public let nameKey: String

    init(type: EQFilterType, freqHz: Double, q: Double, nameKey: String) {
        self.type = type; self.freqHz = freqHz; self.q = q; self.nameKey = nameKey
    }
}

public enum EQBandLayout: String, Codable, CaseIterable, Sendable {
    /// The original four: Bass, Warmth, Presence, Air (stored in `SimpleTasteControls`).
    case four
    /// Same count as Sennheiser's Smart Control (three bands became five in the 4.3 update).
    case five
    /// The reference for headphone tuning: AutoEq's wiki says 10 parametric filters fix most
    /// headphones. Octave spacing, ISO centres.
    case ten

    public var bandCount: Int { slots.count }

    /// Gain travel per band. Fewer, broader bands get less travel: each one moves a lot of the spectrum.
    public var gainRangeDB: Double {
        switch self {
        case .four: return 6
        case .five: return 9
        case .ten: return 12
        }
    }

    public var slots: [EQLayoutSlot] {
        switch self {
        case .four:
            return [
                EQLayoutSlot(type: .lowShelf, freqHz: 105, q: 0.7, nameKey: "eq.band.bass"),
                EQLayoutSlot(type: .peak, freqHz: 250, q: 0.9, nameKey: "eq.band.warmth"),
                EQLayoutSlot(type: .peak, freqHz: 3000, q: 1.0, nameKey: "eq.band.presence"),
                EQLayoutSlot(type: .highShelf, freqHz: 10000, q: 0.7, nameKey: "eq.band.air"),
            ]
        case .five:
            return [
                EQLayoutSlot(type: .lowShelf, freqHz: 80, q: 0.7, nameKey: "eq.band.bass"),
                EQLayoutSlot(type: .peak, freqHz: 250, q: 0.9, nameKey: "eq.band.warmth"),
                EQLayoutSlot(type: .peak, freqHz: 1000, q: 1.0, nameKey: "eq.band.mid"),
                EQLayoutSlot(type: .peak, freqHz: 4000, q: 1.0, nameKey: "eq.band.presence"),
                EQLayoutSlot(type: .highShelf, freqHz: 10000, q: 0.7, nameKey: "eq.band.air"),
            ]
        case .ten:
            let octave = 1.41   // constant-Q for one-octave spacing
            // Region names are a convention and authors disagree on the edges (headphones.com, RTINGS):
            // they label the band, they do not claim an exact range.
            let names = ["eq.band.subbass", "eq.band.bass", "eq.band.body", "eq.band.warmth", "eq.band.lowmid",
                         "eq.band.mid", "eq.band.uppermid", "eq.band.presence.short", "eq.band.brilliance", "eq.band.air"]
            return [31.5, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000].enumerated().map { i, f in
                EQLayoutSlot(type: i == 0 ? .lowShelf : (i == 9 ? .highShelf : .peak), freqHz: f, q: (i == 0 || i == 9) ? 0.7 : octave, nameKey: names[i])
            }
        }
    }
}

public enum EQBandEditing {
    /// Most bands the DSP can run (shared by correction + taste).
    public static let dspBandLimit = 32
    public static let freeBandCeiling = 24

    /// How many free filters fit next to the correction (AutoEq) bands without the DSP silently dropping the excess.
    public static func maxFreeBands(correctionCount: Int) -> Int {
        max(0, min(freeBandCeiling, dspBandLimit - correctionCount))
    }

    /// A band the user adjusts (frequency, gain or Q) is a band they want on. A disabled band that
    /// moves but stays disabled is a handle that does nothing — the curve never follows it.
    /// Toggling `enabled` itself, or changing the type, is left exactly as the user set it.
    public static func afterUserAdjust(old: EQBand, new: EQBand) -> EQBand {
        guard !old.enabled, !new.enabled, new.type == old.type,
              new.freqHz != old.freqHz || new.gainDB != old.gainDB || new.q != old.q else { return new }
        var b = new
        b.enabled = true
        return b
    }

    /// Where a new filter should go: the middle (on the log axis) of the widest gap between the
    /// existing ones, so adding several never stacks them on one spot.
    public static func nextFreeFrequency(existing: [EQBand], lo: Double = 20, hi: Double = 20000) -> Double {
        let points = ([lo] + existing.map { min(max($0.freqHz, lo), hi) } + [hi]).sorted().map { log10($0) }
        var best = (gap: -1.0, mid: log10(1000.0))
        for i in 1..<points.count {
            let gap = points[i] - points[i - 1]
            if gap > best.gap { best = (gap, (points[i] + points[i - 1]) / 2) }
        }
        return (pow(10, best.mid)).rounded()
    }

    /// The set a free PEQ starts from, and returns to on reset: four flat, enabled filters.
    public static func defaultFreeBands() -> [EQBand] { bands(for: .four, gains: [0, 0, 0, 0], enabled: true) }

    /// True when `bands` are exactly the defaults (so "Reset" has nothing left to do).
    public static func isDefaultFree(_ bands: [EQBand]) -> Bool {
        let d = defaultFreeBands()
        guard bands.count == d.count else { return false }
        return zip(bands, d).allSatisfy { $0.type == $1.type && $0.freqHz == $1.freqHz && $0.q == $1.q && abs($0.gainDB) < 0.01 && $0.enabled == $1.enabled }
    }

    /// The bands of a fixed layout for a gain per slot. `enabled`: nil = on only where the gain is not 0
    /// (what the DSP needs), true = all on (what a free PEQ seeded from the layout needs).
    public static func bands(for layout: EQBandLayout, gains: [Double], enabled: Bool? = nil) -> [EQBand] {
        layout.slots.enumerated().map { i, s in
            let g = i < gains.count ? min(max(gains[i], -layout.gainRangeDB), layout.gainRangeDB) : 0
            return EQBand(type: s.type, design: .vicanek, layer: .taste, freqHz: s.freqHz, gainDB: g, q: s.q, enabled: enabled ?? (abs(g) > 0.01))
        }
    }
}
