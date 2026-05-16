# CozyTime Design Rules (Lintable)

Authoritative ruleset for the CozyTime macOS 15 SwiftUI codebase. Where this file disagrees with ad-hoc styling in a view, **this file wins**. Aesthetic principles still live in [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md); this file is the enforceable subset.

Conventions:
- Every rule has a stable ID. Use it in commit messages (`fix(SP-001): drop .padding(10)`) and TODO comments.
- "Lint" is a copy-pasteable `rg` (ripgrep) one-liner. Zero hits = clean. The full script is at the end of this doc and at `scripts/lint_design.sh`.
- "Origin" cites either DESIGN_SYSTEM.md, Apple HIG (macOS 15), Refactoring UI (Wathan/Schoger), or "session feedback" from the user.

Lint scope: `Sources/CozyTime/` only. `DesignSystem.swift` is the single allowed exception for low-level primitives — most rules exclude it via `--glob '!DesignSystem.swift'`.

---

## 1. SPACING & GRID

### SP-001 — Allowed point literals only
**Rule.** Any numeric literal used as a spacing, padding, frame, offset, radius, or `spacing:` value must come from `{0, 2, 4, 8, 12, 16, 20, 24, 28, 32, 40, 48, 56, 64}`. Off-grid values like `7, 9, 10, 11, 13, 14, 15, 18` are banned.
**Why.** A 4pt soft grid (8pt strong) is what `CozyLayout` is built on. Off-grid values create the "almost-aligned-but-not" feeling the user keeps flagging. Origin: Refactoring UI ch. "Spacing & Sizing — Define a spacing and sizing system" + session feedback ("padding 10 keeps coming back").
**Lint.**
```bash
rg -n --glob '!DesignSystem.swift' \
  '\.(padding|frame|offset|spacing|cornerRadius)\([^)]*\b(1|3|5|6|7|9|10|11|13|14|15|17|18|19|21|22|23|25|26|27|29|30|31|33|34|35|36|37|38|39)\b' \
  Sources/CozyTime
```
**Good.**
```swift
VStack(spacing: 12) { … }
    .padding(.horizontal, 16)
```
**Bad.**
```swift
VStack(spacing: 10) { … }      // 10 is off-grid
    .padding(.horizontal, 14)  // 14 is off-grid
```

### SP-002 — No bare `.padding()`
**Rule.** Never call `.padding()` with no argument. Pass an explicit `CozyLayout` token or named edge + value.
**Why.** Bare `.padding()` resolves to SwiftUI's platform default (~16–20 depending on container) which silently disagrees with `CozyLayout.cardPadding`. Origin: session feedback.
**Lint.**
```bash
rg -n --glob '!DesignSystem.swift' '\.padding\(\)' Sources/CozyTime
```
**Good.** `.padding(CozyLayout.cardPadding)` or `.padding(.horizontal, 16)`
**Bad.** `.padding()`

### SP-003 — Card corner radius uses `CozyLayout.cardRadius`
**Rule.** Any `RoundedRectangle`, `.clipShape(RoundedRectangle…)`, or `.cornerRadius(…)` that wraps a *card-sized* surface (≥ 200pt wide) must read `cornerRadius: CozyLayout.cardRadius` (currently 12). Badges/chips use their own tokens (see SP-004); decorative shapes inside the mascot illustration are exempt.
**Why.** Mixed 12/14/16 radii break the eye's expectation of "all cards look like one family." Origin: Refactoring UI "Roundedness has meaning" + session feedback.
**Lint.**
```bash
rg -n --glob '!DesignSystem.swift' \
  'RoundedRectangle\(cornerRadius:\s*(1[0-9]|[2-9])\b' Sources/CozyTime \
  | rg -v 'CozyLayout\.cardRadius|CozyLayout\.badge'
```
**Good.** `RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)`
**Bad.** `RoundedRectangle(cornerRadius: 14, style: .continuous)`

