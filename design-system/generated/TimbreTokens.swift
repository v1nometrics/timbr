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
    public let bg_track: Color
    public let ink_primary: Color
    public let ink_secondary: Color
    public let ink_muted: Color
    public let line_default: Color
    public let line_subtle: Color
    public let line_strong: Color
    public let accent_base: Color
    public let accent_strong: Color
    public let accent_subtle: Color
    public let accent_controlOn: Color
    public let semantic_positive: Color
    public let semantic_warning: Color
    public let semantic_negative: Color
    public let semantic_info: Color

    public static let light = TimbreColors(
        bg_canvas: Color(hex: 0xFAFAFA),
        bg_surface: Color(hex: 0xFFFFFF),
        bg_raised: Color(hex: 0xFFFFFF),
        bg_track: Color(hex: 0xF8F8F8),
        ink_primary: Color(hex: 0x0B0B0B),
        ink_secondary: Color(hex: 0x585858),
        ink_muted: Color(hex: 0x7D7D7D),
        line_default: Color(hex: 0xE9E9E9),
        line_subtle: Color(hex: 0xF3F3F3),
        line_strong: Color(hex: 0xC4C4C4),
        accent_base: Color(hex: 0x7747FF),
        accent_strong: Color(hex: 0x5528CE),
        accent_subtle: Color(red: 119/255.0, green: 71/255.0, blue: 255/255.0).opacity(0.13),
        accent_controlOn: Color(hex: 0x7747FF),
        semantic_positive: Color(hex: 0x00774D),
        semantic_warning: Color(hex: 0x9F6202),
        semantic_negative: Color(hex: 0xBB2C54),
        semantic_info: Color(hex: 0x136D9E)
    )
    public static let dark = TimbreColors(
        bg_canvas: Color(hex: 0x141414),
        bg_surface: Color(hex: 0x191919),
        bg_raised: Color(hex: 0x1F1F1F),
        bg_track: Color(hex: 0x242424),
        ink_primary: Color(hex: 0xF2F2F2),
        ink_secondary: Color(hex: 0xB4B4B4),
        ink_muted: Color(hex: 0x8C8C8C),
        line_default: Color(hex: 0x2B2B2B),
        line_subtle: Color(hex: 0x222222),
        line_strong: Color(hex: 0x484848),
        accent_base: Color(hex: 0xA78BFF),
        accent_strong: Color(hex: 0xC7B7FF),
        accent_subtle: Color(red: 119/255.0, green: 71/255.0, blue: 255/255.0).opacity(0.22),
        accent_controlOn: Color(hex: 0x8A66FF),
        semantic_positive: Color(hex: 0x55D69F),
        semantic_warning: Color(hex: 0xF2BD68),
        semantic_negative: Color(hex: 0xF0738F),
        semantic_info: Color(hex: 0x7CC4F0)
    )
    public static let notch = TimbreColors(
        bg_canvas: Color(hex: 0x000000),
        bg_surface: Color(hex: 0x000000),
        bg_raised: Color.white.opacity(0.07),
        bg_track: Color.white.opacity(0.12),
        ink_primary: Color(hex: 0xF2F2F2),
        ink_secondary: Color(hex: 0xB4B4B4),
        ink_muted: Color(hex: 0x7A7A7A),
        line_default: Color.white.opacity(0.11),
        line_subtle: Color.white.opacity(0.07),
        line_strong: Color.white.opacity(0.28),
        accent_base: Color(hex: 0xA78BFF),
        accent_strong: Color(hex: 0xC7B7FF),
        accent_subtle: Color(red: 119/255.0, green: 71/255.0, blue: 255/255.0).opacity(0.26),
        accent_controlOn: Color(hex: 0xA78BFF),
        semantic_positive: Color(hex: 0x55D69F),
        semantic_warning: Color(hex: 0xF2BD68),
        semantic_negative: Color(hex: 0xF0738F),
        semantic_info: Color(hex: 0x7CC4F0)
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
    public static let snappy = Animation.spring(duration: 0.26, bounce: 0.0)
    public static let smooth = Animation.spring(duration: 0.4, bounce: 0.0)
    public static let morph = Animation.spring(duration: 0.42, bounce: 0.0)
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
    public static let control: CGFloat = 8
    public static let card: CGFloat = 14
    public static let notchExpanded: CGFloat = 22
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

    public var font: Font {
        let baseName: String = switch family {
        case "mono": weight >= 500 ? "GeistMono-Medium" : "GeistMono-Regular"
        case "serif": "GeistSerif-Regular"
        default: weight >= 500 ? "Geist-Medium" : "Geist-Regular"
        }
        let base = Font.custom(baseName, size: size)
        return tabularNums ? base.monospacedDigit() : base
    }
}

public enum TimbreTypography {
    public static let micro = TimbreTypeSpec(family: "mono", size: 9, weight: 400, tracking: 0.72, lineHeightMultiplier: 1.2, tabularNums: true, uppercase: false)
    public static let kicker = TimbreTypeSpec(family: "mono", size: 10, weight: 500, tracking: 1, lineHeightMultiplier: 1.3, tabularNums: true, uppercase: false)
    public static let eyebrow = TimbreTypeSpec(family: "mono", size: 11, weight: 500, tracking: 1.21, lineHeightMultiplier: 1.4, tabularNums: false, uppercase: true)
    public static let monoValue = TimbreTypeSpec(family: "mono", size: 11, weight: 400, tracking: 0.22, lineHeightMultiplier: 1.3, tabularNums: true, uppercase: false)
    public static let caption = TimbreTypeSpec(family: "sans", size: 11, weight: 400, tracking: -0.11, lineHeightMultiplier: 1.45, tabularNums: false, uppercase: false)
    public static let small = TimbreTypeSpec(family: "sans", size: 12, weight: 400, tracking: -0.12, lineHeightMultiplier: 1.4, tabularNums: false, uppercase: false)
    public static let body = TimbreTypeSpec(family: "sans", size: 13.5, weight: 400, tracking: -0.14, lineHeightMultiplier: 1.4, tabularNums: false, uppercase: false)
    public static let prose = TimbreTypeSpec(family: "sans", size: 14.5, weight: 400, tracking: -0.15, lineHeightMultiplier: 1.6, tabularNums: false, uppercase: false)
    public static let cardTitle = TimbreTypeSpec(family: "sans", size: 18, weight: 500, tracking: -0.45, lineHeightMultiplier: 1.25, tabularNums: false, uppercase: false)
    public static let mediumValue = TimbreTypeSpec(family: "sans", size: 24, weight: 500, tracking: -0.96, lineHeightMultiplier: 1, tabularNums: true, uppercase: false)
    public static let displayValue = TimbreTypeSpec(family: "sans", size: 36, weight: 500, tracking: -1.62, lineHeightMultiplier: 1.05, tabularNums: true, uppercase: false)
    public static let heroTitle = TimbreTypeSpec(family: "sans", size: 45, weight: 500, tracking: -2.25, lineHeightMultiplier: 1.01, tabularNums: false, uppercase: false)
    public static let lyric = TimbreTypeSpec(family: "serif", size: 16, weight: 400, tracking: -0.08, lineHeightMultiplier: 1.45, tabularNums: false, uppercase: false)
}
