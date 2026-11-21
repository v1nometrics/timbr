// GENERATED FILE - DO NOT EDIT BY HAND (ADR-0012)
// Source: design-system/tokens/*.tokens.json
import SwiftUI

public enum TimbreSurface: String, CaseIterable, Sendable {
    case light, dark, notch
}

public struct TimbreColors: Sendable {
    public let bg_canvas: Color
    public let bg_surface: Color
    public let bg_raised: Color
    public let bg_sidebar: Color
    public let bg_inset: Color
    public let bg_track: Color
    public let bg_hover: Color
    public let bg_selected: Color
    public let ink_primary: Color
    public let ink_secondary: Color
    public let ink_muted: Color
    public let ink_faint: Color
    public let ink_inverse: Color
    public let line_default: Color
    public let line_subtle: Color
    public let line_strong: Color
    public let line_grid: Color
    public let accent_base: Color
    public let accent_strong: Color
    public let accent_subtle: Color
    public let accent_fill: Color
    public let accent_controlOn: Color
    public let accent_signal: Color
    public let semantic_positive: Color
    public let semantic_warning: Color
    public let semantic_negative: Color
    public let semantic_info: Color

    public static let light = TimbreColors(
        bg_canvas: Color(hex: 0xF5F5F2),
        bg_surface: Color(hex: 0xFFFFFF),
        bg_raised: Color(hex: 0xFFFFFF),
        bg_sidebar: Color(hex: 0xEEEEEA),
        bg_inset: Color(hex: 0xF7F7F5),
        bg_track: Color(hex: 0xE6E6E2),
        bg_hover: Color(red: 17/255.0, green: 17/255.0, blue: 17/255.0).opacity(0.04),
        bg_selected: Color(red: 17/255.0, green: 17/255.0, blue: 17/255.0).opacity(0.07),
        ink_primary: Color(hex: 0x111111),
        ink_secondary: Color(hex: 0x5C5C58),
        ink_muted: Color(hex: 0x8C8C87),
        ink_faint: Color(hex: 0xB4B4AF),
        ink_inverse: Color(hex: 0xFFFFFF),
        line_default: Color(red: 17/255.0, green: 17/255.0, blue: 17/255.0).opacity(0.09),
        line_subtle: Color(red: 17/255.0, green: 17/255.0, blue: 17/255.0).opacity(0.055),
        line_strong: Color(red: 17/255.0, green: 17/255.0, blue: 17/255.0).opacity(0.18),
        line_grid: Color(red: 17/255.0, green: 17/255.0, blue: 17/255.0).opacity(0.06),
        accent_base: Color(hex: 0x6B46FF),
        accent_strong: Color(hex: 0x4F27E8),
        accent_subtle: Color(red: 107/255.0, green: 70/255.0, blue: 255/255.0).opacity(0.1),
        accent_fill: Color(red: 107/255.0, green: 70/255.0, blue: 255/255.0).opacity(0.07),
        accent_controlOn: Color(hex: 0x111111),
        accent_signal: Color(hex: 0x6B46FF),
        semantic_positive: Color(hex: 0x1E8A5A),
        semantic_warning: Color(hex: 0xB06A00),
        semantic_negative: Color(hex: 0xC2334D),
        semantic_info: Color(hex: 0x2D6CB0)
    )
    public static let dark = TimbreColors(
        bg_canvas: Color(hex: 0x0B0B0C),
        bg_surface: Color(hex: 0x131314),
        bg_raised: Color(hex: 0x19191B),
        bg_sidebar: Color(hex: 0x0E0E0F),
        bg_inset: Color(hex: 0x101011),
        bg_track: Color(hex: 0x262628),
        bg_hover: Color.white.opacity(0.04),
        bg_selected: Color.white.opacity(0.075),
        ink_primary: Color(hex: 0xF3F3F1),
        ink_secondary: Color(hex: 0xA3A3A0),
        ink_muted: Color(hex: 0x6F6F6C),
        ink_faint: Color(hex: 0x4A4A48),
        ink_inverse: Color(hex: 0x0B0B0C),
        line_default: Color.white.opacity(0.075),
        line_subtle: Color.white.opacity(0.045),
        line_strong: Color.white.opacity(0.15),
        line_grid: Color.white.opacity(0.05),
        accent_base: Color(hex: 0xA08BFF),
        accent_strong: Color(hex: 0xC0B2FF),
        accent_subtle: Color(red: 160/255.0, green: 139/255.0, blue: 255/255.0).opacity(0.14),
        accent_fill: Color(red: 160/255.0, green: 139/255.0, blue: 255/255.0).opacity(0.1),
        accent_controlOn: Color(hex: 0xF3F3F1),
        accent_signal: Color(hex: 0xA08BFF),
        semantic_positive: Color(hex: 0x4CC38A),
        semantic_warning: Color(hex: 0xE9A23B),
        semantic_negative: Color(hex: 0xF2637E),
        semantic_info: Color(hex: 0x6AB0E8)
    )
    public static let notch = TimbreColors(
        bg_canvas: Color(hex: 0x000000),
        bg_surface: Color(hex: 0x000000),
        bg_raised: Color.white.opacity(0.07),
        bg_sidebar: Color(hex: 0x000000),
        bg_inset: Color.white.opacity(0.04),
        bg_track: Color.white.opacity(0.16),
        bg_hover: Color.white.opacity(0.06),
        bg_selected: Color.white.opacity(0.11),
        ink_primary: Color(hex: 0xFFFFFF),
        ink_secondary: Color(hex: 0xA1A1A1),
        ink_muted: Color(hex: 0x6A6A6A),
        ink_faint: Color(hex: 0x3E3E3E),
        ink_inverse: Color(hex: 0x000000),
        line_default: Color.white.opacity(0.09),
        line_subtle: Color.white.opacity(0.06),
        line_strong: Color.white.opacity(0.18),
        line_grid: Color.white.opacity(0.05),
        accent_base: Color(hex: 0xA592FF),
        accent_strong: Color(hex: 0xC6BAFF),
        accent_subtle: Color(red: 165/255.0, green: 146/255.0, blue: 255/255.0).opacity(0.16),
        accent_fill: Color(red: 165/255.0, green: 146/255.0, blue: 255/255.0).opacity(0.1),
        accent_controlOn: Color(hex: 0xFFFFFF),
        accent_signal: Color(hex: 0xA592FF),
        semantic_positive: Color(hex: 0x4CC38A),
        semantic_warning: Color(hex: 0xF0AA45),
        semantic_negative: Color(hex: 0xF2637E),
        semantic_info: Color(hex: 0x6AB0E8)
    )

