# CozyTime Implementation Notes

## Current Build

This workspace now builds CozyTime through full Xcode and still keeps the SwiftPM path as a fallback for fast domain checks.

Verified on 2026-05-14 with Xcode 26.5:

- `swift test`: passes 24 SwiftPM domain tests.
- `xcodebuild -project CozyTime.xcodeproj -scheme CozyTime -destination 'platform=macOS,arch=arm64' -only-testing:CozyTimeTests test`: passes 40 Xcode unit tests.
- `scripts/run_xcode_release_gate.sh`: passes the full Release test plan, including 40 Xcode unit tests and 4 XCUITests.
- XCUITest flow coverage includes first launch, quick add, focus start/pause/stop, countdown creation, habit creation/toggle, settings edit, reward claim, shop, stats, calendar diary, reflection persistence, and accessibility audit smoke coverage.
- `scripts/package_xcode_unsigned.sh`: runs the release gate by default, creates the Xcode archive, verifies codesign, and writes the unsigned private ZIP.
- Archived app: launches and renders the main CozyTime window in a local visual smoke check.

The production app target uses SwiftData as the primary local store. It migrates once from the older JSON prototype store when the SwiftData store is empty:

`~/Library/Containers/dev.local.cozytime/Data/Library/Application Support/CozyTime/CozyTimeData.json`

The SwiftPM fallback target still uses the JSON store so the reusable domain layer can be checked outside Xcode:

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

4. Package the unsigned Xcode archive:

```bash
scripts/package_xcode_unsigned.sh
```

5. Use Xcode Instruments for deeper launch, memory, and energy profiling before giving the app to more than one private tester.
6. If you want smooth install UX, enroll in Apple Developer Program and ship a Developer ID notarized DMG.

## Xcode Target Layout

- `CozyCore`: framework target using the existing reusable domain code.
- `CozyTime`: macOS SwiftUI app target.
- `CozyTimeTests`: unit tests, including SwiftData migration from the current JSON store.
- `CozyTimeUITests`: first-launch workflow, countdown/habit/settings flow, focus reward/stats/calendar flow, and accessibility audit smoke tests.

The SwiftPM target still uses `Sources/CozyTime/AppDataStore.swift` for JSON persistence. The Xcode target excludes that file and instead uses `XcodeSupport/CozyTime/SwiftDataAppDataStore.swift`, which provides the same `AppDataStore` API backed by SwiftData.
