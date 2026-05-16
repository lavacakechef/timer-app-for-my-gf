# Mascot art — how to swap in real illustrations

The vector mascots in `Sources/CozyTime/DesignSystem.swift` are a fallback. When you add raster art to `XcodeSupport/CozyTime/Assets.xcassets`, the app automatically picks it up — no Swift changes per mascot. The vector body runs only when no matching asset is found.

This doc covers the three sourcing paths: **AI-generated**, **commissioned**, and **CC0 / public-domain**. Everything below targets **original artwork that you own (or that is freely licensed)** — directly reproducing trademarked characters like Labubu, Pompompurin, Snoopy, or other Sanrio / Pop Mart / Peanuts mascots is not part of any of these paths.

---

## 1. File spec

| Property | Value |
|---|---|
| Format | PNG with transparent background, or HEIC |
| Dimensions | **512 × 512 px** at 1x, **1024 × 1024 px** at 2x |
| Color space | sRGB |
| Subject pose | Centered, ~70% of the canvas (leaves margin for app shadows) |
| Background | Fully transparent (no flat fill) |

You don't need every state — the minimum viable set is **idle**, **focus**, **complete** (three images). The app's asset-resolution chain falls back from exact state → coarse category → style-default → Lottie/vector. So `mascot.maltese.idle.png` alone is enough to get started.

## 2. Naming convention

Add an imageset to `XcodeSupport/CozyTime/Assets.xcassets/` with one of these names. The app tries them in this order:

1. `mascot.{styleID}.{state}` — most specific (e.g. `mascot.maltese.deepFocus`)
2. `mascot.{styleID}.{category}` — coarser (e.g. `mascot.maltese.focus`)
3. `mascot.{styleID}` — single fallback (e.g. `mascot.maltese`)

**Style IDs in the current build:** `maltese`, `biscuit`, `tofu`, `bao`, `bramble`, `pip`, `yolk`, `soba`, `hazel`, `acorn`. Retired legacy IDs such as `mango` and `custard` fall back to Mochi.

**State categories** (defined in `MascotState.categoryKey`):
- `idle` — covers idle, countdown, overdue, breakTime
- `focus` — covers settling, focus, deepFocus, landing
- `complete` — covers the celebration state

After dropping files in:
```bash
scripts/generate_xcode_project.sh   # only needed if you add new imagesets
COZYTIME_SKIP_RELEASE_GATE=1 scripts/package_xcode_unsigned.sh
```

Use `COZYTIME_SKIP_RELEASE_GATE=1` only for a local mascot preview build. A
friend-sendable ZIP must run `scripts/package_xcode_unsigned.sh` without that
environment variable so design lint, XCTest, XCUITest, archive, and codesign
verification all run.

## 3. Source path A — AI-generated

Image generators (DALL-E 3 via ChatGPT / Bing, Midjourney, Stable Diffusion) can produce kawaii character art quickly. Keep prompts oriented toward **original character design**; don't ask the model to reproduce a named character.

Suggested prompt for an original soft-puppy mascot (Maltese / Mochi family):

> Original chibi mascot character. Round fluffy white puppy with floppy ears,
> oversized soft eyes, tiny pink cheeks, sitting pose, centered on transparent
> background. Soft pastel color palette, gentle line work, no text or watermark.
> Stylized — not a real animal photograph. 1024x1024.

For the "ugly-cute monster bun" lane (Mango family):

> Original cute monster mascot character. Round peach-colored creature with
> two tall floppy bunny-style ears, big round eyes, two soft fang teeth, sitting
> pose. Soft warm palette. Centered on transparent background. Friendly not
> scary. 1024x1024.

For the "round dessert puppy" lane (Custard family):

> Original chibi puppy mascot. Perfectly round cream-colored puppy with short
> droopy ears, button nose, tiny rust-colored beret on top, gentle smile. Soft
> warm palette. Centered on transparent background. 1024x1024.

Per-state prompts add a behavior modifier:
- **idle**: `relaxed pose, eyes open, gentle smile`
- **focus**: `wearing small soft headphones, eyes slightly closed in concentration`
- **complete**: `arms raised in tiny celebration, sparkle particles around, big smile`

