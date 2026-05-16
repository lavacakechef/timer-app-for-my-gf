# AGENTS.md

## Project

CozyTime is a private native macOS SwiftUI app for one trusted user on an M2 MacBook Air running macOS 15.1. Target macOS 15.0+, Swift 6, local-only data, ad-hoc-signed private ZIP distribution.

## Build Paths

- `Package.swift` is the fast development path. It uses the JSON `AppDataStore` in `Sources/CozyTime/AppDataStore.swift` and runs `CozyCore` tests with `swift test`.
- `CozyTime.xcodeproj` is the release path, generated from `project.yml`. It uses `XcodeSupport/CozyTime/SwiftDataAppDataStore.swift`, asset catalogs, entitlements, unit tests, and UI tests.
- Do not hand-edit `CozyTime.xcodeproj/project.pbxproj`. Edit `project.yml`, then run `scripts/generate_xcode_project.sh`.
- When changing the `AppDataStore` API, keep the SwiftPM JSON store and the Xcode SwiftData store in lock-step.

## Required Checks

Run the smallest relevant gate before reporting completion:

- UI/layout/style changes: `scripts/lint_design.sh`, then `swift build`.
- Domain logic changes in `Sources/CozyCore` or shared model behavior: `swift test`.
- Xcode project, SwiftData, menu bar, notification, packaging, or release changes: `scripts/run_xcode_release_gate.sh` when the local Xcode session is available.
- Final friend-sendable export: `scripts/package_xcode_unsigned.sh`, then copy the resulting ZIP to the Desktop.

If a gate cannot run, say exactly why and do not call the app ready.

## UI And UX Rules

- `docs/DESIGN_RULES.md` is the lintable source of truth for spacing, typography, color, motion, controls, layout, mascot, and economy rules.
- Use `DesignSystem.swift` tokens: `CozyLayout`, `CozyType`, `CozyPalette`, `CozyTheme`, `CozyMotion`, and project wrappers such as `CozyTextInput`, `CozyDateInput`, `CozySegmentedControl`, `CozyToggleRow`, and `CozyFormRow`.
- Do not introduce default SwiftUI controls, raw `.font(.system(...))`, hardcoded `Color.white` / `Color.black` in views, bare `.padding()`, or off-grid point literals outside `DesignSystem.swift`.
- Respect Reduce Motion. Movement animations must go through `CozyMotion` or be explicitly gated by `accessibilityReduceMotion`.
- Favor full-row click targets, visible hover/focus affordances, aligned form rows, stable button sizes, and scannable card hierarchy.

## Product Rules

- The mascot is cute and gentle. Avoid punitive copy, streak panic, guilt language, or sad failure states.
- Progression is additive only. Do not subtract XP or remove earned coins except when the user explicitly spends available paws/coins on a shop item.
- Focus sessions, rewards, and diary/calendar history should stay connected as one loop: start focus, earn progress, save session, see it in stats/calendar/menu bar.

## Codex Guardrails

- Repo-local Codex skill: `.agents/skills/cozytime-swift-ui-audit/SKILL.md`.
- Repo-local Codex Stop hook: `.codex/hooks.json` runs `.codex/hooks/stop_quality_gate.py` after a turn when trusted by Codex. Use `/hooks` in Codex to inspect and trust it.
- Hooks are guardrails, not the only enforcement. Keep `scripts/lint_design.sh`, Swift tests, Xcode tests, and packaging scripts passing.
