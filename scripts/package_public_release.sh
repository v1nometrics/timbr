#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/dist/Timbr.app"
dmg="$root/dist/Timbr.dmg"
for setting in TIMBR_APPLE_TEAM_ID TIMBR_DEVELOPER_ID_P12 TIMBR_DEVELOPER_ID_PASSWORD TIMBR_NOTARY_KEY TIMBR_NOTARY_KEY_ID TIMBR_NOTARY_ISSUER; do
  if [[ -z "${!setting:-}" ]]; then
    printf 'Missing distribution configuration: %s\n' "$setting" >&2
    exit 1
  fi
done
[[ "$TIMBR_APPLE_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]
[[ -d "$app" ]]
work="$(mktemp -d -t timbr-public-release)"
keychain="$work/distribution.keychain-db"
cleanup() {
  security delete-keychain "$keychain" 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT
chmod 700 "$work"
keychain_password="$(openssl rand -hex 24)"
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
printf '%s' "$TIMBR_DEVELOPER_ID_P12" | tr -d '[:space:]' | base64 -D > "$work/certificate.p12"
printf '%s' "$TIMBR_NOTARY_KEY" | tr -d '[:space:]' | base64 -D > "$work/notary.p8"
security import "$work/certificate.p12" -k "$keychain" -f pkcs12 -P "$TIMBR_DEVELOPER_ID_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain" >/dev/null
identity="$(security find-identity -v -p codesigning "$keychain" | awk -v team="($TIMBR_APPLE_TEAM_ID)" '/Developer ID Application:/ && index($0, team) { print $2; exit }')"
if [[ -z "$identity" ]]; then
  echo 'No valid Developer ID Application identity for the configured team.' >&2
  exit 1
fi
sign=(--force --options runtime --timestamp --keychain "$keychain" --sign "$identity")
codesign "${sign[@]}" "$app/Contents/MacOS/timbr-mute-keeper"
codesign "${sign[@]}" "$app"
codesign --verify --deep --strict "$app"
codesign --verify -R="anchor apple generic and certificate leaf[subject.OU] = \"$TIMBR_APPLE_TEAM_ID\" and identifier \"com.timbr.app\"" "$app"
notary=(--key "$work/notary.p8" --key-id "$TIMBR_NOTARY_KEY_ID" --issuer "$TIMBR_NOTARY_ISSUER")
# Staple the app before packaging so the copy in Applications carries its own ticket.
ditto -c -k --keepParent "$app" "$work/Timbr.zip"
xcrun notarytool submit "$work/Timbr.zip" "${notary[@]}" --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"

mkdir "$work/layout"
ditto "$app" "$work/layout/Timbr.app"
ln -s /Applications "$work/layout/Applications"
hdiutil create -volname timbr -srcfolder "$work/layout" -format UDZO "$work/Timbr.dmg"
codesign --force --timestamp --keychain "$keychain" --sign "$identity" "$work/Timbr.dmg"
xcrun notarytool submit "$work/Timbr.dmg" "${notary[@]}" --wait
xcrun stapler staple "$work/Timbr.dmg"
xcrun stapler validate "$work/Timbr.dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$work/Timbr.dmg"
mv -f "$work/Timbr.dmg" "$dmg"
