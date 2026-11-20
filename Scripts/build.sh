#!/usr/bin/env bash
#
# build.sh — builds YabaiBar.app, signs it and installs it.
#
#   ./Scripts/build.sh              build and install into /Applications
#   ./Scripts/build.sh --no-install build only, leave the bundle in build/
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="YabaiBar"
BUNDLE_ID="com.yabaibar.YabaiBar"
VERSION="$(cat "$ROOT/VERSION" 2>/dev/null || echo 1.0.0)"
BUILD_DIR="$ROOT/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
INSTALL_DIR="/Applications"
DO_INSTALL=1

for arg in "$@"; do
  case "$arg" in
    --no-install) DO_INSTALL=0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

step() { printf '\n\033[1;36m▸ %s\033[0m\n' "$1"; }

step "Cleaning previous build"
rm -rf "$BUILD_DIR" "$ROOT/.build/release/$APP_NAME"

step "Rendering the application icon"
swift "$ROOT/Scripts/make_icon.swift" "$ROOT/Assets/AppIcon.icns"
rm -f "$ROOT/Assets/AppIcon.icns"
iconutil -c icns "$ROOT/Assets/AppIcon.iconset" -o "$ROOT/Assets/AppIcon.icns"

step "Compiling (release)"
swift build -c release --product "$APP_NAME"

step "Assembling $APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$ROOT/.build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT/Assets/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>fr</string>
	<key>CFBundleExecutable</key>
	<string>$APP_NAME</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$APP_NAME</string>
	<key>CFBundleDisplayName</key>
	<string>YabaiBar</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>YabaiBar</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSSupportsAutomaticTermination</key>
	<false/>
	<key>NSSupportsSuddenTermination</key>
	<false/>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
PLIST

step "Signing"
# A "Developer ID Application" identity is used when one is available: it is
# what Apple notarization requires, and what the Homebrew cask audit checks.
# Without it the bundle is signed ad-hoc, which is enough to run locally.
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
if [ -z "$SIGN_IDENTITY" ]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | grep 'Developer ID Application' | head -1 | sed -E 's/.*"(.+)".*/\1/')"
fi

if [ -n "$SIGN_IDENTITY" ]; then
  echo "  identity: $SIGN_IDENTITY"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
else
  echo "  no Developer ID identity found, signing ad-hoc"
  echo "  (set SIGN_IDENTITY, or join the Apple Developer Program, to ship a notarized build)"
  codesign --force --sign - --timestamp=none "$APP_BUNDLE"
fi
codesign --verify --verbose=2 "$APP_BUNDLE"

if [ "$DO_INSTALL" -eq 1 ]; then
  step "Installing into $INSTALL_DIR"
  rm -rf "$INSTALL_DIR/$APP_NAME.app"
  cp -R "$APP_BUNDLE" "$INSTALL_DIR/"
  # Let the LaunchServices database know about the new bundle.
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true
  echo "Installed: $INSTALL_DIR/$APP_NAME.app"
else
  echo "Built: $APP_BUNDLE"
fi

printf '\n\033[1;32m✓ Done.\033[0m\n'
