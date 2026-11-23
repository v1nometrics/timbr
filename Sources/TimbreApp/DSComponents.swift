// SPDX-License-Identifier: MPL-2.0
// timbr design system — native component library (docs/05-design-system/04-componentes-e-visualizacao-audio.md).
// Every visual value comes from TimbreDesignSystem tokens (ADR-0012). No stock Slider/Toggle/Picker
// chrome is used on product surfaces: they read as "template" and cannot match the notch.
import SwiftUI
import AppKit
import TimbreCore
import TimbreDesignSystem

// MARK: - Palette environment

private struct TimbrPaletteKey: EnvironmentKey {
    static let defaultValue: TimbreColors = .dark
}

private struct TimbrSurfaceKey: EnvironmentKey {
    static let defaultValue: TimbreSurface = .dark
}

public extension EnvironmentValues {
    var palette: TimbreColors {
        get { self[TimbrPaletteKey.self] }
        set { self[TimbrPaletteKey.self] = newValue }
    }
    var surfaceKind: TimbreSurface {
        get { self[TimbrSurfaceKey.self] }
        set { self[TimbrSurfaceKey.self] = newValue }
    }
}

public extension View {
    func surface(_ kind: TimbreSurface) -> some View {
        environment(\.palette, TimbreColors.forSurface(kind))
            .environment(\.surfaceKind, kind)
    }
}

// MARK: - Primitives

/// 0.5 pt hairline that resolves to one device pixel on Retina.
struct Hairline: View {
    var vertical = false
    var strong = false
    @Environment(\.palette) private var c
    var body: some View {
        Rectangle()
            .fill(strong ? c.line_strong : c.line_default)
            .frame(width: vertical ? 0.5 : nil, height: vertical ? nil : 0.5)
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color?
    @Environment(\.palette) private var c
    var body: some View {
        Text(text)
            .type(TimbreTypography.eyebrow)
            .foregroundStyle(color ?? c.ink_muted)
            .lineLimit(1)
    }
}

/// Editorial numbered section header: `01  Title ··········· trailing`.
struct SectionHeader<Trailing: View>: View {
    let index: String
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing
    @Environment(\.palette) private var c

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: TimbreSpacing.s3) {
            Text(index)
                .type(TimbreTypography.eyebrow)
                .foregroundStyle(c.ink_faint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .type(TimbreTypography.sectionTitle)
                    .foregroundStyle(c.ink_primary)
                if let subtitle {
                    Text(subtitle)
                        .type(TimbreTypography.small)
                        .foregroundStyle(c.ink_secondary)
                }
            }
            Spacer(minLength: TimbreSpacing.s4)
            trailing()
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(index: String, title: String, subtitle: String? = nil) {
        self.init(index: index, title: title, subtitle: subtitle, trailing: { EmptyView() })
    }
}

/// White (light) / graphite (dark) sheet with a hairline edge. No drop shadow: depth comes from tone.
struct Card<Content: View>: View {
    var padding: CGFloat = TimbreSpacing.s5
    var inset = false
    @ViewBuilder var content: () -> Content
    @Environment(\.palette) private var c

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous)
                    .fill(inset ? c.bg_inset : c.bg_surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous)
                    .strokeBorder(c.line_default, lineWidth: 1)
            )
    }
}

/// Editorial KPI tile: eyebrow label, large tabular value, one-line footnote.
struct KPITile: View {
    let label: String
    let value: String
    var unit: String?
    var footnote: String?
    var tone: Color?
    var origin: SignalTrustBadge?
    @Environment(\.palette) private var c

