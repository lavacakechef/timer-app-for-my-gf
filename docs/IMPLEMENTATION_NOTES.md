# CozyTime Implementation Notes

## Current Build

This workspace now builds CozyTime through full Xcode and still keeps the SwiftPM path as a fallback for fast domain checks.

Verified on 2026-05-17 with Xcode 26.5 (build 17F42):

- `scripts/lint_design.sh`: passes the lintable UI/design rules in `docs/DESIGN_RULES.md`.
- `swift build`: passes the SwiftPM app build.
- `swift test`: passes 27 SwiftPM domain tests.
- `xcodebuild -project CozyTime.xcodeproj -scheme CozyTime -destination 'platform=macOS' -testPlan Release -only-testing:CozyTimeTests test`: passes 52 Xcode unit and SwiftData migration tests.
- `scripts/run_xcode_release_gate.sh`: still runs design lint first, but the full Release test plan is not green yet. The latest post-fix targeted UI rerun failed before executing tests because `CozyTimeUITests-Runner` timed out while enabling automation mode.
- Intended XCUITest flow coverage includes first launch, first-session task creation, focus start/pause/stop, countdown creation, compact/wide countdown composer layout, habit creation/toggle, settings edit, reward claim, shop, stats, calendar diary, reflection persistence, and accessibility audit smoke coverage.
- `COZYTIME_SKIP_RELEASE_GATE=1 COZYTIME_FRIEND_ZIP_PATH="$HOME/Desktop/CozyTime.zip" scripts/package_xcode_unsigned.sh`: creates the Xcode archive, verifies codesign, omits AppleDouble sidecar files from the ZIP, and writes the private ad-hoc-signed ZIP while the UI-test runner blocker is unresolved.
- Packaged artifact copied for handoff: `/Users/zinklee/Desktop/CozyTime.zip`.
- Current Desktop ZIP SHA-256: `c947efc3a45577779f15e2a32c3838dda82fb6e333e7626c5e6cb644ec5a98f4`.
- `spctl --assess --type execute` rejects the archived app with exit 3, which is expected for this private ad-hoc-signed build and is covered by `docs/INSTALL.md`.
- The archived app launch-smoke test stayed running for 6 seconds and quit cleanly.
- `/Applications` install smoke, Instruments profiling, and clean-user Downloads/Gatekeeper install still need to be re-run for v0.2.1 before calling it fully release-gated.

The production app target uses SwiftData as the primary local store. The app is **not** sandboxed (`Packaging/CozyTime.entitlements` is empty by design), so data lives directly under `~/Library/Application Support/CozyTime/`. On first launch, if the SwiftData store is empty, it migrates once from the older JSON prototype store at:

`~/Library/Application Support/CozyTime/CozyTimeData.json`

A `~/Library/Containers/dev.local.cozytime/` directory may exist as leftover data from an earlier sandboxed prototype build; the current target does not read or write it.

The SwiftPM fallback target writes the same JSON path so the reusable domain layer can be checked outside Xcode:

```bash
swift test
```

## Build And Release Path

1. Confirm full Xcode is selected:

```bash
xcodebuild -version
```

2. Regenerate the Xcode project after `project.yml` changes:

```bash
scripts/generate_xcode_project.sh
```

3. Run the release gate:

```bash
scripts/run_xcode_release_gate.sh
```

4. Package the ad-hoc-signed Xcode archive:

```bash
scripts/package_xcode_unsigned.sh
```

5. Use Xcode Instruments for deeper launch, memory, and energy profiling before giving the app to more than one private tester.
6. If you want smooth install UX, enroll in Apple Developer Program and ship a Developer ID notarized DMG.

## Codex And Claude Guardrails

- `AGENTS.md` is the Codex project instruction file. It tells Codex which Swift, Xcode, design, and release gates must run for each class of change.
- `.agents/skills/cozytime-swift-ui-audit/SKILL.md` is a repo-local Codex skill for SwiftUI layout, menu bar, persistence, reward-loop, and release-readiness audits.
- `.codex/hooks.json` registers a Codex `Stop` hook that runs `.codex/hooks/stop_quality_gate.py` after a turn when the repo-local hook has been trusted with `/hooks`.
- `.claude/settings.json` keeps the Claude PostToolUse design-lint guardrail.
- Hooks are guardrails, not the only enforcement. `scripts/lint_design.sh`, `swift test`, the Xcode Release test plan, and packaging verification remain the release source of truth.

## Xcode Target Layout

- `CozyCore`: framework target using the existing reusable domain code.
- `CozyTime`: macOS SwiftUI app target.
- `CozyTimeTests`: unit tests, including SwiftData migration from the current JSON store.
- `CozyTimeUITests`: first-launch workflow, countdown/habit/settings flow, focus reward/stats/calendar flow, and accessibility audit smoke tests.

The SwiftPM target still uses `Sources/CozyTime/AppDataStore.swift` for JSON persistence. The Xcode target excludes that file and instead uses `XcodeSupport/CozyTime/SwiftDataAppDataStore.swift`, which provides the same `AppDataStore` API backed by SwiftData.

## Mascot assets and attribution

The picker now ships 10 fully-animated mascot characters. Two come from prior work — Mochi (Pancake the Shiba Inu) under the LottieFiles Simple License, and Biscuit (the Cativity productivity cat) under MIT. The remaining eight (Tofu, Bao, Bramble, Pip, Yolk, Soba, Hazel, Acorn) are pulled from the Google Noto Animated Emoji project and are licensed under CC-BY 4.0. The full per-file attribution lives in `Sources/CozyTime/Resources/Mascot/LICENSE.txt`; the short form for in-app credits / About is:

> Animated emoji by Google (Tofu, Bao, Bramble, Pip, Yolk, Soba, Hazel, Acorn) licensed CC-BY 4.0 — https://github.com/googlefonts/noto-emoji. Mochi by AnnaTalipova (LottieFiles Simple License). Biscuit / Cativity cat (MIT).

To resync the Noto JSONs from upstream (idempotent, retries once per file, never blocks on a single failure):

```bash
bash scripts/fetch_mascot_lotties.sh
```

The Noto emojis only ship a single idle loop per character, so every CozyTime mascot state resolves to `{character}-idle.json` for them — state distinction comes from the surrounding tint and accessory layer in `MascotView`.

## Known limitations (intentionally accepted)

### Habit weekly counts follow the system locale

`Sources/CozyCore/HabitMath.swift` and `Sources/CozyCore/DateHelpers.swift` use `Calendar.autoupdatingCurrent`, so the boundary of "this week" depends on the user's current locale. If the user travels across timezones or changes their system language between a region with Sunday-first weeks (e.g. en_US) and one with Monday-first weeks (e.g. de_DE), completions logged near a week boundary can appear to shift between "this week" and "last week." This is intentional: it keeps the displayed week consistent with the rest of the user's macOS calendar UI. Habit completions themselves are stored as day keys and never lost — only the bucketing into "this week" changes. Do not refactor to ISO-8601 without explicit user agreement.

### Deployment target locks the app to macOS 15+

`project.yml` and both `Info.plist` files declare `LSMinimumSystemVersion = 15.0` and `MACOSX_DEPLOYMENT_TARGET = 15.0`. The SwiftPM `Package.swift` declares `.macOS(.v15)`. The single intended user runs macOS 15.1 on an M2 MacBook Air. Code is free to call macOS 15-only APIs (`MenuBarExtra`, `windowResizability`, `interruptionLevel`, Writing Tools, etc.) without availability fences. If you ever need to support macOS 14 again, restore the previous deployment targets and add `@available(macOS 15, *)` fences.
