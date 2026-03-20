#!/bin/bash
set -euo pipefail

APP_NAME="AudioInputIcon"
BUNDLE_DIR="${APP_NAME}.app"
TGZ_FILE="${APP_NAME}.tgz"

if [ ! -d "$BUNDLE_DIR" ]; then
    echo "Error: ${BUNDLE_DIR} not found. Make sure you copy it to the current directory." >&2
    exit 1
fi

echo "Ad-hoc signing ${BUNDLE_DIR}..."
codesign --force --deep --sign - "$BUNDLE_DIR"

echo "Verifying signature..."
codesign --verify --verbose "$BUNDLE_DIR"

echo "Packaging into ${TGZ_FILE}..."
tar -czf "$TGZ_FILE" "$BUNDLE_DIR"

echo "Done: ${TGZ_FILE}"