    var body: some View {
        VStack(alignment: .leading, spacing: TimbreSpacing.s2) {
            HStack(spacing: 6) {
                Eyebrow(text: label)
                Spacer(minLength: 0)
                if let origin { OriginMark(origin: origin) }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .type(TimbreTypography.mediumValue)
                    .foregroundStyle(tone ?? c.ink_primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit {
                    Text(unit)
                        .type(TimbreTypography.monoValue)
                        .foregroundStyle(c.ink_muted)
                }
            }
            if let footnote {
                Text(footnote)
                    .type(TimbreTypography.caption)
                    .foregroundStyle(c.ink_secondary)
                    .lineLimit(1)
            }
        }
        .padding(TimbreSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous).fill(c.bg_surface))
        .overlay(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous).strokeBorder(c.line_default, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Badges

enum Tone { case neutral, accent, positive, warning, negative, info }

struct Badge: View {
    let text: String
    var tone: Tone = .neutral
    var dot = true
    @Environment(\.palette) private var c

    private var color: Color {
        switch tone {
        case .neutral: return c.ink_secondary
        case .accent: return c.accent_base
        case .positive: return c.semantic_positive
        case .warning: return c.semantic_warning
        case .negative: return c.semantic_negative
        case .info: return c.semantic_info
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            if dot { Circle().fill(color).frame(width: 5, height: 5) }
            Text(text)
                .type(TimbreTypography.micro)
                .foregroundStyle(tone == .neutral ? c.ink_secondary : color)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(Capsule().fill(tone == .neutral ? c.bg_selected : color.opacity(0.12)))
    }
}

/// Shape-coded origin mark (P4): filled = measured, ring = reported by the system, dashed = inferred.
struct OriginMark: View {
    let origin: SignalTrustBadge
    var showLabel = false
    var label: String = ""
    @Environment(\.palette) private var c

    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                switch origin {
                case .measured:
                    Circle().fill(c.ink_primary)
                case .reported:
                    Circle().strokeBorder(c.ink_primary, lineWidth: 1.2)
                case .inferred:
                    Circle().strokeBorder(c.ink_muted, style: StrokeStyle(lineWidth: 1.2, dash: [1.6, 1.4]))
                case .bitPerfect:
                    Circle().fill(c.semantic_positive)
                }
            }
            .frame(width: 7, height: 7)
            if showLabel {
                Text(label).type(TimbreTypography.micro).foregroundStyle(c.ink_muted)
            }
        }
        .accessibilityLabel(label.isEmpty ? origin.rawValue : label)
    }
}

// MARK: - Buttons

enum TButtonKind { case primary, secondary, ghost, accent, destructive }

struct TButtonStyle: ButtonStyle {
    var kind: TButtonKind = .secondary
    var compact = false
    @Environment(\.palette) private var c
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let fg: Color
        let bg: Color
        let stroke: Color
        switch kind {
        case .primary: fg = c.ink_inverse; bg = c.ink_primary; stroke = .clear
        case .accent: fg = c.ink_inverse; bg = c.accent_base; stroke = .clear
        case .secondary: fg = c.ink_primary; bg = c.bg_surface; stroke = c.line_strong
        case .ghost: fg = c.ink_secondary; bg = configuration.isPressed ? c.bg_selected : .clear; stroke = .clear
        case .destructive: fg = c.semantic_negative; bg = c.bg_surface; stroke = c.line_strong
        }
        return configuration.label
            .type(compact ? TimbreTypography.caption : TimbreTypography.small)
            .fontWeight(.medium)
            .foregroundStyle(fg)
            .padding(.horizontal, compact ? 9 : 12)
            .frame(height: compact ? 24 : 28)
            .background(RoundedRectangle(cornerRadius: TimbreRadius.control, style: .continuous).fill(bg))
            .overlay(RoundedRectangle(cornerRadius: TimbreRadius.control, style: .continuous).strokeBorder(stroke, lineWidth: 0.5))
            .opacity(enabled ? 1 : 0.38)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(TimbreMotion.pressOut, value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == TButtonStyle {
    static func t(_ kind: TButtonKind, compact: Bool = false) -> TButtonStyle { TButtonStyle(kind: kind, compact: compact) }
}

/// A small, quiet "i" for the corner of a card: nothing shows until it is clicked, then a short note in a popover.
/// Replaces the hover tooltip, which was easy to trigger by accident and invisible to anyone not hovering.
struct InfoHintButton: View {
    let text: String
    var label: String = ""
    /// Design review only: `--hint-open` opens the note on the first card.
    var startsOpen = false
    @Environment(\.palette) private var c
    @State private var shown = false
    @State private var hover = false

    var body: some View {
        Button { shown.toggle() } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(shown || hover ? c.ink_secondary : c.ink_faint)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .popover(isPresented: $shown, arrowEdge: .bottom) {
            Text(text)
                .type(TimbreTypography.small)
                .foregroundStyle(c.ink_primary)
                .frame(width: 230, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
        }
        .onAppear { if startsOpen && ProcessInfo.processInfo.arguments.contains("--hint-open") { shown = true } }
        .accessibilityLabel(label.isEmpty ? text : label)
        .accessibilityHint(text)
    }
}

/// Square icon button with hover wash. Used for mute, remove, reveal, close.
struct IconButton: View {
    let symbol: String
    var size: CGFloat = 26
    var active = false
    var activeColor: Color?
    var help: String = ""
    let action: () -> Void
    @Environment(\.palette) private var c
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.46, weight: .medium))
                .foregroundStyle(active ? (activeColor ?? c.ink_primary) : (hover ? c.ink_primary : c.ink_secondary))
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: TimbreRadius.control, style: .continuous)
                        .fill(active ? (activeColor ?? c.ink_primary).opacity(0.12) : (hover ? c.bg_hover : .clear))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .onHover { hover = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(TimbreMotion.pressOut, value: configuration.isPressed)
    }
}

// MARK: - Switch

struct TSwitch: View {
    @Binding var isOn: Bool
    var label: String = ""
    @Environment(\.palette) private var c

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? c.accent_controlOn : c.bg_track)
                Circle()
                    .fill(isOn ? c.ink_inverse : Color.white)
                    .shadow(color: .black.opacity(isOn ? 0 : 0.18), radius: 1, y: 0.5)
                    .padding(2)
            }
            .frame(width: 30, height: 18)
            .animation(TimbreMotion.snappy, value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "on" : "off")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Segmented

struct TSegmented<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value
    @Environment(\.palette) private var c
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { i in
                let (value, title) = options[i]
                let selected = value == selection
                Button {
                    selection = value
                } label: {
                    Text(title)
                        .type(TimbreTypography.caption)
                        .fontWeight(selected ? .semibold : .regular)
                        .foregroundStyle(selected ? c.ink_primary : c.ink_secondary)
                        .padding(.horizontal, 10)
                        .frame(height: 22)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                                    .fill(c.bg_raised)
                                    .overlay(RoundedRectangle(cornerRadius: 5.5, style: .continuous).strokeBorder(c.line_default, lineWidth: 0.5))
                                    .shadow(color: .black.opacity(0.06), radius: 1, y: 0.5)
                                    .matchedGeometryEffect(id: "seg", in: ns)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: TimbreRadius.control, style: .continuous).fill(c.bg_selected))
        .animation(TimbreMotion.snappy, value: selection)
    }
}

// MARK: - Fader

