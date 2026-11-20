#!/usr/bin/env bash
#
# package.sh — builds YabaiBar.app and packages it as a release zip.
#
# The zip is what the Homebrew cask downloads: the .app bundle must sit at
# the root of the archive.
#
# It also refreshes Casks/yabaibar.rb with the new version and checksum, so
# publishing a release is just: tag, upload, open a pull request on
# homebrew/cask.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-$(cat "$ROOT/VERSION" 2>/dev/null || echo 1.0.0)}"

DIST="$ROOT/dist"
ZIP="$DIST/YabaiBar-$VERSION.zip"

step() { printf '\n\033[1;36m▸ %s\033[0m\n' "$1"; }

step "Building YabaiBar $VERSION"
./Scripts/build.sh --no-install

step "Packaging $ZIP"
rm -rf "$DIST"
mkdir -p "$DIST"
cd "$ROOT/build"
zip -qry "$ZIP" "YabaiBar.app" -x "*.DS_Store"
cd "$ROOT"

SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"

step "Updating Casks/yabaibar.rb"
mkdir -p "$ROOT/Casks"
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
echo "Next:"
echo "  git tag v$VERSION && git push --tags"
echo "  gh release create v$VERSION $ZIP --title \"YabaiBar $VERSION\" --notes \"See CHANGELOG.md\""
