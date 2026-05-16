---
name: cozytime-swift-ui-audit
description: Use when editing or auditing CozyTime SwiftUI/macOS UI, layout, menu bar, timer flows, mascot/reward UX, persistence logic, or release readiness. Run repo gates, inspect screenshots where possible, and verify Swift/macOS behavior instead of handwaving.
---

# CozyTime Swift UI Audit

Use this skill for CozyTime app work that touches SwiftUI views, menu bar behavior, timer/countdown/habit/task flows, progression, persistence, packaging, or release readiness.

## Workflow

1. Read the actual files before making claims.
   - Use `rg --files` and `rg`.
   - For large Swift files, run `wc -l` first, then read deliberate ranges.

2. Identify the touched surface.
   - UI/layout/style: `Sources/CozyTime/*Views.swift`, `RootView.swift`, `CozyTimeApp.swift`, `DesignSystem.swift`.
   - Logic/domain: `Sources/CozyCore/`.
   - Persistence: `Sources/CozyTime/AppDataStore.swift` and `XcodeSupport/CozyTime/SwiftDataAppDataStore.swift`.
   - Release/Xcode: `project.yml`, `CozyTime.xcodeproj`, `XcodeTests/`, `scripts/package_xcode_unsigned.sh`.

3. Enforce design system first.
   - Use `docs/DESIGN_RULES.md` and `scripts/lint_design.sh`.
   - Replace raw fonts with `CozyType`.
   - Replace raw colors with `CozyPalette` or `CozyTheme`.
   - Replace default controls with project wrappers.
   - Use `CozyFormRow` for multi-column forms.
   - Gate animations with `CozyMotion` or `accessibilityReduceMotion`.

4. Verify flow wiring.
   - Focus start/pause/complete/save session.
   - Menu bar quick add, active timer text, save reward flow, today summary.
   - Countdown create/edit/delete/prep/reset task.
   - Task add/edit/delete/complete/focus-from-task.
   - Habit toggle/delete/streak.
   - Rewards, shop purchase, mascot/timer customization, settings persistence.

5. Run checks.
   - UI/style change: `scripts/lint_design.sh` and `swift build`.
   - Logic/model change: `swift test`.
   - Release/Xcode change: `scripts/run_xcode_release_gate.sh` if Xcode automation is available.
   - Packaging/export: `scripts/package_xcode_unsigned.sh`.

6. Report honestly.
   - State exact commands run and pass/fail.
   - If screenshots, XCUITest, Instruments, Gatekeeper, or clean-user install were not run, say so explicitly.
   - Do not call the app ready unless the relevant gate passed.

## UX Bar

- The first action should be obvious within a few seconds.
- Whole cards/buttons should be clickable, not just text.
- Columns and controls should align on a stable grid.
- Text fields/date fields/buttons should look custom and integrated, not default AppKit.
- Menu bar should be useful: active timer, quick add, today progress, session diary, and open-app actions.
- Mascot/reward interactions should be cute but restrained, with non-punitive copy and Reduce Motion fallbacks.
