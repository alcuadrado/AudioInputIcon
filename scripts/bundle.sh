#!/bin/bash
set -euo pipefail

APP_NAME="AudioInputIcon"
BUILD_DIR="zig-out/bin"
BUNDLE_DIR="${APP_NAME}.app"

rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "$BUNDLE_DIR/Contents/MacOS/"
cp bundle/Info.plist "$BUNDLE_DIR/Contents/"
if [ -f bundle/AppIcon.icns ]; then
    cp bundle/AppIcon.icns "$BUNDLE_DIR/Contents/Resources/"
fi

echo "APPL????" > "$BUNDLE_DIR/Contents/PkgInfo"

echo "Created ${BUNDLE_DIR}"
echo "To install: cp -r ${BUNDLE_DIR} /Applications/"
