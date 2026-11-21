#!/usr/bin/env python3
"""Generate Timbr.icns from pure Python RGBA PNGs + macOS iconutil (no third-party deps)."""
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

def write_png(path: Path, size: int) -> None:
    raw = bytearray()
    cx = (size - 1) / 2.0
    cy = (size - 1) / 2.0
    rad = size * 0.45
    corner = size * 0.22
    # Rounded square icon on #141414 dark canvas with #A78BFF waveform arc & dot
    for y in range(size):
        raw.append(0)
        ny = (y - cy) / rad
        for x in range(size):
            nx = (x - cx) / rad
            # Superellipse / rounded box mask
            dx = max(abs(x - cx) - (rad - corner), 0.0)
            dy = max(abs(y - cy) - (rad - corner), 0.0)
            dist = math.hypot(dx, dy) - corner
            if dist > 1.0:
                raw.extend((0, 0, 0, 0))
                continue
            alpha = 255 if dist < 0 else int(max(0.0, min(1.0, 1.0 - dist)) * 255)
            # Subtle border
            if -max(1.2, size * 0.015) <= dist <= 0:
                r, g, b = 0x2B, 0x2B, 0x2B
            else:
                r, g, b = 0x14, 0x14, 0x14

            # Centered precision waveform bars (5 symmetric bars)
            bar_x = abs(nx)
            in_wave = False
            for idx, (bx, bh) in enumerate([(0.0, 0.50), (0.20, 0.34), (0.40, 0.18)]):
                if abs(bar_x - bx) < 0.055 and abs(ny) <= bh:
                    in_wave = True
                    break
            # Accent signature dot at bottom-right of waveform
            dot_dist = math.hypot(nx - 0.56, ny - 0.42)
            if in_wave:
                r, g, b = 0xF2, 0xF2, 0xF2
            elif dot_dist < 0.08:
                r, g, b = 0xA7, 0x8B, 0xFF
            raw.extend((r, g, b, alpha))

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