### SP-004 — Badges use the badge-padding tokens
**Rule.** A pill/chip/badge (Text or HStack with a colored capsule background ≤ 200pt wide) must use `CozyLayout.badgePaddingSmall|Medium|Large` for inner padding and `Capsule()` (or `RoundedRectangle(cornerRadius: 999)`) as the shape. Add these tokens to `CozyLayout` if missing: `badgePaddingSmall = (h: 8, v: 2)`, `badgePaddingMedium = (h: 12, v: 4)`, `badgePaddingLarge = (h: 16, v: 6)`.
**Why.** Every badge currently sets its own h/v padding pair, leading to mismatched chip heights in the same row. Origin: session feedback.
**Lint (custom — catches hand-rolled badge padding).**
```bash
rg -n --glob '!DesignSystem.swift' -B1 -A1 'Capsule\(\)\.fill' Sources/CozyTime \
  | rg -E '\.padding\(\.(horizontal|vertical),\s*\d+\)' \
  | rg -v 'CozyLayout\.badgePadding'
```
**Good.**
```swift
Text("DUE").cozyBadge(.small, tint: theme.accent)
```
**Bad.**
```swift
Text("DUE")
    .padding(.horizontal, 9)
    .padding(.vertical, 3)
    .background(Capsule().fill(theme.accent))
```

---

## 2. TYPOGRAPHY & COLOR

### TC-001 — No raw `.font(.system(…))` in views
**Rule.** Outside `DesignSystem.swift`, every `.font(…)` callsite must reference a `CozyType.*` token.
**Why.** `CozyType` rounds every face to `design: .rounded`. Raw `.system` slips back to default SF which immediately reads "less cozy." Origin: `DesignSystem.swift` line 47-71 doc comment + session feedback.
**Lint.**
```bash
rg -n --glob '!DesignSystem.swift' '\.font\(\.system\(' Sources/CozyTime
```
**Good.** `.font(CozyType.rowTitle)`
**Bad.** `.font(.system(.title3, design: .rounded).weight(.bold))`

### TC-002 — No hardcoded `Color.white` / `Color.black` / `Color(red:…)` outside `DesignSystem.swift`
**Rule.** All literal colors must originate from `CozyPalette` or a `CozyTheme` instance. The only legal exceptions are `Color.clear` and `Color.black.opacity(…)` used inside `.shadow(color:…)`.
**Why.** `Color.white` text on themed accents reads fine in light mode but turns into a contrast hole in dark mode where the accent is auto-mixed. Origin: DESIGN_SYSTEM.md line 25 ("Dark mode uses semantic colors…") + session feedback.
**Lint.**
```bash
rg -n --glob '!DesignSystem.swift' \
  '\b(Color\.white|Color\.black|Color\(red:|Color\(hex:)' Sources/CozyTime \
  | rg -v '\.shadow\(color:.*Color\.black' \
  | rg -v 'Color\.clear'
```
**Good.** `.foregroundStyle(theme.foregroundOnAccent(colorScheme))`
**Bad.** `.foregroundStyle(reached ? Color.white : color.opacity(0.85))`

### TC-003 — Text on a themed accent fill uses `theme.foregroundOnAccent`
**Rule.** Any `Text` / `Label` / `Image(systemName:)` placed *on top of* a `theme.accent`, `theme.reward`, or `theme.secondary` fill must use `theme.foregroundOnAccent(colorScheme)`. Add this helper to `CozyTheme` if missing — it returns `.white` for dark-on-light accent and `CozyPalette.ink` for pale accents (e.g. wasabi, peach).
**Why.** `theme.accent` mutates in dark mode (`accent.cozyMix(with: darkText, amount: 0.36)`), so hard-coded `.white` becomes too dim. Origin: DesignSystem.swift lines 177–182 + Apple HIG "Color and Contrast" (macOS 15 minimum 3:1 for graphical elements, 4.5:1 for body text).
**Lint.**
```bash
rg -n --glob '!DesignSystem.swift' -B2 'foregroundStyle\(.*\.white' Sources/CozyTime \
  | rg -B2 'theme\.(accent|reward|secondary)'
```
**Good.** `Text("Start").foregroundStyle(theme.foregroundOnAccent(colorScheme))`
**Bad.** `Text("Start").foregroundStyle(.white)` over `theme.accent`

### TC-004 — OFF-state controls keep a contrast floor of 3.0:1 in dark mode
**Rule.** `.foregroundStyle(.secondary)` or `CozyPalette.secondaryText` is required for OFF-state labels — never `.opacity(0.4)` on `primaryText`, which fails the 3:1 floor in dark mode against `darkSurface`.
**Why.** Apple HIG macOS 15 ("Color and Contrast") sets 3:1 as the floor for non-text UI; the muted-text token is pre-tuned to that. Origin: HIG + DESIGN_SYSTEM.md line 25–33.
**Lint (heuristic).**
```bash
rg -n --glob '!DesignSystem.swift' \
  '\.foregroundStyle\(.*\.opacity\(0?\.[1-4]\d*\)\)' Sources/CozyTime
```
**Good.** `.foregroundStyle(CozyPalette.secondaryText(colorScheme))`
**Bad.** `.foregroundStyle(CozyPalette.primaryText(colorScheme).opacity(0.4))`

