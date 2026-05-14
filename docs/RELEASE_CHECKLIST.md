# CozyTime Release Checklist

## Automated Gates

- `swift test` passes the SwiftPM domain tests.
- `xcodebuild -project CozyTime.xcodeproj -scheme CozyTime -destination 'platform=macOS' build` passes.
- `xcodebuild -project CozyTime.xcodeproj -scheme CozyTime -destination 'platform=macOS,arch=arm64' -only-testing:CozyTimeTests test` passes the Xcode unit tests.
- `scripts/run_xcode_release_gate.sh` passes the full Release test plan, including UI tests. Do not waive this for a public release.
- `scripts/package_xcode_unsigned.sh` creates `.build/xcode/CozyTime.xcarchive` and `.build/xcode/CozyTime-unsigned-xcode.zip`.
- `codesign --verify --deep --strict --verbose=2 /Applications/CozyTime.app` passes after local install.
- `spctl --assess --type execute` rejects the app as expected for the private ad-hoc/unsigned release path.
- Optional visual smoke screenshot should confirm the archived app launches and renders the main window.

## Verified Manual Gates On This Machine

- Launches from `/Applications/CozyTime.app`.
- Today screen renders with the Mochi mascot, aligned cards, quick add, progress, countdown, and habit sections.
- Today screen now includes the pet-first hero, daily cozy quests, visible paws/level state, and a desk-room preview.
- Menu bar item appears with the paw/timer icon and active countdown text when a timer is running.
- Release XCUITests passed on this machine for first launch, quick add, focus lifecycle, countdown creation, habit completion, settings persistence, reward claim, stats/calendar diary, reflection persistence, and an accessibility audit smoke test.
- Idle/energy profiling with Instruments is not yet proven for the current build.

## Remaining Local QA Before Handing To Friend

- Run Instruments for cold launch, active timer, menu bar idle, notification flow, memory, and energy.
- Do a manual VoiceOver, keyboard-only, Reduce Motion, Increase Contrast, Light Mode, and Dark Mode pass.
- Verify JSON-to-SwiftData migration with real old sandbox data if the prototype was used heavily.
- Install the generated ZIP on a clean macOS user account from `Downloads`.

## Clean-Mac Gate

- Download the ZIP from the real transfer location so quarantine is preserved.
- Confirm Gatekeeper warning appears for unsigned build.
- Confirm the documented manual override works.
- Confirm relaunch works without new prompts.
- Confirm local data persists after quit/relaunch.
- Confirm uninstall is clean by deleting `/Applications/CozyTime.app` and, if desired, `~/Library/Application Support/CozyTime` plus any `~/Library/Containers/dev.local.cozytime` folder.
