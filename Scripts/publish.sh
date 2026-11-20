#!/usr/bin/env bash
#
# publish.sh — prepares the local git repositories and prints the exact
# commands to publish YabaiBar.
#
# Two repositories are involved:
#
#   github.com/remixeco/YabaiBar        the application itself
#   github.com/remixeco/homebrew-tap    the Homebrew cask
#
# The tap must be named "homebrew-tap" for `brew tap remixeco/tap` to work.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

USER="remixeco"
TAP_DIR="$ROOT/.tap/homebrew-tap"
VERSION="$(cat "$ROOT/VERSION")"

step() { printf '\n\033[1;36m▸ %s\033[0m\n' "$1"; }

step "Preparing the Homebrew tap in $TAP_DIR"
rm -rf "$ROOT/.tap"
mkdir -p "$TAP_DIR/Casks"
cp "$ROOT/Casks/yabaibar.rb" "$TAP_DIR/Casks/yabaibar.rb"
cat > "$TAP_DIR/README.md" <<EOF
# Homebrew tap

Casks for the tools maintained by [$USER](https://github.com/$USER).

\`\`\`sh
brew tap $USER/tap
brew install --cask $USER/tap/yabaibar
\`\`\`
EOF
printf '.DS_Store\n' > "$TAP_DIR/.gitignore"

step "Preparing the application repository"
cd "$ROOT"
if [ ! -d .git ]; then
  git init -b main
  git remote add origin "https://github.com/$USER/YabaiBar.git"
fi
git add -A
git status --short | head -40
echo
echo "Next steps:"
echo
echo "  # 1. create the repositories on GitHub (empty, no README)"
echo "  #    https://github.com/new  ->  YabaiBar"
echo "  #    https://github.com/new  ->  homebrew-tap"
echo
echo "  # 2. push the application"
echo "  cd '$ROOT'"
echo "  git commit -m 'Initial release of YabaiBar'"
echo "  git push -u origin main"
echo
echo "  # 3. push the tap"
echo "  cd '$TAP_DIR'"
echo "  git init -b main && git remote add origin https://github.com/$USER/homebrew-tap.git"
echo "  git add -A && git commit -m 'Add yabaibar cask'"
echo "  git push -u origin main"
echo
echo "  # 4. package and publish the release"
echo "  cd '$ROOT'"
echo "  ./Scripts/package.sh $VERSION"
echo "  git tag v$VERSION && git push --tags"
echo "  gh release create v$VERSION dist/YabaiBar-$VERSION.zip \\"
echo "    --title \"YabaiBar $VERSION\" --generate-notes"
echo
echo "  # 5. open the pull requests (see contrib/)"
echo "  #    contrib/yabai-wiki/README.md"
echo "  #    contrib/yabai-readme/PR.md"
