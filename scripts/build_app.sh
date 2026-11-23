#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
if [ ! -d "$SDK" ]; then
  SDK="$(xcrun --show-sdk-path)"
fi

# Match the deployment target in Package.swift.
TARGET="$(uname -m)-apple-macosx15.0"
BUILD="$ROOT/.build-local"
DIST="$ROOT/dist"
APP="$DIST/Timbr.app"

mkdir -p "$BUILD" "$DIST"

echo "==> Regenerating design tokens & verifying parity"
python3 "$ROOT/design-system/scripts/generate_tokens.py"

echo "==> Generating Timbr.icns"
python3 "$ROOT/scripts/generate_icns.py"

echo "==> Compiling CTimbreDSP (C++20 + Accelerate/vDSP)"
clang++ -target "$TARGET" -isysroot "$SDK" -std=c++20 -O2 -Wall -Wextra -Werror \
  -I "$ROOT/Sources/CTimbreDSP/include" \
  -c "$ROOT/Sources/CTimbreDSP/src/timbre_dsp.cpp" \
  -o "$BUILD/timbre_dsp.o"
ar rcs "$BUILD/libCTimbreDSP.a" "$BUILD/timbre_dsp.o"

echo "==> Compiling TimbreDesignSystem (Swift 6)"
swiftc -target "$TARGET" -sdk "$SDK" -swift-version 6 -wmo -parse-as-library \
  -module-name TimbreDesignSystem \
  -emit-object -emit-module -emit-module-path "$BUILD/TimbreDesignSystem.swiftmodule" \
  -o "$BUILD/TimbreTokens.o" \
  "$ROOT/design-system/generated/TimbreTokens.swift"

echo "==> Compiling TimbreCore (Swift 6)"
swiftc -target "$TARGET" -sdk "$SDK" -swift-version 6 -wmo -parse-as-library \
  -I "$BUILD" -I "$ROOT/Sources/CTimbreDSP/include" \
  -module-name TimbreCore \
  -emit-object -emit-module -emit-module-path "$BUILD/TimbreCore.swiftmodule" \
  -o "$BUILD/TimbreCore.o" \
  "$ROOT/Sources/TimbreCore/"*.swift

echo "==> Compiling TimbreEngine (Swift 6)"
swiftc -target "$TARGET" -sdk "$SDK" -swift-version 6 -wmo -parse-as-library \
  -I "$BUILD" -I "$ROOT/Sources/CTimbreDSP/include" \
  -module-name TimbreEngine \
  -emit-object -emit-module -emit-module-path "$BUILD/TimbreEngine.swiftmodule" \
  -o "$BUILD/TimbreEngine.o" \
  "$ROOT/Sources/TimbreEngine/"*.swift

echo "==> Compiling & Linking Timbr executable (Swift 6)"
swiftc -target "$TARGET" -sdk "$SDK" -swift-version 6 -wmo -parse-as-library \
  -I "$BUILD" -I "$ROOT/Sources/CTimbreDSP/include" \
  -module-name TimbreApp \
  -emit-executable -o "$BUILD/Timbr" \
  "$ROOT/Sources/TimbreApp/"*.swift \
  "$BUILD/TimbreEngine.o" "$BUILD/TimbreCore.o" "$BUILD/TimbreTokens.o" "$BUILD/libCTimbreDSP.a" \
  -Xlinker -lsqlite3 -Xlinker -lc++ \
  -framework Accelerate -framework CoreAudio -framework AudioToolbox \
  -framework IOBluetooth -framework CoreBluetooth -framework Carbon \
  -framework AppKit -framework SwiftUI

echo "==> Compiling timbr-mute-keeper (fail-closed mute holder, ADR-0017)"
swiftc -target "$TARGET" -sdk "$SDK" -swift-version 6 -O -module-name TimbrMuteKeeper \
  -emit-executable -o "$BUILD/timbr-mute-keeper" \
  "$ROOT/Sources/TimbrMuteKeeper/main.swift" "$ROOT/Sources/TimbreCore/MuteKeeperProtocol.swift" \
  -framework CoreAudio -framework AudioToolbox

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD/Timbr" "$APP/Contents/MacOS/Timbr"
cp "$BUILD/timbr-mute-keeper" "$APP/Contents/MacOS/timbr-mute-keeper"
cp "$ROOT/Resources/Timbr.icns" "$APP/Contents/Resources/Timbr.icns"
cp "$ROOT/Resources/TimbrMenuTemplate.png" "$APP/Contents/Resources/TimbrMenuTemplate.png"
cp "$ROOT/Resources/Brand/timbr-icon-1024.png" "$APP/Contents/Resources/TimbrBrandIcon.png"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>Timbr</string>
  <key>CFBundleIconFile</key>
  <string>Timbr</string>
  <key>CFBundleIdentifier</key>
  <string>com.timbr.app</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>timbr</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>15.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAudioCaptureUsageDescription</key>
  <string>timbr needs audio capture access exclusively to apply local per-app volume and parametric EQ. No audio is ever recorded or transmitted.</string>
  <key>NSBluetoothAlwaysUsageDescription</key>
  <string>timbr uses Bluetooth (RFCOMM) only to read battery, ANC and EQ telemetry from supported headphones such as Sennheiser Momentum 4.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

# Stable local identity when available (scripts/setup_dev_signing.sh): TCC grants such as
# Accessibility survive rebuilds. Otherwise ad-hoc (grants must be re-approved after each build).
DEV_KC="$HOME/Library/Keychains/timbr-dev.keychain-db"
DEV_ID="timbr Local Signing"
if [ -f "$DEV_KC" ] && [ -f "$HOME/.timbr-dev/keychain-pass" ] && security find-certificate -c "$DEV_ID" "$DEV_KC" >/dev/null 2>&1; then
  security unlock-keychain -p "$(cat "$HOME/.timbr-dev/keychain-pass")" "$DEV_KC"
  echo "==> Signing $APP with stable local identity ($DEV_ID)"
  codesign --force --deep --keychain "$DEV_KC" --sign "$DEV_ID" "$APP"
else
  echo "==> Ad-hoc signing $APP (run scripts/setup_dev_signing.sh to keep permissions across builds)"
  codesign --force --deep --sign - "$APP"
fi
codesign --verify --verbose=2 "$APP"
echo "Built & verified: $APP"
