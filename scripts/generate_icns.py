#!/usr/bin/env python3
"""Generate Timbr.icns (ADR-0022: the notch with the sound below it) from pure Python RGBA PNGs + macOS iconutil."""
import math
import shutil
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

# App icon (ADR-0022): the notch hanging from the top edge of a paper-coloured tile, and the sound it
# controls below it. Drawn analytically (signed distances) on the 1024-pt Apple icon grid: the tile
# spans 100..924. Small sizes use a bolder variant so the notch and bars survive at 16 px.
PAPER = (0xF3, 0xF3, 0xF1)
EDGE = (0xDE, 0xDE, 0xD9)
INK = (0x14, 0x14, 0x14)
BLACK = (0x00, 0x00, 0x00)


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


def icon_shapes(small: bool):
    """(notch_left, notch_right, notch_bottom, bar_w, bar_gap, bar_h, bar_cy) in 1024 space."""
    if small:
        return 262.0, 762.0, 300.0, 80.0, 46.0, 300.0, 630.0
    return 312.0, 712.0, 272.0, 54.0, 36.0, 250.0, 610.0


def pixel(x: float, y: float, scale: float, small: bool) -> tuple:
    """RGBA of one icon pixel; (x, y) in 1024 space."""
    tile = sd_box(x, y, 512, 512, 412, 412, 185)
    a_tile = cover(tile, scale)
    if a_tile <= 0.0:
        return (0, 0, 0, 0)
    nl, nr, nb, bw, bg, bh, bcy = icon_shapes(small)
    # tile with a hairline edge
    edge_w = max(2.5, 4.0)
    edge = cover(tile + edge_w, scale)           # 1 inside, 0 on the hairline band at the rim
    r, g, b = (PAPER[0] * edge + EDGE[0] * (1 - edge), PAPER[1] * edge + EDGE[1] * (1 - edge), PAPER[2] * edge + EDGE[2] * (1 - edge))
    # the notch: a body with round lower corners, plus a concave fillet at each top corner
    half, ncx = (nr - nl) / 2, (nr + nl) / 2
    body = sd_box(x, y, ncx, (nb - 60) / 2, half, (nb + 60) / 2, 72)
    fl = 30.0
    flare_l = max(sd_box(x, y, nl - fl / 2, 100 + fl / 2, fl / 2, fl / 2), -sd_circle(x, y, nl - fl, 100 + fl, fl))
    flare_r = max(sd_box(x, y, nr + fl / 2, 100 + fl / 2, fl / 2, fl / 2), -sd_circle(x, y, nr + fl, 100 + fl, fl))
    notch = min(body, flare_l, flare_r)
    ca = cover(notch, scale)
    if ca > 0:
        r, g, b = r * (1 - ca) + BLACK[0] * ca, g * (1 - ca) + BLACK[1] * ca, b * (1 - ca) + BLACK[2] * ca
    # five symmetric bars: the same silhouette the app draws beside the notch
    total = 5 * bw + 4 * bg
    bx = 512 - total / 2
    for k, f in enumerate((0.42, 0.72, 1.0, 0.72, 0.42)):
        hh = bh * f / 2
        cx = bx + k * (bw + bg) + bw / 2
        ba = cover(sd_box(x, y, cx, bcy, bw / 2, hh, bw / 2), scale)
        if ba > 0:
            r, g, b = r * (1 - ba) + INK[0] * ba, g * (1 - ba) + INK[1] * ba, b * (1 - ba) + INK[2] * ba
    return (int(r + 0.5), int(g + 0.5), int(b + 0.5), int(a_tile * 255 + 0.5))


def write_png(path: Path, size: int) -> None:
    raw = bytearray()
    scale = size / 1024.0
    small = size <= 64
    for py in range(size):
        raw.append(0)
        y = (py + 0.5) / scale
        for px in range(size):
            raw.extend(pixel((px + 0.5) / scale, y, scale, small))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
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
            write_png(iconset / fname, px)
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(out_icns)], check=True)
    print(f"Generated {out_icns}")

if __name__ == "__main__":
    main()
