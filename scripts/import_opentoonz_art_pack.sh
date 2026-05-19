#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${COZYTIME_OPENTOONZ_DIR:-$ROOT_DIR/.build/external/opentoonz}"
ASSET_DIR="$ROOT_DIR/XcodeSupport/CozyTime/Assets.xcassets"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "OpenToonz checkout not found at $SOURCE_DIR; keeping existing OpenToonz art assets."
  exit 0
fi

CUSTOM_DIR="$SOURCE_DIR/stuff/library/custom styles"
if [[ ! -d "$CUSTOM_DIR" ]]; then
  echo "OpenToonz custom styles directory missing at $CUSTOM_DIR; keeping existing assets."
  exit 0
fi

mkdir -p "$ASSET_DIR"

write_imageset() {
  local asset_name="$1"
  local source_file="$2"
  local imageset="$ASSET_DIR/$asset_name.imageset"
  local filename="$asset_name.png"

  if [[ ! -f "$source_file" ]]; then
    echo "Missing OpenToonz art source: $source_file" >&2
    return 1
  fi

  mkdir -p "$imageset"
  cp "$source_file" "$imageset/$filename"
  cat > "$imageset/Contents.json" <<JSON
{
  "images" : [
    { "filename" : "$filename", "idiom" : "universal", "scale" : "1x" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
}

write_alias() {
  write_imageset "$1" "$CUSTOM_DIR/$2"
}

while IFS= read -r -d '' source_file; do
  filename="$(basename "$source_file")"
  stem="${filename%.png}"
  normalized="$(printf '%s' "$stem" | tr '[:upper:]' '[:lower:]')"
  write_imageset "opentoonz.custom.$normalized" "$source_file"
done < <(find "$CUSTOM_DIR" -maxdepth 1 -type f -name '*.png' -print0)

write_imageset "mascot.toonz-buddy.idle" "$CUSTOM_DIR/Dog.0001.png"
write_imageset "mascot.toonz-buddy.focus" "$CUSTOM_DIR/Dog.0002.png"
write_imageset "mascot.toonz-buddy.complete" "$CUSTOM_DIR/Dog.0003.png"
write_imageset "mascot.toonz-buddy.countdown" "$CUSTOM_DIR/Dog.0004.png"

write_imageset "mascot.toonz-chick.idle" "$CUSTOM_DIR/Chick.0001.png"
write_imageset "mascot.toonz-chick.focus" "$CUSTOM_DIR/Chick.0002.png"
write_imageset "mascot.toonz-chick.complete" "$CUSTOM_DIR/Chick.0003.png"

write_alias "opentoonz.arc" "Arc.0001.png"
write_alias "opentoonz.ball" "Ball.0001.png"
write_alias "opentoonz.bow" "Bow.0001.png"
write_alias "opentoonz.brush" "Brush.0001.png"
write_alias "opentoonz.brush2" "Brush2.0001.png"
write_alias "opentoonz.bubbles" "bubb2.0001.png"
write_alias "opentoonz.candy" "Candy.0001.png"
write_alias "opentoonz.domino" "domino.0001.png"
write_alias "opentoonz.fish2" "Fish2.0001.png"
write_alias "opentoonz.fish3" "Fish3.0001.png"
write_alias "opentoonz.fishbone" "Fishbone.0001.png"
write_alias "opentoonz.flower" "flow.0001.png"
write_alias "opentoonz.flower3" "flow3.0001.png"
write_alias "opentoonz.flower4" "flow4.0001.png"
write_alias "opentoonz.frame" "Frame.0001.png"
write_alias "opentoonz.fruit" "Fruit.0001.png"
write_alias "opentoonz.half" "half.0001.png"
write_alias "opentoonz.hedge" "hedg.0001.png"
write_alias "opentoonz.icecream" "Icecream.0001.png"
write_alias "opentoonz.ladybird" "Ladybird.0001.png"
write_alias "opentoonz.leaf" "Leaf2.0001.png"
write_alias "opentoonz.orange" "Orange.0001.png"
write_alias "opentoonz.pare" "pare.0001.png"
write_alias "opentoonz.pare2" "pare2.0001.png"
write_alias "opentoonz.pencil" "Pencil.0001.png"
write_alias "opentoonz.rice" "rice.0001.png"
write_alias "opentoonz.spring" "Spring.0001.png"
write_alias "opentoonz.stain" "stai.0001.png"
write_alias "opentoonz.star" "star.0001.png"
write_alias "opentoonz.sunflower" "Sunflower.0001.png"
write_alias "opentoonz.umbrella" "Umbrella.0001.png"

echo "Imported OpenToonz custom styles art pack into $ASSET_DIR"
