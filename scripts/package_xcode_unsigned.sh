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

if [[ "${COZYTIME_SKIP_RELEASE_GATE:-0}" != "1" ]]; then
  scripts/run_xcode_release_gate.sh
fi

ARCHIVE_PATH="$ROOT_DIR/.build/xcode/CozyTime.xcarchive"
EXPORT_DIR="$ROOT_DIR/.build/xcode/export"
ZIP_PATH="$ROOT_DIR/.build/xcode/CozyTime-unsigned-xcode.zip"

rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR" "$ZIP_PATH"
mkdir -p "$EXPORT_DIR"

xcodebuild \
  -project CozyTime.xcodeproj \
  -scheme CozyTime \
  -configuration Release \
  -destination 'platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="-" \
  archive

APP_PATH="$ARCHIVE_PATH/Products/Applications/CozyTime.app"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"
/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Archive: $ARCHIVE_PATH"
echo "App: $APP_PATH"
echo "Zip: $ZIP_PATH"
