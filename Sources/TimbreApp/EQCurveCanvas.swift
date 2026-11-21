// SPDX-License-Identifier: MPL-2.0
import SwiftUI
import TimbreCore
import TimbreEngine
import TimbreDesignSystem

public struct EQCurveCanvas: View {
    @ObservedObject var appState: AppState
    let colors: TimbreColors

    private let minFreq: Double = 20.0
    private let maxFreq: Double = 20000.0
    private let minDB: Double = -18.0
    private let maxDB: Double = 18.0
    private let gridFreqs: [Double] = [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000]
    private let gridDBs: [Double] = [-12, -6, 0, 6, 12]

    @State private var draggedBandID: UUID?

    public init(appState: AppState, colors: TimbreColors) {
        self.appState = appState
        self.colors = colors
    }

    private func xForFreq(_ f: Double, width: CGFloat) -> CGFloat {
        let clamped = min(max(f, minFreq), maxFreq)
        let norm = (log10(clamped) - log10(minFreq)) / (log10(maxFreq) - log10(minFreq))
        return CGFloat(norm) * width
    }

    private func freqForX(_ x: CGFloat, width: CGFloat) -> Double {
        let norm = Double(min(max(x / max(width, 1), 0), 1))
        let logVal = log10(minFreq) + norm * (log10(maxFreq) - log10(minFreq))
        return pow(10.0, logVal)
    }

    private func yForDB(_ db: Double, height: CGFloat) -> CGFloat {
        let norm = (db - minDB) / (maxDB - minDB)
        return height * (1.0 - CGFloat(min(max(norm, 0), 1)))
    }

    private func dbForY(_ y: CGFloat, height: CGFloat) -> Double {
        let norm = 1.0 - Double(min(max(y / max(height, 1), 0), 1))
        return minDB + norm * (maxDB - minDB)
    }

