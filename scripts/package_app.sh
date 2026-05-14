#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ "${COZYTIME_ALLOW_SWIFTPM_PACKAGE:-0}" != "1" ]]; then
  echo "This SwiftPM bundle path is dev-only and does not include the full Xcode app stack." >&2
  echo "Use scripts/package_xcode_unsigned.sh for private handoff builds." >&2
  echo "Set COZYTIME_ALLOW_SWIFTPM_PACKAGE=1 only for local CLI smoke testing." >&2
  exit 1
fi

swift build -c release

APP_DIR="$ROOT_DIR/.build/release/CozyTime.app"
ZIP_PATH="$ROOT_DIR/.build/release/CozyTime-unsigned.zip"

rm -rf "$APP_DIR" "$ZIP_PATH"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$ROOT_DIR/.build/release/CozyTime" "$APP_DIR/Contents/MacOS/CozyTime"
cp "$ROOT_DIR/Packaging/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Sources/CozyTime/Resources/PrivacyInfo.xcprivacy" "$APP_DIR/Contents/Resources/PrivacyInfo.xcprivacy"
chmod +x "$APP_DIR/Contents/MacOS/CozyTime"

/usr/bin/codesign \
  --force \
  --deep \
  --sign - \
  --entitlements "$ROOT_DIR/Packaging/CozyTime.entitlements" \
  "$APP_DIR"

/usr/bin/plutil -lint "$APP_DIR/Contents/Info.plist" >/dev/null
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

echo "App: $APP_DIR"
echo "Zip: $ZIP_PATH"