/// Thin-track fader. Unity (100% / 0 dB) gets a detent tick; dragging past it changes tone.
/// ⌥-drag = fine (1/10). Double-click = reset. Keyboard: arrows when focused via accessibility.
struct TFader: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var unity: Double? = nil
    var bipolar = false
    var resetValue: Double? = nil
    var tint: Color? = nil
    var overTint: Color? = nil
    var height: CGFloat = 22
    var trackHeight: CGFloat = 3
    var label: String = ""
    var valueText: String = ""
    /// Console taper: unity sits at this fraction of travel (e.g. 0.75), the rest is boost.
    var unityPosition: Double? = nil
    /// Optional embedded live signal level (0…1) inside the fader track (audiocn FaderTrack + LevelMeter pattern).
    var liveMeterNorm: Double? = nil
    /// Optional tick values along the track (audiocn FaderScale).
    var scaleMarks: [Double] = []
    @Environment(\.palette) private var c
    @State private var hover = false
    @State private var dragging = false
    @State private var dragStartValue: Double = 0

    private func norm(_ v: Double) -> CGFloat {
        let x = min(max(v, range.lowerBound), range.upperBound)
        if let u = unity, let up = unityPosition {
            if x <= u { return CGFloat((x - range.lowerBound) / (u - range.lowerBound) * up) }
            return CGFloat(up + (x - u) / (range.upperBound - u) * (1 - up))
        }
        return CGFloat((x - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    private func value(at fraction: Double) -> Double {
        let p = min(max(fraction, 0), 1)
        if let u = unity, let up = unityPosition {
            if p <= up { return range.lowerBound + p / up * (u - range.lowerBound) }
            return u + (p - up) / (1 - up) * (range.upperBound - u)
        }
        return range.lowerBound + p * (range.upperBound - range.lowerBound)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x = norm(value) * w
            let anchorX = bipolar ? norm(0) * w : 0
            let isOver = unity.map { value > $0 + 0.0001 } ?? false
            let fill = isOver ? (overTint ?? c.semantic_warning) : (tint ?? c.ink_primary)
            ZStack(alignment: .leading) {
                Capsule().fill(c.bg_track).frame(height: trackHeight)
                if let live = liveMeterNorm, live > 0.005 {
                    Capsule()
                        .fill(c.semantic_positive.opacity(0.28))
                        .frame(width: min(w, max(trackHeight, CGFloat(min(max(live, 0), 1)) * w)), height: trackHeight)
                }
                ForEach(scaleMarks, id: \.self) { mark in
                    Rectangle()
                        .fill(c.ink_faint)
                        .frame(width: 1, height: trackHeight + 3)
                        .offset(x: norm(mark) * w - 0.5)
                        .opacity(0.55)
                }
                Capsule()
                    .fill(fill)
                    .frame(width: max(abs(x - anchorX), trackHeight), height: trackHeight)
                    .offset(x: min(x, anchorX))
                if let unity {
                    Rectangle()
                        .fill(c.ink_muted)
                        .frame(width: 1, height: trackHeight + 6)
                        .offset(x: norm(unity) * w - 0.5)
                        .opacity(0.7)
                }
                if bipolar {
                    Rectangle().fill(c.ink_muted).frame(width: 1, height: trackHeight + 6).offset(x: anchorX - 0.5)
                }
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.22), radius: 1.5, y: 0.5)
                    .frame(width: (hover || dragging) ? 13 : 10, height: (hover || dragging) ? 13 : 10)
                    .offset(x: x - ((hover || dragging) ? 6.5 : 5))
                    .animation(TimbreMotion.snappy, value: hover || dragging)
            }
            .frame(height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if !dragging { dragging = true; dragStartValue = value }
                        let fine = NSEvent.modifierFlags.contains(.option)
                        let span = range.upperBound - range.lowerBound
                        var v: Double
                        if fine {
                            v = dragStartValue + Double(g.translation.width / max(w, 1)) * span * 0.1
                        } else {
                            v = value(at: Double(g.location.x / max(w, 1)))
                        }
                        if let unity, !fine, abs(norm(v) - norm(unity)) < 0.012 { v = unity }
                        value = min(max(v, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in dragging = false }
            )
            .simultaneousGesture(TapGesture(count: 2).onEnded {
                if let r = resetValue ?? unity { value = r }
            })
        }
        .frame(height: height)
        .onHover { hover = $0 }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(valueText)
        .accessibilityAdjustableAction { dir in
            let step = (range.upperBound - range.lowerBound) / 50
            switch dir {
            case .increment: value = min(value + step, range.upperBound)
            case .decrement: value = max(value - step, range.lowerBound)
            @unknown default: break
            }
        }
    }
}

// MARK: - Scrubbable number (Pro-Q style)

/// Drag horizontally to change; scroll to fine-tune. Shows value in mono.
struct ScrubValue: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var logarithmic = false
    var format: (Double) -> String
    var width: CGFloat = 72
    @Environment(\.palette) private var c
    @State private var start: Double?
    @State private var hover = false

    var body: some View {
        Text(format(value))
            .type(TimbreTypography.monoValue)
            .foregroundStyle(c.ink_primary)
            .frame(width: width, height: 24, alignment: .trailing)
            .padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: TimbreRadius.badge, style: .continuous).fill(hover || start != nil ? c.bg_selected : c.bg_hover))
            .contentShape(Rectangle())
            .onHover { h in
                hover = h
                if h { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { g in
                        if start == nil { start = value }
                        guard let s = start else { return }
                        let fine = NSEvent.modifierFlags.contains(.option) ? 0.1 : 1.0
                        let delta = Double(g.translation.width) * fine
                        var v: Double
                        if logarithmic {
                            v = s * pow(2.0, delta / 120.0)
                        } else {
                            v = s + delta * step / 3.0
                        }
                        v = (v / step).rounded() * step
                        value = min(max(v, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in start = nil }
            )
            .accessibilityElement()
            .accessibilityValue(format(value))
            .accessibilityAdjustableAction { dir in
                let mult = logarithmic ? (dir == .increment ? 1.06 : 1 / 1.06) : 1
                if logarithmic { value = min(max(value * mult, range.lowerBound), range.upperBound) }
                else { value = min(max(value + (dir == .increment ? step : -step), range.lowerBound), range.upperBound) }
            }
    }
}

// MARK: - App icon & transport glyph

@MainActor
enum AppIconCache {
    private static var cache: [String: NSImage] = [:]
    static func icon(for bundleID: String) -> NSImage? {
        if let hit = cache[bundleID] { return hit }
        // macOS daemon groups (System sounds, Siri…) borrow the icon of the app that represents them.
        let lookup = SystemAudioClient(bundleID: bundleID)?.iconBundleID ?? bundleID
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: lookup) else { return nil }
        let img = NSWorkspace.shared.icon(forFile: url.path)
        cache[bundleID] = img
        return img
    }
}

