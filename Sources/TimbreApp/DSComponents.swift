// SPDX-License-Identifier: MPL-2.0
// timbr. design system — native component library (docs/05-design-system/04-componentes.md).
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

/// Ronda-style numbered section header: `01  Title ··········· trailing`.
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

/// Ronda KPI: eyebrow label, large tabular value, one-line footnote.
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
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
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

/// Three-bar activity meter for the notch ears. Driven by real level; static when silent.
struct MiniMeter: View {
    /// Real level 0…1, or nil when nothing is measured (then a static "playing" glyph, never a fake meter).
    var level: Double?
    var active: Bool
    var color: Color
    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                let weight: [Double] = [0.62, 1.0, 0.78]
                let glyph: [CGFloat] = [6, 11, 8]
                let h: CGFloat = !active ? 3 : (level.map { max(3, 13 * CGFloat(min(1, $0 * weight[i]))) } ?? glyph[i])
                Capsule().fill(color).frame(width: 2.5, height: h)
            }
        }
        .frame(height: 14)
        .animation(.linear(duration: 0.09), value: level)
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
        .animation(.linear(duration: 0.08), value: dbfs)
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
    @ViewBuilder var content: () -> Content
    @Environment(\.palette) private var c

    var body: some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 10, weight: .medium))
                }
                Text(title).type(TimbreTypography.caption).lineLimit(1)
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