    public static func forSurface(_ surface: TimbreSurface) -> TimbreColors {
        switch surface {
        case .light: return .light
        case .dark: return .dark
        case .notch: return .notch
        }
    }
}

public enum TimbreMotion {
    public static let enter = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.24)
    public static let standard = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.24)
    public static let exit = Animation.timingCurve(0.7, 0, 0.84, 0, duration: 0.18)
    public static let inOut = Animation.timingCurve(0.65, 0, 0.35, 1, duration: 0.24)
    public static let pressOut = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.14)
    public static let snappy = Animation.spring(duration: 0.24, bounce: 0.0)
    public static let smooth = Animation.spring(duration: 0.36, bounce: 0.0)
    public static let morph = Animation.spring(duration: 0.42, bounce: 0.0)
    public static let notchOpen = Animation.spring(duration: 0.44, bounce: 0.14)
    public static let notchClose = Animation.spring(duration: 0.32, bounce: 0.0)
    public static let responsive = Animation.interpolatingSpring(stiffness: 520, damping: 44)
    public static let staggerItem: Double = 0.035
    public static let staggerMaxTotal: Double = 0.35
}

public enum TimbreSpacing {
    public static let s1: CGFloat = 4
    public static let s2: CGFloat = 8
    public static let s3: CGFloat = 12
    public static let s4: CGFloat = 16
    public static let s5: CGFloat = 20
    public static let s6: CGFloat = 24
    public static let s8: CGFloat = 32
    public static let s10: CGFloat = 40
    public static let s12: CGFloat = 48
    public static let s16: CGFloat = 64
}

public enum TimbreRadius {
    public static let badge: CGFloat = 5
    public static let control: CGFloat = 7
    public static let field: CGFloat = 8
    public static let card: CGFloat = 12
    public static let panel: CGFloat = 16
    public static let notchExpanded: CGFloat = 26
    public static let notchShoulder: CGFloat = 9
    public static let pill: CGFloat = 9999
}

public struct TimbreTypeSpec: Sendable {
    public let family: String
    public let size: CGFloat
    public let weight: Int
    public let tracking: CGFloat
    public let lineHeightMultiplier: CGFloat
    public let tabularNums: Bool
    public let uppercase: Bool

    public var fontWeight: Font.Weight {
        switch weight {
        case ..<450: return .regular
        case ..<550: return .medium
        case ..<650: return .semibold
        default: return .bold
        }
    }

