#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$ROOT_DIR/ThirdPartyLicensed/Ghibli"
ASSET_DIR="$ROOT_DIR/XcodeSupport/CozyTime/Assets.xcassets"

mkdir -p "$SRC_DIR" "$ASSET_DIR"

states=(
  idle
  focus
  complete
  countdown
  overdue
  breakTime
  settling
  deepFocus
  landing
)

synced=0

for state in "${states[@]}"; do
  src="$SRC_DIR/mascot.licensed.$state.png"
  imageset="$ASSET_DIR/mascot.licensed.$state.imageset"
  dest_name="mascot.licensed.$state.png"

  if [[ ! -f "$src" ]]; then
    rm -rf "$imageset"
    continue
  fi

  mkdir -p "$imageset"
  cp "$src" "$imageset/$dest_name"
  cat > "$imageset/Contents.json" <<JSON
{
  "images" : [
    { "filename" : "$dest_name", "idiom" : "universal", "scale" : "1x" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
  synced=$((synced + 1))
done

if [[ "$synced" -eq 0 ]]; then
  echo "No approved licensed mascot PNGs found in $SRC_DIR"
  echo "Expected names: mascot.licensed.{idle,focus,complete,...}.png"
else
  echo "Synced $synced licensed mascot image(s) into the Xcode asset catalog."
fi
