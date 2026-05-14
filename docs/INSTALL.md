# CozyTime Private Install

This is a private unsigned macOS build. It is intended for one trusted person, not public distribution.

## Install

1. Unzip `CozyTime-unsigned-xcode.zip`.
2. Drag `CozyTime.app` to `/Applications`.
3. If macOS blocks the app, use one of Apple’s manual trust flows:
   - Control-click `CozyTime.app`, choose `Open`, then confirm.
   - Or open System Settings > Privacy & Security and choose `Open Anyway` after the first failed launch.

## Uninstall

1. Quit CozyTime from the app menu or menu bar.
2. Delete `/Applications/CozyTime.app`.
3. Optional data reset: delete `~/Library/Application Support/CozyTime` and, if present from a sandboxed build, `~/Library/Containers/dev.local.cozytime`.

## Better install UX later

For a non-scary install flow, enroll in the Apple Developer Program, sign with Developer ID, notarize, staple, and distribute a DMG.
