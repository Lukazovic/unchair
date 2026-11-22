#!/bin/bash
# Runs everything CI runs: formatting, lint, core tests, and an app build.
set -euo pipefail
cd "$(dirname "$0")/.."

step() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }

step "SwiftFormat"
swiftformat --lint . 2>&1 | tail -1

step "SwiftLint"
swiftlint --strict --quiet

step "UnchairCore tests"
swift test --package-path Packages/UnchairCore 2>&1 | grep -E "error|✘|Test run"

step "App build"
log=$(mktemp)
if ! xcodebuild build -project Unchair.xcodeproj -scheme Unchair -derivedDataPath build/DerivedData >"$log" 2>&1; then
    grep -E "error:" "$log" || tail -20 "$log"
    exit 1
fi
echo "Build succeeded."

printf '\n\033[1;32m✓ All checks passed\033[0m\n'