---

## 3. CONTROL STYLE (no defaults leak)

### CT-001 — TextField / TextEditor wrap with `.cozyTextInput()`
**Rule.** Every `TextField`, `SecureField`, and `TextEditor` must be followed by `.cozyTextInput()` (or be inside a `CozyFieldShell { … }`). Default AppKit text-field chrome is forbidden.
**Why.** Default macOS bezels disagree with our card radius and don't honor the focus-ring color. Origin: session feedback ("default SwiftUI controls keep slipping in unstyled").
**Lint.**
```bash
rg -nU --glob '!DesignSystem.swift' \
  '(TextField|TextEditor|SecureField)\([^)]*\)(?![^\n]*cozyTextInput|[^\n]*CozyFieldShell)' \
  --pcre2 Sources/CozyTime
```
**Good.** `TextField("Title", text: $title).cozyTextInput()`
**Bad.** `TextField("Title", text: $title).textFieldStyle(.roundedBorder)`

### CT-002 — `DatePicker(.graphical)` is banned outside `DesignSystem.swift`
**Rule.** Use `CozyDateInput` for date pickers. The graphical `DatePicker` style is reserved for `CozyDateInput`'s own popover content.
**Why.** Graphical date pickers do not fit our 12pt card radius or accent color and dwarf nearby fields. Origin: session feedback.
**Lint.**
```bash
rg -n --glob '!DesignSystem.swift' \
  'datePickerStyle\(\.graphical\)' Sources/CozyTime
```
**Good.** `CozyDateInput(title: "Due", date: $dueDate)`
**Bad.** `DatePicker("Due", selection: $dueDate).datePickerStyle(.graphical)`

### CT-003 — Toggle / Picker / Stepper use the project wrappers
**Rule.** `Toggle` must use `CozyToggleRow` (or `.toggleStyle(CozyToggleStyle())`). `Picker` of inline items must use `CozySegmentedControl`. `Stepper` is banned for numeric input under 10 (use `CozySegmentedControl` of explicit choices); for ≥ 10, wrap in `CozyLabeledControl`.
**Why.** Native toggle/picker chrome reads "form sheet from 2014" against rounded cozy surfaces. Origin: session feedback.
**Lint.**
```bash
rg -nU --glob '!DesignSystem.swift' \
  '^\s*(Toggle|Picker|Stepper)\(' Sources/CozyTime \
  | rg -v 'CozyToggleRow|CozySegmentedControl|CozyLabeledControl'
```
**Good.** `CozyToggleRow(title: "Reminders", isOn: $remindersOn)`
**Bad.** `Toggle("Reminders", isOn: $remindersOn)`

---

## 4. LAYOUT & ALIGNMENT

### LA-001 — Icon + multi-line text uses `.firstTextBaseline`
**Rule.** Any `HStack` whose children are `(Image, Text)` or `(Image, VStack of text)` must declare `alignment: .firstTextBaseline` — or, if the icon is a glyph-sized container, `.firstTextBaseline` with `.alignmentGuide(.firstTextBaseline)` on the image.
**Why.** Default `.center` alignment makes SF Symbols float visually higher than the text cap height, especially for `Image(systemName:)` at non-text sizes. Origin: Apple HIG "Layout — Alignment" + Refactoring UI "Align with a baseline, not the middle".
**Lint (heuristic — catches HStacks containing Image and Text but no alignment hint).**
```bash
rg -nU --glob '!DesignSystem.swift' \
  'HStack\((?!.*alignment:).*\)\s*\{[^}]*Image\(systemName:[^}]*Text\(' \
  --pcre2 -U Sources/CozyTime
```
**Good.** `HStack(alignment: .firstTextBaseline, spacing: 8) { Image(systemName: "flame"); Text(streakLine) }`
**Bad.** `HStack(spacing: 8) { Image(systemName: "flame"); Text(streakLine) }`

### LA-002 — Multi-column form rows use `CozyFormRow`
**Rule.** Any `HStack` containing two or more `CozyLabeledControl` siblings must be wrapped in a `CozyFormRow { … }` container. `CozyFormRow` enforces:
1. Every child reserves the hint slot (passing `hint: nil` still renders an invisible spacer — `CozyLabeledControl` already does this on line 1179–1181, but `CozyFormRow` asserts it at debug time).
2. `alignment: .top` for the underlying HStack.
3. Even spacing of `CozyLayout.formRowSpacing` (12pt).