    private func sampleFreqs(count: Int) -> [Double] {
        (0..<count).map { i in
            let t = Double(i) / Double(max(count - 1, 1))
            return pow(10.0, log10(minFreq) + t * (log10(maxFreq) - log10(minFreq)))
        }
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let freqs = sampleFreqs(count: 140)
            let correctionEval = appState.tapEngine.evaluateCurve(bands: appState.activePreset.correctionBands, freqsHz: freqs, layer: .correction)
            let tasteEval = appState.tapEngine.evaluateCurve(bands: appState.activePreset.effectiveTasteBands, freqsHz: freqs, layer: .taste)
            let resultEval = appState.tapEngine.evaluateCurve(bands: appState.activePreset.allEffectiveBands, freqsHz: freqs, layer: nil)

            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    // Vertical log frequency grid
                    for f in gridFreqs {
                        let x = xForFreq(f, width: size.width)
                        var p = Path()
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(p, with: .color(colors.line_subtle), lineWidth: 1)
                    }

                    // Horizontal dB grid
                    for db in gridDBs {
                        let y = yForDB(db, height: size.height)
                        var p = Path()
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(
                            p,
                            with: .color(db == 0 ? colors.line_strong : colors.line_subtle),
                            lineWidth: db == 0 ? 1.2 : 1.0
                        )
                    }

                    // Live FFT spectrum underlay (128 log-spaced bins from 20 Hz .. min(20k, sr*0.49))
                    let bins = appState.telemetry.spectrumBinsDB
                    if bins.count > 8 {
                        var fftPath = Path()
                        let sr = max(appState.tapEngine.lastSampleRate, 44100)
                        let fMax = min(maxFreq, sr * 0.49)
                        let ratio = pow(fMax / minFreq, 1.0 / Double(bins.count - 1))
                        var f = minFreq
                        fftPath.move(to: CGPoint(x: 0, y: size.height))
                        for i in 0..<bins.count {
                            let x = xForFreq(f, width: size.width)
                            let db = Double(min(max(bins[i], -90), 0))
                            let y = size.height * CGFloat((-db) / 90.0)
                            fftPath.addLine(to: CGPoint(x: x, y: y))
                            f *= ratio
                        }
                        fftPath.addLine(to: CGPoint(x: size.width, y: size.height))
                        fftPath.closeSubpath()
                        context.fill(fftPath, with: .color(colors.accent_subtle.opacity(0.45)))
                    }

                    // Correction curve (dashed info)
                    if !appState.activePreset.correctionBands.isEmpty {
                        var cPath = Path()
                        for (idx, f) in freqs.enumerated() {
                            let pt = CGPoint(x: xForFreq(f, width: size.width), y: yForDB(correctionEval.magDB[idx], height: size.height))
                            if idx == 0 { cPath.move(to: pt) } else { cPath.addLine(to: pt) }
                        }
                        context.stroke(cPath, with: .color(colors.semantic_info.opacity(0.85)), style: StrokeStyle(lineWidth: 1.4, dash: [4, 3]))
                    }

                    // Taste curve (thin secondary)
                    if !appState.activePreset.effectiveTasteBands.isEmpty {
                        var tPath = Path()
                        for (idx, f) in freqs.enumerated() {
                            let pt = CGPoint(x: xForFreq(f, width: size.width), y: yForDB(tasteEval.magDB[idx], height: size.height))
                            if idx == 0 { tPath.move(to: pt) } else { tPath.addLine(to: pt) }
                        }
                        context.stroke(tPath, with: .color(colors.accent_strong.opacity(0.7)), lineWidth: 1.2)
                    }

                    // Result curve (primary 2pt accent)
                    var rPath = Path()
                    for (idx, f) in freqs.enumerated() {
                        let db = appState.isProcessingBypassed ? 0.0 : resultEval.magDB[idx]
                        let pt = CGPoint(x: xForFreq(f, width: size.width), y: yForDB(db, height: size.height))
                        if idx == 0 { rPath.move(to: pt) } else { rPath.addLine(to: pt) }
                    }
                    context.stroke(rPath, with: .color(appState.isProcessingBypassed ? colors.ink_muted : colors.accent_base), lineWidth: 2.0)

                    // Interactive Taste band nodes (when in Free PEQ mode)
                    if appState.activePreset.useAdvancedPEQ {
                        for (index, band) in appState.activePreset.tasteBands.enumerated() {
                            let cx = xForFreq(band.freqHz, width: size.width)
                            let cy = yForDB(band.gainDB, height: size.height)
                            let rect = CGRect(x: cx - 6, y: cy - 6, width: 12, height: 12)
                            context.fill(Path(ellipseIn: rect), with: .color(band.enabled ? colors.accent_base : colors.ink_muted))
                            context.stroke(Path(ellipseIn: rect), with: .color(colors.bg_surface), lineWidth: 1.5)
                            let label = Text("\(index + 1)")
                                .font(TimbreTypography.micro.font)
                                .foregroundColor(colors.ink_primary)
                            context.draw(label, at: CGPoint(x: cx, y: max(10, cy - 13)))
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard appState.activePreset.useAdvancedPEQ else { return }
                            if draggedBandID == nil {
                                // Pick closest handle within 24 pt
                                let bands = appState.activePreset.tasteBands
                                var best: (UUID, CGFloat)?
                                for b in bands {
                                    let bx = xForFreq(b.freqHz, width: w)
                                    let by = yForDB(b.gainDB, height: h)
                                    let dist = hypot(bx - value.startLocation.x, by - value.startLocation.y)
                                    if dist < 26, best == nil || dist < best!.1 {
                                        best = (b.id, dist)
                                    }
                                }
                                draggedBandID = best?.0
                            }
                            if let id = draggedBandID,
                               var band = appState.activePreset.tasteBands.first(where: { $0.id == id }) {
                                band.freqHz = min(max(freqForX(value.location.x, width: w), 20.0), 20000.0)
                                band.gainDB = (min(max(dbForY(value.location.y, height: h), -15.0), 15.0) * 10.0).rounded() / 10.0
                                appState.updateTasteBand(band)
                            }
                        }
                        .onEnded { _ in
                            draggedBandID = nil
                        }
                )

                // Axis Labels
                HStack {
                    ForEach([("20", 20.0), ("100", 100.0), ("1k", 1000.0), ("10k", 10000.0), ("20k", 20000.0)], id: \.0) { label, freq in
                        Text(label)
                            .font(TimbreTypography.micro.font)
                            .foregroundStyle(colors.ink_muted)
                            .position(x: min(max(xForFreq(freq, width: w), 14), w - 16), y: h - 10)
                    }
                }
                .allowsHitTesting(false)
            }
            .background(colors.bg_track)
            .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TimbreRadius.control, style: .continuous)
                    .stroke(colors.line_default, lineWidth: 1)
            )
        }
        .frame(minHeight: 220)
    }
}