    /// ADR-0015: SF Pro / SF Mono / New York (system, optical sizes). Geist only on web surfaces.
    public var font: Font {
        let design: Font.Design = switch family {
        case "mono": .monospaced
        case "serif": .serif
        default: .default
        }
        let base = Font.system(size: size, weight: fontWeight, design: design)
        return tabularNums ? base.monospacedDigit() : base
    }

    public var lineSpacing: CGFloat { max(0, size * lineHeightMultiplier - size * 1.2) }
}

public struct TimbreTypeModifier: ViewModifier {
    public let spec: TimbreTypeSpec
    public func body(content: Content) -> some View {
        content
            .font(spec.font)
            .tracking(spec.tracking)
            .lineSpacing(spec.lineSpacing)
            .textCase(spec.uppercase ? .uppercase : nil)
    }
}

public extension View {
    /// Applies font + size-specific tracking + leading + case from a type token.
    func type(_ spec: TimbreTypeSpec) -> some View { modifier(TimbreTypeModifier(spec: spec)) }
}

public enum TimbreTypography {
    public static let micro = TimbreTypeSpec(family: "mono", size: 9, weight: 500, tracking: 0.6, lineHeightMultiplier: 1.2, tabularNums: true, uppercase: true)
    public static let eyebrow = TimbreTypeSpec(family: "mono", size: 10, weight: 500, tracking: 1.1, lineHeightMultiplier: 1.3, tabularNums: true, uppercase: true)
    public static let monoValue = TimbreTypeSpec(family: "mono", size: 11, weight: 400, tracking: 0, lineHeightMultiplier: 1.3, tabularNums: true, uppercase: false)
    public static let monoSmall = TimbreTypeSpec(family: "mono", size: 10, weight: 400, tracking: 0, lineHeightMultiplier: 1.3, tabularNums: true, uppercase: false)
    public static let caption = TimbreTypeSpec(family: "sans", size: 11, weight: 400, tracking: 0.06, lineHeightMultiplier: 1.4, tabularNums: false, uppercase: false)
    public static let small = TimbreTypeSpec(family: "sans", size: 12, weight: 400, tracking: 0, lineHeightMultiplier: 1.4, tabularNums: false, uppercase: false)
    public static let body = TimbreTypeSpec(family: "sans", size: 13, weight: 400, tracking: -0.08, lineHeightMultiplier: 1.45, tabularNums: false, uppercase: false)
    public static let bodyStrong = TimbreTypeSpec(family: "sans", size: 13, weight: 600, tracking: -0.1, lineHeightMultiplier: 1.4, tabularNums: false, uppercase: false)
    public static let prose = TimbreTypeSpec(family: "sans", size: 14, weight: 400, tracking: -0.15, lineHeightMultiplier: 1.55, tabularNums: false, uppercase: false)
    public static let cardTitle = TimbreTypeSpec(family: "sans", size: 14, weight: 600, tracking: -0.2, lineHeightMultiplier: 1.3, tabularNums: false, uppercase: false)
    public static let sectionTitle = TimbreTypeSpec(family: "sans", size: 17, weight: 600, tracking: -0.35, lineHeightMultiplier: 1.25, tabularNums: false, uppercase: false)
    public static let pageTitle = TimbreTypeSpec(family: "sans", size: 28, weight: 600, tracking: -0.9, lineHeightMultiplier: 1.1, tabularNums: false, uppercase: false)
    public static let mediumValue = TimbreTypeSpec(family: "sans", size: 22, weight: 500, tracking: -0.6, lineHeightMultiplier: 1.05, tabularNums: true, uppercase: false)
    public static let displayValue = TimbreTypeSpec(family: "sans", size: 34, weight: 500, tracking: -1.3, lineHeightMultiplier: 1, tabularNums: true, uppercase: false)
    public static let heroTitle = TimbreTypeSpec(family: "sans", size: 28, weight: 600, tracking: -0.9, lineHeightMultiplier: 1.1, tabularNums: false, uppercase: false)
    public static let notchTitle = TimbreTypeSpec(family: "sans", size: 13, weight: 600, tracking: -0.15, lineHeightMultiplier: 1.2, tabularNums: false, uppercase: false)
    public static let notchValue = TimbreTypeSpec(family: "sans", size: 22, weight: 500, tracking: -0.7, lineHeightMultiplier: 1, tabularNums: true, uppercase: false)
    public static let lyric = TimbreTypeSpec(family: "serif", size: 16, weight: 400, tracking: -0.1, lineHeightMultiplier: 1.45, tabularNums: false, uppercase: false)
}

private extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
