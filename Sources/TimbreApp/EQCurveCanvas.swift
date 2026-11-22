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

    // Static and nonisolated: these are pure math used inside Canvas closures, which Swift 6.1
    // (Xcode 16.4, the CI runner) treats as nonisolated.
    private static let fMin = 20.0, fMax = 20000.0
    private static let dbRange = 15.0
    private let gridF: [Double] = [20, 30, 40, 50, 60, 80, 100, 200, 300, 400, 500, 600, 800, 1000, 2000, 3000, 4000, 5000, 6000, 8000, 10000, 20000]
    private let majorF: [Double] = [100, 1000, 10000]
    private let labelF: [Double] = [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000]

    public init(appState: AppState, height: CGFloat = 300) {
        self.appState = appState
        self.height = height
    }

    nonisolated private func x(_ f: Double, _ w: CGFloat) -> CGFloat {
        CGFloat((log10(min(max(f, Self.fMin), Self.fMax)) - log10(Self.fMin)) / (log10(Self.fMax) - log10(Self.fMin))) * w
    }
    nonisolated private func f(_ x: CGFloat, _ w: CGFloat) -> Double {
        pow(10, log10(Self.fMin) + Double(min(max(x / max(w, 1), 0), 1)) * (log10(Self.fMax) - log10(Self.fMin)))
    }
    nonisolated private func y(_ db: Double, _ h: CGFloat) -> CGFloat {
        h * (1 - CGFloat((min(max(db, -Self.dbRange), Self.dbRange) + Self.dbRange) / (2 * Self.dbRange)))
    }
    nonisolated private func db(_ y: CGFloat, _ h: CGFloat) -> Double {
        (1 - Double(min(max(y / max(h, 1), 0), 1))) * 2 * Self.dbRange - Self.dbRange
    }

    private var freqs: [Double] {
        (0..<240).map { i in pow(10, log10(Self.fMin) + Double(i) / 239 * (log10(Self.fMax) - log10(Self.fMin))) }
    }

    public var body: some View {
        let fs = freqs
        let corr = appState.tapEngine.evaluateCurve(bands: appState.activePreset.correctionBands, freqsHz: fs, layer: .correction).magDB
        let taste = appState.tapEngine.evaluateCurve(bands: appState.activePreset.effectiveTasteBands, freqsHz: fs, layer: .taste).magDB
        let result = zip(corr, taste).map { $0 + $1 }
        let hasCorrection = appState.activePreset.correctionBands.contains { $0.enabled }
        let spectrum = appState.telemetry.spectrumBinsDB
        let rate = appState.activeOutputDevice?.sampleRate ?? 48000

        GeometryReader { geo in
            let w = geo.size.width - 34   // right gutter for dB labels
            let h = geo.size.height - 20  // bottom gutter for Hz labels
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    // Grid
                    for gf in gridF {
                        var p = Path(); let gx = x(gf, w)
                        p.move(to: CGPoint(x: gx, y: 0)); p.addLine(to: CGPoint(x: gx, y: h))
                        ctx.stroke(p, with: .color(majorF.contains(gf) ? c.line_default : c.line_grid), lineWidth: 0.5)
                    }
                    for d in stride(from: -12.0, through: 12.0, by: 6.0) {
                        var p = Path(); let gy = y(d, h)
                        p.move(to: CGPoint(x: 0, y: gy)); p.addLine(to: CGPoint(x: w, y: gy))
                        ctx.stroke(p, with: .color(d == 0 ? c.line_strong : c.line_grid), lineWidth: d == 0 ? 0.75 : 0.5)
                    }
                    // Live spectrum (real data only; empty when no tap is active)
                    if spectrum.count > 8 {
                        var sp = Path()
                        sp.move(to: CGPoint(x: 0, y: h))
                        let n = spectrum.count
                        for (i, v) in spectrum.enumerated() where i > 0 {
                            let fr = Double(i) / Double(n) * rate / 2
                            guard fr >= Self.fMin, fr <= Self.fMax else { continue }
                            let norm = CGFloat(min(max((Double(v) + 90) / 90, 0), 1))
                            sp.addLine(to: CGPoint(x: x(fr, w), y: h - norm * h * 0.9))
                        }
                        sp.addLine(to: CGPoint(x: w, y: h)); sp.closeSubpath()
                        ctx.fill(sp, with: .color(c.ink_primary.opacity(0.05)))
                    }
                    // Result fill between curve and 0 dB
                    let zeroY = y(0, h)
                    var fill = Path(); fill.move(to: CGPoint(x: 0, y: zeroY))
                    for (i, fr) in fs.enumerated() { fill.addLine(to: CGPoint(x: x(fr, w), y: y(result[i], h))) }
                    fill.addLine(to: CGPoint(x: w, y: zeroY)); fill.closeSubpath()
                    ctx.fill(fill, with: .color(c.accent_fill))

                    func curve(_ m: [Double]) -> Path {
                        var p = Path()
                        for (i, fr) in fs.enumerated() {
                            let pt = CGPoint(x: x(fr, w), y: y(m[i], h))
                            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                        }
                        return p
                    }
                    if hasCorrection {
                        ctx.stroke(curve(corr), with: .color(c.ink_secondary), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        ctx.stroke(curve(taste), with: .color(c.ink_muted), style: StrokeStyle(lineWidth: 1))
                    }
                    ctx.stroke(curve(result), with: .color(c.accent_signal), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                .frame(width: w, height: h)

                // Hz labels
                ForEach(labelF, id: \.self) { lf in
                    Text(Fmt.hz(lf))
                        .type(TimbreTypography.monoSmall)
                        .foregroundStyle(c.ink_muted)
                        .fixedSize()
                        .position(x: min(max(x(lf, w), 10), w - 12), y: h + 11)
                }
                // dB labels
                ForEach([12.0, 6.0, 0.0, -6.0, -12.0], id: \.self) { d in
                    Text(d == 0 ? "0" : Fmt.db(d, decimals: 0))
                        .type(TimbreTypography.monoSmall)
                        .foregroundStyle(d == 0 ? c.ink_secondary : c.ink_muted)
                        .fixedSize()
                        .position(x: w + 18, y: y(d, h))
                }

                // Band handles (advanced mode)
                if appState.activePreset.useAdvancedPEQ {
                    ForEach(Array(appState.activePreset.tasteBands.enumerated()), id: \.element.id) { idx, band in
                        let active = dragged == band.id || hovered == band.id
                        ZStack {
                            Circle().fill(band.enabled ? c.bg_surface : c.bg_inset)
                            Circle().strokeBorder(band.enabled ? c.accent_signal : c.ink_muted, lineWidth: active ? 2 : 1.5)
                            Text("\(idx + 1)")
                                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(band.enabled ? c.ink_primary : c.ink_muted)
                        }
                        .frame(width: active ? 20 : 17, height: active ? 20 : 17)
                        .position(x: x(band.freqHz, w), y: y(band.type == .peak || band.type == .lowShelf || band.type == .highShelf ? band.gainDB : 0, h))
                        .onHover { hovered = $0 ? band.id : (hovered == band.id ? nil : hovered) }
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("eq"))
                                .onChanged { g in
                                    dragged = band.id
                                    var b = band
                                    b.freqHz = min(max(f(g.location.x, w), Self.fMin), Self.fMax)
                                    if b.type == .peak || b.type == .lowShelf || b.type == .highShelf {
                                        b.gainDB = (db(g.location.y, h) * 2).rounded() / 2
                                    }
                                    appState.updateTasteBand(b)
                                }
                                .onEnded { _ in dragged = nil }
                        )
                        .animation(TimbreMotion.snappy, value: active)
                        .accessibilityLabel("Band \(idx + 1)")
                        .accessibilityValue("\(Fmt.hz(band.freqHz)) Hz, \(Fmt.db(band.gainDB)) dB")
                    }
                }
            }
            .coordinateSpace(name: "eq")
        }
        .frame(height: height)
        .accessibilityElement(children: .contain)
    }
}
