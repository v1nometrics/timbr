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

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Timbr.app"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "timbr." -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"
shasum -a 256 "$DMG"
echo "Built DMG: $DMG"
