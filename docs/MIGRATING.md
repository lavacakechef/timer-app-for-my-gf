# Migrating to a new CozyTime build

This is a private ad-hoc-signed app. Every new build has a different code-signing
hash, but it keeps the same bundle identifier (`dev.local.cozytime`) and the same
on-disk layout. That means your data lives **outside** the app bundle and survives
replacement of `CozyTime.app` in `/Applications`.

Target system: macOS 15.0+ (Sequoia). M2 MacBook Air.

## TL;DR

1. Back up `~/Library/Application Support/CozyTime/` first. Always.
2. Quit the running CozyTime (right-click the menu bar paw -> Quit).
3. Drag the new `CozyTime.app` into `/Applications`, choose **Replace**.
4. First launch: Gatekeeper will show "Apple cannot verify". Go to
   System Settings -> Privacy & Security -> Open Anyway.
5. Verify tasks, focus history, habits, unlocks, mascot name, and theme are intact.
6. Re-grant notification permission if macOS prompts again (it usually does not).

## Why your data persists

CozyTime stores everything user-visible **outside** the app bundle, in two well-known
per-user locations:

- `~/Library/Application Support/CozyTime/CozyTime.store` (SwiftData / SQLite trio:
  `.store`, `.store-wal`, `.store-shm`). Tasks, focus sessions, countdowns, habits,
  rewards, unlocks.
- `~/Library/Preferences/dev.local.cozytime.plist` (UserDefaults). Mascot name,
  theme, `hasCompletedFirstRun`, last-used focus duration, notification cadence
  preferences.

Replacing `/Applications/CozyTime.app` does not touch either of those paths.
Apple's own File System Programming Guide says support files belong in
Application Support precisely because they are owned by the app's data, not its
binary. UserDefaults plists are filed under the **bundle identifier**, not the
code-signing hash, so a rebuild with the same bundle ID reads the same plist.

## What can re-prompt

These are the only things that may ask again after a fresh build, because macOS
TCC validates each entry against a code-signing requirement, and the cdhash of an
ad-hoc-signed app changes every build:

- **Notification permission** (UserNotifications). In practice macOS Sequoia tends
  to remember this by bundle ID for non-sandboxed apps, but the system is allowed
  to re-evaluate. If you don't see notifications, open System Settings ->
  Notifications -> CozyTime and re-enable. UNVERIFIED for ad-hoc signed apps on
  15.1 specifically.
- **Gatekeeper "Open Anyway"**. The new ZIP carries a fresh `com.apple.quarantine`
  extended attribute. macOS treats it as a never-seen-before file and will block
  the first launch until you confirm in Privacy & Security.
- **TCC entries (Accessibility, Automation, Screen Recording, etc.)**. CozyTime
  currently does not request any of these, so this is a non-issue today. If a
  future build did request them, expect a re-prompt because TCC's `csreq` blob
  pins entries to a designated requirement that an ad-hoc rebuild does not satisfy.

## Step-by-step

### 1. Back up data

```bash
cp -R ~/Library/Application\ Support/CozyTime ~/Desktop/CozyTime-backup-$(date +%Y%m%d)
cp ~/Library/Preferences/dev.local.cozytime.plist ~/Desktop/CozyTime-prefs-$(date +%Y%m%d).plist
```

If anything goes wrong, dragging those back into the same locations restores you
to before the upgrade.

### 2. Quit the running app

- Right-click the paw icon in the menu bar -> Quit.
- Or Cmd-Q from the CozyTime app menu.

Replacing a running app's bundle is supported by Finder but unhelpful: the running
process keeps the old binary mapped, and SwiftData may not flush its WAL cleanly.
Quit first.

### 3. Install the new build

1. Open the ZIP from your Downloads folder (keep it there so macOS preserves the
   `com.apple.quarantine` attribute -- removing it manually would skip the first-run
   Gatekeeper check, which is fine but means no chance to verify the new bundle).
2. Drag the unpacked `CozyTime.app` into `/Applications`. Finder will ask:
   "An item named CozyTime.app already exists. Do you want to replace it?" -> **Replace**.

### 4. First launch (Gatekeeper)

Double-click `CozyTime.app`. macOS will show:

> "CozyTime" cannot be opened because Apple cannot check it for malicious software.

Click **Done**. Then:

