# CozyTime

CozyTime is a private native macOS productivity app built for a local-only TickTick-style workflow with a softer, cuter focus loop.

It includes tasks, countdowns, focus sessions, habits, stats, rewards, mascot customization, SwiftData storage, and an AppKit menu bar companion.

## Requirements

- macOS 14+
- Full Xcode selected with `xcode-select`
- XcodeGen only if regenerating `CozyTime.xcodeproj` from `project.yml`

## Project Layout

- `CozyTime.xcodeproj`: full Xcode macOS app project.
- `Sources/CozyCore`: reusable domain logic.
- `Sources/CozyTime`: SwiftUI app shell, views, timer store, commands, menu bar controller, and JSON fallback store for SwiftPM checks.
- `XcodeSupport/CozyTime`: Xcode-only SwiftData store, app plist, colors, icons, mascot art, and sticker/timer assets.
- `Tests/CozyCoreTests`: SwiftPM domain tests.
- `XcodeTests`: Xcode unit and UI tests.
- `docs`: install, release, design-system, and implementation notes.

## Verification

Run the lightweight domain suite:

```bash
swift test
```

Run the full Xcode release gate:

```bash
scripts/run_xcode_release_gate.sh
```

Build the private unsigned ZIP:

```bash
scripts/package_xcode_unsigned.sh
```

The package script runs the release gate by default, then archives and writes:

```text
.build/xcode/CozyTime-unsigned-xcode.zip
```

## Distribution

The current release path is private, ad-hoc signed, and unsigned/not notarized for public distribution. macOS can show a Gatekeeper warning on first launch. See `docs/INSTALL.md` for the manual trust flow.

For a polished public-style install, use Apple Developer Program, Developer ID signing, hardened runtime, notarization, and a stapled DMG.
