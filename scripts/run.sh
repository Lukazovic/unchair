#!/bin/bash
# Builds a Debug copy of Unchair and opens it, quitting any other copy first
# (they share settings and the global shortcut).
#
# Usage: scripts/run.sh [options]
#   --sample       a month of in-memory sample history (your data is untouched)
#   --fullscreen   show a full-screen reminder right after launch
#   --lang CODE    run in a language: en, es, or pt-BR
set -euo pipefail
cd "$(dirname "$0")/.."

args=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --sample) args+=(-UnchairSampleData) ;;
        --fullscreen) args+=(-UnchairDemoFullScreen) ;;
        --lang) args+=(-AppleLanguages "($2)"); shift ;;
        -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $1 (see --help)" >&2; exit 1 ;;
    esac
    shift
done

derived_data="build/DerivedData"
echo "Building…"
xcodebuild build \
    -project Unchair.xcodeproj \
    -scheme Unchair \
    -configuration Debug \
    -derivedDataPath "$derived_data" \
    -quiet 2>&1 | grep -E "error:" || true

app="$derived_data/Build/Products/Debug/Unchair.app"
[[ -x "$app/Contents/MacOS/Unchair" ]] || { echo "Build failed." >&2; exit 1; }

if pgrep -x Unchair >/dev/null; then
    echo "Quitting the running copy of Unchair…"
    pkill -x Unchair || true
    sleep 1
fi

open -n "$app" --args "${args[@]+"${args[@]}"}"
echo "Unchair is running. Look for its icon in the menu bar."