If `CozyFormRow` does not exist, add it now to `DesignSystem.swift`. Suggested signature:
```swift
struct CozyFormRow<Content: View>: View {
    var spacing: CGFloat = CozyLayout.formRowSpacing
    @ViewBuilder var content: Content
    var body: some View {
        HStack(alignment: .top, spacing: spacing) { content }
    }
}
```
**Why.** This is the exact bug the user has flagged 3+ times (LIST/DUE/ESTIMATE/PRIORITY and HABIT/WEEKLY GOAL/ACTION). Origin: session feedback.
**Lint.**
```bash
rg -nU --glob '!DesignSystem.swift' \
  'HStack\([^)]*\)\s*\{[^}]*CozyLabeledControl[^}]*CozyLabeledControl' \
  --pcre2 -U Sources/CozyTime \
  | rg -v 'CozyFormRow'
```
**Good.**
```swift
CozyFormRow {
    CozyLabeledControl(title: "LIST")     { listMenu }
    CozyLabeledControl(title: "DUE",
                       hint: "Optional")  { CozyDateInput(date: $due) }
    CozyLabeledControl(title: "ESTIMATE") { estimateStepper }
    CozyLabeledControl(title: "PRIORITY") { prioritySegmented }
}
```
**Bad.**
```swift
HStack(spacing: 12) {
    CozyLabeledControl(title: "LIST") { listMenu }              // no hint
    CozyLabeledControl(title: "DUE",
                       hint: "Optional") { … }                  // hint visible
    CozyLabeledControl(title: "ESTIMATE") { … }                 // no hint
    CozyLabeledControl(title: "PRIORITY") { … }                 // no hint
} // misaligned bottoms — controls render at different Y
```

### LA-003 — Grid rows with variable body height pin children with `.frame(maxHeight: .infinity, alignment: .top)`
**Rule.** Any `LazyVGrid` / `Grid` cell whose contents can wrap to different heights must apply `.frame(maxHeight: .infinity, alignment: .top)` to each child so the row resolves to the tallest child's height and cards visually align.
**Why.** Without it, a 2-line card and a 4-line card in the same row sit at different bottom Ys. Origin: Apple HIG "Grids" + Refactoring UI "Hierarchy" (siblings should read as a row).
**Lint (heuristic).**
```bash
rg -nU --glob '!DesignSystem.swift' \
  'LazyVGrid\(' -A 60 Sources/CozyTime \
  | rg -v 'maxHeight:\s*\.infinity' \
  | rg 'CozyCard|cozyCard'
```
**Good.** `.cozyCard().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)` inside the grid item.
**Bad.** Card with no `maxHeight: .infinity` inside `LazyVGrid`.

---

## 5. ACCESSIBILITY & MOTION

### AM-001 — Animations gated on `@Environment(\.accessibilityReduceMotion)`
**Rule.** Every `withAnimation(…)` and `.animation(…)` call must be guarded by the Reduce Motion environment. Introduce `CozyMotion`:
```swift
enum CozyMotion {
    static func gentle(_ reduceMotion: Bool, duration: Double = 0.18) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: duration)
    }
    static func snappy(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .snappy(duration: 0.18)
    }
}
```
Then sites become `withAnimation(CozyMotion.snappy(reduceMotion)) { … }` and `.animation(CozyMotion.gentle(reduceMotion), value: x)`.
`.transition(.move)` / `.transition(.scale)` are banned outright; use `.transition(.opacity)` (already a no-op-ish under Reduce Motion).
**Why.** DESIGN_SYSTEM.md line 76 ("Reduce Motion: replace movement with fades or static color changes"). Currently violated at multiple sites in HabitStatsViews/CountdownViews/TaskViews/FocusViews.
**Lint.**
```bash
rg -nU --glob '!DesignSystem.swift' \
  '(withAnimation\(|\.animation\()' Sources/CozyTime \
  | rg -v 'reduceMotion|CozyMotion'
```
And for banned transitions:
```bash
rg -n --glob '!DesignSystem.swift' \
  '\.transition\(\.(move|scale|slide|offset)' Sources/CozyTime
```
**Good.** `withAnimation(CozyMotion.snappy(reduceMotion)) { selected.toggle() }`
**Bad.** `withAnimation(.snappy(duration: 0.18)) { selected.toggle() }` (no gate)

