#!/usr/bin/env bash
#
# notarize.sh — signs, notarizes and staples the release build.
#
# Apple only notarizes software signed with a "Developer ID Application"
# certificate, which requires a paid Apple Developer Program membership.
# Once you have one, this script produces a build that Homebrew accepts.
#
# One-time setup:
#
#   # 1. a Developer ID Application certificate in the keychain
#   #    Xcode > Settings > Accounts > Manage Certificates, or the Keychain
#   #    Access Assistant.
#
#   # 2. a notarytool credential
#   xcrun notarytool store-credentials "AC_NOTARY" \
#     --apple-id "you@example.com" \
#     --team-id "XXXXXXXXXX" \
#     --password "app-specific-password"
#
# Then:
#
#   ./Scripts/notarize.sh
#
# The notarized zip replaces dist/YabaiBar-<version>.zip; upload that one to
# the release.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROFILE="${NOTARY_PROFILE:-AC_NOTARY}"
VERSION="$(cat "$ROOT/VERSION" 2>/dev/null || echo 1.0.0)"
DIST="$ROOT/dist"
ZIP="$DIST/YabaiBar-$VERSION.zip"

step() { printf '\n\033[1;36m▸ %s\033[0m\n' "$1"; }

step "Checking the signing identity"
IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
  | grep 'Developer ID Application' | head -1 | sed -E 's/.*"(.+)".*/\1/')"
if [ -z "$IDENTITY" ]; then
  echo "No \"Developer ID Application\" certificate found in the keychain."
  echo "Notarization is impossible without one: it comes with the Apple Developer Program."
  exit 1
fi
echo "  $IDENTITY"

step "Building"
./Scripts/build.sh --no-install

step "Creating the archive for notarization"
rm -rf "$ROOT/build/notarize"
mkdir -p "$ROOT/build/notarize"
ditto -c -k --keepParent "$ROOT/build/YabaiBar.app" "$ROOT/build/notarize/YabaiBar.zip"

step "Submitting to Apple"
xcrun notarytool submit "$ROOT/build/notarize/YabaiBar.zip" \
  --keychain-profile "$PROFILE" \
  --wait

step "Stapling the ticket"
xcrun stapler staple "$ROOT/build/YabaiBar.app"
xcrun stapler validate "$ROOT/build/YabaiBar.app"

step "Repackaging"
rm -f "$ZIP"
cd "$ROOT/build"
zip -qry "$ZIP" "YabaiBar.app" -x "*.DS_Store"
cd "$ROOT"
SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"

step "Updating the cask checksum"
python3 - "$ROOT/Casks/yabaibar.rb" "$VERSION" "$SHA" <<'PY'
import re, sys
path, version, sha = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
text = re.sub(r'version "[^"]+"', f'version "{version}"', text)
text = re.sub(r'sha256 "[^"]+"', f'sha256 "{sha}"', text)
open(path, "w").write(text)
PY

printf '\n\033[1;32m✓ %s\033[0m\n' "$ZIP"
echo "  sha256: $SHA"
echo
echo "Commit the updated cask, then upload the zip to the v$VERSION release."
