#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Full Xcode is required. Install Xcode, then run:" >&2
  echo "sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

if [[ ! -d CozyTime.xcodeproj ]]; then
  scripts/generate_xcode_project.sh
fi

scripts/sync_licensed_assets.sh
scripts/import_opentoonz_art_pack.sh

scripts/lint_design.sh

xcodebuild \
  -project CozyTime.xcodeproj \
  -scheme CozyTime \
  -destination 'platform=macOS' \
  -testPlan Release \
  test
