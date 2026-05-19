# CozyTime Release Checklist

## Automated Gates

- `swift test` passes the SwiftPM domain tests.
- `xcodebuild -project CozyTime.xcodeproj -scheme CozyTime -destination 'platform=macOS' build` passes.
- `xcodebuild -project CozyTime.xcodeproj -scheme CozyTime -destination 'platform=macOS,arch=arm64' -only-testing:CozyTimeTests test` passes the Xcode unit tests.
- `scripts/run_xcode_release_gate.sh` passes the full Release test plan, including UI tests. Do not waive this for a public release.
- `scripts/package_xcode_unsigned.sh` creates `.build/xcode/CozyTime.xcarchive`, `.build/xcode/CozyTime-unsigned-xcode.zip`, and `/Users/zinklee/Desktop/CozyTime-for-friend.zip` unless `COZYTIME_FRIEND_ZIP_PATH` overrides the friend handoff path.
- If private licensed mascot art is used, keep files under `ThirdPartyLicensed/Ghibli/`, run `scripts/sync_licensed_assets.sh`, verify the generated `mascot.licensed*.imageset` folders are ignored by Git, and select `Private Art` in Settings before packaging.
- `codesign --verify --deep --strict --verbose=2 /Applications/CozyTime.app` passes after local install.
- `spctl --assess --type execute` rejects the app as expected for the private ad-hoc/unsigned release path.
- Optional visual smoke screenshot should confirm the archived app launches and renders the main window.

## Verified Manual Gates On This Machine

- 2026-05-17 package run produced `/Users/zinklee/Desktop/CozyTime.zip` with `COZYTIME_SKIP_RELEASE_GATE=1` because the local XCUITest runner is blocked before app launch while enabling automation mode.
- Desktop ZIP SHA-256: `c947efc3a45577779f15e2a32c3838dda82fb6e333e7626c5e6cb644ec5a98f4`.
- Archived app passed `codesign --verify --deep --strict --verbose=2`.
- `spctl --assess --type execute` rejected the archived app with exit 3, as expected for the private ad-hoc/unsigned release path.
- Archived app launch-smoke test stayed running for 6 seconds and quit cleanly.
- `/Applications` install smoke and clean-user Downloads/Gatekeeper install are not yet re-run for v0.2.1.
- Today screen renders with the Mochi mascot, aligned cards, quick add, progress, countdown, and habit sections.
- Today screen now includes the pet-first hero, daily cozy quests, visible paws/level state, and a desk-room preview.
- Menu bar item appears with the paw/timer icon and active countdown text when a timer is running.
- Xcode unit/migration tests passed on this machine for v0.2.1. Full Release XCUITests are not green yet: the last post-fix targeted UI run failed before executing tests because `CozyTimeUITests-Runner` timed out while enabling automation mode.
- Idle/energy profiling with Instruments is not yet proven for the current build.

## Remaining Local QA Before Handing To Friend

- Run Instruments for cold launch, active timer, menu bar idle, notification flow, memory, and energy.
- Do a manual VoiceOver, keyboard-only, Reduce Motion, Increase Contrast, Light Mode, and Dark Mode pass.
- Verify JSON-to-SwiftData migration with real old sandbox data if the prototype was used heavily.
- Install the generated ZIP on a clean macOS user account from `Downloads`.

## Clean-Mac Gate

- Download the ZIP from the real transfer location so quarantine is preserved.
- Confirm Gatekeeper warning appears for the private ad-hoc-signed, unnotarized build.
- Confirm the documented manual override works.
- Confirm relaunch works without new prompts.
- Confirm local data persists after quit/relaunch.
- Confirm uninstall is clean by deleting `/Applications/CozyTime.app` and, if desired, `~/Library/Application Support/CozyTime` plus any `~/Library/Containers/dev.local.cozytime` folder.
