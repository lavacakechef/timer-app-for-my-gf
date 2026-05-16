#!/usr/bin/env bash
# scripts/fetch_mascot_lotties.sh
# ------------------------------------------------------------------
# Downloads the 8 Google Noto Animated Emoji Lottie JSONs that back the
# extended CozyTime mascot lineup (tofu / bao / bramble / pip / yolk /
# soba / hazel / acorn). Each file is licensed CC-BY 4.0 — see
# Sources/CozyTime/Resources/Mascot/LICENSE.txt and
# docs/IMPLEMENTATION_NOTES.md for attribution.
#
# Idempotent: skips a name when the local file already exists and is
# non-empty. Retries each failed download once, then continues so a
# single network blip never blocks the whole sync. The script reports
# any names that did not land so the caller can decide what to do.
#
# Usage:
#   bash scripts/fetch_mascot_lotties.sh
# ------------------------------------------------------------------
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="$REPO_ROOT/Sources/CozyTime/Resources/Mascot"
mkdir -p "$DEST_DIR"

# name|codepoint pairs (Google Noto Animated Emoji)
ENTRIES=(
  "tofu|1f431"
  "bao|1f43c"
  "bramble|1f43b"
  "pip|1f424"
  "yolk|1f425"
  "soba|1f438"
  "hazel|1f98a"
  "acorn|1f9a6"
)

URL_TEMPLATE="https://fonts.gstatic.com/s/e/notoemoji/latest/%s/lottie.json"

FAILED=()

download_one() {
  local name="$1" codepoint="$2"
  local url; url="$(printf "$URL_TEMPLATE" "$codepoint")"
  local out="$DEST_DIR/${name}-idle.json"

  if [[ -s "$out" ]]; then
    echo "ok    : ${name}-idle.json (already present)"
    return 0
  fi

  local tmp="${out}.tmp"
  if curl --fail --silent --show-error --location \
          --max-time 30 \
          --output "$tmp" "$url"; then
    if [[ -s "$tmp" ]]; then
      mv "$tmp" "$out"
      echo "ok    : ${name}-idle.json"
      return 0
    fi
  fi
  rm -f "$tmp"
  return 1
}

for entry in "${ENTRIES[@]}"; do
  name="${entry%%|*}"
  codepoint="${entry##*|}"
  if ! download_one "$name" "$codepoint"; then
    echo "retry : ${name}-idle.json"
    if ! download_one "$name" "$codepoint"; then
      echo "fail  : ${name}-idle.json (skipped after retry)"
      FAILED+=("$name")
    fi
  fi
done

if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo
  echo "Some Noto Lotties did not download: ${FAILED[*]}"
  echo "App will fall back to the SF Symbol tile for those mascots."
  exit 0
fi

echo
echo "All 8 Noto mascot Lotties present in $DEST_DIR"
