#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
if [ ! -d "$SDK" ]; then
  SDK="$(xcrun --show-sdk-path)"
fi

BUILD="$ROOT/.build-local"
mkdir -p "$BUILD"

echo "=== 1. Design Token Generation & Sync Check ==="
python3 "$ROOT/design-system/scripts/generate_tokens.py"

echo "=== 2. Browser Extensions JSON & Playground Check ==="
ROOT="$ROOT" python3 - <<'INNER_PY'
import json, os
from pathlib import Path
root = Path(os.environ['ROOT'])
for mf in [root/'extensions/chrome-mv3/manifest.json', root/'extensions/safari-web-ext/manifest.json']:
    data = json.loads(mf.read_text())
    assert data['manifest_version'] == 3, mf
for pg in [root/'design-system/playground/index.html', root/'design-system/playground/styles.css', root/'design-system/playground/app.js']:
    assert pg.exists() and pg.stat().st_size > 100, pg
print("  [PASS] Extensions & Playground validated")
INNER_PY

echo "=== 3. MPL-2.0 / Zero-GPL Guardrail Check ==="
if grep -rnE "SPDX-License-Identifier:\s*(GPL|AGPL)" "$ROOT/Sources" "$ROOT/extensions" "$ROOT/Tests"; then
  echo "ERROR: GPL/AGPL header found in repo!"
  exit 1
fi
echo "  [PASS] Zero GPL/AGPL headers"

echo "=== 4. Build Full App Bundle & Compile Modules ==="
"$ROOT/scripts/build_app.sh"

echo "=== 5. C++ DSP Tests (Address + Undefined Sanitizers) ==="
clang++ -isysroot "$SDK" -std=c++20 -O1 -g -fsanitize=address,undefined \
  -Wall -Wextra -Werror \
  -I "$ROOT/Sources/CTimbreDSP/include" \
  "$ROOT/Sources/CTimbreDSP/src/timbre_dsp.cpp" \
  "$ROOT/Tests/CTimbreDSPTests/dsp_tests.cpp" \
  -framework Accelerate \
  -o "$BUILD/CTimbreDSPTests"
"$BUILD/CTimbreDSPTests"

LLVM_CXX="${LLVM_CLANGXX:-/opt/homebrew/opt/llvm/bin/clang++}"
if [ -x "$LLVM_CXX" ]; then
  echo "=== 5b. C++ DSP RealtimeSanitizer Check (LLVM RTSan) ==="
  "$LLVM_CXX" -isysroot "$SDK" -std=c++20 -O1 -g -fsanitize=realtime \
    -Wall -Wextra -Werror \
    -I "$ROOT/Sources/CTimbreDSP/include" \
    "$ROOT/Sources/CTimbreDSP/src/timbre_dsp.cpp" \
    "$ROOT/Tests/CTimbreDSPTests/dsp_tests.cpp" \
    -framework Accelerate \
    -o "$BUILD/CTimbreDSPTestsRTSan"
  "$BUILD/CTimbreDSPTestsRTSan"
else
  echo "=== 5b. Skipping RTSan (optional Homebrew LLVM not installed at $LLVM_CXX) ==="
fi

echo "=== 6. Swift 6 TimbreCore Tests ==="
swiftc -sdk "$SDK" -swift-version 6 -wmo -parse-as-library \
  -I "$BUILD" -I "$ROOT/Sources/CTimbreDSP/include" \
  -module-name TimbreCoreTests \
  -emit-executable -o "$BUILD/TimbreCoreTests" \
  "$ROOT/Tests/TimbreCoreTests/main.swift" \
  "$BUILD/TimbreCore.o" "$BUILD/libCTimbreDSP.a" \
  -Xlinker -lsqlite3 -Xlinker -lc++ -framework Accelerate
"$BUILD/TimbreCoreTests"

echo "=== 7. Swift 6 TimbreEngine Tests ==="
swiftc -sdk "$SDK" -swift-version 6 -wmo -parse-as-library \
  -I "$BUILD" -I "$ROOT/Sources/CTimbreDSP/include" \
  -module-name TimbreEngineTests \
  -emit-executable -o "$BUILD/TimbreEngineTests" \
  "$ROOT/Tests/TimbreEngineTests/main.swift" \
  "$BUILD/TimbreEngine.o" "$BUILD/TimbreCore.o" "$BUILD/libCTimbreDSP.a" \
  -Xlinker -lsqlite3 -Xlinker -lc++ \
  -framework Accelerate -framework CoreAudio -framework AudioToolbox \
  -framework IOBluetooth -framework AppKit
"$BUILD/TimbreEngineTests"

echo "=== 8. Timbr.app Bundle Smoke Launch & Clean Exit ==="
"$ROOT/dist/Timbr.app/Contents/MacOS/Timbr" --smoke-check

echo "=== 9. 20x SIGKILL Fail-Safe & P3 Clean Exit Check ==="
"$ROOT/scripts/verify_failsafe.sh"

echo "=== ALL CI CHECKS PASSED ==="