struct AppIcon: View {
    let bundleID: String
    var name: String = ""
    var size: CGFloat = 24
    @Environment(\.palette) private var c

    var body: some View {
        Group {
            if let img = AppIconCache.icon(for: bundleID) {
                Image(nsImage: img).resizable().interpolation(.high)
            } else {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(c.bg_selected)
                    .overlay(
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: size * 0.45, weight: .semibold))
                            .foregroundStyle(c.ink_secondary)
                    )
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension DeviceTransport {
    var symbol: String {
        switch self {
        case .builtIn: return "laptopcomputer"
        case .usb: return "cable.connector"
        case .bluetoothA2DP: return "headphones"
        case .bluetoothHFP: return "phone.badge.waveform"
        case .wiredAnalog: return "headphones"
        case .hdmi: return "tv"
        case .aggregate: return "square.stack.3d.up"
        case .virtual: return "waveform"
        case .continuity: return "airpods"
        case .unknown: return "hifispeaker"
        }
    }
}

extension AudioDeviceDescriptor {
    /// Device symbol that prefers the product family (AirPods, Momentum) over the transport.
    var glyph: String {
        let n = name.lowercased()
        if n.contains("airpods max") { return "airpodsmax" }
        if n.contains("airpods pro") { return "airpodspro" }
        if n.contains("airpods") { return "airpods" }
        if n.contains("speaker") || n.contains("alto-falante") || n.contains("altavoz") { return transport == .builtIn ? "laptopcomputer" : "hifispeaker" }
        return transport.symbol
    }

    func transportLabel(_ t: (String) -> String) -> String {
        switch transport {
        case .builtIn: return t("ui.transport.builtin")
        case .usb: return "USB"
        case .bluetoothA2DP: return "Bluetooth"
        case .bluetoothHFP: return t("ui.transport.hfp")
        case .wiredAnalog: return t("ui.transport.analog")
        case .hdmi: return "HDMI / DP"
        case .aggregate: return t("ui.transport.aggregate")
        case .virtual: return t("ui.transport.virtual")
        case .continuity: return "Continuity"
        case .unknown: return "—"
        }
    }

    var rateLabel: String {
        let k = sampleRate / 1000
        return k == k.rounded() ? String(format: "%.0f kHz", k) : String(format: "%.1f kHz", k)
    }
}

struct DeviceGlyph: View {
    let device: AudioDeviceDescriptor
    var size: CGFloat = 30
    var active = false
    @Environment(\.palette) private var c

    var body: some View {
        Image(systemName: device.glyph)
            .font(.system(size: size * 0.46, weight: .regular))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(active ? c.ink_primary : c.ink_secondary)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: TimbreRadius.control + 1, style: .continuous).fill(active ? c.bg_selected : c.bg_hover))
            .accessibilityHidden(true)
    }
}

// MARK: - Meters

/// Five-bar symmetric harmonic mark (`timbr` silhouette) for the notch ears.
/// Gentle harmonic overtone breathing (~2.6 s cadence, 12 Hz) when active; static with Reduce Motion; zero work when paused.
struct MiniMeter: View {
    /// Real level 0…1, or nil on native zero-tap pass-through (subtle harmonic breath, never a fake peak meter).
    var level: Double?
    var active: Bool
    var color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: !active || reduceMotion)) { ctx in
            let bars = TimbreHarmonicMath.samples(
                active: active,
                level: level,
                time: ctx.date.timeIntervalSinceReferenceDate,
                reduceMotion: reduceMotion
            )
            HStack(alignment: .center, spacing: 1.5) {
                ForEach(0..<bars.count, id: \.self) { i in
                    Capsule()
                        .fill(color.opacity(bars[i].opacity))
                        .frame(width: 1.5, height: bars[i].height)
                }
            }
        }
        .frame(height: 14)
        .animation(TimbreMotion.meter, value: level)
        .accessibilityHidden(true)
    }
}

/// Horizontal peak/level bar with clip segment (> -1 dBFS) shown in warning.
struct LevelBar: View {
    var dbfs: Double
    var floorDB: Double = -60
    @Environment(\.palette) private var c
    var body: some View {
        GeometryReader { g in
            let n = CGFloat(min(max((dbfs - floorDB) / -floorDB, 0), 1))
            ZStack(alignment: .leading) {
                Capsule().fill(c.bg_track)
                Capsule().fill(dbfs > -1 ? c.semantic_warning : c.ink_secondary).frame(width: g.size.width * n)
            }
        }
        .frame(height: 3)
        .animation(TimbreMotion.meter, value: dbfs)
    }
}

// MARK: - audiocn-Modeled Audio UI Primitives (TKnob, TChannelButton, TClipIndicator, TdBReadout, TdBScale, TLevelMeter, TLCDDisplay, TLCDMeter)