Run each prompt three or four times, pick the one with the cleanest silhouette + clearest transparency. If the background isn't transparent, post-process in Preview (Tools → Instant Alpha) or a free remover (https://www.remove.bg/).

## 4. Source path B — Commission (Fiverr / Etsy / Ko-fi)

Typical kawaii character set: **$15–$40** for a 3-pose set delivered in 3–7 days. Search terms that surface the right artists: `kawaii mascot illustration`, `chibi character commission`, `cute pet mascot`.

Brief template to paste into the seller's intake form:

```
Hi! I'd love a 3-pose mascot character set for a personal productivity app
(not for commercial sale).

Character: Original cute mascot — a [Maltese puppy / cream bun creature /
soft round puppy with beret]. I'm open to your interpretation as long as
it stays in the soft kawaii / chibi style.

Poses needed:
  1. Idle — gentle, relaxed, eyes open
  2. Focus — wearing small headphones, looking concentrated
  3. Celebrate — arms up, sparkles around, big smile

Format: PNG with transparent background, 1024×1024 px each, sRGB.
Centered subject taking ~70% of canvas (margin for shadows).
Soft pastel palette, gentle line work.

I'll hold the usage rights for personal/private app use. Please name the
files mascot.mochi.idle.png / mascot.mochi.focus.png / mascot.mochi.complete.png.
```

After delivery, drop the three files into a new imageset directory
`XcodeSupport/CozyTime/Assets.xcassets/mascot.mochi.idle.imageset/`
(repeat for each state).

## 5. Source path C — Creative Commons / public-domain

These libraries publish artwork under CC0 (no rights reserved) or CC-BY (attribution required). Always verify the license on the specific image before bundling — even on these sites, individual uploads can have stricter terms.

- **OpenClipArt** — https://openclipart.org/ — search terms: `puppy chibi`, `cute mascot`, `cartoon dog`, `kawaii cat`. License: CC0.
- **Pixabay** — https://pixabay.com/ — search filter to "Vector graphics" + "Free for use". License: Pixabay Content License (free for personal + commercial).
- **Pexels** — https://www.pexels.com/ — has fewer cartoon mascots but good for photo-realistic backdrops if you want to swap that route. License: Pexels License.
- **Public Domain Vectors** — https://publicdomainvectors.org/ — search: `chibi`, `cute dog`. License: CC0.
- **The Noun Project** — https://thenounproject.com/ — search: `kawaii puppy`. License: CC-BY (attribution required) or paid royalty-free; add the attribution to `docs/CREDITS.md`.
- **Iconscout / Flaticon (free tiers)** — attribution required; bundle a `CREDITS.md` entry.

When using CC-BY or attribution-required artwork, add a single line to a new `docs/CREDITS.md` like:

```
- mascot.mochi by [Artist Name] — https://link-to-original — CC-BY-4.0
```

## 6. Smoke test

After adding any image:

```bash
swift build
scripts/generate_xcode_project.sh
open /Applications/CozyTime.app    # or run via Xcode
```

If the app still shows the vector mascot, double-check:
- The imageset directory name exactly matches one of the four asset-resolution candidates.
- The PNG inside is referenced from the `Contents.json` (Xcode handles this automatically when you drag-and-drop in Xcode, but `scripts/generate_xcode_assets.swift` may need updating for fully scripted projects).
- The `selectedMascotStyle` AppStorage matches a `styleID` you provided (e.g. select Mochi in Settings if you supplied `mascot.maltese.*`).

If multiple styles ship art and you want users to switch, no extra code is needed — selecting a mascot in Settings already drives `selectedMascotStyle` → which drives the asset lookup.

---

## What this design doesn't do (intentional)

- **Doesn't recommend or facilitate reproduction of trademarked characters.** Even for private use, copying named characters (Labubu, Snoopy, Pompompurin, Hello Kitty, Pikachu, etc.) is a real liability the moment the build leaves your machine.
- **Doesn't bundle any specific image in the repo.** Each user / fork sources their own art.
- **Doesn't tie art to specific themes.** Swap themes and mascots independently.
