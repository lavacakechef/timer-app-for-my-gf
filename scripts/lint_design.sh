#!/usr/bin/env bash
# scripts/lint_design.sh — enforce docs/DESIGN_RULES.md.
# Usage: scripts/lint_design.sh [paths…]  (defaults to Sources/CozyTime)
# Exits non-zero on any rule violation so CI / pre-commit / Claude Code
# PreToolUse hooks can block. Each finding is prefixed with its rule ID
# (e.g. "SP-001  …") so you can `grep ^SP-` to scope.
#
# Uses ripgrep if available (faster, better regex), falls back to POSIX
# `grep -rEn` so it works in stripped non-interactive shells (CI / pre-commit
# / Claude Code hooks) where `rg` may not be on PATH.

set -uo pipefail
ROOT="${1:-Sources/CozyTime}"
FAIL=0

# Resolve ripgrep — interactive shells may shadow `rg` with a function;
# binary install via Homebrew lands at /opt/homebrew/bin/rg on Apple Silicon.
if [[ -x /opt/homebrew/bin/rg ]]; then
  RG=/opt/homebrew/bin/rg
elif command -v rg >/dev/null 2>&1 && rg --version >/dev/null 2>&1; then
  RG=rg
else
  RG=""
fi

# usage: search PATTERN  — emits matching lines, respecting RG availability.
search() {
  local pattern="$1"
  if [[ -n "$RG" ]]; then
    "$RG" -n --glob '*.swift' --glob '!**/DesignSystem.swift' "$pattern" "$ROOT" 2>/dev/null || true
  else
    grep -rEn --include='*.swift' --exclude=DesignSystem.swift "$pattern" "$ROOT" 2>/dev/null || true
  fi
}

# usage: run ID DESC PATTERN
run() {
  local id="$1" desc="$2" pattern="$3"
  local out; out="$(search "$pattern")"
  if [[ -n "$out" ]]; then
    echo "── $id  $desc ──"
    echo "$out" | sed "s/^/$id  /"
    echo
    FAIL=1
  fi
}

# usage: run_excl ID DESC PATTERN EXCLUDE_PATTERN
run_excl() {
  local id="$1" desc="$2" pattern="$3" exclude="$4"
  local out; out="$(search "$pattern" | grep -Ev "$exclude" || true)"
  if [[ -n "$out" ]]; then
    echo "── $id  $desc ──"
    echo "$out" | sed "s/^/$id  /"
    echo
    FAIL=1
  fi
}

# 1. Spacing & grid
# SP-001: any padding / frame / offset / spacing / cornerRadius literal not on
# the allowed grid {0,2,4,8,12,16,20,24,28,32,40,48,56,64}. We ban a fixed
# list of off-grid integers under 40.
run "SP-001" "Off-grid point literal (allowed grid: 2/4/8/12/16/20/24/28/32/40/48/56/64)" \
  '\.(padding|frame|offset|spacing|cornerRadius)\([^)]*(\b(1|3|5|6|7|9|10|11|13|14|15|17|18|19|21|22|23|25|26|27|29|30|31|33|34|35|36|37|38|39))\b'

run "SP-002" "Bare .padding() with no argument" \
  '\.padding\(\)'

run "SP-003" "RoundedRectangle without CozyLayout.cardRadius" \
  'RoundedRectangle\(cornerRadius: *(1[346-9]|[2-9])\b'

# 2. Typography & color
run "TC-001" '.font(.system(…)) instead of CozyType token' \
  '\.font\(\.system\('

# TC-002: hardcoded literal colors. Shadow callsites with Color.black are OK,
# so we exclude lines containing ".shadow(color:".
run_excl "TC-002" "Hardcoded Color.white / .black / Color(red:) / Color(hex:) in views" \
  '\b(Color\.white|Color\.black|Color\(red:|Color\(hex:)' \
  '\.shadow\(color:'

# 3. Controls
run "CT-002" "Banned DatePicker(.graphical) outside DesignSystem" \
  'datePickerStyle\(\.graphical\)'

run "CT-003" "Raw Toggle / Picker / Stepper without project wrapper" \
  '^ *(Toggle|Picker|Stepper)\('

# 4. Layout — heuristic (manual review on hits)
# LA-002: this is approximate. Catches "HStack { ... CozyLabeledControl ...
# CozyLabeledControl" on a single logical block. With grep we can only flag
# files containing 2+ CozyLabeledControl in close proximity.
run "LA-002" "Two+ CozyLabeledControl in raw HStack (use CozyFormRow)" \
  'HStack.*CozyLabeledControl'

# 5. Motion & a11y
# AM-001: animation not gated on reduceMotion. Heuristic; some sites already
# read reduceMotion on the same line, this regex picks up the lazy callsites.
run_excl "AM-001" "Animation not gated on reduceMotion / CozyMotion" \
  '(withAnimation\(|\.animation\()' \
  'reduceMotion|CozyMotion'

run "AM-001b" "Banned movement transition (use .opacity instead)" \
  '\.transition\(\.(move|scale|slide|offset)'

# 6. Mascot
run "MD-003" "Punitive mascot copy" \
  '(you failed|broke the chain|streak.*dying|slacking|gave up)'

# 8. Economy
run "EC-001" "XP / coin subtraction (additive-only rule)" \
  '\b(xp|pawCoins|coins) *-='

if [[ $FAIL -ne 0 ]]; then
  echo "─────────────────────────────────────────────────────────────"
  echo "Design lint failed. See docs/DESIGN_RULES.md for rule definitions."
  echo "─────────────────────────────────────────────────────────────"
  exit 1
fi
echo "Design lint clean ✓"