/// Console channel toggle button (`M` mute, `S` solo, `BYP` bypass, `A/B`, `LIM`) modeled after `@audiocn/channel-toggle`.
enum TChannelButtonTone {
    case mute
    case solo
    case monitor
    case neutral
}

struct TChannelButton: View {
    let text: String
    var symbol: String? = nil
    var pressed: Bool
    var tone: TChannelButtonTone = .mute
    var size: CGFloat = 22
    var help: String = ""
    let action: () -> Void
    @Environment(\.palette) private var c
    @State private var hover = false

    private var activeFill: Color {
        switch tone {
        case .mute: return c.semantic_warning
        case .solo: return c.semantic_info
        case .monitor: return c.semantic_positive
        case .neutral: return c.ink_primary
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: size * 0.42, weight: .semibold))
                }
                if !text.isEmpty {
                    Text(text)
                        .font(.system(size: size * 0.44, weight: .bold, design: .monospaced))
                        .tracking(0.3)
                }
            }
            .foregroundStyle(pressed ? c.ink_inverse : (hover ? c.ink_primary : c.ink_secondary))
            .padding(.horizontal, text.count > 1 ? 6 : 0)
            .frame(minWidth: size, minHeight: size)
            .background(
                RoundedRectangle(cornerRadius: TimbreRadius.badge, style: .continuous)
                    .fill(pressed ? activeFill : (hover ? c.bg_hover : c.bg_inset))
            )
            .overlay(
                RoundedRectangle(cornerRadius: TimbreRadius.badge, style: .continuous)
                    .strokeBorder(pressed ? activeFill : c.line_default, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .onHover { hover = $0 }
        .help(help)
        .accessibilityLabel(help.isEmpty ? text : help)
        .accessibilityValue(pressed ? "on" : "off")
        .accessibilityAddTraits(.isButton)
    }
}

/// Latching clip / limiter indicator light with optional count and click-to-reset, modeled after `@audiocn/clip-indicator`.
struct TClipIndicator: View {
    var clipping: Bool
    var count: Int = 0
    var label: String = "CLIP"
    var onReset: (() -> Void)? = nil
    @Environment(\.palette) private var c
    @State private var hover = false

    var body: some View {
        Button {
            onReset?()
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(clipping ? c.semantic_negative : c.ink_faint.opacity(0.45))
                    .frame(width: 5, height: 5)
                Text(count > 0 ? "\(label) · \(count)" : label)
                    .type(TimbreTypography.micro)
                    .foregroundStyle(clipping ? c.semantic_negative : c.ink_muted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(
                RoundedRectangle(cornerRadius: TimbreRadius.badge, style: .continuous)
                    .fill(clipping ? c.semantic_negative.opacity(0.14) : (hover && onReset != nil ? c.bg_hover : c.bg_inset))
            )
            .overlay(
                RoundedRectangle(cornerRadius: TimbreRadius.badge, style: .continuous)
                    .strokeBorder(clipping ? c.semantic_negative.opacity(0.45) : c.line_default, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(onReset == nil && !clipping)
        .onHover { hover = $0 }
        .help(clipping ? "Clipping detected — click to reset" : label)
        .accessibilityLabel(clipping ? "Clipping. Reset clip indicator" : label)
    }
}

/// Fixed-width tabular dB readout that colors by zone (`normal`, `warning`, `clip`, `silent`) and never shifts layout, modeled after `@audiocn/db-readout`.
struct TdBReadout: View {
    var dbfs: Double?
    var floorDB: Double = -60.0
    var warningDB: Double = -12.0
    var clipDB: Double = -1.0
    var unit: String = "dB"
    var signed: Bool = false
    var width: CGFloat = 58
    @Environment(\.palette) private var c

    private var zone: AudioMeterZone {
        guard let dbfs else { return .silent }
        return AudioDecibelMath.zone(forDB: dbfs, floorDB: floorDB, warningDB: warningDB, clipDB: clipDB)
    }

    private var color: Color {
        switch zone {
        case .silent: return c.ink_muted
        case .normal: return c.ink_primary
        case .warning: return c.semantic_warning
        case .clip: return c.semantic_negative
        }
    }

    private var formattedText: String {
        guard let dbfs, dbfs.isFinite, dbfs > floorDB else { return "−∞" }
        return signed ? Fmt.db(dbfs) : Fmt.signed(dbfs)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(formattedText)
                .type(TimbreTypography.monoValue)
                .foregroundStyle(color)
                .lineLimit(1)
            if !unit.isEmpty, let dbfs, dbfs.isFinite, dbfs > floorDB {
                Text(unit)
                    .type(TimbreTypography.monoSmall)
                    .foregroundStyle(c.ink_muted)
            }
        }
        .frame(width: width, alignment: .trailing)
        .accessibilityElement(children: .combine)
    }
}

/// Decibel tick marks and labels shared by meters and faders, modeled after `@audiocn/db-scale`.
struct TdBScale: View {
    var minDB: Double = -60.0
    var maxDB: Double = 0.0
    var ticks: [Double] = [-48, -36, -24, -12, -6, -3, 0]
    var audioTaper: Bool = true
    var showLabels: Bool = true
    @Environment(\.palette) private var c

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                ForEach(ticks, id: \.self) { tick in
                    let norm = CGFloat(AudioDecibelMath.dbToNormalized(tick, minDB: minDB, maxDB: maxDB, audioTaper: audioTaper))
                    let x = min(max(norm * w, 0), w)
                    let isMajor = tick == 0 || tick == -6 || tick == -12 || tick == -24 || tick == -48
                    Rectangle()
                        .fill(tick == 0 ? c.line_strong : c.line_default)
                        .frame(width: 1, height: isMajor ? 4 : 2.5)
                        .position(x: x, y: 2)
                    if showLabels && isMajor {
                        Text(tick == 0 ? "0" : "\(Int(tick))")
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(tick == 0 ? c.ink_secondary : c.ink_muted)
                            .fixedSize()
                            .position(x: min(max(x, 8), w - 8), y: 10)
                    }
                }
            }
        }
        .frame(height: showLabels ? 15 : 5)
        .accessibilityHidden(true)
    }
}

