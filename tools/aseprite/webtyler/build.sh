#!/usr/bin/env bash
# Build the Webtyler Aseprite extension.
#
# Produces a VERSION-STAMPED archive (webtyler.aseprite-extension_v<maj>_<min>_<patch>)
# from the version in package.json, and syncs the installed copy so a restart of
# Aseprite picks up the new code. Version-stamped filenames keep a history of
# builds and avoid the "installed a stale generic file" confusion.
#
# Usage:  ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

VERSION="$(grep '"version"' package.json | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
if [ -z "$VERSION" ]; then
    echo "ERROR: couldn't read version from package.json" >&2
    exit 1
fi
# Version goes BEFORE the extension — the file MUST end in `.aseprite-extension`
# or Aseprite's "Add Extension" picker filters it out.
VTAG="v${VERSION//./_}"
OUT="webtyler_${VTAG}.aseprite-extension"

# Build the version-stamped archive (flat zip of the two extension files).
rm -f "$OUT"
zip -j -q "$OUT" package.json webtyler.lua

# Sync the installed copy (what Aseprite actually runs — restart to apply).
INSTALL="$HOME/.config/aseprite/extensions/webtyler"
if [ -d "$INSTALL" ]; then
    cp package.json webtyler.lua "$INSTALL/"
    SYNCED="$INSTALL"
else
    SYNCED="(not installed — skipped)"
fi

echo "Built:  $OUT  (version $VERSION)"
echo "Synced: $SYNCED"
echo "Restart Aseprite to load the new code."
