# CozyTime Private Install

This is a private ad-hoc-signed macOS build. It requires **macOS 15.0 Sequoia or later** and is tested for the recipient on **macOS 15.1**, not public distribution.

## Install

1. Download `CozyTime-for-friend.zip` from where it was sent to you. Save it to **Downloads** so macOS preserves the quarantine attribute (AirDrop works too).
2. Double-click the ZIP to unpack `CozyTime.app`.
3. Drag `CozyTime.app` into `/Applications`.
4. Double-click `CozyTime.app`. macOS will show a dialog: **"Apple cannot check it for malicious software"** (or similar). Click **Done** to dismiss.
5. Open **System Settings → Privacy & Security**. Scroll down to the **Security** section. You should see a line:
   > *"CozyTime" was blocked to protect your Mac.*

   Click **Open Anyway** next to it. macOS asks for your Touch ID or password to confirm. Approve it.
6. Double-click `CozyTime.app` again. This time you'll get a smaller dialog confirming you really want to open it — click **Open**.
7. CozyTime launches. Subsequent launches do not show any warning.

> **Note on macOS 15:** Apple removed the older "control-click → Open" contextual menu shortcut for unsigned apps in macOS 15 Sequoia. The path above (System Settings → Open Anyway) is the only supported way in.

## Troubleshooting

If macOS says the app is not verified and will be moved to Trash, or if `Open Anyway` does not appear after step 6, open **Terminal** (Applications → Utilities → Terminal) and paste:

```bash
xattr -dr com.apple.quarantine /Applications/CozyTime.app
```

Hit Return. Then try opening CozyTime again. (`xattr` removes the macOS download quarantine flag recursively from the app bundle so Gatekeeper stops blocking the launch. The app is still ad-hoc signed, so codesign verification still applies.)

## Allow notifications

On first launch CozyTime will ask permission to send notifications. Click **Allow** so timer-completion alerts can interrupt Focus mode (CozyTime marks timer completions as time-sensitive — they break through Do Not Disturb).

## Find CozyTime in the menu bar

After launch you should see a tiny paw icon in your menu bar (top of the screen). When a focus timer is running, the icon shows the remaining time next to it. Click it for the quick popover; double-click the app icon in the Dock to bring back the main window.

## Uninstall

1. Quit CozyTime from the app menu or the menu bar (right-click the paw → Quit).
2. Delete `/Applications/CozyTime.app`.
3. Optional full data reset: delete `~/Library/Application Support/CozyTime` and `~/Library/Preferences/dev.local.cozytime.plist`. If you ever used a sandboxed prototype build, also delete `~/Library/Containers/dev.local.cozytime`.

## Better install UX later

For a one-click install with no security dialogs, the developer would need to enroll in the Apple Developer Program, sign with a Developer ID certificate, notarize, staple, and distribute a DMG. Not in scope for this private build.