/// Dual-layer Peak + RMS/LUFS level meter with held-peak tick, audio taper, and zone coloring, modeled after `@audiocn/level-meter`.
struct TLevelMeter: View {
    var peakDB: Double
    var rmsDB: Double? = nil
    var heldPeakDB: Double? = nil
    var minDB: Double = -60.0
    var maxDB: Double = 0.0
    var warningDB: Double = -12.0
    var clipDB: Double = -1.0
    var audioTaper: Bool = true
    var height: CGFloat = 6
    @Environment(\.palette) private var c

    private func barColor(for db: Double) -> Color {
        switch AudioDecibelMath.zone(forDB: db, floorDB: minDB, warningDB: warningDB, clipDB: clipDB) {
        case .clip: return c.semantic_negative
        case .warning: return c.semantic_warning
        case .normal: return c.ink_primary
        case .silent: return c.ink_muted
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let peakNorm = CGFloat(AudioDecibelMath.dbToNormalized(peakDB, minDB: minDB, maxDB: maxDB, audioTaper: audioTaper))
            let rmsNorm = rmsDB.map { CGFloat(AudioDecibelMath.dbToNormalized($0, minDB: minDB, maxDB: maxDB, audioTaper: audioTaper)) }
            let holdNorm = heldPeakDB.map { CGFloat(AudioDecibelMath.dbToNormalized($0, minDB: minDB, maxDB: maxDB, audioTaper: audioTaper)) }
            let color = barColor(for: peakDB)

            ZStack(alignment: .leading) {
                Capsule().fill(c.bg_track)
                if let rmsNorm {
                    // Dual mode: translucent peak bar behind solid RMS bar
                    Capsule()
                        .fill(color.opacity(0.35))
                        .frame(width: max(0, w * peakNorm))
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, w * min(rmsNorm, peakNorm)))
                } else {
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, w * peakNorm))
                }
                if let holdNorm, holdNorm > 0.01 {
                    Rectangle()
                        .fill(heldPeakDB.map { $0 >= clipDB } == true ? c.semantic_negative : c.ink_primary)
                        .frame(width: 1.5, height: height + 2)
                        .offset(x: min(w - 1.5, max(0, w * holdNorm - 0.75)))
                }
            }
        }
        .frame(height: height)
        .animation(TimbreMotion.meter, value: peakDB)
    }
}

/// Hardware-style dot-matrix LCD screen container with status pixel, bezel, and glowing ink, modeled after `@audiocn/lcd-display`.
struct TLCDDisplay<Content: View>: View {
    var title: String? = nil
    var statusText: String? = nil
    var isLive: Bool = false
    @ViewBuilder var content: () -> Content
    @Environment(\.palette) private var c

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if title != nil || statusText != nil {
                HStack(spacing: 8) {
                    if let title {
                        Text(title)
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .tracking(1.1)
                            .foregroundStyle(c.ink_secondary)
                            .textCase(.uppercase)
                    }
                    Spacer()
                    if let statusText {
                        HStack(spacing: 5) {
                            Rectangle()
                                .fill(isLive ? c.semantic_positive : c.ink_muted)
                                .frame(width: 5, height: 5)
                            Text(statusText)
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                .tracking(0.6)
                                .foregroundStyle(isLive ? c.ink_primary : c.ink_muted)
                        }
                    }
                }
                Hairline()
            }
            content()
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous)
                    .fill(c.bg_inset)
                // Subtle dot-matrix grid pitch overlay
                Canvas { ctx, size in
                    let step: CGFloat = 4
                    var dotPath = Path()
                    var y: CGFloat = 2
                    while y < size.height {
                        var x: CGFloat = 2
                        while x < size.width {
                            dotPath.addRect(CGRect(x: x, y: y, width: 1, height: 1))
                            x += step
                        }
                        y += step
                    }
                    ctx.fill(dotPath, with: .color(c.ink_primary.opacity(0.025)))
                }
                .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous))
                .allowsHitTesting(false)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous)
                .strokeBorder(c.line_strong, lineWidth: 1)
        )
    }
}

/// Whole-segment quantized LCD block-segment stereo/channel level meter with held-peak segment, printed dB scale, and CLIP flag, modeled after `@audiocn/lcd-meter`.
struct TLCDMeterRow: View {
    let channelLabel: String
    var dbfs: Double
    var heldPeakDB: Double? = nil
    var minDB: Double = -60.0
    var maxDB: Double = 0.0
    var warningDB: Double = -12.0
    var clipDB: Double = -1.0
    var segmentCount: Int = 28
    var unit: String = "dBTP"
    @Environment(\.palette) private var c

