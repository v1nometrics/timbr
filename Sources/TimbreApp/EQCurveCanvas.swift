// SPDX-License-Identifier: MPL-2.0
// EQ response display (docs/05-design-system/05-visualizacao.md §EQ).
// Conventions from pro audio (FabFilter Pro-Q, REW): log frequency axis 20 Hz–20 kHz,
// linear dB, 0 dB reference emphasised, the DIGITAL response evaluated by the real DSP kernel
// (never the analog prototype), live spectrum underneath, layers distinguished by line style.
import SwiftUI
import TimbreCore
import TimbreEngine
import TimbreDesignSystem

public struct EQCurveCanvas: View {
    @ObservedObject var appState: AppState
    var height: CGFloat = 300
    @Environment(\.palette) private var c
    @State private var dragged: UUID?
    @State private var hovered: UUID?
    @State private var dragStartQ: Double?
    @State private var lastClickLocation: CGPoint = .zero

    private let gridF: [Double] = [20, 30, 40, 50, 60, 80, 100, 200, 300, 400, 500, 600, 800, 1000, 2000, 3000, 4000, 5000, 6000, 8000, 10000, 20000]
    private let majorF: [Double] = [100, 1000, 10000]
    private let labelF: [Double] = [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000]

    public init(appState: AppState, height: CGFloat = 300) {
        self.appState = appState
        self.height = height
    }

    /// Stable identity for a fixed-layout handle (the bands themselves are rebuilt on every render).
    private func layoutHandleID(_ index: Int) -> UUID {
        UUID(uuid: (0xE0, 0xE0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(index)))
    }

    private func freqText(_ f: Double) -> String {
        f < 100 && f != f.rounded() ? String(format: "%.1f", f) : Fmt.hz(f)
    }

