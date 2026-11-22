#!/usr/bin/env bash
# Local first-run installer for dogfooding (ad-hoc signed builds).
# Removes Gatekeeper quarantine so the first open matches a notarized experience as closely as possible.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_SRC="$ROOT/dist/Timbr.app"
DMG="$ROOT/dist/Timbr.dmg"
DEST="/Applications/Timbr.app"
RESET_ONBOARDING=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [--dmg] [--reset-onboarding] [--dest PATH]

  (default)   Build Timbr.app if needed, copy to /Applications, clear quarantine, launch.
  --dmg       Also rebuild the DMG after the app bundle.
  --reset-onboarding
              Clear local onboarding flag so the welcome flow appears again.
  --dest PATH Install destination (default: /Applications/Timbr.app).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dmg) bash "$ROOT/scripts/build_dmg.sh"; shift ;;
    --reset-onboarding) RESET_ONBOARDING=1; shift ;;
    --dest) DEST="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [ ! -d "$APP_SRC" ]; then
  "$ROOT/scripts/build_app.sh"
fi

echo "==> Installing $APP_SRC → $DEST"
# Quit running instance if present
pkill -x Timbr 2>/dev/null || true
sleep 0.3

rm -rf "$DEST"
cp -R "$APP_SRC" "$DEST"

# Clear quarantine so Gatekeeper doesn't block ad-hoc local builds mid-dogfood
xattr -cr "$DEST" 2>/dev/null || true

if [ "$RESET_ONBOARDING" -eq 1 ]; then
  DB="$HOME/Library/Application Support/dev.v1torres.timbr/timbr.sqlite"
  echo "==> Resetting onboardingCompleted for first-run rehearsal"
  python3 - <<PY
import sqlite3, time
from pathlib import Path
db = Path.home() / "Library/Application Support/dev.v1torres.timbr/timbr.sqlite"
db.parent.mkdir(parents=True, exist_ok=True)
con = sqlite3.connect(db)
con.execute("""
CREATE TABLE IF NOT EXISTS kv_store (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at REAL NOT NULL
)
""")
con.execute(
    "INSERT OR REPLACE INTO kv_store(key, value, updated_at) VALUES(?,?,?)",
    ("onboardingCompleted", "0", time.time()),
)
con.commit()
con.close()
print(f"  reset in {db}")
PY
fi

echo "==> Launching $DEST"
open "$DEST"
echo "Installed. Look for the timbr. welcome window (first run) or the menu-bar waveform icon."
if [ -f "$DMG" ]; then
  echo "DMG also available at: $DMG"
fi
