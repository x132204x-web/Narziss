#!/bin/zsh
set -euo pipefail
SCRIPT_DIR=${0:A:h}
REPO_DIR=${SCRIPT_DIR:h}
PACKAGE_DIR="$REPO_DIR/macos/NarzissNotch"
DIST_DIR="$REPO_DIR/dist"
APP_DIR="$DIST_DIR/Narziss Notch.app"
VERSION=$(cd "$REPO_DIR" && node -p "require('./package.json').version")
# --scratch-path keeps Swift's build cache outside the source tree when supplied.
BUILD_ARGS=()
if [[ -n "${NOTCH_SCRATCH_PATH:-}" ]]; then
  BUILD_ARGS=(--scratch-path "$NOTCH_SCRATCH_PATH")
fi
swift build --package-path "$PACKAGE_DIR" -c release "${BUILD_ARGS[@]}"
BIN_DIR=$(swift build --package-path "$PACKAGE_DIR" -c release "${BUILD_ARGS[@]}" --show-bin-path)
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$BIN_DIR/NarzissNotch" "$APP_DIR/Contents/MacOS/NarzissNotch"
cp "$PACKAGE_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP_DIR/Contents/Info.plist"
# Compile the source artwork into all native macOS icon representations.
ICONSET_DIR="$DIST_DIR/NotchIcon.iconset"
mkdir -p "$ICONSET_DIR" "$APP_DIR/Contents/Resources"
for ICON_SIZE in 16 32 128 256 512; do
  sips -z "$ICON_SIZE" "$ICON_SIZE" "$PACKAGE_DIR/Resources/AppIcon.png" \
    --out "$ICONSET_DIR/icon_$ICON_SIZE"x"$ICON_SIZE.png" >/dev/null
  RETINA_SIZE=$((ICON_SIZE * 2))
  sips -z "$RETINA_SIZE" "$RETINA_SIZE" "$PACKAGE_DIR/Resources/AppIcon.png" \
    --out "$ICONSET_DIR/icon_$ICON_SIZE"x"$ICON_SIZE@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/NotchIcon.icns"
VENDOR_DIR="$PACKAGE_DIR/Vendor/mediaremote-adapter"
FRAMEWORK_DIR="$APP_DIR/Contents/Frameworks/MediaRemoteAdapter.framework"
mkdir -p "$FRAMEWORK_DIR/Versions/A/Resources" "$APP_DIR/Contents/Resources/MediaRemote"
xcrun clang -dynamiclib -fobjc-arc -mmacosx-version-min=14.0 \
  -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
  -I"$VENDOR_DIR/include" -I"$VENDOR_DIR/src" \
  "$VENDOR_DIR"/src/{adapter,private,utility}/*.m \
  -install_name '@rpath/MediaRemoteAdapter.framework/Versions/A/MediaRemoteAdapter' \
  -o "$FRAMEWORK_DIR/Versions/A/MediaRemoteAdapter"
cat > "$FRAMEWORK_DIR/Versions/A/Resources/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MediaRemoteAdapter</string>
<key>CFBundleIdentifier</key><string>com.vandenbe.MediaRemoteAdapter</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleVersion</key><string>1</string>
</dict></plist>
PLIST
ln -sfn A "$FRAMEWORK_DIR/Versions/Current"
ln -sfn Versions/Current/MediaRemoteAdapter "$FRAMEWORK_DIR/MediaRemoteAdapter"
ln -sfn Versions/Current/Resources "$FRAMEWORK_DIR/Resources"
cp "$VENDOR_DIR/bin/mediaremote-adapter.pl" "$VENDOR_DIR/LICENSE" "$APP_DIR/Contents/Resources/MediaRemote/"
codesign --force --sign - "$FRAMEWORK_DIR"
codesign --force --deep --sign - "$APP_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$DIST_DIR/narziss-notch-v$VERSION-macos.zip"
echo "$DIST_DIR/narziss-notch-v$VERSION-macos.zip"
