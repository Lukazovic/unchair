#!/bin/bash
# Prints the path to a Sparkle command-line tool (generate_keys, sign_update,
# generate_appcast) from the Swift package Xcode downloaded.
# Usage: scripts/sparkle-tool.sh <tool> [derived-data-path]
set -euo pipefail
tool="$1"
derived_data="${2:-$HOME/Library/Developer/Xcode/DerivedData}"
path=$(find "$derived_data" -path "*artifacts/sparkle/Sparkle/bin/$tool" -type f 2>/dev/null | head -1)
if [[ -z "$path" ]]; then
    echo "Couldn't find Sparkle's $tool. Build the project in Xcode once so the package is downloaded." >&2
    exit 1
fi
echo "$path"
