#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/Timbr.app"
STAGE="$ROOT/.build-local/dmg-stage"
DMG="$DIST/Timbr.dmg"

if [ ! -d "$APP" ]; then
  "$ROOT/scripts/build_app.sh"
fi

if [ -n "${DEVELOPER_ID:-}" ]; then
  echo "==> Signing $APP with Developer ID: $DEVELOPER_ID"
  codesign --force --deep --options runtime --timestamp --sign "$DEVELOPER_ID" "$APP"
  codesign --verify --strict --verbose=2 "$APP"
else
  echo "==> Using ad-hoc signature (set DEVELOPER_ID & NOTARY_PROFILE for Gate G3 public notarization)"
fi

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Timbr.app"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "timbr." -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"

if [ -n "${DEVELOPER_ID:-}" ]; then
  codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG"
fi

if [ -n "${NOTARY_PROFILE:-}" ]; then
  echo "==> Submitting $DMG for Apple Notarization (profile: $NOTARY_PROFILE)"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
fi

shasum -a 256 "$DMG"
echo "Built DMG: $DMG"