### AM-002 — Hit targets ≥ 44pt unless `compactHitSize` is opted in
**Rule.** Any `Button`, `.onTapGesture`-bearing view, or interactive `Image` must resolve to a frame of at least `CozyLayout.hitSize` (44pt) on the smallest axis. Compact targets must explicitly pass `CozyLayout.compactHitSize` and be inside a known-dense container (status bar, segmented strip).
**Why.** Apple HIG "Inputs — Pointers" recommends 44pt; the codebase already standardizes on this. Origin: HIG + DesignSystem.swift line 17–18.
**Lint (heuristic — frames smaller than 44 on a Button).**
```bash
rg -nU --glob '!DesignSystem.swift' \
  'Button\(' -A 8 Sources/CozyTime \
  | rg -E '\.frame\((width|height):\s*([0-9]|[1-3][0-9])\b' \
  | rg -v 'compactHitSize|CozyLayout\.hitSize'
```
**Good.** `.frame(width: CozyLayout.hitSize, height: CozyLayout.hitSize)`
**Bad.** `.frame(width: 24, height: 24).onTapGesture { … }`

### AM-003 — Icon-only interactive views need `.accessibilityLabel`
**Rule.** Any `Button` / `Menu` / `.onTapGesture` whose visible label is only `Image(systemName:)` must declare `.accessibilityLabel("…")`.
**Why.** Apple HIG "Accessibility — Labels". VoiceOver users otherwise hear "button, image" with no context.
**Lint (heuristic — Buttons with only Image inside, no accessibilityLabel within 6 lines).**
```bash
rg -nU --glob '!DesignSystem.swift' \
  'Button\(action:[^)]*\)\s*\{\s*Image\(systemName:' -A 6 Sources/CozyTime \
  | rg -v 'accessibilityLabel'
```
**Good.** `Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Close")`
**Bad.** `Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") }`

---

## 6. MASCOT & DECORATION