    public var body: some View {
        let fs = EQAxis.curveFrequencies
        let corr = appState.tapEngine.evaluateCurve(bands: appState.activePreset.correctionBands, freqsHz: fs, layer: .correction).magDB
        let taste = appState.tapEngine.evaluateCurve(bands: appState.activePreset.effectiveTasteBands, freqsHz: fs, layer: .taste).magDB
        let result = zip(corr, taste).map { $0 + $1 }
        let hasCorrection = appState.activePreset.correctionBands.contains { $0.enabled }
        let rate = appState.activeOutputDevice?.sampleRate ?? 48000

        // Active / selected single band response highlight
        let activeBandCurve: [Double]? = {
            if appState.activePreset.useAdvancedPEQ {
                let targetID = dragged ?? hovered ?? appState.selectedEQBandID
                guard let id = targetID,
                      let b = appState.activePreset.tasteBands.first(where: { $0.id == id && $0.enabled }) else { return nil }
                return appState.tapEngine.evaluateCurve(bands: [b], freqsHz: fs, layer: .taste).magDB
            } else {
                let layout = appState.activePreset.layout
                let idx: Int? = {
                    if let d = dragged {
                        return (0..<layout.bandCount).first(where: { layoutHandleID($0) == d })
                    }
                    if let h = hovered {
                        return (0..<layout.bandCount).first(where: { layoutHandleID($0) == h })
                    }
                    return appState.selectedFixedSlotIndex
                }()
                guard let slotIdx = idx, slotIdx < appState.activePreset.layoutBands.count else { return nil }
                let b = appState.activePreset.layoutBands[slotIdx]
                guard abs(b.gainDB) > 0.01 else { return nil }
                return appState.tapEngine.evaluateCurve(bands: [b], freqsHz: fs, layer: .taste).magDB
            }
        }()

        GeometryReader { geo in
            let w = geo.size.width - 34   // right gutter for dB labels
            let h = geo.size.height - 20  // bottom gutter for Hz labels
            ZStack(alignment: .topLeading) {
                // Live FFT spectrum in an isolated leaf so 24 Hz redraws never re-evaluate
                // C++ biquad curves, drag handles, or the surrounding EqualizerPage layout.
                EQSpectrumOverlay(
                    liveMeters: appState.liveMeters,
                    hasLiveSignal: appState.hasLiveSignal,
                    sampleRate: rate
                )
                .frame(width: w, height: h)
                .allowsHitTesting(false)

                Canvas { ctx, _ in
                    // Grid
                    for gf in gridF {
                        var p = Path(); let gx = EQAxis.x(gf, w)
                        p.move(to: CGPoint(x: gx, y: 0)); p.addLine(to: CGPoint(x: gx, y: h))
                        ctx.stroke(p, with: .color(majorF.contains(gf) ? c.line_default : c.line_grid), lineWidth: 0.5)
                    }
                    for d in stride(from: -12.0, through: 12.0, by: 6.0) {
                        var p = Path(); let gy = EQAxis.y(d, h)
                        p.move(to: CGPoint(x: 0, y: gy)); p.addLine(to: CGPoint(x: w, y: gy))
                        ctx.stroke(p, with: .color(d == 0 ? c.line_strong : c.line_grid), lineWidth: d == 0 ? 0.75 : 0.5)
                    }
                    let zeroY = EQAxis.y(0, h)

                    func curve(_ m: [Double]) -> Path {
                        var p = Path()
                        for (i, fr) in fs.enumerated() {
                            let pt = CGPoint(x: EQAxis.x(fr, w), y: EQAxis.y(m[i], h))
                            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                        }
                        return p
                    }

                    // Individual active/selected band bell envelope
                    if let single = activeBandCurve {
                        var singleFill = Path(); singleFill.move(to: CGPoint(x: 0, y: zeroY))
                        for (i, fr) in fs.enumerated() { singleFill.addLine(to: CGPoint(x: EQAxis.x(fr, w), y: EQAxis.y(single[i], h))) }
                        singleFill.addLine(to: CGPoint(x: w, y: zeroY)); singleFill.closeSubpath()
                        ctx.fill(singleFill, with: .color(c.ink_primary.opacity(0.08)))
                        ctx.stroke(curve(single), with: .color(c.ink_secondary.opacity(0.65)), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    }

                    // Result fill between curve and 0 dB
                    var fill = Path(); fill.move(to: CGPoint(x: 0, y: zeroY))
                    for (i, fr) in fs.enumerated() { fill.addLine(to: CGPoint(x: EQAxis.x(fr, w), y: EQAxis.y(result[i], h))) }
                    fill.addLine(to: CGPoint(x: w, y: zeroY)); fill.closeSubpath()
                    ctx.fill(fill, with: .color(c.accent_fill))

                    if hasCorrection {
                        ctx.stroke(curve(corr), with: .color(c.ink_secondary), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        ctx.stroke(curve(taste), with: .color(c.ink_muted), style: StrokeStyle(lineWidth: 1))
                    }
                    ctx.stroke(curve(result), with: .color(appState.isProcessingBypassed ? c.ink_muted : c.accent_signal), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                .frame(width: w, height: h)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("eq"))
                        .onChanged { g in
                            lastClickLocation = g.location
                        }
                )
                .onTapGesture(count: 2) {
                    if appState.activePreset.useAdvancedPEQ, appState.canAddFreeBand {
                        let f = EQAxis.f(lastClickLocation.x, w)
                        let db = EQAxis.db(lastClickLocation.y, h)
                        appState.addTasteBand(freqHz: f, gainDB: db)
                    }
                }

                // Hz labels
                ForEach(labelF, id: \.self) { lf in
                    Text(Fmt.hz(lf))
                        .type(TimbreTypography.monoSmall)
                        .foregroundStyle(c.ink_muted)
                        .fixedSize()
                        .position(x: min(max(EQAxis.x(lf, w), 10), w - 12), y: h + 11)
                }
                // dB labels
                ForEach([12.0, 6.0, 0.0, -6.0, -12.0], id: \.self) { d in
                    Text(d == 0 ? "0" : Fmt.db(d, decimals: 0))
                        .type(TimbreTypography.monoSmall)
                        .foregroundStyle(d == 0 ? c.ink_secondary : c.ink_muted)
                        .fixedSize()
                        .position(x: w + 18, y: EQAxis.y(d, h))
                }

                // Fixed layouts (4 / 5 / 10 bands): one handle per band at its fixed frequency; only the gain moves.
                if !appState.activePreset.useAdvancedPEQ {
                    let layout = appState.activePreset.layout
                    let gains = appState.activePreset.gains(for: layout)
                    ForEach(Array(layout.slots.enumerated()), id: \.offset) { idx, slot in
                        let gain = gains[idx]
                        let hid = layoutHandleID(idx)
                        let active = dragged == hid || hovered == hid || appState.selectedFixedSlotIndex == idx
                        let hx = EQAxis.x(slot.freqHz, w)
                        let hy = EQAxis.y(gain, h)
                        ZStack {
                            Circle().fill(active ? c.bg_raised : c.bg_surface)
                            Circle().strokeBorder(abs(gain) > 0.01 || active ? c.accent_signal : c.ink_muted, lineWidth: active ? 2 : 1.5)
                            Text("\(idx + 1)")
                                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(abs(gain) > 0.01 || active ? c.ink_primary : c.ink_muted)
                        }
                        .frame(width: active ? 20 : 17, height: active ? 20 : 17)
                        .contentShape(Circle())
                        .onHover { isHov in
                            hovered = isHov ? hid : (hovered == hid ? nil : hovered)
                        }
                        .position(x: hx, y: hy)
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("eq"))
                                .onChanged { g in
                                    dragged = hid
                                    appState.selectedFixedSlotIndex = idx
                                    appState.setLayoutGain(EQAxis.db(g.location.y, h), at: idx)
                                }
                                .onEnded { _ in
                                    dragged = nil
                                    appState.selectedFixedSlotIndex = nil
                                }
                        )
                        .simultaneousGesture(
                            TapGesture(count: 2).onEnded {
                                appState.setLayoutGain(0.0, at: idx)
                            }
                        )
                        .animation(TimbreMotion.snappy, value: active)
                        .accessibilityLabel("Band \(idx + 1)")
                        .accessibilityValue("\(Fmt.hz(slot.freqHz)) Hz, \(Fmt.db(gain)) dB")

                        if dragged == hid || hovered == hid {
                            handleReadout(
                                title: "#\(idx + 1) · \(freqText(slot.freqHz)) Hz · \(Fmt.db(gain)) dB",
                                x: hx,
                                y: hy,
                                w: w,
                                h: h
                            )
                        }
                    }
                }

                // Band handles (free PEQ)
                if appState.activePreset.useAdvancedPEQ {
                    ForEach(Array(appState.activePreset.tasteBands.enumerated()), id: \.element.id) { idx, band in
                        let selected = appState.selectedEQBandID == band.id
                        let active = dragged == band.id || hovered == band.id || selected
                        let hasGain = band.type == .peak || band.type == .lowShelf || band.type == .highShelf
                        let hx = EQAxis.x(band.freqHz, w)
                        let hy = EQAxis.y(hasGain ? band.gainDB : 0, h)
                        ZStack {
                            if selected {
                                Circle()
                                    .strokeBorder(c.accent_signal.opacity(0.35), lineWidth: 3)
                                    .frame(width: 24, height: 24)
                            }
                            Circle().fill(band.enabled ? (active ? c.bg_raised : c.bg_surface) : c.bg_inset)
                            Circle().strokeBorder(band.enabled ? c.accent_signal : c.ink_muted, lineWidth: active ? 2 : 1.5)
                            Text("\(idx + 1)")
                                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(band.enabled ? c.ink_primary : c.ink_muted)
                        }
                        .frame(width: active ? 20 : 17, height: active ? 20 : 17)
                        .contentShape(Circle())
                        .onHover { isHov in
                            hovered = isHov ? band.id : (hovered == band.id ? nil : hovered)
                        }
                        .position(x: hx, y: hy)
                        .onTapGesture(count: 2) {
                            var b = band
                            if hasGain && abs(b.gainDB) > 0.05 {
                                b.gainDB = 0.0
                            } else {
                                b.enabled.toggle()
                            }
                            appState.selectedEQBandID = band.id
                            appState.updateTasteBand(b)
                        }
                        .onTapGesture(count: 1) {
                            appState.selectedEQBandID = band.id
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("eq"))
                                .onChanged { g in
                                    if dragged != band.id {
                                        dragged = band.id
                                        dragStartQ = band.q
                                        appState.selectedEQBandID = band.id
                                    }
                                    var b = band
                                    if NSEvent.modifierFlags.contains(.option) {
                                        // Option-drag vertically adjusts Q (bandwidth)
                                        let baseQ = dragStartQ ?? band.q
                                        let factor = pow(2.0, Double(-g.translation.height) / 60.0)
                                        b.q = ((min(max(baseQ * factor, 0.1), 10.0)) * 100).rounded() / 100
                                    } else {
                                        b.freqHz = min(max(EQAxis.f(g.location.x, w), EQAxis.fMin), EQAxis.fMax)
                                        if hasGain {
                                            b.gainDB = (EQAxis.db(g.location.y, h) * 10).rounded() / 10
                                        }
                                    }
                                    appState.updateTasteBand(b)
                                }
                                .onEnded { _ in
                                    dragged = nil
                                    dragStartQ = nil
                                }
                        )
                        .animation(TimbreMotion.snappy, value: active)
                        .accessibilityLabel("Band \(idx + 1)")
                        .accessibilityValue("\(Fmt.hz(band.freqHz)) Hz, \(Fmt.db(band.gainDB)) dB")

                        if dragged == band.id || hovered == band.id {
                            let readoutText = hasGain
                                ? "#\(idx + 1) · \(Fmt.hz(band.freqHz)) Hz · \(Fmt.db(band.gainDB)) dB · Q \(String(format: "%.2f", band.q))"
                                : "#\(idx + 1) · \(Fmt.hz(band.freqHz)) Hz · Q \(String(format: "%.2f", band.q))"
                            handleReadout(title: readoutText, x: hx, y: hy, w: w, h: h)
                        }
                    }
                }
            }
            .coordinateSpace(name: "eq")
        }
        .frame(height: height)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func handleReadout(title: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> some View {
        let clampedX = min(max(x, 86), max(86, w - 86))
        let aboveY = y > 36 ? (y - 22) : min(h - 14, y + 22)
        Text(title)
            .type(TimbreTypography.monoSmall)
            .foregroundStyle(c.ink_primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(
                Capsule()
                    .fill(c.bg_raised)
                    .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
            )
            .overlay(
                Capsule()
                    .strokeBorder(c.line_strong, lineWidth: 0.75)
            )
            .fixedSize()
            .position(x: clampedX, y: aboveY)
            .allowsHitTesting(false)
    }
}

/// Isolated 24 Hz FFT spectrum overlay inside `EQCurveCanvas`.
private struct EQSpectrumOverlay: View {
    @ObservedObject var liveMeters: LiveMeterModel
    let hasLiveSignal: Bool
    let sampleRate: Double
    @Environment(\.palette) private var c

    var body: some View {
        let spectrum = hasLiveSignal ? liveMeters.telemetry.spectrumBinsDB : []
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            guard w > 1, h > 1, spectrum.count > 8 else { return }
            var sp = Path()
            sp.move(to: CGPoint(x: 0, y: h))
            let n = spectrum.count
            for (i, v) in spectrum.enumerated() where i > 0 {
                let fr = Double(i) / Double(n) * sampleRate / 2
                guard fr >= EQAxis.fMin, fr <= EQAxis.fMax else { continue }
                let norm = CGFloat(min(max((Double(v) + 90) / 90, 0), 1))
                sp.addLine(to: CGPoint(x: EQAxis.x(fr, w), y: h - norm * h * 0.9))
            }
            sp.addLine(to: CGPoint(x: w, y: h))
            sp.closeSubpath()
            ctx.fill(sp, with: .color(c.ink_primary.opacity(0.05)))
        }
    }
}

/// Axis math for the EQ curve: log frequency (20 Hz–20 kHz) × ±15 dB. A plain enum outside the View,
/// so it is not MainActor-isolated: Canvas closures are nonisolated under Swift 6.1 (Xcode 16.4,
/// the CI runner) and must be able to call it.
enum EQAxis {
    static let fMin = 20.0
    static let fMax = 20000.0
    static let dbRange = 15.0
    static let curveFrequencies: [Double] = (0..<240).map { i in
        pow(10, log10(fMin) + Double(i) / 239.0 * (log10(fMax) - log10(fMin)))
    }

    static func x(_ f: Double, _ w: CGFloat) -> CGFloat {
        CGFloat((log10(min(max(f, fMin), fMax)) - log10(fMin)) / (log10(fMax) - log10(fMin))) * w
    }
    static func f(_ x: CGFloat, _ w: CGFloat) -> Double {
        pow(10, log10(fMin) + Double(min(max(x / max(w, 1), 0), 1)) * (log10(fMax) - log10(fMin)))
    }
    static func y(_ db: Double, _ h: CGFloat) -> CGFloat {
        h * (1 - CGFloat((min(max(db, -dbRange), dbRange) + dbRange) / (2 * dbRange)))
    }
    static func db(_ y: CGFloat, _ h: CGFloat) -> Double {
        (1 - Double(min(max(y / max(h, 1), 0), 1))) * 2 * dbRange - dbRange
    }
}
