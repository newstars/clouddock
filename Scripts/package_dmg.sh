#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/dist/CloudDock.app"
if [[ "${SKIP_PACKAGE:-0}" != "1" ]]; then
    bash "$ROOT_DIR/Scripts/package_app.sh"
fi
bash "$ROOT_DIR/Scripts/verify_app_bundle.sh"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid app version" >&2; exit 1; }
ARCHS="$(lipo -archs "$APP_DIR/Contents/MacOS/CloudDock")"
case "$ARCHS" in
    *arm64*x86_64*|*x86_64*arm64*) ARCH=universal ;;
    arm64) ARCH=arm64 ;;
    x86_64) ARCH=x86_64 ;;
    *) echo "Unsupported architectures: $ARCHS" >&2; exit 1 ;;
esac
DIST_DIR="$ROOT_DIR/.build/dist"
DMG="$DIST_DIR/CloudDock-$VERSION-$ARCH.dmg"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/clouddock-dmg.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP_DIR" "$STAGING/CloudDock.app"
ln -s /Applications "$STAGING/Applications"
cp "$ROOT_DIR/LICENSE" "$STAGING/LICENSE"
hdiutil create -ov -volname "CloudDock $VERSION" -srcfolder "$STAGING" -format UDZO "$DMG"
hdiutil verify "$DMG"
cd "$DIST_DIR"
shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256"
echo "$DMG"
