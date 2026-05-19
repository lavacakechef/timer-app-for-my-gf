#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${1:-$ROOT_DIR/.build/external/opentoonz}"
OUT_DIR="$ROOT_DIR/.build/reports"
MANIFEST="$OUT_DIR/opentoonz-art-assets.tsv"
SUMMARY="$OUT_DIR/opentoonz-art-summary.txt"

if [[ ! -d "$SOURCE_DIR/.git" ]]; then
  echo "OpenToonz checkout not found at $SOURCE_DIR" >&2
  echo "Run:" >&2
  echo "  git clone --depth 1 --filter=blob:none https://github.com/opentoonz/opentoonz.git $SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

find "$SOURCE_DIR" -type f \
  \( -iname '*.png' -o -iname '*.svg' -o -iname '*.jpg' -o -iname '*.jpeg' \
     -o -iname '*.gif' -o -iname '*.ico' -o -iname '*.tif' -o -iname '*.tiff' \
     -o -iname '*.bmp' -o -iname '*.webp' \) \
  | sed "s#^$SOURCE_DIR/##" \
  | sort \
  | awk -F/ '
      BEGIN { OFS="\t"; print "path", "extension", "top_area", "license_bucket" }
      {
        ext=$0
        sub(/^.*\./, "", ext)
        path=tolower($0)
        bucket="OpenToonz BSD-3-Clause candidate"
        if (path ~ /^thirdparty\//) bucket="thirdparty: review separately"
        if (path ~ /^stuff\/library\/mypaint brushes\//) bucket="mypaint brushes: review Licenses.txt"
        if (path ~ /^stuff\/profiles\/layouts\/rooms\/studioghibli\//) bucket="layout config only; not character art"
        print $0, tolower(ext), $1"/"$2"/"$3, bucket
      }
    ' > "$MANIFEST"

{
  echo "OpenToonz asset crawl"
  echo "source: $SOURCE_DIR"
  echo "commit: $(git -C "$SOURCE_DIR" rev-parse HEAD)"
  echo
  echo "image-like files by extension:"
  tail -n +2 "$MANIFEST" | awk -F'\t' '{count[$2]++} END{for (k in count) print count[k], k}' | sort -nr
  echo
  echo "image-like files by top area:"
  tail -n +2 "$MANIFEST" | awk -F'\t' '{count[$3]++} END{for (k in count) print count[k], k}' | sort -nr | sed -n '1,40p'
  echo
  echo "Ghibli / film-name path matches:"
  find "$SOURCE_DIR" -type f \
    | sed "s#^$SOURCE_DIR/##" \
    | rg -i 'ghibli|totoro|howl|spirited|kiki|ponyo|mononoke|nausica|laputa|calcifer|noface|no.face|chihiro' \
    || true
} > "$SUMMARY"

echo "Manifest: $MANIFEST"
echo "Summary:  $SUMMARY"
