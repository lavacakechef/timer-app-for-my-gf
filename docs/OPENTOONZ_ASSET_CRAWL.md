# OpenToonz Asset Crawl

Last crawl: May 19, 2026.

Source:
https://github.com/opentoonz/opentoonz

Local command:

```bash
git clone --depth 1 --filter=blob:none https://github.com/opentoonz/opentoonz.git .build/external/opentoonz
scripts/crawl_opentoonz_assets.sh
```

Generated reports:

- `.build/reports/opentoonz-art-assets.tsv`
- `.build/reports/opentoonz-art-summary.txt`

Findings from the current crawl:

- The repository contains many image-like files, mostly OpenToonz UI icons,
  texture libraries, brush tips, custom styles, documentation images, and
  third-party test assets.
- The Ghibli-named paths are layout/menu configuration files under
  `stuff/profiles/layouts/rooms/StudioGhibli/`.
- The crawl did not find bundled Ghibli character artwork, film stills, mascot
  sprites, or named character assets.

License handling:

- The root OpenToonz license is BSD 3-Clause.
- Files under `thirdparty/` require separate review from their own licenses.
- Files under `stuff/library/mypaint brushes/` require review of that folder's
  `Licenses.txt`.
- Do not bulk-import the full OpenToonz image tree into CozyTime. Use the crawl
  manifest to curate specific, license-reviewed assets if they materially help
  the product.

CozyTime integration path:

- Approved private mascot art belongs under `ThirdPartyLicensed/Ghibli/`.
- The app-facing style id is `licensed`, displayed as `Private Art`.
- Run `scripts/sync_licensed_assets.sh` to generate ignored
  `mascot.licensed*.imageset` asset catalogs for private local builds.

Curated OpenToonz pack now wired into CozyTime:

- `mascot.toonz-buddy.*` from `stuff/library/custom styles/Dog.0001-0004.png`.
- `mascot.toonz-chick.*` from `stuff/library/custom styles/Chick.0001-0003.png`.
- Every `stuff/library/custom styles/*.png` frame as
  `opentoonz.custom.{filename}`.
- Reward/decor aliases include `opentoonz.arc`, `opentoonz.ball`,
  `opentoonz.bow`, `opentoonz.brush`, `opentoonz.bubbles`,
  `opentoonz.candy`, `opentoonz.fish2`, `opentoonz.flower4`,
  `opentoonz.frame`, `opentoonz.icecream`, `opentoonz.ladybird`,
  `opentoonz.leaf`, `opentoonz.orange`, `opentoonz.spring`,
  `opentoonz.star`, `opentoonz.sunflower`, and `opentoonz.umbrella`.

Import command:

```bash
scripts/import_opentoonz_art_pack.sh
```

The pack is intentionally small. It excludes OpenToonz UI icons, Qt theme
assets, `thirdparty/`, MyPaint brush previews, documentation screenshots, and
Ghibli layout config files.
