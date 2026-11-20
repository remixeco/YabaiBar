#!/usr/bin/env bash
#
# screenshots.sh — regenerates the images used in the README.
#
# The app renders its own interface off-screen, so the pictures always match
# the code and no manual screenshots are needed.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP="$ROOT/build/YabaiBar.app/Contents/MacOS/YabaiBar"

if [ ! -x "$APP" ]; then
  echo "Building the app first…"
  ./Scripts/build.sh --no-install
fi

"$APP" --screenshots "$ROOT/docs"

echo
echo "Images written to $ROOT/docs"
