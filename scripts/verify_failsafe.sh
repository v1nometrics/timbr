#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/dist/Timbr.app/Contents/MacOS/Timbr"

if [ ! -x "$BIN" ]; then
  "$ROOT/scripts/build_app.sh"
fi

echo "=== Fail-safe Resilience Test: 20x SIGKILL (kill -9) + P3 Snapshot Check ==="
BEFORE_OUT="$(system_profiler SPAudioDataType 2>/dev/null | grep -E "Default Output Device: Yes" -B 4 || true)"

for i in $(seq 1 20); do
  "$BIN" >/dev/null 2>&1 &
  PID=$!
  sleep 0.25
  kill -9 "$PID" 2>/dev/null || true
  wait "$PID" 2>/dev/null || true

  # Verify cleanup of any leaked timbr aggregate devices occurs within < 1s
  LEAKED="$(system_profiler SPAudioDataType 2>/dev/null | grep -c "dev.v1torres.timbr.agg" || true)"
  if [ "$LEAKED" -gt 0 ]; then
    echo "FAIL on iteration $i: found leaked aggregate device!"
    exit 1
  fi
done

# Run one clean launch + smoke exit to confirm post-crash HAL recovery & 0 leftovers
"$BIN" --smoke-check
AFTER_OUT="$(system_profiler SPAudioDataType 2>/dev/null | grep -E "Default Output Device: Yes" -B 4 || true)"

if [ "$BEFORE_OUT" != "$AFTER_OUT" ]; then
  echo "FAIL: Default output device changed across 20x SIGKILL cycles!"
  exit 1
fi

echo "  [PASS] 20/20 kill -9 cycles survived with 0 leaked aggregates and identical default output (P3)"
