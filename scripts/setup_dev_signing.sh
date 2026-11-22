#!/usr/bin/env bash
# One-time: create a stable, local-only code-signing identity for dev builds.
#
# Why: ad-hoc signatures ("codesign -s -") change with every build, and macOS TCC pins
# Accessibility / Input Monitoring grants to that exact signature. After each rebuild the grant
# silently stops applying: the media-key interceptor cannot start and the Mac's own volume HUD
# comes back. A self-signed certificate gives a designated requirement that survives rebuilds.
#
# The identity lives in its own keychain (~/Library/Keychains/timbr-dev.keychain-db) with a random
# password stored in ~/.timbr-dev/ (mode 600), so signing never prompts and nothing secret
# enters the repository. Release builds keep using Developer ID (scripts/build_dmg.sh).
set -euo pipefail
NAME="timbr Local Signing"
DIR="$HOME/.timbr-dev"
KC="$HOME/Library/Keychains/timbr-dev.keychain-db"
mkdir -p "$DIR"; chmod 700 "$DIR"

if [ -f "$KC" ] && security find-certificate -c "$NAME" "$KC" >/dev/null 2>&1; then
  echo "Already set up: $NAME in $KC"; exit 0
fi

PASS="$(openssl rand -hex 24)"
printf '%s' "$PASS" > "$DIR/keychain-pass"; chmod 600 "$DIR/keychain-pass"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/cfg" <<CFG
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CFG
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cfg" 2>/dev/null
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -out "$TMP/id.p12" -passout pass:"$PASS" -name "$NAME" 2>/dev/null

[ -f "$KC" ] || security create-keychain -p "$PASS" "$KC"
security set-keychain-settings "$KC"            # no auto-lock
security unlock-keychain -p "$PASS" "$KC"
security import "$TMP/id.p12" -k "$KC" -P "$PASS" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PASS" "$KC" >/dev/null
# Add to the user search list (keeping existing keychains) so codesign can find the identity.
EXISTING=$(security list-keychains -d user | sed 's/[" ]//g')
security list-keychains -d user -s "$KC" $EXISTING
echo "Created $NAME in $KC"
