#!/usr/bin/env python3
"""Gera TimbreTokens.swift e tokens.css a partir de design-system/tokens/*.tokens.json (ADR-0012)."""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOK = os.path.join(ROOT, "tokens")
OUT = os.path.join(ROOT, "generated")
os.makedirs(OUT, exist_ok=True)


def load(name):
    with open(os.path.join(TOK, name), encoding="utf-8") as f:
        return json.load(f)


def px_num(val: str) -> float:
    return float(str(val).replace("px", ""))


colors = load("color.tokens.json")
motion = load("motion.tokens.json")
spacing = load("spacing-radius.tokens.json")
typography = load("typography.tokens.json")


def swift_color(val: str) -> str:
    if val.startswith("#"):
        return f"Color(hex: 0x{val[1:]})"
    m = re.match(r"rgba\((\d+),\s*(\d+),\s*(\d+),\s*([0-9.]+)\)", val)
    if m:
        r, g, b, a = int(m.group(1)), int(m.group(2)), int(m.group(3)), float(m.group(4))
        if r == 255 and g == 255 and b == 255:
            return f"Color.white.opacity({a})"
        return f"Color(red: {r}/255.0, green: {g}/255.0, blue: {b}/255.0).opacity({a})"
    return f"/* unsupported: {val} */ Color.clear"


def flatten_surface(surf):
    res = {}
    for grp, items in surf.items():
        for k, v in items.items():
            res[f"{grp}.{k}"] = v["$value"]
    return res


surfaces = {name: flatten_surface(data) for name, data in colors["surface"].items()}

# Generate Swift
swift_lines = [
    "// GENERATED FILE - DO NOT EDIT BY HAND (ADR-0012)",
    "// Source: design-system/tokens/*.tokens.json",
    "import SwiftUI",
    "import AppKit",
    "",
    "public enum TimbreSurface: String, CaseIterable, Sendable {",
    "    case light, dark, notch",
    "}",
    "",
    "public struct TimbreColors: Sendable {",
]
keys = list(surfaces["light"].keys())
prop_names = [k.replace(".", "_") for k in keys]
for p in prop_names:
    swift_lines.append(f"    public let {p}: Color")
swift_lines.append("")
for sname, sdict in surfaces.items():
    swift_lines.append(f"    public static let {sname} = TimbreColors(")
    entries = [f"        {k.replace('.', '_')}: {swift_color(sdict[k])}" for k in keys]
    swift_lines.append(",\n".join(entries))
    swift_lines.append("    )")
swift_lines.append("")
swift_lines.append("    public static func forSurface(_ surface: TimbreSurface) -> TimbreColors {")
swift_lines.append("        switch surface {")
swift_lines.append("        case .light: return .light")
swift_lines.append("        case .dark: return .dark")
swift_lines.append("        case .notch: return .notch")
swift_lines.append("        }")
swift_lines.append("    }")
swift_lines.append("}")
swift_lines.append("")

# Motion
# Every animation token honours System Settings > Accessibility > Display > Reduce motion at the moment
# it starts (computed, not stored): geometry springs and curves become a 120 ms fade, staggers vanish.
# Pointer-following springs are exempt: tracking a finger is direct manipulation, not decoration.
swift_lines.append("public enum TimbreMotion {")
swift_lines.append("    /// Tests and design review (`--reduce-motion`) can force the setting.")
swift_lines.append("    nonisolated(unsafe) public static var reducedOverride: Bool?")
swift_lines.append("    public static var reduced: Bool { reducedOverride ?? NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }")
swift_lines.append("    private static let reducedFade = Animation.easeOut(duration: 0.12)")
swift_lines.append("    /// The animation every decorative token collapses into under Reduce Motion (for tests).")
swift_lines.append("    public static var reducedFadeForTests: Animation { reducedFade }")
for cname, cdata in motion["curve"].items():
    a_, b_, c_, d_ = cdata["$value"]
    # docs/05-design-system/02-motion-e-fisica.md §6: ease-in is forbidden on UI (it is slow exactly when the eye is watching).
    # An ease-in has both control points on the floor: (x1, 0, x2, y2 <= 0.2).
    if b_ == 0 and d_ <= 0.2:
        raise SystemExit(f"motion curve '{cname}' is an ease-in ({a_}, {b_}, {c_}, {d_}); use an ease-out or an ease-in-out")
    dur = motion["curveDurationSeconds"][cname]
    swift_lines.append(f"    public static var {cname}: Animation {{ reduced ? reducedFade : Animation.timingCurve({a_}, {b_}, {c_}, {d_}, duration: {dur}) }}")
