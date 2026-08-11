#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
REPO_DIR=${SCRIPT_DIR:h}
PACKAGE_DIR="$REPO_DIR/macos/NarzissCompanion"
DIST_DIR="$REPO_DIR/dist"
APP_DIR="$DIST_DIR/Narziss Companion.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
VERSION=$(cd "$REPO_DIR" && node -p "require('./package.json').version")

swift build --package-path "$PACKAGE_DIR" -c release
BIN_DIR=$(swift build --package-path "$PACKAGE_DIR" -c release --show-bin-path)

mkdir -p "$MACOS_DIR"
cp "$BIN_DIR/NarzissCompanion" "$MACOS_DIR/NarzissCompanion"
cp "$PACKAGE_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$CONTENTS_DIR/Info.plist"

codesign --force --deep --sign - "$APP_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$DIST_DIR/narziss-companion-v$VERSION-macos.zip"

echo "$DIST_DIR/narziss-companion-v$VERSION-macos.zip"
