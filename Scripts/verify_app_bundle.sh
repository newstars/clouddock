#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/dist/CloudDock.app"
INFO_PLIST="$APP_DIR/Contents/Info.plist"
EXECUTABLE="$APP_DIR/Contents/MacOS/CloudDock"
ICON_FILE="$APP_DIR/Contents/Resources/CloudDock.icns"

[[ -d "$APP_DIR" ]] || { echo "Missing app bundle: $APP_DIR" >&2; exit 1; }
[[ -x "$EXECUTABLE" ]] || { echo "Missing executable: $EXECUTABLE" >&2; exit 1; }
[[ -f "$INFO_PLIST" ]] || { echo "Missing Info.plist: $INFO_PLIST" >&2; exit 1; }
[[ -f "$ICON_FILE" ]] || { echo "Missing icon: $ICON_FILE" >&2; exit 1; }

plutil -lint "$INFO_PLIST" >/dev/null
codesign --verify --deep --strict --verbose=2 "$APP_DIR"
echo "Verified $APP_DIR"