1. Open **System Settings -> Privacy & Security**.
2. Scroll to the Security section.
3. Click **Open Anyway** next to the CozyTime line.
4. Authenticate with Touch ID or password.
5. Double-click `CozyTime.app` again. Confirm **Open** in the smaller dialog.

If `Open Anyway` does not appear (rare on Sequoia), Terminal escape hatch:

```bash
xattr -d com.apple.quarantine /Applications/CozyTime.app
```

### 5. Verify data

After launch, check:

- Today view shows the same daily task count.
- Focus history (Stats tab) shows previous sessions.
- Habits show their existing completion grid.
- Reward Album shows previously unlocked items, mascot still equipped.
- Mascot name and selected theme are unchanged.
- Menu bar paw is back and the focus timer popover works.

If any of these are blank, **quit immediately** and restore from the backup you
made in step 1. Do not start a new focus session on top of empty state -- that
will create new SwiftData rows and complicate restoring.

### 6. Re-grant notifications if needed

Start a 1-minute focus timer. If completion doesn't fire a banner:

- System Settings -> Notifications -> CozyTime -> Allow Notifications **on**.
- Allow **Time Sensitive Notifications** (CozyTime marks timer-completion alerts
  time-sensitive so they break through Focus / Do Not Disturb).

## SwiftData schema changes

The store file uses SwiftData's automatic lightweight migration. That covers:

- **Identical schema** (most builds): instant, no migration needed.
- **Adding a new optional property** (default `nil`): automatic. Old rows simply
  have `nil` for the new field.
- **Renaming a property** annotated with `@Attribute(originalName: "...")`:
  automatic.

Anything beyond that (changing a relationship's cardinality, splitting a model,
required non-nullable additions without a default) needs an explicit
`VersionedSchema` + `SchemaMigrationPlan` in the source. The packaging script's
release gate runs the migration tests in `XcodeTests/CozyTimeTests/SwiftDataMigrationTests.swift`
before producing a ZIP, so a build that breaks the schema should not reach you.

## Rolling back

If a new build misbehaves:

1. Quit CozyTime.
2. Drag the old `CozyTime.app` (keep a copy of each ZIP) back into `/Applications`.
3. If you suspect data corruption, restore the `Application Support/CozyTime`
   backup from step 1.
4. Launch the old build. Gatekeeper may or may not re-prompt depending on whether
   the old bundle's quarantine attribute was previously cleared.

## What never carries forward

These reset on bundle replacement and that is expected:

- The app's bundle code signature (always re-evaluated).
- The Gatekeeper "this is a downloaded file" approval (the new ZIP brings a new
  quarantine attribute).
- Crash report routing (each unique cdhash gets fresh log entries in
  `~/Library/Logs/DiagnosticReports/`).

The cdhash change is also why TCC permissions could theoretically reset. CozyTime
asks for none of them today, so this is informational, not a real cost.

## Pre-upgrade auto-backup (recommended)