for lname, ldur in motion["linear"].items():
    swift_lines.append(f"    /// Constant motion (live meters): linear on purpose, and short enough to track the data.")
    swift_lines.append(f"    public static var {lname}: Animation {{ reduced ? Animation.linear(duration: 0.0) : Animation.linear(duration: {ldur}) }}")
for sname, sdata in motion["spring"].items():
    follows = sdata.get("followsPointer", False)
    if "duration" in sdata:
        body = f"Animation.spring(duration: {sdata['duration']}, bounce: {sdata['bounce']})"
    elif "response" in sdata:
        body = f"Animation.interactiveSpring(response: {sdata['response']}, dampingFraction: {sdata['damping']})"
    else:
        body = f"Animation.interpolatingSpring(stiffness: {sdata['stiffness']}, damping: {sdata['damping']})"
    if follows:
        swift_lines.append(f"    public static var {sname}: Animation {{ {body} }}")
    else:
        swift_lines.append(f"    public static var {sname}: Animation {{ reduced ? reducedFade : {body} }}")
swift_lines.append(f"    public static var staggerItem: Double {{ reduced ? 0 : {motion['stagger']['itemSeconds']} }}")
swift_lines.append(f"    public static var staggerMaxTotal: Double {{ reduced ? 0 : {motion['stagger']['maxTotalSeconds']} }}")
swift_lines.append("}")
swift_lines.append("")

# Spacing & Radius
swift_lines.append("public enum TimbreSpacing {")
for k, v in spacing["spacing"].items():
    swift_lines.append(f"    public static let s{k}: CGFloat = {px_num(v['$value']):g}")
swift_lines.append("}")
swift_lines.append("")
swift_lines.append("public enum TimbreRadius {")
for k, v in spacing["radius"].items():
    swift_lines.append(f"    public static let {k}: CGFloat = {px_num(v['$value']):g}")
swift_lines.append("}")
swift_lines.append("")

# Typography
swift_lines.append("public struct TimbreTypeSpec: Sendable {")
swift_lines.append("    public let family: String")
swift_lines.append("    public let size: CGFloat")
swift_lines.append("    public let weight: Int")
swift_lines.append("    public let tracking: CGFloat")
swift_lines.append("    public let lineHeightMultiplier: CGFloat")
swift_lines.append("    public let tabularNums: Bool")
swift_lines.append("    public let uppercase: Bool")
swift_lines.append("")
swift_lines.append("    public var fontWeight: Font.Weight {")
swift_lines.append("        switch weight {")
swift_lines.append("        case ..<450: return .regular")
swift_lines.append("        case ..<550: return .medium")
swift_lines.append("        case ..<650: return .semibold")
swift_lines.append("        default: return .bold")
swift_lines.append("        }")
swift_lines.append("    }")
swift_lines.append("")
swift_lines.append("    /// ADR-0015: SF Pro / SF Mono / New York (system, optical sizes). Geist only on web surfaces.")
swift_lines.append("    public var font: Font {")
swift_lines.append("        let design: Font.Design = switch family {")
swift_lines.append('        case "mono": .monospaced')
swift_lines.append('        case "serif": .serif')
swift_lines.append("        default: .default")
swift_lines.append("        }")
swift_lines.append("        let base = Font.system(size: size, weight: fontWeight, design: design)")
swift_lines.append("        return tabularNums ? base.monospacedDigit() : base")
swift_lines.append("    }")
swift_lines.append("")
swift_lines.append("    public var lineSpacing: CGFloat { max(0, size * lineHeightMultiplier - size * 1.2) }")
swift_lines.append("}")
swift_lines.append("")
swift_lines.append("public struct TimbreTypeModifier: ViewModifier {")
swift_lines.append("    public let spec: TimbreTypeSpec")
swift_lines.append("    public func body(content: Content) -> some View {")
swift_lines.append("        content")
swift_lines.append("            .font(spec.font)")
swift_lines.append("            .tracking(spec.tracking)")
swift_lines.append("            .lineSpacing(spec.lineSpacing)")
swift_lines.append("            .textCase(spec.uppercase ? .uppercase : nil)")
swift_lines.append("    }")
swift_lines.append("}")
swift_lines.append("")
swift_lines.append("public extension View {")
swift_lines.append("    /// Applies font + size-specific tracking + leading + case from a type token.")
swift_lines.append("    func type(_ spec: TimbreTypeSpec) -> some View { modifier(TimbreTypeModifier(spec: spec)) }")
swift_lines.append("}")
swift_lines.append("")
swift_lines.append("public enum TimbreTypography {")
for tname, tdata in typography["typeStyle"].items():
    v = tdata["$value"]
    fam = v["fontFamily"]
    sz = px_num(v["fontSize"])
    wt = int(v["fontWeight"])
    tr = px_num(v["letterSpacing"])
    lh = float(v["lineHeight"])
    tab = "true" if v.get("tabularNums", False) else "false"
    up = "true" if v.get("textTransform") == "uppercase" else "false"
    swift_lines.append(
        f'    public static let {tname} = TimbreTypeSpec(family: "{fam}", size: {sz:g}, weight: {wt}, tracking: {tr:g}, lineHeightMultiplier: {lh:g}, tabularNums: {tab}, uppercase: {up})'
    )
