#!/usr/bin/env bash
# End-to-end per-app volume measurement inside the installed app (needs the System Audio
# Recording grant, plays a 1 kHz tone through the default output for ~30 s).
# Usage: scripts/selftest_audio.sh [report.json] [app path]
set -euo pipefail
REPORT="${1:-$(mktemp -t timbr-selftest).json}"
APP="${2:-/Applications/Timbr.app}"
pkill -x Timbr 2>/dev/null || true
sleep 0.5
"$APP/Contents/MacOS/Timbr" --selftest-audio "$REPORT" >/dev/null 2>&1 &
PID=$!
for _ in $(seq 1 90); do sleep 1; kill -0 "$PID" 2>/dev/null || break; done
python3 - "$REPORT" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
print(f"Output: {r['outputDevice']} @ {r['sampleRate']:.0f} Hz")
for c in r["cases"]:
    exp = c.get("expectedGainDB")
    print(f"  [{'PASS' if c['pass'] else 'FAIL'}] {c['name']}: source {c['sourceRMSdBFS']:.2f} dBFS → out {c['outputRMSdBFS']:.2f} dBFS "
          f"(gain {c['measuredGainDB']:+.2f} dB{'' if exp is None else f', expected {exp:+.2f}'}) — {c['note']}")
print("ALL PASSED" if r["allPassed"] else "FAILED")
sys.exit(0 if r["allPassed"] else 1)
PY
