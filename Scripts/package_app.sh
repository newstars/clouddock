#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="CloudDock"
BUNDLE_ID="dev.clouddock.CloudDock"
BUILD_DIR="$ROOT_DIR/.build"
DIST_DIR="$BUILD_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_NAME="CloudDock"
ICON_PNG="$ROOT_DIR/Resources/CloudDockIcon.png"
ICONSET="$BUILD_DIR/$ICON_NAME.iconset"
ICON_FILE="$ICON_NAME.icns"

for required_tool in swift python3 sips iconutil codesign; do
    command -v "$required_tool" >/dev/null || {
        echo "Missing required tool: $required_tool" >&2
        exit 1
    }
done

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
    swift build -c release --package-path "$ROOT_DIR"
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_DIR/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Resources/Datadog.png" "$RESOURCES_DIR/Datadog.png"

if [[ ! -f "$ICON_PNG" ]]; then
    python3 "$ROOT_DIR/Scripts/generate_app_icon.py"
fi

rm -rf "$ICONSET"
mkdir -p "$ICONSET"
sips -z 16 16 "$ICON_PNG" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_PNG" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_PNG" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_PNG" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_PNG" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_PNG" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_PNG" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_PNG" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$RESOURCES_DIR/$ICON_FILE"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>$ICON_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>CloudDock shows your upcoming calendar events and meeting links.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>CloudDock controls Music playback when you use the music widget.</string>
</dict>
</plist>
PLIST

codesign --force --sign "${CODESIGN_IDENTITY:--}" "$APP_DIR"
echo "$APP_DIR"