swift_lines.append("}")

swift_lines.extend([
    "",
    "private extension Color {",
    "    init(hex: UInt32) {",
    "        let r = Double((hex >> 16) & 0xFF) / 255.0",
    "        let g = Double((hex >> 8) & 0xFF) / 255.0",
    "        let b = Double(hex & 0xFF) / 255.0",
    "        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)",
    "    }",
    "}",
])
with open(os.path.join(OUT, "TimbreTokens.swift"), "w", encoding="utf-8") as f:
    f.write("\n".join(swift_lines) + "\n")

# Generate CSS
css_lines = [
    "/* GENERATED FILE - DO NOT EDIT BY HAND (ADR-0012) */",
    ":root {",
]
for k, v in surfaces["light"].items():
    css_lines.append(f"  --timbre-{k.replace('.', '-')}: {v};")
for k, v in spacing["spacing"].items():
    css_lines.append(f"  --timbre-space-{k}: {v['$value']};")
for k, v in spacing["radius"].items():
    css_lines.append(f"  --timbre-radius-{k}: {v['$value']};")
for k, v in spacing["borderWidth"].items():
    css_lines.append(f"  --timbre-border-{k}: {v['$value']};")
for cname, cdata in motion["curve"].items():
    a, b, c, d = cdata["$value"]
    css_lines.append(f"  --timbre-ease-{cname}: cubic-bezier({a}, {b}, {c}, {d});")
for fname, fdata in typography["fontFamily"].items():
    css_lines.append(f"  --timbre-font-{fname}: {', '.join(repr(x) if ' ' in x else x for x in fdata['$value'])};")
for tname, tdata in typography["typeStyle"].items():
    v = tdata["$value"]
    css_lines.append(f"  --timbre-type-{tname}-size: {v['fontSize']};")
    css_lines.append(f"  --timbre-type-{tname}-weight: {v['fontWeight']};")
    css_lines.append(f"  --timbre-type-{tname}-tracking: {v['letterSpacing']};")
    css_lines.append(f"  --timbre-type-{tname}-line-height: {v['lineHeight']};")
css_lines.append("}")
for sname in ("dark", "notch"):
    css_lines.append(f'[data-timbre-surface="{sname}"] {{')
    for k, v in surfaces[sname].items():
        css_lines.append(f"  --timbre-{k.replace('.', '-')}: {v};")
    css_lines.append("}")

with open(os.path.join(OUT, "tokens.css"), "w", encoding="utf-8") as f:
    f.write("\n".join(css_lines) + "\n")

print("Generated Swift & CSS successfully in", OUT)
