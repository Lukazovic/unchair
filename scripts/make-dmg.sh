#!/bin/bash
# Builds a Release copy of Unchair and packages it as a drag-to-Applications DMG.
# The app is signed to run locally (ad hoc), so first-time users have to
# confirm it in System Settings (see docs/install.md).
#
# Usage: scripts/make-dmg.sh [version]
# Output: build/Unchair-<version>.dmg
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:-$(xcodebuild -project Unchair.xcodeproj -target Unchair -showBuildSettings 2>/dev/null | awk -F' = ' '/ MARKETING_VERSION /{print $2}')}"
# Sparkle compares build numbers, so they must only grow: the commit count on main does.
build_number="${BUILD_NUMBER:-$(git rev-list --count HEAD)}"
build_dir="build"
derived_data="$build_dir/DerivedData"
staging="$build_dir/dmg"
dmg="$build_dir/Unchair-$version.dmg"

rm -rf "$staging" "$dmg"
mkdir -p "$staging"

xcodebuild \
    -project Unchair.xcodeproj \
    -scheme Unchair \
    -configuration Release \
    -derivedDataPath "$derived_data" \
    MARKETING_VERSION="$version" \
    CURRENT_PROJECT_VERSION="$build_number" \
    build | grep -E "error:|warning:|BUILD" || true

app="$derived_data/Build/Products/Release/Unchair.app"
[[ -d "$app" ]] || { echo "Build failed: $app not found" >&2; exit 1; }

cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
hdiutil create -volname "Unchair" -srcfolder "$staging" -ov -format UDZO "$dmg" >/dev/null
rm -rf "$staging"

echo "$dmg"