### MD-001 — Decorations use `MascotAnchor` named anchors
**Rule.** Stickers, reward badges, and accessory overlays on a mascot must be positioned via a `MascotAnchor` enum, not by raw `.offset(x:y:)`. Add to `DesignSystem.swift`:
```swift
enum MascotAnchor {
    case topLeft, topRight, bottomLeft, bottomRight
    case earLeft, earRight, collar, pawFront, sideKick

    func offset(for size: CGFloat, mascot: CozyMascotStyle) -> CGSize {
        // Each mascot character provides its own anchor table.
        mascot.anchorTable[self] ?? .zero
    }
}
```
Each `CozyMascotStyle` must declare its anchor coordinates so different mascots (Mochi today, others tomorrow) don't all use Mochi's offsets.
**Why.** Stickers overlap the body because every callsite picks its own offsets. Origin: session feedback (multiple screenshots of pink star + tiny mascot + coffee cup stacking on Mochi's right shoulder).
**Lint.**
```bash
rg -n --glob '!DesignSystem.swift' \
  '\.offset\(' Sources/CozyTime/FocusViews.swift Sources/CozyTime/RootView.swift \
  | rg -v 'MascotAnchor'
```
**Good.** `.cozyMascotSticker(.bowtie, at: .collar)`
**Bad.** `.offset(x: 18, y: -22)` on a sticker view

### MD-002 — Max 2 stickers per mascot card per state
**Rule.** A mascot card may render at most two `cozyMascotSticker` modifiers concurrently (one accessory + one reward stamp). Anchors must come from disjoint groups (`{earLeft, earRight, collar}` vs `{topRight, bottomLeft, sideKick}`) to prevent collision.
**Why.** Visual noise breaks the "calm" tone. Origin: DESIGN_SYSTEM.md line 5 ("Cute restraint") + session feedback.
**Lint.**
```bash
rg -nU --glob '!DesignSystem.swift' \
  'cozyMascotSticker' -c Sources/CozyTime \
  | awk -F: '$2 > 2 { print }'
```
Then manual review on flagged files.

### MD-003 — Mascot copy is never punitive
**Rule.** Strings shown on or near the mascot must not contain `fail`, `failed`, `broke`, `streak`, `behind`, `lazy`, `slacking`, `lost`, `gave up`. Use "restart gently" phrasing.
**Why.** DESIGN_SYSTEM.md line 46. Origin: DESIGN_SYSTEM.md (mascot tone).
**Lint.**
```bash
rg -nwi --glob '!DesignSystem.swift' \
  '"[^"]*(you failed|broke the chain|streak.*dying|don.?t break|slacking|gave up)[^"]*"' \
  Sources/CozyTime
```
**Good.** `"One small session?"`
**Bad.** `"Don't break the chain!"`

---

## 7. SHEET / MODAL UX

### SM-001 — Sheets ship visible close + Escape
**Rule.** Every `.sheet { … }` content view must apply `.modifier(CozySheetDismissAffordance(dismiss: …))`. The affordance already wires `.keyboardShortcut(.cancelAction)`, so applying it satisfies both halves of the rule.
**Why.** Apple HIG "Modality — Sheets" requires a visible dismiss. Origin: session feedback + HIG.
**Lint.**
```bash
rg -nU --glob '!DesignSystem.swift' \
  '\.sheet\(' -A 30 Sources/CozyTime \
  | rg -v 'CozySheetDismissAffordance'
```
**Good.** `MyComposer().modifier(CozySheetDismissAffordance(dismiss: { isPresented = false }))`
**Bad.** `MyComposer()` (no dismiss affordance)

### SM-002 — Sheets with > 3 inputs auto-focus the first field
**Rule.** If a sheet contains four or more focusable controls (`TextField`, `TextEditor`, `Picker`, `DatePicker`), declare `@FocusState private var initialFocus: …` and set it in `.onAppear { initialFocus = .first }`.
**Why.** Reduces "where do I start?" friction. Origin: Apple HIG "Inputs — Focus" + Refactoring UI "Reduce decisions".

### SM-003 — Lightweight pickers use `.popover`, not `.sheet`
**Rule.** A modal whose body is a single `DatePicker`, a single `Picker`, or a one-question Yes/No must be `.popover(isPresented:)` and not `.sheet(isPresented:)`. Sheets are for ≥ 3 inputs.
**Why.** macOS users expect popover-style outside-click dismiss for quick pickers; sheets feel heavy. Origin: Apple HIG macOS 15 "Popovers".

---

## 8. ECONOMY (additive-only)

### EC-001 — No XP or coin subtraction
**Rule.** No code path may subtract from `xp`, `pawCoins`, or any progression counter. Allowed mutations are `+=`, `max(current, new)`, and "spend" actions that route through `RewardItem.purchase(…)` — which itself only debits a transaction ledger, not the lifetime totals.
**Why.** DESIGN_SYSTEM.md line 50 ("Do not subtract XP, remove coins, or punish missed days"). Origin: DESIGN_SYSTEM.md.
**Lint.**
```bash
rg -n '\b(xp|pawCoins|coins)\s*-=' Sources/ \
  && rg -n '\b(xp|pawCoins|coins)\s*=\s*[^+]*-' Sources/
```
**Good.** `xp += earned`
**Bad.** `xp -= penalty`

### EC-002 — Shop always shows at least one unaffordable next-unlock
**Rule.** `ShopView` (or whatever surfaces `RewardItem`) must compute `nextUnlock = items.first { $0.cost > currentPaws }` and render it visibly. If `nextUnlock == nil`, render a "More coming soon" tile.
**Why.** A "completed" shop kills the loop. Origin: DESIGN_SYSTEM.md ("The main reward loop should be visible on the first screen") + session feedback ("she's too rich, bought everything").

---

## Lint script

Save as `scripts/lint_design.sh`, `chmod +x`, run before every PR. Exits non-zero on any hit so CI / pre-commit can wire it. Each rule prints its ID prefix so you can `grep ^SP-` to scope.

The script body lives at `scripts/lint_design.sh` — see that file.

### Adoption order

1. Add missing primitives to `DesignSystem.swift`: `CozyFormRow`, `CozyMotion`, `MascotAnchor`, `CozyTheme.foregroundOnAccent(colorScheme:)`, `CozyLayout.badgePadding{Small,Medium,Large}`, `.cozyTextInput()`, `.cozyMascotSticker(_:at:)`.
2. Land `scripts/lint_design.sh` and wire it into the release gate (`scripts/run_xcode_release_gate.sh`) so violations fail the same gate as XCTest.
3. Mass-fix the known violations cataloged inline above.
4. Wire `lint_design.sh` into a Claude Code `PreToolUse` hook in `.claude/settings.json` for in-session enforcement and into a git `pre-commit` hook for non-Claude edits.
