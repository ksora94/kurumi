#!/usr/bin/env bash
# Builds a release binary and wraps it into build/Kurumi.app (menu bar only, no Dock icon).
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Kurumi"
BUNDLE_ID="com.cyan.kurumi"
VERSION="0.1.0"
APP_DIR="build/${APP_NAME}.app"

# The default swift-build backend needs Xcode; the native one works with Command Line Tools.
swift build -c release --build-system native
BIN_DIR="$(swift build -c release --build-system native --show-bin-path)"

# Prefer the vector glyph so the app icon stays sharp at every size.
GLYPH="icon.svg"
[[ -f "$GLYPH" ]] || GLYPH="icon.png"

ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
swift scripts/make-icon.swift "$GLYPH" build/AppIcon-1024.png
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" build/AppIcon-1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" build/AppIcon-1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o build/AppIcon.icns

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$GLYPH" "$APP_DIR/Contents/Resources/$GLYPH"
cp build/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP_DIR" >/dev/null
echo "Built $APP_DIR"