    var body: some View {
        let layout = LCDSegmentLayout.quantize(
            dbfs: dbfs,
            heldPeakDB: heldPeakDB,
            minDB: minDB,
            maxDB: maxDB,
            warningDB: warningDB,
            clipDB: clipDB,
            segmentCount: segmentCount,
            audioTaper: true
        )
        HStack(spacing: 8) {
            Text(channelLabel)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(c.ink_secondary)
                .frame(width: 24, alignment: .leading)

            GeometryReader { geo in
                let gap: CGFloat = 2
                let totalGap = gap * CGFloat(max(0, layout.totalSegments - 1))
                let segW = max(2, (geo.size.width - totalGap) / CGFloat(layout.totalSegments))
                HStack(spacing: gap) {
                    ForEach(0..<layout.totalSegments, id: \.self) { idx in
                        let isLit = idx < layout.litCount
                        let isHeld = layout.heldPeakIndex == idx
                        let segColor: Color = {
                            if idx >= layout.clipStartIndex { return c.semantic_negative }
                            if idx >= layout.warningStartIndex { return c.semantic_warning }
                            return c.ink_primary
                        }()
                        RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                            .fill((isLit || isHeld) ? segColor : c.ink_primary.opacity(0.08))
                            .opacity(isLit ? 1.0 : (isHeld ? 0.92 : 1.0))
                            .frame(width: segW, height: geo.size.height)
                    }
                }
            }
            .frame(height: 10)

            TdBReadout(
                dbfs: dbfs,
                floorDB: minDB,
                warningDB: warningDB,
                clipDB: clipDB,
                unit: unit,
                width: 68
            )
        }
    }
}

/// Rotary dial control drawn in Canvas with peripheral tick scale (`KnobScale`), bipolar origin arc (`KnobRange`), cap, and pointer (`KnobPointer`), modeled after `@audiocn/knob`.
/// Supports vertical drag, ⌥-fine drag (1/10x), double-click reset to `origin ?? resetValue`, and accessibility increments.
struct TKnob: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = -6.0...6.0
    var step: Double = 0.5
    var origin: Double? = 0.0
    var resetValue: Double? = 0.0
    var size: CGFloat = 46
    var tickCount: Int = 13
    var label: String = ""
    var valueText: String = ""
    @Environment(\.palette) private var c
    @State private var hover = false
    @State private var dragging = false
    @State private var dragStartValue: Double = 0

    var body: some View {
        let geom = KnobArcGeometry.compute(value: value, range: range, origin: origin)
        let isModified = abs(value - (resetValue ?? origin ?? range.lowerBound)) > 0.01

        Canvas { ctx, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let outerR = min(canvasSize.width, canvasSize.height) / 2 - 1.5
            let arcR = outerR - 4.5
            let capR = arcR - 4.5

            // 1. Peripheral scale ticks (KnobScale)
            if tickCount > 1 {
                for i in 0..<tickCount {
                    let frac = Double(i) / Double(tickCount - 1)
                    let deg = geom.trackStartDeg + frac * (geom.trackEndDeg - geom.trackStartDeg)
                    let rad = (deg - 90.0) * .pi / 180.0
                    let isCenter = abs(deg) < 0.5
                    let lit = isModified && geom.isTickLit(tickIndex: i, tickCount: tickCount)
                    let r1 = outerR - (isCenter ? 2.5 : 1.8)
                    let r2 = outerR
                    var tick = Path()
                    tick.move(to: CGPoint(x: center.x + CGFloat(cos(rad)) * r1, y: center.y + CGFloat(sin(rad)) * r1))
                    tick.addLine(to: CGPoint(x: center.x + CGFloat(cos(rad)) * r2, y: center.y + CGFloat(sin(rad)) * r2))
                    ctx.stroke(
                        tick,
                        with: .color(lit ? c.accent_signal : (isCenter ? c.ink_secondary : c.ink_faint)),
                        lineWidth: isCenter ? 1.4 : 1.0
                    )
                }
            }

            // 2. Background arc track (KnobTrack)
            var trackArc = Path()
            trackArc.addArc(
                center: center,
                radius: arcR,
                startAngle: .degrees(geom.trackStartDeg - 90.0),
                endAngle: .degrees(geom.trackEndDeg - 90.0),
                clockwise: false
            )
            ctx.stroke(trackArc, with: .color(c.bg_track), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

            // 3. Active arc from origin to value (KnobRange)
            if abs(geom.valueDeg - geom.originDeg) > 0.5 {
                let startDeg = min(geom.originDeg, geom.valueDeg) - 90.0
                let endDeg = max(geom.originDeg, geom.valueDeg) - 90.0
                var activeArc = Path()
                activeArc.addArc(
                    center: center,
                    radius: arcR,
                    startAngle: .degrees(startDeg),
                    endAngle: .degrees(endDeg),
                    clockwise: false
                )
                ctx.stroke(activeArc, with: .color(c.accent_signal), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }

            // 4. Rotary cap (KnobCap)
            let capRect = CGRect(x: center.x - capR, y: center.y - capR, width: capR * 2, height: capR * 2)
            ctx.fill(Path(ellipseIn: capRect), with: .color(hover || dragging ? c.bg_selected : c.bg_raised))
            ctx.stroke(Path(ellipseIn: capRect), with: .color(hover || dragging ? c.line_strong : c.line_default), lineWidth: 1)

            // 5. Pointer line on cap (KnobPointer)
            let ptrRad = (geom.valueDeg - 90.0) * .pi / 180.0
            let pInner = capR * 0.28
            let pOuter = capR * 0.82
            var ptr = Path()
            ptr.move(to: CGPoint(x: center.x + CGFloat(cos(ptrRad)) * pInner, y: center.y + CGFloat(sin(ptrRad)) * pInner))
            ptr.addLine(to: CGPoint(x: center.x + CGFloat(cos(ptrRad)) * pOuter, y: center.y + CGFloat(sin(ptrRad)) * pOuter))
            ctx.stroke(ptr, with: .color(c.ink_primary), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .onHover { hover = $0 }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    if !dragging {
                        dragging = true
                        dragStartValue = value
                    }
                    let fine = NSEvent.modifierFlags.contains(.option) || NSEvent.modifierFlags.contains(.shift)
                    let sensitivity = fine ? 360.0 : 96.0
                    let span = range.upperBound - range.lowerBound
                    let delta = (Double(-g.translation.height) + Double(g.translation.width) * 0.35) / sensitivity * span
                    var next = dragStartValue + delta
                    if let org = origin, !fine, abs(next - org) < span * 0.025 {
                        next = org
                    } else if step > 0 {
                        next = (next / step).rounded() * step
                    }
                    value = min(max(next, range.lowerBound), range.upperBound)
                }
                .onEnded { _ in dragging = false }
        )
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                if let r = resetValue ?? origin {
                    value = r
                }
            }
        )
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(valueText)
        .accessibilityAdjustableAction { dir in
            let s = step > 0 ? step : (range.upperBound - range.lowerBound) / 24.0
            switch dir {
            case .increment: value = min(value + s, range.upperBound)
            case .decrement: value = max(value - s, range.lowerBound)
            @unknown default: break
            }
        }
    }
}

