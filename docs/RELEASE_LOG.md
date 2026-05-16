# CozyTime Release Log

This file is the canonical "what changed in each build" log. It exists for two reasons:

1. The in-app `WelcomeBackBanner` uses `CFBundleShortVersionString` and
   `@AppStorage("lastSeenAppVersion")` to reassure the user after an upgrade.
   It does not parse this file yet; a richer "What's New" sheet can be added
   later if the app needs per-version notes inside the UI.
2. Whoever is rebuilding the ZIP (currently you) keeps a paper trail of what
   each ad-hoc-signed bundle actually contains, since there is no App Store
   listing to fall back on.

## Format rules

- **One section per shipped version.** Add a new section *above* the older
  ones (newest at the top).
- Version header is `## vX.Y.Z — YYYY-MM-DD` exactly.
- Each section has at most **three short bullets**, written in cozy second
  person ("you can now …"). Long-form rationale belongs in
  `docs/IMPLEMENTATION_NOTES.md`, not here.
- Tone follows `docs/DESIGN_SYSTEM.md`: never punitive, never "we fixed your
  bad behavior." Bug fixes phrased as "we tidied up X" or "X feels smoother."
- Never delete an old entry. This file is repo/handoff documentation for now;
  the app does not bundle or parse it yet.

## Pending entry (uncomment + edit when cutting the next build)

<!--
## vNEXT — YYYY-MM-DD

- Headline change in one sentence.
- Second smaller change.
- Tidy-up bullet (optional).
-->

## v0.2.0 — 2026-05-16

- You can now claim focus rewards into a diary loop: reward, reflection,
  stats, and calendar history all stay connected.
- Mochi has a cleaner mascot/reward room, more personalization, and gentler
  menu-bar quick actions.
- Forms, date inputs, buttons, and cards were tightened onto one design grid,
  with lint rules to keep future edits aligned.

## v0.1.0 — 2026-04-20 (PLACEHOLDER — fill in at cut time)

- First private build. Focus timer, tasks, countdowns, habits, rewards,
  mascot all working end to end.
- Data lives in `~/Library/Application Support/CozyTime/` so upgrades keep
  your history.
- Menu-bar paw with quick start / pause for the focus timer.

---

## How to ship a new entry

1. Append the new `## vX.Y.Z — YYYY-MM-DD` block at the top.
2. Bump `MARKETING_VERSION` in `project.yml`, regenerate the Xcode project,
   run the release gate, package the ZIP.
3. Drop a copy of this file alongside the ZIP in your handoff folder, so the
   recipient has the human-readable changelog even before they open the app.
