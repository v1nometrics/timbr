#!/usr/bin/env bash
# Fail-closed mute mechanics (ADR-0017), inside the installed app (needs the System Audio Recording grant).
# Plays a quiet 1 kHz tone (−30 dBFS), mutes it from a second timbr process through timbr-mute-keeper,
# SIGKILLs that process and checks the keeper still holds the mute; then a fresh process adopts and
# releases it. Uses a private state dir: the real app's mutes are never touched. Speaker silence is
# checked by ear with scripts/listen_mute_crash.sh.
# Usage: scripts/selftest_mute_persistence.sh [report.json] [app path]
set -euo pipefail
REPORT="${1:-$(mktemp -t timbr-mutetest).json}"
APP="${2:-/Applications/Timbr.app}"
WAS_RUNNING=0
pgrep -x Timbr >/dev/null 2>&1 && WAS_RUNNING=1
pkill -x Timbr 2>/dev/null || true
sleep 0.5
"$APP/Contents/MacOS/Timbr" --selftest-mute-persistence "$REPORT" >/dev/null 2>&1 &
PID=$!
for _ in $(seq 1 60); do sleep 1; kill -0 "$PID" 2>/dev/null || break; done
pkill -f -- "--selftest-mute-holder" 2>/dev/null || true
pkill -f -- "--selftest-tone" 2>/dev/null || true
[ "$WAS_RUNNING" = 1 ] && open "$APP"
python3 - "$REPORT" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
print(f"macOS {r['macOS']}")
for c in r["checks"]:
    print(f"  [{'PASS' if c['pass'] else 'FAIL'}] {c['name']} — {c['detail']}")
for n in r["notes"]: print(f"  note: {n}")
print("ALL PASSED" if r["allPassed"] else "FAILED")
sys.exit(0 if r["allPassed"] else 1)
PY
