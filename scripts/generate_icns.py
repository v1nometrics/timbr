#!/usr/bin/env python3
"""Generate Timbr.icns (ADR-0025: Ilha refinada) from the approved Ilha refinada SVG via pure Python RGBA PNGs + macOS iconutil.

`Timbr.icns` renders as an opaque full-bleed paper canvas (#F3F3F1) with the canonical SVG inner shapes
scaled by 1024/824 around (512, 512). On macOS 26+ (Tahoe), IconServices masks full-bleed canvases cleanly
to the native continuous Liquid Glass squircle (824/1024) without running the legacy pre-masked-squircle
foreground-segmentation emboss filter, which otherwise creates blurry gray halos around the black pill and
white bars. `Resources/Brand/timbr-icon-1024.png` keeps the standalone rounded squircle with transparent
margin for README, web, and macOS 15 runtime Dock fallback.
"""
import math
import struct
import subprocess
import tempfile
import zlib
from pathlib import Path

SIZES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

# Canonical geometry: Resources/Brand/timbr-icon.svg and its approved small-size variant.
PAPER = (0xF3, 0xF3, 0xF1)
EDGE = (0xDE, 0xDE, 0xD9)
INK = (0x14, 0x14, 0x14)
BLACK = (0x00, 0x00, 0x00)
FULL_BLEED_SCALE = 1024.0 / 824.0


def sd_box(px: float, py: float, cx: float, cy: float, hw: float, hh: float, r: float = 0.0) -> float:
    """Signed distance to a rounded box (negative inside)."""
    dx = abs(px - cx) - (hw - r)
    dy = abs(py - cy) - (hh - r)
    return math.hypot(max(dx, 0.0), max(dy, 0.0)) + min(max(dx, dy), 0.0) - r


def sd_circle(px: float, py: float, cx: float, cy: float, r: float) -> float:
    return math.hypot(px - cx, py - cy) - r


def cover(d: float, scale: float) -> float:
    """Anti-aliased coverage from a distance in 1024-space (one output pixel = 1/scale units)."""
    return min(max(0.5 - d * scale, 0.0), 1.0)


def load_shapes(name):
    import xml.etree.ElementTree as ET
    source = Path(__file__).resolve().parent.parent / "Resources/Brand" / name
    return [dict(node.attrib) for node in ET.parse(source).getroot() if node.tag.endswith("rect")]


SHAPES = load_shapes("timbr-icon.svg")
SMALL_SHAPES = load_shapes("timbr-icon-small.svg")


def pixel(x: float, y: float, scale: float, small: bool, glyph: bool = False, full_bleed: bool = False) -> tuple:
    """Rasterize the approved SVG rectangles; preserve original geometry and optical sizes."""
    shapes = SMALL_SHAPES if small else SHAPES
    if full_bleed and not glyph:
        r, g, b = (float(c) for c in PAPER)
        for shape in shapes[1:]:
            sx, sy, w, h = (float(shape[k]) for k in ("x", "y", "width", "height"))
            rx = float(shape.get("rx", 0))
            cx = 512.0 + (sx + w / 2.0 - 512.0) * FULL_BLEED_SCALE
            cy = 512.0 + (sy + h / 2.0 - 512.0) * FULL_BLEED_SCALE
            w *= FULL_BLEED_SCALE
            h *= FULL_BLEED_SCALE
            rx *= FULL_BLEED_SCALE
            d = sd_box(x, y, cx, cy, w / 2.0, h / 2.0, rx)
            alpha = cover(d, scale)
            fill = shape["fill"].lstrip("#")
            if len(fill) == 3:
                fill = "".join(c * 2 for c in fill)
            col = tuple(int(fill[j:j+2], 16) for j in (0, 2, 4))
            r, g, b = (c * alpha + old * (1.0 - alpha) for c, old in zip(col, (r, g, b)))
        return (round(r), round(g), round(b), 255)

    r = g = b = a = 0.0
    for i, shape in enumerate(shapes):
        if glyph and i == 0:
            continue
        sx, sy, w, h = (float(shape[k]) for k in ("x", "y", "width", "height"))
        d = sd_box(x, y, sx + w / 2, sy + h / 2, w / 2, h / 2, float(shape.get("rx", 0)))
        alpha = cover(d, scale)
        if glyph:
            # Template glyph: solid pill, transparent eye and bars; no app tile.
            a = alpha if i == 1 else a * (1 - alpha)
            continue
        if "stroke" in shape:
            stroke = cover(abs(d) - float(shape["stroke-width"]) / 2, scale)
            fill = shape["stroke"].lstrip("#")
            col = tuple(int(fill[j:j+2], 16) for j in (0, 2, 4))
            r, g, b = (c * stroke + old * (1 - stroke) for c, old in zip(col, (r,g,b)))
            a = stroke + a * (1 - stroke)
        fill = shape["fill"].lstrip("#")
        if len(fill) == 3:
            fill = "".join(c * 2 for c in fill)
        col = tuple(int(fill[j:j+2], 16) for j in (0, 2, 4))
        # SVG stroke overlays the fill at the rim.
        if "stroke" in shape:
            alpha = cover(d + float(shape["stroke-width"]) / 2, scale)
        r, g, b = (c * alpha + old * (1 - alpha) for c, old in zip(col, (r,g,b)))
        a = alpha + a * (1 - alpha)
    if glyph:
        return (0, 0, 0, round(a * 255))
    return (round(r / a) if a else 0, round(g / a) if a else 0, round(b / a) if a else 0, round(a * 255))


def write_png(path: Path, size: int, glyph: bool = False, full_bleed: bool = False) -> None:
    raw = bytearray()
    scale = size / 1024.0
    small = size <= 64
    height = size
    ox = oy = 0.0
    if glyph:
        bounds = SMALL_SHAPES[1]
        ox, oy = float(bounds["x"]), float(bounds["y"])
        scale = size / float(bounds["width"])
        height = round(float(bounds["height"]) * scale)
    for py in range(height):
        raw.append(0)
        y = oy + (py + 0.5) / scale
        for px in range(size):
            raw.extend(pixel(ox + (px + 0.5) / scale, y, scale, small, glyph, full_bleed))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", size, height, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(raw), level=6)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")
    path.write_bytes(png)

def main() -> None:
    out_icns = Path(__file__).resolve().parent.parent / "Resources" / "Timbr.icns"
    out_icns.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        iconset = Path(td) / "Timbr.iconset"
        iconset.mkdir()
        for fname, px in SIZES:
            write_png(iconset / fname, px, full_bleed=True)
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(out_icns)], check=True)
    resources = out_icns.parent
    write_png(resources / "TimbrMenuTemplate.png", 64, glyph=True)
    write_png(resources / "Brand/timbr-icon-1024.png", 1024, full_bleed=False)
    print(f"Generated {out_icns}")

if __name__ == "__main__":
    main()
