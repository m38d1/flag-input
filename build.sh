#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="FlagInput"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

if [[ -w /Applications ]]; then
    INSTALL_DIR="/Applications"
else
    INSTALL_DIR="$HOME/Applications"
fi

rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

swiftc -O -swift-version 5 -target arm64-apple-macosx13.0 "$PWD/Sources/main.swift" \
    -o "$BUILD_DIR/FlagInput-arm64" \
    -framework Cocoa -framework Carbon -framework ServiceManagement

swiftc -O -swift-version 5 -target x86_64-apple-macosx13.0 "$PWD/Sources/main.swift" \
    -o "$BUILD_DIR/FlagInput-x86_64" \
    -framework Cocoa -framework Carbon -framework ServiceManagement

lipo -create "$BUILD_DIR/FlagInput-arm64" "$BUILD_DIR/FlagInput-x86_64" \
    -output "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

swiftc -O -swift-version 5 make-icon.swift -o "$BUILD_DIR/make-icon" -framework AppKit
"$BUILD_DIR/make-icon" "$BUILD_DIR/icon-render.png" >/dev/null
rm -rf "$BUILD_DIR/Icon.iconset"
mkdir -p "$BUILD_DIR/Icon.iconset"
for size in 16 32 128 256 512; do
    sips -z $size $size "$BUILD_DIR/icon-render.png" --out "$BUILD_DIR/Icon.iconset/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) "$BUILD_DIR/icon-render.png" --out "$BUILD_DIR/Icon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$BUILD_DIR/Icon.iconset" -o "$BUILD_DIR/$APP_NAME.icns"

cp Info.plist "$APP_BUNDLE/Contents/Info.plist"
cp "$BUILD_DIR/$APP_NAME.icns" "$APP_BUNDLE/Contents/Resources/$APP_NAME.icns"
codesign --force --sign - "$APP_BUNDLE"

/usr/bin/ditto "$APP_BUNDLE" "$INSTALL_DIR/$APP_NAME.app"

if [[ -d "$HOME/Applications/$APP_NAME.app" && "$INSTALL_DIR" != "$HOME/Applications" ]]; then
    rm -rf "$HOME/Applications/$APP_NAME.app"
fi

echo "Installed: $INSTALL_DIR/$APP_NAME.app"