The single biggest reliability hole in the manual-ZIP upgrade flow is that
**the user has to remember step 1** ("back up `~/Library/Application Support/
CozyTime/` first"). When they forget — and a future SwiftData migration
mishandles a row — there is no rollback path, because the new build has
already rewritten the store in place.

Fix: the *currently installed* build (not the new one) should produce a
backup snapshot of its data directory once a day, automatically, in a
location the user can find from Finder without instruction. Time Machine's
philosophy is the model here: backups should be invisible until the moment
you need one. The next CozyTime build that the user installs can then point
the migration-failure banner at that folder.

### Storage location

- **Destination**: `~/Documents/CozyTime Backups/` (lives in the user's home,
  iCloud-syncable if they want, survives `/Applications/` replacement).
- **Filename**: `CozyTime-YYYY-MM-DD.zip` (one per calendar day, overwrites
  itself if run twice the same day).
- **Retention**: keep the most recent 14 files, delete older ones.
- **What gets archived**: the entire `~/Library/Application Support/CozyTime/`
  directory (SwiftData store + WAL + SHM files), plus a copy of
  `~/Library/Preferences/dev.local.cozytime.plist`.

### When to run

- On `applicationDidFinishLaunching`, **after** SwiftData has successfully
  opened the store (so we never archive a half-written file).
- On `applicationWillTerminate` (best-effort, dispatch with a 2s deadline so
  we don't block quit).
- Skip the run if today's backup file already exists. This makes the backup
  effectively daily without scheduling timers.

### Reference implementation

`FileManager` ships an archive helper since macOS 13 — `FileManager`'s
`zipItem` does not exist, but the older `NSFileCoordinator` plus
Foundation's `Archive` API in `AppleArchive.framework` does. The simplest
zero-dependency option on macOS 15 is to shell out to `/usr/bin/ditto`,
which has been the Apple-recommended way to create a Finder-compatible zip
since 10.5 and preserves extended attributes. CozyTime is not sandboxed
(see `Packaging/CozyTime.entitlements`), so `Process` is available.

```swift
import Foundation

/// Writes a daily snapshot of CozyTime's data directory to
/// ~/Documents/CozyTime Backups/. Safe to call on every launch — it
/// short-circuits if today's file already exists. Never throws; failures
/// are logged but don't surface to the user, because a backup we can't
/// produce is a quality-of-life loss, not a correctness loss.
enum CozyAutoBackup {
    private static let folderName = "CozyTime Backups"
    private static let retentionCount = 14

    static func runDailyBackupIfNeeded() {
        let fm = FileManager.default
        guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first,
              let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return }

        let source = appSupport.appendingPathComponent("CozyTime", isDirectory: true)
        guard fm.fileExists(atPath: source.path) else { return }

        let backupsDir = documents.appendingPathComponent(folderName, isDirectory: true)
        try? fm.createDirectory(at: backupsDir, withIntermediateDirectories: true)

        let stamp = ISO8601DateFormatter.cozyDayStamp.string(from: Date())
        let destination = backupsDir.appendingPathComponent("CozyTime-\(stamp).zip")
        if fm.fileExists(atPath: destination.path) {
            return // today's backup is already on disk
        }

        // /usr/bin/ditto -c -k --sequesterRsrc --keepParent SRC DEST
        // produces a Finder-style zip that round-trips xattrs and SwiftData's
        // WAL/SHM sidecar files. We don't pipe through Archive.framework so
        // the user can also unzip in Finder with a double-click.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [
            "-c", "-k",
            "--sequesterRsrc", "--keepParent",
            source.path,
            destination.path
        ]
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return }
            pruneOldBackups(in: backupsDir, keep: retentionCount)
        } catch {
            // Intentional: a backup failure should never block app launch.
            #if DEBUG
            print("CozyAutoBackup failed: \(error)")
            #endif
        }
    }

    private static func pruneOldBackups(in folder: URL, keep: Int) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        let sorted = entries
            .filter { $0.pathExtension.lowercased() == "zip" }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate > rhsDate
            }
        for stale in sorted.dropFirst(keep) {
            try? fm.removeItem(at: stale)
        }
    }
}

private extension ISO8601DateFormatter {
    static let cozyDayStamp: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return f
    }()
}
```

Call `CozyAutoBackup.runDailyBackupIfNeeded()` from `CozyTimeApp.init()`
**after** `AppDataStore` initialization, or from `applicationDidFinishLaunching`.
The function returns in &lt;10ms when today's file already exists (it just
does an `fileExists` check), so launch cost is negligible on warm days.

### Restoring from a backup

1. Quit CozyTime.
2. Move the current `~/Library/Application Support/CozyTime/` directory aside
   (rename to `CozyTime.broken-YYYY-MM-DD/` rather than delete — never
   destroy data during a rollback).
3. Unzip the desired snapshot in `~/Documents/CozyTime Backups/`. It expands
   to a `CozyTime/` folder.
4. Move that folder back into `~/Library/Application Support/`.
5. Relaunch.

The migration-failure banner (`CozyDataStoreErrorBanner`) should offer a
**Reveal Backups in Finder** button so a user who has never opened a Finder
window in their life can still find the zip:

```swift
NSWorkspace.shared.activateFileViewerSelecting([backupsURL])
```

This whole flow is opt-out-by-deletion: a user who doesn't want backups can
delete `~/Documents/CozyTime Backups/` and CozyTime will simply re-create
the folder on next launch. There is no UI to disable backups, because for a
private gift app the cost (a few MB/day, kept 14 days) is invisible relative
to the value of "your three months of focus sessions did not vanish."
