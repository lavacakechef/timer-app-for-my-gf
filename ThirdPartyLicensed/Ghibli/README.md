# Restricted Licensed Mascot Assets

Put only rights-holder-approved local asset files for the private CozyTime
mascot integration in this folder.

This folder is intentionally ignored by Git except for this README and
`.gitkeep`. Do not commit or push supplied third-party artwork, permission
letters, exported frames, or converted files.

Accepted source names for the sync script:

- `mascot.licensed.idle.png`
- `mascot.licensed.focus.png`
- `mascot.licensed.complete.png`
- `mascot.licensed.countdown.png`
- `mascot.licensed.overdue.png`
- `mascot.licensed.breakTime.png`
- `mascot.licensed.settling.png`
- `mascot.licensed.deepFocus.png`
- `mascot.licensed.landing.png`

Run:

```bash
scripts/sync_licensed_assets.sh
scripts/generate_xcode_project.sh
```

Then choose `Private Art` in Settings.