// MARK: - Field

struct TField: View {
    let placeholder: String
    @Binding var text: String
    var onSubmit: () -> Void = {}
    @Environment(\.palette) private var c
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .type(TimbreTypography.body)
            .foregroundStyle(c.ink_primary)
            .focused($focused)
            .onSubmit(onSubmit)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: TimbreRadius.field, style: .continuous).fill(c.bg_inset))
            .overlay(
                RoundedRectangle(cornerRadius: TimbreRadius.field, style: .continuous)
                    .strokeBorder(focused ? c.ink_primary.opacity(0.5) : c.line_default, lineWidth: focused ? 1 : 0.5)
            )
            .animation(TimbreMotion.snappy, value: focused)
    }
}

// MARK: - Menu chip (native menu, designed label)

struct MenuChip<Content: View>: View {
    let title: String
    var symbol: String?
    /// Icon + chevron only (title becomes the tooltip): for tight spots like the notch wings.
    var iconOnly = false
    @ViewBuilder var content: () -> Content
    @Environment(\.palette) private var c

    var body: some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: iconOnly ? 11 : 10, weight: .medium))
                }
                if !iconOnly { Text(title).type(TimbreTypography.caption).lineLimit(1) }
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 7.5, weight: .semibold)).opacity(0.6)
            }
            .foregroundStyle(c.ink_secondary)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Capsule().fill(c.bg_selected))
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(title)
        .accessibilityLabel(title)
    }
}

// MARK: - Formatting

enum Fmt {
    static func percent(_ v: Double) -> String { "\(Int((v * 100).rounded()))" }
    static func db(_ v: Double, decimals: Int = 1) -> String {
        let r = (v * pow(10, Double(decimals))).rounded() / pow(10, Double(decimals))
        if r == 0 { return String(format: "%.\(decimals)f", 0.0) }
        return String(format: "%+.\(decimals)f", r).replacingOccurrences(of: "-", with: "−")
    }
    static func signed(_ v: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f", v).replacingOccurrences(of: "-", with: "−")
    }
    static func hz(_ f: Double) -> String {
        guard f >= 1000 else { return String(format: "%.0f", f) }
        let k = f / 1000
        if abs(k - k.rounded()) < 0.005 { return String(format: "%.0fk", k) }
        return String(format: k >= 10 ? "%.1fk" : "%.2fk", k).replacingOccurrences(of: "0k", with: "k")
    }
    static func volumeDB(_ linear: Double) -> String {
        guard linear > 0.0001 else { return "−∞" }
        return db(20 * log10(linear))
    }
}


/// Native vector rendering of the approved *Ilha refinada* icon (ADR-0025, `Resources/Brand/timbr-icon.svg`).
/// Drawn directly from the canonical 824x824 tile geometry without macOS icon-grid outer padding so it stays
/// razor-sharp at any Retina scale and aligns flush with typography in Onboarding and About.
struct TimbrBrandIcon: View {
    var size: CGFloat

    var body: some View {
        Canvas { ctx, canvasSize in
            let s = min(canvasSize.width, canvasSize.height) / 824.0
            let strokeW = max(0.5, 5.0 * s)
            let halfStroke = strokeW / 2.0

            func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
                Path(roundedRect: CGRect(x: x * s, y: y * s, width: w * s, height: h * s), cornerRadius: r * s, style: .circular)
            }

            let tileRect = CGRect(
                x: halfStroke,
                y: halfStroke,
                width: 824.0 * s - strokeW,
                height: 824.0 * s - strokeW
            )
            let tilePath = Path(roundedRect: tileRect, cornerRadius: max(0, 185.0 * s - halfStroke), style: .circular)
            ctx.fill(tilePath, with: .color(Color(red: 0xF3 / 255.0, green: 0xF3 / 255.0, blue: 0xF1 / 255.0)))
            ctx.stroke(tilePath, with: .color(Color(red: 0xDE / 255.0, green: 0xDE / 255.0, blue: 0xD9 / 255.0)), lineWidth: strokeW)

            // Black island pill (182-100 = 82, 387-100 = 287, 660x250, rx=125)
            ctx.fill(rounded(82.0, 287.0, 660.0, 250.0, 125.0), with: .color(Color(red: 0, green: 0, blue: 0)))

            // Inner glyph elements (#F2F2F2)
            let glyph = Color(red: 0xF2 / 255.0, green: 0xF2 / 255.0, blue: 0xF2 / 255.0)
            ctx.fill(rounded(222.0, 344.0, 136.0, 136.0, 36.7), with: .color(glyph))
            ctx.fill(rounded(416.0, 365.2, 42.0, 93.5, 21.0), with: .color(glyph))
            ctx.fill(rounded(488.0, 327.0, 42.0, 170.0, 21.0), with: .color(glyph))
            ctx.fill(rounded(560.0, 350.8, 42.0, 122.4, 21.0), with: .color(glyph))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("timbr")
    }
}
