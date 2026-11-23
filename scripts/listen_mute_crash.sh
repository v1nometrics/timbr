#!/usr/bin/env bash
# Listening test for the fail-closed mute (ADR-0017) — the one thing no tap can measure (taps read
# audio before the mute). ~15 s, speakers on. A voice announces each part:
#   1 · a tone plays                                  → you HEAR it
#   2 · a timbr process mutes it (via timbr-mute-keeper) → SILENCE
#   3 · that timbr process is SIGKILLed              → still SILENCE
#   4 · `Timbr --release-all-mutes`                   → you HEAR it again
# Usage: scripts/listen_mute_crash.sh [app path]
set -euo pipefail
APP="${1:-/Applications/Timbr.app}"
BIN="$APP/Contents/MacOS/Timbr"
WORK="$(mktemp -d -t timbr-listen)"
WAS_RUNNING=0
pgrep -x Timbr >/dev/null 2>&1 && WAS_RUNNING=1
pkill -x Timbr 2>/dev/null || true
sleep 0.5
python3 - "$WORK/tone.wav" <<'PY'
import math, struct, sys, wave
sr, secs, amp = 48000, 40, 10 ** (-18 / 20) * 32767
with wave.open(sys.argv[1], "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(sr)
    frames = bytearray()
    for i in range(sr * secs):
        on = (i // (sr // 4)) % 2 == 0          # 250 ms beeps: easy to tell from silence
        v = int(amp * math.sin(2 * math.pi * 660 * i / sr)) if on else 0
        frames += struct.pack("<hh", v, v)
    w.writeframes(bytes(frames))
PY
cleanup() { pkill -f -- "--selftest-tone" 2>/dev/null || true; pkill -f -- "--selftest-mute-holder" 2>/dev/null || true; "$BIN" --release-all-mutes --mute-dir "$WORK/state" >/dev/null 2>&1 || true; rm -rf "$WORK"; [ "$WAS_RUNNING" = 1 ] && open "$APP" || true; }
trap cleanup EXIT

mkdir -p "$WORK/state"
say -v Luciana "Parte um. Deve tocar." 2>/dev/null || say "Part one. You should hear it."
"$BIN" --selftest-tone "$WORK/tone.wav" >/dev/null 2>&1 &
PLAYER=$!
sleep 4
"$BIN" --selftest-mute-holder "$PLAYER" "$WORK/state" >/dev/null 2>&1 &
HOLDER=$!
for _ in $(seq 1 160); do [ -f "$WORK/state/ready" ] && break; sleep 0.05; done
[ -f "$WORK/state/ready" ] && echo "keeper holds the mute" || echo "WARNING: keeper did not confirm"
say -v Luciana "Parte dois. Timbr vivo, silenciando." 2>/dev/null || say "Part two. timbr alive, muting."
sleep 5
kill -9 "$HOLDER"; wait "$HOLDER" 2>/dev/null || true
echo "holder $HOLDER killed with SIGKILL"
say -v Luciana "Parte três. Timbr morto. Deve continuar em silêncio." 2>/dev/null || say "Part three. timbr killed. Still silent."
sleep 5
"$BIN" --release-all-mutes --mute-dir "$WORK/state"
say -v Luciana "Parte quatro. Deve tocar de novo." 2>/dev/null || say "Part four. You should hear it again."
sleep 4
