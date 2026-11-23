#!/usr/bin/env python3
"""Reject bundles whose executable deployment targets disagree with their manifest."""
import pathlib, plistlib, re, subprocess
root = pathlib.Path(__file__).resolve().parents[1]
app = root / 'dist/Timbr.app/Contents'
minimum = plistlib.loads((app/'Info.plist').read_bytes())['LSMinimumSystemVersion']
assert minimum == '15.0', f'Package.swift targets macOS 15; plist declares {minimum}'
for name in ('Timbr', 'timbr-mute-keeper'):
    output = subprocess.check_output(['otool', '-l', str(app/'MacOS'/name)], text=True)
    targets = re.findall(r'\bminos\s+(\S+)', output)
    assert targets and all(t == minimum for t in targets), f'{name}: {targets} != {minimum}'
    print(f'[PASS] {name}: Mach-O minos = Info.plist = {minimum}')
