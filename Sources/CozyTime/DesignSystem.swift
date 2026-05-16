import CozyCore
import AppKit
import SwiftUI

// MARK: - CozyFormRow (rule LA-002)
//
// Wraps multi-column form rows so siblings align. Every `CozyLabeledControl`
// in the row reserves the (possibly invisible) hint slot via its own internal
// spacer, so the row resolves to a uniform body height regardless of which
// columns have visible captions.
struct CozyFormRow<Content: View>: View {
    var spacing: CGFloat = CozyLayout.formRowSpacing
    @ViewBuilder var content: Content
    var body: some View {
        HStack(alignment: .top, spacing: spacing) { content }
    }
}

struct CozyResponsiveFormRow<Leading: View, Trailing: View, Auxiliary: View>: View {
    var spacing: CGFloat = CozyLayout.formRowSpacing
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var auxiliary: Auxiliary

    init(
        spacing: CGFloat = CozyLayout.formRowSpacing,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder auxiliary: () -> Auxiliary
    ) {
        self.spacing = spacing
        self.leading = leading()
        self.trailing = trailing()
        self.auxiliary = auxiliary()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: spacing) {
                    leading
                        .layoutPriority(1)
                    horizontalTrailing
                }

                VStack(alignment: .leading, spacing: spacing) {
                    leading
                        .frame(maxWidth: .infinity, alignment: .leading)
                    verticalTrailing
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            auxiliary
        }
    }

    private var horizontalTrailing: some View {
        CozyFormRow(spacing: spacing) {
            trailing
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var verticalTrailing: some View {
        ViewThatFits(in: .horizontal) {
            CozyFormRow(spacing: spacing) {
                trailing
            }
            VStack(alignment: .leading, spacing: spacing) {
                trailing
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension CozyResponsiveFormRow where Auxiliary == EmptyView {
    init(
        spacing: CGFloat = CozyLayout.formRowSpacing,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.spacing = spacing
        self.leading = leading()
        self.trailing = trailing()
        self.auxiliary = EmptyView()
    }
}

struct CozyResponsiveFieldRow<Content: View>: View {
    var spacing: CGFloat = CozyLayout.formRowSpacing
    @ViewBuilder var content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            CozyFormRow(spacing: spacing) {
                content
            }
            VStack(alignment: .leading, spacing: spacing) {
                content
            }
        }
    }
}

// MARK: - CozyMotion (rule AM-001)
//
// Wraps every animation in a Reduce-Motion guard. Replaces `.snappy(0.18)`,
// `.easeOut(0.22)` etc. at callsites with `CozyMotion.snappy(reduceMotion)` —
// returns `nil` when Reduce Motion is on, which SwiftUI interprets as
// "instant, no animation."
enum CozyMotion {
    static func gentle(_ reduceMotion: Bool, duration: Double = 0.22) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: duration)
    }
    static func snappy(_ reduceMotion: Bool, duration: Double = 0.18) -> Animation? {
        reduceMotion ? nil : .snappy(duration: duration)
    }
    static func spring(_ reduceMotion: Bool, response: Double = 0.28, damping: Double = 0.62) -> Animation? {
        reduceMotion ? nil : .spring(response: response, dampingFraction: damping)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - MascotAnchor (rules MD-001, MD-002)
//
// Named anchor zones on a mascot card. Each `CozyMascotStyle` provides its
// own anchor table so stickers don't collide with the character's body or
// with each other. Anchors are bucketed into disjoint groups so the
// `cozyMascotSticker` modifier can detect collisions at debug time.
enum MascotAnchor: Hashable {
    case topLeft, topRight, bottomLeft, bottomRight
    case earLeft, earRight, collar
    case sideKick   // companion-object slot to the bottom-right

    enum Group {
        case corners
        case body
        case companion
    }
    var group: Group {
        switch self {
        case .topLeft, .topRight, .bottomLeft, .bottomRight: return .corners
        case .earLeft, .earRight, .collar: return .body
        case .sideKick: return .companion
        }
    }

    // Default anchor offsets, expressed as fractions of mascot size so they
    // scale correctly. Per-mascot overrides may be added later.
    func offset(for size: CGFloat) -> CGSize {
        switch self {
        case .topLeft:      return CGSize(width: -size * 0.32, height: -size * 0.32)
        case .topRight:     return CGSize(width:  size * 0.32, height: -size * 0.32)
        case .bottomLeft:   return CGSize(width: -size * 0.30, height:  size * 0.30)
        case .bottomRight:  return CGSize(width:  size * 0.30, height:  size * 0.30)
        case .earLeft:      return CGSize(width: -size * 0.20, height: -size * 0.36)
        case .earRight:     return CGSize(width:  size * 0.20, height: -size * 0.36)
        case .collar:       return CGSize(width: 0,             height:  size * 0.20)
        case .sideKick:     return CGSize(width:  size * 0.38, height:  size * 0.22)
        }
    }
}


enum CozyLayout {
    static let unit: CGFloat = 8
    static let pageMaxWidth: CGFloat = 1080
    static let pagePadding: CGFloat = 28
    static let sectionSpacing: CGFloat = 24
    static let gridSpacing: CGFloat = 16
    static let formRowSpacing: CGFloat = 12
    static let cardPadding: CGFloat = 20
    static let cardRadius: CGFloat = 12
    static let compactTileMinHeight: CGFloat = 132
    static let controlHeight: CGFloat = 44
    static let compactControlHeight: CGFloat = 38
    static let hitSize: CGFloat = 44
    static let compactHitSize: CGFloat = 38
    static let primaryButtonMinWidth: CGFloat = 108
    static let labeledControlMinWidth: CGFloat = 128

    // Sub-card / pill radius. Used for inner mini-cards (≤180pt wide) where
    // 12pt feels too soft. SP-003 lints non-cardRadius RoundedRectangle; use
    // this token for any intentional 8pt radius callsite.
    static let subCardRadius: CGFloat = 8

    // Interactive control radius. Used for toggle tracks, segmented-control
    // backgrounds, button backgrounds, and flat-panel inner corners. Token
    // replaces the ~25 magic `cornerRadius: 10` literals (SP-003).
    static let controlRadius: CGFloat = 10

    // Badge inner padding tokens (rule SP-004). Use these whenever a pill or
    // chip wraps a colored capsule background, so badge heights stay uniform
    // across the row.
    static let badgePaddingSmallH: CGFloat = 8
    static let badgePaddingSmallV: CGFloat = 4
    static let badgePaddingMediumH: CGFloat = 12
    static let badgePaddingMediumV: CGFloat = 4
    static let badgePaddingLargeH: CGFloat = 16
    static let badgePaddingLargeV: CGFloat = 8

    // Sheet sizing tokens (UX MED #100). Use these on `.frame(width:)` or
    // `.frame(minWidth:idealWidth:)` for any modal sheet so widths cluster
    // on a known scale instead of drifting (was: 336, 360, 400, 440, 460,
    // 480, 560, 640, 720).
    //   small  — single-decision composers (rename, confirm)
    //   medium — first-run prompts, settings detail
    //   large  — multi-section editors (countdowns, focus reflection)
    static let sheetIdealWidthSmall: CGFloat = 360
    static let sheetIdealWidthMedium: CGFloat = 460
    static let sheetIdealWidthLarge: CGFloat = 560
    static let sheetIdealHeightSmall: CGFloat = 360
    static let sheetIdealHeightMedium: CGFloat = 520
    static let sheetIdealHeightLarge: CGFloat = 640

    static func adaptiveColumns(minimum: CGFloat = 280) -> [GridItem] {
        [GridItem(.adaptive(minimum: minimum), spacing: gridSpacing, alignment: .top)]
    }

    static var twoColumnCards: [GridItem] {
        [
            GridItem(.flexible(), spacing: gridSpacing, alignment: .top),
            GridItem(.flexible(), spacing: gridSpacing, alignment: .top)
        ]
    }

    static var metricColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: gridSpacing, alignment: .top),
            GridItem(.flexible(), spacing: gridSpacing, alignment: .top),
            GridItem(.flexible(), spacing: gridSpacing, alignment: .top),
            GridItem(.flexible(), spacing: gridSpacing, alignment: .top)
        ]
    }

    static var settingsGrid: [GridItem] {
        [GridItem(.adaptive(minimum: 190), spacing: formRowSpacing, alignment: .top)]
    }
}

/// Modern type scale. Every face uses `design: .rounded` (SF Pro Rounded) which reads
/// noticeably softer and more "modern app" than the default SF Pro — ideal for a cozy
/// productivity tool meant for a non-technical Gen-Z user. Bigger sites should reach for
/// `pageTitle` / `heroCardTitle` / `cardTitle` rather than raw `.font(.title2)` / `.headline`
/// so the rounded design propagates everywhere.
enum CozyType {
    static let pageTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let heroCardTitle = Font.system(.title2, design: .rounded).weight(.bold)
    static let cardTitle = Font.system(.title3, design: .rounded).weight(.bold)
    /// Row-level titles inside a card (e.g. each habit row, each task row, each shop tile).
    static let rowTitle = Font.system(.callout, design: .rounded).weight(.bold)
    static let metric = Font.system(size: 34, weight: .black, design: .rounded)
    /// Inline numeric for paw counts, percentages, durations — slightly smaller and
    /// monospaced-friendly.
    static let metricSmall = Font.system(.title3, design: .rounded).weight(.bold)
    static let timer = Font.system(size: 42, weight: .black, design: .rounded)
    static let body = Font.system(.callout, design: .rounded)
    static let control = Font.system(.callout, design: .rounded).weight(.medium)
    static let controlStrong = Font.system(.callout, design: .rounded).weight(.bold)
    static let caption = Font.system(.caption, design: .rounded)
    static let captionStrong = Font.system(.caption, design: .rounded).weight(.semibold)
    /// Footnote / muted secondary label under a CozyFormCaption.
    static let footnote = Font.system(.caption2, design: .rounded).weight(.semibold)
    static let badge = Font.system(.caption2, design: .rounded).weight(.bold)
}

enum CozyPalette {
    static let canvas = Color(hex: "#FFF9F7")
    static let surface = Color(hex: "#FFFFFF")
    static let ink = Color(hex: "#2E2623")
    static let mutedText = Color(hex: "#746863")
    static let focusJade = Color(hex: "#2F6F64")
    static let mistBlue = Color(hex: "#8CB8D0")
    static let softMint = Color(hex: "#DDEDE7")
    static let persimmon = Color(hex: "#A8512D")
    static let peach = Color(hex: "#FFD7B8")
    static let stickerPink = Color(hex: "#F2AFC5")
    static let blushPink = Color(hex: "#F8D7E2")
    static let warmCream = Color(hex: "#FFF1E8")
    static let berry = Color(hex: "#9E3F64")
    static let softSage = Color(hex: "#CFE2D8")
    static let habitLavender = Color(hex: "#7566A8")
    static let lavenderMist = Color(hex: "#E8E1F5")
    static let countdownBerry = Color(hex: "#A64D72")
    static let skyBlue = Color(hex: "#336D92")
    static let selectionFill = Color(hex: "#FBE7EE")
    static let neutralBorder = Color(hex: "#EADDD8")
    static let neutralRaised = Color(hex: "#FFFCFA")
    static let lofiInk = Color(hex: "#211C24")
    static let plum = Color(hex: "#6E4C77")
    static let coolBlue = Color(hex: "#496FA6")
    static let wasabi = Color(hex: "#D9F06A")
    static let wasabiText = Color(hex: "#5F7114")
    static let overdue = Color(hex: "#B75239")
    static let darkCanvas = Color(hex: "#151218")
    static let darkSurface = Color(hex: "#26212B")
    static let darkRaised = Color(hex: "#312936")
    static let darkText = Color(hex: "#FFF8F0")
    static let darkMutedText = Color(hex: "#D8CBC3")
    static let darkBorder = Color(hex: "#493D48")

    static func primaryText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkText : ink
    }

    static func secondaryText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkMutedText : mutedText
    }

    static func cardFill(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkSurface : surface
    }

    static func raisedFill(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkRaised : neutralRaised
    }

    static func cardBorder(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkBorder : neutralBorder
    }

    /// UX LOW #108 — contrast-aware border. When `.increased` is set (System
    /// Settings → Accessibility → Display → Increase contrast), darken the
    /// border so the card edge separates clearly from the canvas. Keeps the
    /// soft 1-pt hairline at default contrast; jumps to a more deliberate
    /// stroke when the user has explicitly asked for sharper outlines.
    static func cardBorder(_ colorScheme: ColorScheme, contrast: ColorSchemeContrast) -> Color {
        let base = cardBorder(colorScheme)
        return contrast == .increased ? base.opacity(0.85) : base
    }

    static func quietContainer(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkRaised.opacity(0.72) : Color(hex: "#FFF5F0")
    }

    static func catalogColor(_ hex: String) -> Color {
        Color(hex: hex)
    }

    static func softShadow(_ colorScheme: ColorScheme, active: Bool = false) -> Color {
        lofiInk.opacity(active ? (colorScheme == .dark ? 0.24 : 0.14) : (colorScheme == .dark ? 0.12 : 0.05))
    }
}

enum CozyFeedback {
    enum Cue {
        case add
        case complete
        case reward
        case undo
        case delete

        var soundName: NSSound.Name {
            switch self {
            case .add: NSSound.Name("Pop")
            case .complete: NSSound.Name("Glass")
            case .reward: NSSound.Name("Hero")
            case .undo: NSSound.Name("Tink")
            case .delete: NSSound.Name("Basso")
            }
        }

        var bundleSoundName: String {
            switch self {
            case .complete, .reward: "cozy_complete"
            case .add, .undo: "cozy_tick"
            case .delete: "cozy_action"
            }
        }
    }

    static func play(_ cue: Cue) {
        guard UserDefaults.standard.bool(forKey: "soundsEnabled") else { return }
        if let path = Bundle.main.path(forResource: cue.bundleSoundName, ofType: "aiff"),
           let sound = NSSound(contentsOfFile: path, byReference: false) {
            sound.play()
            return
        }
        _ = NSSound(named: cue.soundName)?.play()
    }
}

struct CozyTheme: Identifiable, Equatable {
    let id: String
    let accent: Color
    let secondary: Color
    let reward: Color
    let canvas: Color
    let surfaceTint: Color
    let symbolName: String

    static let defaultName = "Blush Mochi"

    /// Accent suitable for foreground TEXT on dark surfaces. Stored accent fails WCAG AA
    /// on `darkSurface` for every theme (worst case Blush Mochi #9E3F64 = 2.51:1).
    /// In dark mode we blend toward `darkText` (~#FFF8F0) by 36% which lifts most themes
    /// to AA-pass at title2 size. Keep the stored accent for fills/buttons (those sit on
    /// surfaceTint or accent backgrounds where the contrast computation is different).
    func tintedText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? accent.cozyMix(with: CozyPalette.darkText, amount: 0.36) : accent
    }

    /// Same idea for the reward (paw / persimmon) color used as foreground in dark mode.
    func rewardText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? reward.cozyMix(with: CozyPalette.darkText, amount: 0.30) : reward
    }

    func foregroundOnAccent(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? CozyPalette.darkText : .white
    }

    static let all: [CozyTheme] = [
        CozyTheme(
            id: "Blush Mochi",
            accent: CozyPalette.berry,
            secondary: CozyPalette.blushPink,
            reward: CozyPalette.persimmon,
            canvas: CozyPalette.canvas,
            surfaceTint: CozyPalette.warmCream,
            symbolName: "heart.circle.fill"
        ),
        CozyTheme(
            id: "Rose Milk",
            accent: Color(hex: "#B84E73"),
            secondary: Color(hex: "#F8C9D8"),
            reward: Color(hex: "#D97862"),
            canvas: Color(hex: "#FFF7FA"),
            surfaceTint: Color(hex: "#FFE1EA"),
            symbolName: "heart.fill"
        ),
        CozyTheme(
            id: "Pearl Ribbon",
            accent: Color(hex: "#8B5E83"),
            secondary: Color(hex: "#E8DDF0"),
            reward: Color(hex: "#C96A4C"),
            canvas: Color(hex: "#FFF9F2"),
            surfaceTint: Color(hex: "#F4E4EE"),
            symbolName: "gift.fill"
        ),
        CozyTheme(
            id: "Cherry Study",
            accent: Color(hex: "#A83E5C"),
            secondary: Color(hex: "#FFDCE6"),
            reward: Color(hex: "#E37A45"),
            canvas: Color(hex: "#FFF4F7"),
            surfaceTint: Color(hex: "#FFD6D6"),
            symbolName: "sparkle"
        ),
        CozyTheme(
            id: "Jade Desk",
            accent: CozyPalette.focusJade,
            secondary: CozyPalette.mistBlue,
            reward: CozyPalette.persimmon,
            canvas: CozyPalette.canvas,
            surfaceTint: CozyPalette.softMint,
            symbolName: "leaf.fill"
        ),
        CozyTheme(
            id: "Peach Sticker",
            accent: CozyPalette.persimmon,
            secondary: CozyPalette.stickerPink,
            reward: CozyPalette.focusJade,
            canvas: Color(hex: "#FFF4EC"),
            surfaceTint: CozyPalette.peach,
            symbolName: "seal.fill"
        ),
        CozyTheme(
            id: "Sky Study",
            accent: Color(hex: "#336D92"),
            secondary: CozyPalette.coolBlue,
            reward: CozyPalette.wasabiText,
            canvas: Color(hex: "#F4FAFF"),
            surfaceTint: Color(hex: "#CDE8FF"),
            symbolName: "cloud.fill"
        ),
        CozyTheme(
            id: "Night Lofi",
            accent: CozyPalette.coolBlue,
            secondary: CozyPalette.plum,
            reward: CozyPalette.wasabiText,
            canvas: Color(hex: "#F8F3FF"),
            surfaceTint: Color(hex: "#D8C4E8"),
            symbolName: "moon.stars.fill"
        ),
        CozyTheme(
            id: "Wasabi Pop",
            accent: Color(hex: "#5F7114"),
            secondary: CozyPalette.wasabi,
            reward: CozyPalette.persimmon,
            canvas: Color(hex: "#FAFFF1"),
            surfaceTint: CozyPalette.wasabi,
            symbolName: "sparkles"
        )
    ]

    static func named(_ name: String) -> CozyTheme {
        all.first { $0.id == name } ?? all.first { $0.id == defaultName } ?? all[0]
    }
}

struct CozyMascotStyle: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let symbolName: String

    static let defaultID = "maltese"

    // 2026 mascot lineup. The original "twinkle" star and "cloud pup" were
    // retired (gf feedback + research showing both were trend-saturated and
    // failed Lorenz baby-schema rules). A second pass also retired the
    // SwiftUI-vector-only "mango" / "custard" entries because picking them
    // felt broken — the picker tile WYSIWYGs from Lottie now, and those two
    // had no animation to show. They were replaced with 8 Google Noto
    // Animated Emoji characters (CC-BY 4.0) so every picker tile previews
    // an actual animated mascot.
    // Legacy keys ("frog", "pudding", "mango", "custard") remain accepted
    // in `named(_:)` and the SwiftUI body switch so existing user defaults
    // don't crash — they just fall back to Mochi via the unknown-id branch.
    static let all: [CozyMascotStyle] = [
        CozyMascotStyle(id: "maltese",  title: "Mochi",   subtitle: "Smiling shiba puppy",     symbolName: "pawprint.fill"),
        CozyMascotStyle(id: "biscuit",  title: "Biscuit", subtitle: "Orange study cat",        symbolName: "cat.fill"),
        CozyMascotStyle(id: "tofu",     title: "Tofu",    subtitle: "Round little cat",        symbolName: "cat.circle.fill"),
        CozyMascotStyle(id: "bao",      title: "Bao",     subtitle: "Panda dumpling",          symbolName: "circle.fill"),
        CozyMascotStyle(id: "bramble",  title: "Bramble", subtitle: "Caramel bear",            symbolName: "teddybear.fill"),
        CozyMascotStyle(id: "pip",      title: "Pip",     subtitle: "Bouncy baby chick",       symbolName: "bird.fill"),
        CozyMascotStyle(id: "yolk",     title: "Yolk",    subtitle: "Front-facing chick",      symbolName: "bird"),
        CozyMascotStyle(id: "soba",     title: "Soba",    subtitle: "Cheek-puffing frog",      symbolName: "drop.fill"),
        CozyMascotStyle(id: "hazel",    title: "Hazel",   subtitle: "Soft fox",                symbolName: "leaf.fill"),
        CozyMascotStyle(id: "acorn",    title: "Acorn",   subtitle: "Floating otter",          symbolName: "drop.circle.fill")
    ]

    /// Resolve a stored mascot id to a known style. Unknown ids (including
    /// retired entries like "mango" / "custard" left over in `AppStorage`)
    /// fall back to Mochi so saved state never crashes the picker.
    static func named(_ id: String) -> CozyMascotStyle {
        all.first { $0.id == id } ?? all.first { $0.id == defaultID } ?? all[0]
    }
}

struct CozyTimerSkin: Identifiable, Equatable {
    let id: String
    let title: String
    let symbolName: String
    let color: Color
    let secondary: Color

    static let defaultID = "rose-ring"

    static let all: [CozyTimerSkin] = [
        CozyTimerSkin(id: "rose-ring", title: "Rose Ring", symbolName: "heart.circle.fill", color: Color(hex: "#B84E73"), secondary: Color(hex: "#F8C9D8")),
        CozyTimerSkin(id: "jade-ring", title: "Jade Ring", symbolName: "timer", color: CozyPalette.focusJade, secondary: CozyPalette.softMint),
        CozyTimerSkin(id: "peach-hourglass", title: "Peach Hourglass", symbolName: "hourglass", color: CozyPalette.persimmon, secondary: CozyPalette.peach),
        CozyTimerSkin(id: "lofi-moon", title: "Lofi Moon", symbolName: "moon.stars.fill", color: CozyPalette.coolBlue, secondary: CozyPalette.lavenderMist),
        CozyTimerSkin(id: "cherry-pulse", title: "Cherry Pulse", symbolName: "sparkles", color: Color(hex: "#A83E5C"), secondary: Color(hex: "#FFDCE6"))
    ]

    static func named(_ id: String) -> CozyTimerSkin {
        all.first { $0.id == id } ?? all[0]
    }

    static func id(matching rewardName: String) -> String? {
        let normalized = rewardName
            .replacingOccurrences(of: " Timer Skin", with: "")
            .replacingOccurrences(of: " Skin", with: "")
        return all.first { $0.title.localizedCaseInsensitiveCompare(normalized) == .orderedSame }?.id
    }
}

enum CozyTimerShape: String, CaseIterable, Identifiable {
    case ring
    case capsule
    case hourglass

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ring: "Ring"
        case .capsule: "Pill"
        case .hourglass: "Hourglass"
        }
    }

    var symbolName: String {
        switch self {
        case .ring: "circle"
        case .capsule: "capsule.fill"
        case .hourglass: "hourglass"
        }
    }
}

enum CozyQuoteStyle: String, CaseIterable, Identifiable {
    case cozy
    case study
    case bold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cozy: "Cozy"
        case .study: "Study"
        case .bold: "Bright"
        }
    }

    func quote(for phase: FocusPhase, minute: Int) -> String {
        let phaseIndex = switch phase {
        case .prepare: 0
        case .settling: 1
        case .deepFocus: 2
        case .finalMinute: 3
        case .wrap: 4
        case .breakTime: 5
        }
        let quotes: [String]
        switch self {
        case .cozy:
            quotes = [
                "One soft start is enough.",
                "Settle in. Mochi has the clock.",
                "Stay with the next tiny piece.",
                "Almost there. Land it gently.",
                "Save the win before moving on.",
                "Rest is part of the plan."
            ]
        case .study:
            quotes = [
                "Open the page. Start with one line.",
                "Make the next idea visible.",
                "Protect the focus lane.",
                "Finish the current thought.",
                "Log what changed.",
                "Reset the desk before the next block."
            ]
        case .bold:
            quotes = [
                "Start small. Keep going.",
                "Lock in for one clean block.",
                "You only need the next rep.",
                "Do not rush. Finish sharp.",
                "Claim the progress.",
                "Recharge, then choose again."
            ]
        }
        return quotes[(phaseIndex + max(0, minute / 10)) % quotes.count]
    }
}

struct CozyBackground: ViewModifier {
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let theme = CozyTheme.named(selectedTheme)
        content
            .background(
                ZStack {
                    if colorScheme == .dark {
                        LinearGradient(
                            colors: [
                                CozyPalette.darkCanvas,
                                Color(hex: "#1F1924"),
                                theme.accent.opacity(0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        LinearGradient(
                            colors: [
                                theme.canvas,
                                Color(hex: "#FFFDF9"),
                                theme.surfaceTint.opacity(selectedTheme == "Night Lofi" ? 0.26 : 0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .ignoresSafeArea()
            )
    }
}

struct ThemeSwatch: View {
    @Environment(\.colorScheme) private var colorScheme
    let theme: CozyTheme
    var isSelected = false

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(theme.secondary.opacity(0.55))
                Image(systemName: theme.symbolName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.tintedText(colorScheme))
            }
            .frame(width: 28, height: 28)
            Text(theme.id)
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? theme.secondary.opacity(0.28) : Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? theme.accent.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: 1)
        )
        .accessibilityLabel(theme.id)
    }
}

struct CozyPressButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.985
    var hoverScale: CGFloat = 1.006

    func makeBody(configuration: Configuration) -> some View {
        CozyPressButton(configuration: configuration, pressedScale: pressedScale, hoverScale: hoverScale)
    }

    private struct CozyPressButton: View {
        let configuration: ButtonStyle.Configuration
        let pressedScale: CGFloat
        let hoverScale: CGFloat

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var isHovering = false
        @FocusState private var isFocused: Bool

        private var scale: CGFloat {
            guard !reduceMotion else { return 1 }
            if configuration.isPressed { return pressedScale }
            if isHovering { return hoverScale }
            return 1
        }

        var body: some View {
            configuration.label
                .scaleEffect(scale)
                .brightness(configuration.isPressed ? -0.018 : 0)
                .contentShape(Rectangle())
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isFocused ? CozyPalette.focusJade.opacity(0.72) : Color.clear, lineWidth: 2)
                }
                .focusable(true)
                .focused($isFocused)
                .focusEffectDisabled()
                .animation(.snappy(duration: 0.14), value: configuration.isPressed)
                .animation(.snappy(duration: 0.16), value: isHovering)
                .onHover { isHovering = $0 }
        }
    }
}

struct CozyIconButtonStyle: ButtonStyle {
    var size: CGFloat = CozyLayout.hitSize

    func makeBody(configuration: Configuration) -> some View {
        CozyIconButton(configuration: configuration, size: size)
    }

    private struct CozyIconButton: View {
        let configuration: ButtonStyle.Configuration
        let size: CGFloat

        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
        @State private var isHovering = false
        @FocusState private var isFocused: Bool

        private var theme: CozyTheme {
            CozyTheme.named(selectedTheme)
        }

        var body: some View {
            configuration.label
                .font(.callout.weight(.bold))
                .foregroundStyle(isEnabled ? theme.accent : CozyPalette.secondaryText(colorScheme).opacity(0.6))
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous)
                        .fill(backgroundFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous)
                        .stroke(iconBorder, lineWidth: isFocused && isEnabled ? 2 : 1)
                )
                .scaleEffect(!reduceMotion && configuration.isPressed ? 0.96 : 1)
                .opacity(isEnabled ? 1 : 0.58)
                .contentShape(RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous))
                .focused($isFocused)
                .focusable(true)
                .focusEffectDisabled()
                .animation(.snappy(duration: 0.14), value: configuration.isPressed)
                .animation(.snappy(duration: 0.16), value: isHovering)
                .onHover { isHovering = $0 }
        }

        private var iconBorder: Color {
            guard isEnabled else { return CozyPalette.cardBorder(colorScheme) }
            if isFocused { return theme.accent.opacity(0.82) }
            return isHovering ? theme.accent.opacity(0.38) : CozyPalette.cardBorder(colorScheme)
        }

        private var backgroundFill: Color {
            if configuration.isPressed {
                return theme.secondary.opacity(colorScheme == .dark ? 0.20 : 0.52)
            }
            if isHovering && isEnabled {
                return theme.secondary.opacity(colorScheme == .dark ? 0.15 : 0.36)
            }
            return CozyPalette.raisedFill(colorScheme)
        }
    }
}

enum CozyButtonKind {
    case primary
    case secondary
    case destructive
    case ghost
}

struct CozyActionButtonStyle: ButtonStyle {
    var kind: CozyButtonKind = .secondary
    var minWidth: CGFloat? = nil
    var minHeight: CGFloat = CozyLayout.controlHeight
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        CozyActionButton(
            configuration: configuration,
            kind: kind,
            minWidth: minWidth,
            minHeight: minHeight,
            fullWidth: fullWidth
        )
    }

    private struct CozyActionButton: View {
        let configuration: ButtonStyle.Configuration
        let kind: CozyButtonKind
        let minWidth: CGFloat?
        let minHeight: CGFloat
        let fullWidth: Bool

        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
        @State private var isHovering = false
        @FocusState private var isFocused: Bool

        private var theme: CozyTheme {
            CozyTheme.named(selectedTheme)
        }

        var body: some View {
            configuration.label
                .font(CozyType.controlStrong)
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .foregroundStyle(foreground)
                .padding(.horizontal, 16)
                .frame(
                    minWidth: minWidth,
                    maxWidth: fullWidth ? .infinity : nil,
                    minHeight: minHeight,
                    alignment: .center
                )
                .background(
                    RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous)
                        .fill(background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous)
                        .stroke(border, lineWidth: isFocused && isEnabled ? 2 : 1)
                )
                .shadow(color: shadow, radius: kind == .primary && isEnabled ? 10 : 0, y: kind == .primary && isEnabled ? 4 : 0)
                .scaleEffect(!reduceMotion && configuration.isPressed ? 0.985 : 1)
                .contentShape(RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous))
                .focused($isFocused)
                .focusable(true)
                .focusEffectDisabled()
                .animation(.snappy(duration: 0.14), value: configuration.isPressed)
                .animation(.snappy(duration: 0.16), value: isHovering)
                .onHover { isHovering = $0 }
        }

        private var foreground: Color {
            guard isEnabled else { return CozyPalette.secondaryText(colorScheme) }
            switch kind {
            case .primary:
                return theme.foregroundOnAccent(colorScheme)
            case .destructive:
                return CozyPalette.overdue
            case .secondary, .ghost:
                return theme.accent
            }
        }

        private var background: Color {
            guard isEnabled else { return CozyPalette.quietContainer(colorScheme) }
            switch kind {
            case .primary:
                let base = configuration.isPressed ? theme.accent.opacity(0.90) : theme.accent
                return isHovering ? base.opacity(0.94) : base
            case .secondary:
                let opacity = isHovering || configuration.isPressed ? 0.48 : 0.24
                return theme.secondary.opacity(colorScheme == .dark ? opacity * 0.60 : opacity)
            case .destructive:
                return CozyPalette.overdue.opacity(isHovering || configuration.isPressed ? 0.16 : 0.10)
            case .ghost:
                return isHovering || configuration.isPressed ? theme.secondary.opacity(colorScheme == .dark ? 0.13 : 0.28) : .clear
            }
        }

        private var border: Color {
            guard isEnabled else { return CozyPalette.cardBorder(colorScheme) }
            if isFocused { return theme.accent.opacity(0.82) }
            switch kind {
            case .primary:
                return isHovering ? Color.white.opacity(0.30) : theme.accent.opacity(0.26)
            case .secondary:
                return isHovering ? theme.accent.opacity(0.38) : theme.accent.opacity(0.18)
            case .destructive:
                return CozyPalette.overdue.opacity(isHovering ? 0.40 : 0.20)
            case .ghost:
                return isHovering ? theme.accent.opacity(0.24) : .clear
            }
        }

        private var shadow: Color {
            guard isEnabled else { return .clear }
            return theme.accent.opacity(colorScheme == .dark ? 0.20 : 0.16)
        }
    }
}

struct CozyToggleRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName

    let title: String
    var symbolName: String?
    var subtitle: String?
    @Binding var isOn: Bool

    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.callout.weight(.bold))
                        .frame(width: 22, alignment: .center)
                        .foregroundStyle(isOn ? theme.accent : CozyPalette.secondaryText(colorScheme))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(CozyType.controlStrong)
                        .foregroundStyle(CozyPalette.primaryText(colorScheme))
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(CozyType.caption)
                            .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 10)
                switchTrack
            }
            .padding(.horizontal, 12)
            .padding(.vertical, subtitle == nil ? 9 : 10)
            .frame(maxWidth: .infinity, minHeight: CozyLayout.controlHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: isFocused && isEnabled ? 2 : isHovering && isEnabled ? 1.35 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .focused($isFocused)
        .focusable(true)
        .focusEffectDisabled()
        .onHover { isHovering = $0 }
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }

    private var switchTrack: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            // T2.2: OFF-state track was CozyPalette.cardBorder which renders
            // at ~1.8:1 against darkRaised — below the WCAG AA 3:1 floor for
            // non-text UI. Switch to secondaryText@0.55 which is pre-tuned
            // to 3:1+ in both color schemes.
            Capsule()
                .fill(isOn ? theme.accent : CozyPalette.secondaryText(colorScheme).opacity(0.55))
                .frame(width: 48, height: 28)
            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
                .padding(.horizontal, 4)
                .shadow(color: Color.black.opacity(0.12), radius: 3, y: 1)
        }
    }

    private var backgroundFill: Color {
        guard isEnabled else { return CozyPalette.quietContainer(colorScheme).opacity(0.68) }
        if isHovering { return CozyPalette.quietContainer(colorScheme) }
        return CozyPalette.raisedFill(colorScheme)
    }

    private var borderColor: Color {
        guard isEnabled else { return CozyPalette.cardBorder(colorScheme).opacity(0.70) }
        if isFocused { return theme.accent.opacity(0.82) }
        return isHovering ? theme.accent.opacity(0.38) : CozyPalette.cardBorder(colorScheme)
    }
}

struct CozyDisclosureSection<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName

    let title: String
    var symbolName: String?
    @Binding var isExpanded: Bool
    @ViewBuilder var content: Content

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    if let symbolName {
                        Image(systemName: symbolName)
                    }
                    Text(title)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .font(CozyType.captionStrong)
                .foregroundStyle(isExpanded ? theme.accent : CozyPalette.secondaryText(colorScheme))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: CozyLayout.compactControlHeight, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous)
                        .fill(isExpanded ? theme.secondary.opacity(colorScheme == .dark ? 0.14 : 0.30) : CozyPalette.quietContainer(colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous)
                        .stroke(isExpanded ? theme.accent.opacity(0.26) : CozyPalette.cardBorder(colorScheme), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

            if isExpanded {
                content
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
                    .transition(.opacity)
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let red: UInt64
        let green: UInt64
        let blue: UInt64
        let alpha: UInt64

        switch cleaned.count {
        case 3:
            red = (int >> 8) * 17
            green = ((int >> 4) & 0xF) * 17
            blue = (int & 0xF) * 17
            alpha = 255
        case 6:
            red = int >> 16
            green = (int >> 8) & 0xFF
            blue = int & 0xFF
            alpha = 255
        case 8:
            red = int >> 24
            green = (int >> 16) & 0xFF
            blue = (int >> 8) & 0xFF
            alpha = int & 0xFF
        default:
            red = 255
            green = 255
            blue = 255
            alpha = 255
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }

    /// Linear interpolation in sRGB between this color and `other`. `amount` 0 = self,
    /// 1 = other. Used by `CozyTheme.tintedText(_:)` to lift accent colors toward
    /// `darkText` for WCAG AA contrast on dark surfaces.
    func cozyMix(with other: Color, amount: Double) -> Color {
        let clampedAmount = max(0, min(1, amount))
        let selfNS = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let otherNS = NSColor(other).usingColorSpace(.sRGB) ?? NSColor(other)
        let r = selfNS.redComponent + (otherNS.redComponent - selfNS.redComponent) * CGFloat(clampedAmount)
        let g = selfNS.greenComponent + (otherNS.greenComponent - selfNS.greenComponent) * CGFloat(clampedAmount)
        let b = selfNS.blueComponent + (otherNS.blueComponent - selfNS.blueComponent) * CGFloat(clampedAmount)
        let a = selfNS.alphaComponent + (otherNS.alphaComponent - selfNS.alphaComponent) * CGFloat(clampedAmount)
        return Color(.sRGB, red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
    }
}

struct CozyCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    // UX LOW #108 — honor Increase Contrast in System Settings → Accessibility.
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let fill = CozyPalette.cardFill(colorScheme).opacity(reduceTransparency ? 1 : (colorScheme == .dark ? 0.98 : 0.97))

        content
            .padding(CozyLayout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
                            .stroke(CozyPalette.cardBorder(colorScheme, contrast: contrast), lineWidth: 1)
                    )
            )
            // Two-shadow elevation per Refactoring UI: tight crisp shadow for the
            // edge crisis + larger soft shadow for atmospheric depth. Single
            // shadows read as flat-with-blur; pairs read as elevated objects.
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.04), radius: 1, y: 1)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.055), radius: 10, y: 3)
            .foregroundStyle(CozyPalette.primaryText(colorScheme))
    }
}

// CozyFlatPanel — the third elevation rung. For panels INSIDE a cozyCard
// (e.g. the inner stats strip in FirstSessionCard, the boost detail row in
// FocusSetupCard). No shadow, hairline border, smaller padding. Formalizes
// the de facto third rung that was previously hard-coded inline as
// RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous) across ~12 sites.
struct CozyFlatPanel: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    // UX LOW #108 — Increase Contrast bumps the hairline so the inner panel
    // pops away from its parent card.
    @Environment(\.colorSchemeContrast) private var contrast
    var radius: CGFloat = CozyLayout.controlRadius
    var paddingValue: CGFloat = 12

    func body(content: Content) -> some View {
        let borderOpacity: Double = contrast == .increased ? 0.85 : 0.6
        content
            .padding(paddingValue)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(CozyPalette.raisedFill(colorScheme).opacity(colorScheme == .dark ? 0.45 : 0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(CozyPalette.cardBorder(colorScheme).opacity(borderOpacity), lineWidth: 0.5)
            )
            .foregroundStyle(CozyPalette.primaryText(colorScheme))
    }
}

struct CozyHeroCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    // UX LOW #108 — Increase Contrast deepens the hero-card outline against
    // the gradient fill so the card edge stays readable.
    @Environment(\.colorSchemeContrast) private var contrast
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName

    func body(content: Content) -> some View {
        let theme = CozyTheme.named(selectedTheme)
        content
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: colorScheme == .dark
                                        ? [Color(hex: "#302737"), Color(hex: "#211C24"), theme.accent.opacity(0.34)]
                                        : [Color.white, theme.surfaceTint.opacity(0.30), CozyPalette.softSage.opacity(0.22)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(CozyPalette.cardBorder(colorScheme, contrast: contrast), lineWidth: 1)
                            )
            )
            // Two-shadow elevation per Refactoring UI — see CozyCard.
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.06), radius: 2, y: 2)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.08), radius: 22, y: 10)
            .foregroundStyle(CozyPalette.primaryText(colorScheme))
    }
}

struct CozyPageFrame: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(CozyLayout.pagePadding)
            .frame(maxWidth: CozyLayout.pageMaxWidth, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
    }
}

struct CompactDashboardTile: ViewModifier {
    // SwiftUI Grid / LazyVGrid rules: per-row line-up requires every sibling tile
    // to share maxHeight. Without the infinity ceiling, the row collapses to the
    // tallest card's minHeight + the shortest card's intrinsic content height,
    // leaving the row jagged. Apple Grid docs:
    // https://developer.apple.com/documentation/swiftui/grid
    func body(content: Content) -> some View {
        content
            .frame(minHeight: CozyLayout.compactTileMinHeight, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct CozyFieldShell: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName

    var minWidth: CGFloat?
    var width: CGFloat?
    // Default to the regular control height (44pt). Previously 38 made `CozyFieldShell`-
    // wrapped controls (date picker pop button, menu pickers, steppers' outer shell) end
    // up shorter than sibling text fields / primary buttons in the same form row.
    var minHeight: CGFloat = CozyLayout.controlHeight
    var alignment: Alignment = .center
    var isTextInput = false

    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if isTextInput {
            decorated(content.textFieldStyle(.plain).focused($isFocused))
        } else {
            // Wire focused-state on non-text shells too (Menu task picker, CozyDateInput,
            // disclosure rows) so the custom theme-accent border lights up under keyboard
            // navigation. Without this the cozy halo was dead and macOS would draw its
            // default electric-blue ring instead. (F-08 from focus/hover audit.)
            decorated(content.focusable().focused($isFocused).focusEffectDisabled())
        }
    }

    @ViewBuilder
    private func decorated<V: View>(_ content: V) -> some View {
        let field = content
            .font(CozyType.control)
            .foregroundStyle(CozyPalette.primaryText(colorScheme))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

        if let width {
            field
                .frame(minWidth: width, maxWidth: width, minHeight: minHeight, alignment: alignment)
                .fieldDecoration(isEnabled: isEnabled, isHovering: isHovering, isFocused: isFocused, borderColor: borderColor, colorScheme: colorScheme)
                .onHover { isHovering = $0 }
        } else {
            field
                .frame(minWidth: minWidth, minHeight: minHeight, alignment: alignment)
                .fieldDecoration(isEnabled: isEnabled, isHovering: isHovering, isFocused: isFocused, borderColor: borderColor, colorScheme: colorScheme)
                .onHover { isHovering = $0 }
        }
    }

    private var borderColor: Color {
        guard isEnabled else { return CozyPalette.cardBorder(colorScheme).opacity(0.70) }
        if isFocused { return theme.accent.opacity(0.78) }
        return isHovering ? theme.accent.opacity(0.42) : CozyPalette.cardBorder(colorScheme)
    }
}

private struct CozyFieldDecoration: ViewModifier {
    let isEnabled: Bool
    let isHovering: Bool
    let isFocused: Bool
    let borderColor: Color
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous)
                    .fill(isEnabled ? CozyPalette.raisedFill(colorScheme) : CozyPalette.quietContainer(colorScheme).opacity(0.62))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: (isFocused || isHovering) && isEnabled ? 1.35 : 1)
            )
            .shadow(color: isFocused ? borderColor.opacity(0.16) : .clear, radius: 8, y: 0)
            .opacity(isEnabled ? 1 : 0.62)
            .contentShape(RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous))
    }
}

private extension View {
    func fieldDecoration(
        isEnabled: Bool,
        isHovering: Bool,
        isFocused: Bool,
        borderColor: Color,
        colorScheme: ColorScheme
    ) -> some View {
        modifier(CozyFieldDecoration(
            isEnabled: isEnabled,
            isHovering: isHovering,
            isFocused: isFocused,
            borderColor: borderColor,
            colorScheme: colorScheme
        ))
    }
}

struct CozyFormCaption: View {
    let title: String
    var symbolName: String?

    var body: some View {
        HStack(spacing: 8) {
            if let symbolName {
                Image(systemName: symbolName)
                    .frame(width: 14, alignment: .center)
            }
            Text(title.uppercased())
                .lineLimit(1)
                .truncationMode(.tail)
                .fixedSize(horizontal: true, vertical: false)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)
        .frame(minHeight: 17, alignment: .leading)
        .accessibilityLabel(title)
    }
}

struct CozyLabeledControl<Content: View>: View {
    let title: String
    var symbolName: String?
    var minWidth: CGFloat?
    var spacing: CGFloat = 6
    var hint: String?
    var hintIsError: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            CozyFormCaption(title: title, symbolName: symbolName)
            content
            // Reserve a fixed hint slot on every labeled control so sibling columns in a form row
            // share the same vertical extent. Invisible when no hint is supplied, but still
            // occupies the row so HStack(alignment: .top) places the controls at matched Y.
            CozyFieldHint(text: hint ?? " ", isError: hintIsError)
                .opacity(hint == nil ? 0 : 1)
                .accessibilityHidden(hint == nil)
        }
        .frame(minWidth: minWidth ?? CozyLayout.labeledControlMinWidth, alignment: .leading)
    }
}

/// Overlays an Escape-key-shortcut close button on a sheet's top-trailing
/// corner. Sheets without this leave non-keyboard users with no obvious
/// way to dismiss — the user got stuck inside the countdown composer
/// because the sheet had neither a visible X nor an Escape shortcut.
struct CozySheetDismissAffordance: ViewModifier {
    let dismiss: () -> Void
    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)   // Escape dismisses too.
            .help("Close")
            .accessibilityLabel("Close")
            .accessibilityIdentifier("sheet.close")
        }
    }
}

struct CozyFieldHint: View {
    let text: String
    var isError = false

    var body: some View {
        Label(text, systemImage: isError ? "exclamationmark.circle.fill" : "info.circle.fill")
            .font(CozyType.captionStrong)
            .foregroundStyle(isError ? CozyPalette.overdue : .secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct CozySegmentOption<Value: Hashable>: Identifiable {
    let id: Value
    let title: String
    let symbolName: String?

    init(_ id: Value, title: String, symbolName: String? = nil) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
    }
}

struct CozySegmentedControl<Value: Hashable>: View {
    @Environment(\.colorScheme) private var colorScheme
    // UX LOW #108 — Increase Contrast sharpens the segmented-control track
    // so the unselected state isn't a near-invisible chip on canvas.
    @Environment(\.colorSchemeContrast) private var contrast
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName

    let options: [CozySegmentOption<Value>]
    @Binding var selection: Value
    var minSegmentWidth: CGFloat = 86

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                Button {
                    selection = option.id
                } label: {
                    HStack(spacing: 6) {
                        if let symbolName = option.symbolName {
                            Image(systemName: symbolName)
                        }
                        Text(option.title)
                    }
                    .frame(minWidth: minSegmentWidth, minHeight: CozyLayout.compactControlHeight)
                    .padding(.horizontal, 8)
                    .contentShape(RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .font(CozyType.controlStrong)
                .foregroundStyle(selection == option.id ? theme.foregroundOnAccent(colorScheme) : CozyPalette.primaryText(colorScheme))
                .background(
                    RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous)
                        .fill(selection == option.id ? theme.accent : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous)
                        .stroke(selection == option.id ? theme.accent.opacity(0.32) : Color.clear, lineWidth: 1)
                )
                .accessibilityAddTraits(selection == option.id ? .isSelected : AccessibilityTraits())
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(CozyPalette.quietContainer(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(CozyPalette.cardBorder(colorScheme, contrast: contrast), lineWidth: 1)
        )
    }
}

// CozyPill — the canonical status / category indicator. Material 3 reserves
// chips for *interactive* selection and Polaris reserves "badge" for *static*
// status — this is the static badge variant. 14% / 22% (dark) fill tint with
// full-opacity foreground keeps the type readable at AA.
struct CozyPill: View {
    enum Intent: Equatable {
        case info, success, warning, danger, neutral
        case accent(Color)
    }

    enum Size {
        case small, regular

        var height: CGFloat { self == .small ? 22 : 28 }
        var hPad: CGFloat { self == .small ? 8 : 12 }
        var spacing: CGFloat { self == .small ? 4 : 6 }
        var font: Font {
            // Small uses caption2 bold (status pip on a card); regular uses
            // caption bold (eyebrow on a hero / row).
            self == .small ? .caption2.weight(.bold) : .caption.weight(.bold)
        }
        var symbolFontSize: CGFloat { self == .small ? 9 : 11 }
    }

    @Environment(\.colorScheme) private var colorScheme
    let title: String
    var symbolName: String? = nil
    var intent: Intent = .neutral
    var size: Size = .regular
    var uppercased: Bool = false

    private var tint: Color {
        switch intent {
        case .info:    return CozyPalette.skyBlue
        case .success: return CozyPalette.focusJade
        case .warning: return CozyPalette.persimmon
        case .danger:  return CozyPalette.overdue
        case .neutral: return CozyPalette.secondaryText(colorScheme)
        case .accent(let c): return c
        }
    }

    private var displayTitle: String {
        uppercased ? title.uppercased() : title
    }

    var body: some View {
        HStack(spacing: size.spacing) {
            if let symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: size.symbolFontSize, weight: .bold))
            }
            Text(displayTitle)
                .font(size.font)
                .tracking(uppercased ? 0.5 : 0)
                .lineLimit(1)
        }
        .padding(.horizontal, size.hPad)
        .frame(height: size.height)
        .foregroundStyle(tint)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(colorScheme == .dark ? 0.22 : 0.14))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(displayTitle)
    }
}

// CozyDurationChip — the unit of the CozyDurationPicker. Selection-only (chips
// never auto-start). Capsule shape + 38pt height (compactControlHeight) is
// the modern wellness-app pattern (Calm, Finch, Headspace) — Material 3's chip
// guidance and Carbon's tag spec both put pills under 44pt to read as
// "selectable filter," not "primary CTA."
//
// Equatable conformance lets SwiftUI skip the body recomputation on chips
// whose `isSelected` didn't change during a slider drag. With 4 chips on
// screen and the slider crossing many integer thresholds per second, only
// the chip that gained or lost selection re-renders.
struct CozyDurationChip: View, Equatable {
    nonisolated static func == (lhs: CozyDurationChip, rhs: CozyDurationChip) -> Bool {
        lhs.minutes == rhs.minutes
            && lhs.symbolName == rhs.symbolName
            && lhs.isSelected == rhs.isSelected
            && lhs.accent == rhs.accent
    }

    @Environment(\.colorScheme) private var colorScheme
    let minutes: Int
    let symbolName: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbolName)
                    .font(.caption.weight(.black))
                Text("\(minutes)m")
                    .font(.callout.weight(.bold))
                    .monospacedDigit()
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: CozyLayout.compactControlHeight)
            .foregroundStyle(isSelected ? Color.white : accent)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? accent : accent.opacity(colorScheme == .dark ? 0.18 : 0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.30) : accent.opacity(0.30),
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .cozyPressable(pressedScale: 0.965, hoverScale: 1.015)
        .accessibilityLabel("\(minutes) minutes\(isSelected ? ", selected" : "")")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// CozyDurationPicker — chip row + slider + live readout. One canonical
// duration-selection surface used on the Today hero card AND the Focus setup
// card. The pattern (presets + slider + readout) is what Calm, Headspace,
// Forest, and Bear Focus all converge on; chips alone aren't enough above ~30
// minutes, and free slider alone makes 25-min the hard-to-hit needle.
//
// Performance: high-frequency slider state lives in CozyDurationSliderControl,
// a tiny child view. Dragging the thumb no longer invalidates preset chips,
// ViewThatFits, parent hero cards, or adjacent mascot panels.
struct CozyDurationPicker: View {
    struct Preset {
        let minutes: Int
        let symbol: String
    }

    @Binding var minutes: Int
    var accent: Color = CozyPalette.focusJade
    var presets: [Preset] = [
        Preset(minutes: 5, symbol: "bolt.fill"),
        Preset(minutes: 15, symbol: "timer"),
        Preset(minutes: 25, symbol: "timer"),
        Preset(minutes: 50, symbol: "moon.stars.fill")
    ]
    var range: ClosedRange<Int> = 1...180
    var identifierPrefix: String? = nil
    var compactChipMinWidth: CGFloat = 84

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { chipRow }
                LazyVGrid(columns: CozyLayout.adaptiveColumns(minimum: compactChipMinWidth), spacing: 8) {
                    chipRow
                }
            }

            CozyDurationSliderControl(
                committedMinutes: minutes,
                accent: accent,
                range: range,
                identifier: identifierPrefix.map { "\($0).customMinutes" } ?? "duration.slider"
            ) { newMinutes in
                minutes = newMinutes
            }
        }
    }

    @ViewBuilder
    private var chipRow: some View {
        ForEach(Array(presets.enumerated()), id: \.offset) { _, preset in
            CozyDurationChip(
                minutes: preset.minutes,
                symbolName: preset.symbol,
                isSelected: minutes == preset.minutes,
                accent: accent
            ) {
                minutes = preset.minutes   // chip tap = immediate commit
            }
            .applyingIfLet(identifierPrefix) { view, prefix in
                view.accessibilityIdentifier("\(prefix).select.\(preset.minutes)")
            }
        }
    }
}

private struct CozyDurationSliderControl: View {
    let committedMinutes: Int
    let accent: Color
    let range: ClosedRange<Int>
    let identifier: String
    let onCommit: (Int) -> Void

    @State private var sliderPosition: Double = 25
    @State private var isDraggingSlider = false

    private var liveMinutes: Int {
        max(range.lowerBound,
            min(range.upperBound, Int(sliderPosition.rounded())))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Label(CozyFormatters.durationLabel(TimeInterval(liveMinutes * 60)), systemImage: "slider.horizontal.3")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .monospacedDigit()
                Spacer(minLength: 8)
                Text(rangeLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            sliderRow
                .controlSize(.small)
                .tint(accent)
                .accessibilityLabel("Focus duration")
                .accessibilityValue("\(liveMinutes) minutes")
                .accessibilityIdentifier(identifier)
        }
        .animation(nil, value: sliderPosition)
        .onAppear { sliderPosition = Double(committedMinutes) }
        .onChange(of: committedMinutes) { _, newValue in
            if !isDraggingSlider && Int(sliderPosition.rounded()) != newValue {
                sliderPosition = Double(newValue)
            }
        }
    }

    private var sliderRow: some View {
        Slider(
            value: $sliderPosition,
            in: Double(range.lowerBound)...Double(range.upperBound),
            onEditingChanged: { editing in
                isDraggingSlider = editing
                guard !editing else { return }
                let snapped = liveMinutes
                sliderPosition = Double(snapped)
                if snapped != committedMinutes {
                    onCommit(snapped)
                }
            },
            minimumValueLabel: sliderEndLabel(range.lowerBound),
            maximumValueLabel: sliderEndLabel(range.upperBound),
            label: { Text("Focus duration") }
        )
    }

    private func sliderEndLabel(_ value: Int) -> some View {
        Text("\(value)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }

    private var rangeLabel: String {
        if range == 1...180 { return "1m – 3h" }
        let lower = range.lowerBound
        let upper = range.upperBound
        return "\(lower)m – \(upper)m"
    }
}

// Tiny conditional-modifier helper — applies the trailing transform only when
// the optional value is non-nil. Used by CozyDurationPicker to attach an
// accessibility identifier to each chip only when a prefix is supplied.
private extension View {
    @ViewBuilder
    func applyingIfLet<T, V: View>(_ value: T?, transform: (Self, T) -> V) -> some View {
        if let value { transform(self, value) } else { self }
    }
}

struct CozyStepperField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    var valueText: (Int) -> String = { "\($0)" }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                value = max(range.lowerBound, value - step)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 18, height: 18)
            }
            .cozyIconButton(size: CozyLayout.compactHitSize)
            .disabled(value <= range.lowerBound)
            .accessibilityLabel("Decrease")

            Text(valueText(value))
                .font(CozyType.controlStrong)
                .monospacedDigit()
                .frame(minWidth: 64)

            Button {
                value = min(range.upperBound, value + step)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 18, height: 18)
            }
            .cozyIconButton(size: CozyLayout.compactHitSize)
            .disabled(value >= range.upperBound)
            .accessibilityLabel("Increase")
        }
        .padding(.horizontal, 8)
        .frame(minHeight: CozyLayout.controlHeight)
        .cozyControlShell(alignment: .center)
        .accessibilityValue(valueText(value))
    }
}

struct CozyDateQuickChoice: Identifiable {
    let id: String
    let title: String
    let daysFromToday: Int

    init(_ title: String, daysFromToday: Int) {
        self.id = "\(title)-\(daysFromToday)"
        self.title = title
        self.daysFromToday = daysFromToday
    }
}

struct CozyDateInput: View {
    @Binding var date: Date
    var label: String = "Date"
    var quickChoices: [CozyDateQuickChoice] = [
        CozyDateQuickChoice("Tomorrow", daysFromToday: 1),
        CozyDateQuickChoice("7 days", daysFromToday: 7),
        CozyDateQuickChoice("30 days", daysFromToday: 30)
    ]
    /// When false, the quick-pick chips are NOT rendered inline beneath the
    /// date button — the caller is responsible for placing them. Used by the
    /// countdown composer so the chips become a full-width row instead of
    /// overrunning the DATE column's height next to the ACTION button.
    var includeInlineQuickChoices: Bool = true

    @Environment(\.colorScheme) private var colorScheme
    @State private var showsCalendar = false
    @State private var visibleMonth = Date()

    private var calendar: Calendar {
        .autoupdatingCurrent
    }

    private var displayText: String {
        CozyFormatters.shortDate.string(from: date)
    }

    private var isPastDate: Bool {
        calendar.startOfDay(for: date) < calendar.startOfDay(for: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                visibleMonth = monthStart(for: date)
                showsCalendar.toggle()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .foregroundStyle(CozyPalette.berry)
                    Text(displayText)
                        .font(CozyType.controlStrong)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: showsCalendar ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: CozyLayout.controlHeight, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .cozyControlShell(minWidth: 190, alignment: .leading)
            .popover(isPresented: $showsCalendar, arrowEdge: .bottom) {
                calendarPopover
            }
            .accessibilityLabel(label)
            .accessibilityValue(displayText)

            if includeInlineQuickChoices {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        quickChoiceButtons
                    }
                    LazyVGrid(columns: CozyLayout.adaptiveColumns(minimum: 78), spacing: 8) {
                        quickChoiceButtons
                    }
                }
            }

            if isPastDate {
                CozyFieldHint(text: "Pick today or a future date.", isError: true)
            }
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: visibleMonth)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let first = max(0, calendar.firstWeekday - 1)
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    private var calendarDays: [CozyDateCell] {
        let monthStart = monthStart(for: visibleMonth)
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingEmptyDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [CozyDateCell] = (0..<leadingEmptyDays).map { CozyDateCell.empty(index: $0) }

        for day in dayRange {
            guard let cellDate = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            cells.append(CozyDateCell(date: cellDate, day: day))
        }

        while cells.count % 7 != 0 {
            cells.append(CozyDateCell.empty(index: cells.count))
        }
        return cells
    }

    private var canNavigateToPreviousMonth: Bool {
        monthStart(for: visibleMonth) > monthStart(for: Date())
    }

    /// Exposed so callers that suppress inline quick choices can lay them out
    /// in a different position (e.g. a separate row spanning multiple columns).
    @ViewBuilder
    var quickChoicesRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { quickChoiceButtons }
            LazyVGrid(columns: CozyLayout.adaptiveColumns(minimum: 78), spacing: 8) {
                quickChoiceButtons
            }
        }
    }

    @ViewBuilder
    private var quickChoiceButtons: some View {
        ForEach(quickChoices) { choice in
            Button(choice.title) {
                if let next = calendar.date(byAdding: .day, value: choice.daysFromToday, to: Date()) {
                    date = next
                }
            }
            .cozyGhostButton(minWidth: 66)
        }
    }

    private var calendarPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(CozyType.captionStrong)
                        .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                    Text(monthTitle)
                        .font(CozyType.cardTitle)
                        .foregroundStyle(CozyPalette.primaryText(colorScheme))
                }
                Spacer(minLength: 8)
                Button {
                    shiftVisibleMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 32, height: 32)
                }
                .cozyIconButton()
                .disabled(!canNavigateToPreviousMonth)
                .help("Previous month")
                Button {
                    shiftVisibleMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 32, height: 32)
                }
                .cozyIconButton()
                .help("Next month")
            }

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(36), spacing: 4), count: 7), spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(CozyType.badge)
                        .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                        .frame(width: 36, height: 24)
                }
                ForEach(calendarDays) { cell in
                    if let cellDate = cell.date {
                        dayButton(date: cellDate, day: cell.day)
                    } else {
                        Color.clear
                            .frame(width: 36, height: 36)
                    }
                }
            }

            HStack {
                Button("Today") {
                    date = Date()
                    visibleMonth = monthStart(for: date)
                    showsCalendar = false
                }
                .cozyGhostButton(minWidth: 80)
                Spacer()
                Button("Done") {
                    showsCalendar = false
                }
                .cozyPrimaryButton(minWidth: 92)
            }
        }
        .padding(16)
        .frame(width: 336)
        .background(CozyPalette.cardFill(colorScheme))
    }

    @ViewBuilder
    private func dayButton(date cellDate: Date, day: Int) -> some View {
        let disabled = calendar.startOfDay(for: cellDate) < calendar.startOfDay(for: Date())
        let selected = calendar.isDate(cellDate, inSameDayAs: date)
        let today = calendar.isDateInToday(cellDate)

        Button {
            date = cellDate
            showsCalendar = false
        } label: {
            Text("\(day)")
                .font(selected ? CozyType.controlStrong : CozyType.control)
                .foregroundStyle(dayForeground(selected: selected, disabled: disabled))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(dayFill(selected: selected, today: today))
                )
                .overlay(
                    Circle()
                        .stroke(today && !selected ? CozyPalette.berry.opacity(0.46) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(DateFormatter.localizedString(from: cellDate, dateStyle: .full, timeStyle: .none))
    }

    private func dayForeground(selected: Bool, disabled: Bool) -> Color {
        if selected { return CozyTheme.named(UserDefaults.standard.string(forKey: "selectedTheme") ?? CozyTheme.defaultName).foregroundOnAccent(colorScheme) }
        if disabled { return CozyPalette.secondaryText(colorScheme).opacity(0.38) }
        return CozyPalette.primaryText(colorScheme)
    }

    private func dayFill(selected: Bool, today: Bool) -> Color {
        if selected { return CozyTheme.named(UserDefaults.standard.string(forKey: "selectedTheme") ?? CozyTheme.defaultName).accent }
        if today { return CozyPalette.selectionFill.opacity(colorScheme == .dark ? 0.22 : 0.66) }
        return Color.clear
    }

    private func shiftVisibleMonth(by value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: visibleMonth) else { return }
        visibleMonth = monthStart(for: next)
    }

    private func monthStart(for value: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: value)
        return calendar.date(from: components) ?? value
    }
}

private struct CozyDateCell: Identifiable {
    let id: String
    let date: Date?
    let day: Int

    init(date: Date, day: Int) {
        self.id = "day-\(date.timeIntervalSinceReferenceDate)"
        self.date = date
        self.day = day
    }

    static func empty(index: Int) -> CozyDateCell {
        CozyDateCell(id: "empty-\(index)", date: nil, day: 0)
    }

    private init(id: String, date: Date?, day: Int) {
        self.id = id
        self.date = date
        self.day = day
    }
}

extension View {
    func cozyCard() -> some View {
        modifier(CozyCard())
    }

    func cozyHeroCard() -> some View {
        modifier(CozyHeroCard())
    }

    func cozyFlatPanel(radius: CGFloat = 10, padding: CGFloat = 12) -> some View {
        modifier(CozyFlatPanel(radius: radius, paddingValue: padding))
    }

    func cozyBackground() -> some View {
        modifier(CozyBackground())
    }

    func cozyPageFrame() -> some View {
        modifier(CozyPageFrame())
    }

    func compactDashboardTile() -> some View {
        modifier(CompactDashboardTile())
    }

    func cozyPressable(pressedScale: CGFloat = 0.985, hoverScale: CGFloat = 1.006) -> some View {
        buttonStyle(CozyPressButtonStyle(pressedScale: pressedScale, hoverScale: hoverScale))
    }

    func cozyIconButton(size: CGFloat = CozyLayout.hitSize) -> some View {
        buttonStyle(CozyIconButtonStyle(size: size))
    }

    func cozyPrimaryButton(minWidth: CGFloat? = CozyLayout.primaryButtonMinWidth, fullWidth: Bool = false) -> some View {
        buttonStyle(CozyActionButtonStyle(kind: .primary, minWidth: minWidth, fullWidth: fullWidth))
    }

    func cozySecondaryButton(minWidth: CGFloat? = nil, fullWidth: Bool = false) -> some View {
        buttonStyle(CozyActionButtonStyle(kind: .secondary, minWidth: minWidth, fullWidth: fullWidth))
    }

    func cozyDestructiveButton(minWidth: CGFloat? = nil, fullWidth: Bool = false) -> some View {
        buttonStyle(CozyActionButtonStyle(kind: .destructive, minWidth: minWidth, fullWidth: fullWidth))
    }

    func cozyGhostButton(minWidth: CGFloat? = nil, fullWidth: Bool = false) -> some View {
        buttonStyle(CozyActionButtonStyle(kind: .ghost, minWidth: minWidth, fullWidth: fullWidth))
    }

    func cozyTextInput(minWidth: CGFloat? = nil, width: CGFloat? = nil, minHeight: CGFloat = CozyLayout.controlHeight, alignment: Alignment = .center) -> some View {
        modifier(CozyFieldShell(minWidth: minWidth, width: width, minHeight: minHeight, alignment: alignment, isTextInput: true))
    }

    func cozyControlShell(minWidth: CGFloat? = nil, width: CGFloat? = nil, minHeight: CGFloat = CozyLayout.controlHeight, alignment: Alignment = .center) -> some View {
        modifier(CozyFieldShell(minWidth: minWidth, width: width, minHeight: minHeight, alignment: alignment))
    }
}

enum MascotState: String {
    case idle
    case settling
    case focus
    case deepFocus
    case landing
    case breakTime
    case complete
    case overdue
    case countdown

    var accessibilityLabel: String {
        switch self {
        case .idle: "The desk buddy is ready."
        case .settling: "The desk buddy is settling into focus."
        case .focus: "The desk buddy is focusing."
        case .deepFocus: "The desk buddy is in deep focus."
        case .landing: "The desk buddy is landing the final minute."
        case .breakTime: "The desk buddy is taking a break."
        case .complete: "The desk buddy is celebrating a small win."
        case .overdue: "The desk buddy is gently reminding you."
        case .countdown: "The desk buddy is preparing for an event."
        }
    }

    // Exact state name used to look up an image asset.
    var assetKey: String { rawValue }

    // Coarser category for the minimum-viable artist set — most projects only
    // ship idle / focus / complete and let the rest fall back. Lookup tries
    // the exact `assetKey` first, then this `categoryKey`.
    var categoryKey: String {
        switch self {
        case .idle, .countdown, .overdue, .breakTime: "idle"
        case .settling, .focus, .deepFocus, .landing: "focus"
        case .complete: "complete"
        }
    }
}

enum MascotMoment {
    case morning
    case daytime
    case evening
    case night

    static func current(at date: Date) -> MascotMoment {
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: date)
        switch hour {
        case 5..<11: return .morning
        case 11..<17: return .daytime
        case 17..<21: return .evening
        default: return .night
        }
    }

    var accent: Color {
        switch self {
        case .morning: CozyPalette.peach
        case .daytime: CozyPalette.mistBlue
        case .evening: CozyPalette.stickerPink
        case .night: CozyPalette.plum
        }
    }

    var symbolName: String {
        switch self {
        case .morning: "sunrise.fill"
        case .daytime: "sparkles"
        case .evening: "sunset.fill"
        case .night: "moon.stars.fill"
        }
    }
}

// MascotSize — researched recipe E. Five canonical rungs replace 11 magic
// numbers (52/56/58/62/70/72/96/100/112/128/136) across the codebase. Sanrio
// chibi convention favors a tight head:body ratio at every size, so consistent
// frames keep Mochi's silhouette legible. Use the enum at call-sites:
//   MascotView(state: .idle, size: .card)
// The CGFloat init stays for one-off custom sizes that don't fit the ladder.
enum MascotSize {
    case inline    // 28 — status row / sidebar pip
    case avatar    // 56 — list-item leading icon / completion row
    case card      // 88 — inside a cozyCard / section header
    case hero      // 128 — first-session / running-companion / empty-state spotlight
    case spotlight // 176 — reserved for true full-bleed onboarding moments

    var points: CGFloat {
        switch self {
        case .inline: 28
        case .avatar: 56
        case .card: 88
        case .hero: 128
        case .spotlight: 176
        }
    }
}

struct MascotView: View {
    let state: MascotState
    var size: CGFloat = 96
    var styleIDOverride: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("reducedDecoration") private var reducedDecoration = false
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    @AppStorage("selectedMascotStyle") private var selectedMascotStyle = CozyMascotStyle.defaultID

    private var accent: Color {
        let themeAccent = CozyTheme.named(selectedTheme).accent
        return switch state {
        case .idle: CozyPalette.mistBlue
        case .settling: CozyPalette.softMint
        case .focus, .deepFocus: themeAccent
        case .landing: CozyPalette.peach
        case .breakTime: CozyPalette.peach
        case .complete: CozyPalette.persimmon
        case .overdue: CozyPalette.overdue
        case .countdown: CozyPalette.stickerPink
        }
    }

    private var styleID: String {
        CozyMascotStyle.named(styleIDOverride ?? selectedMascotStyle).id
    }

    private var usesLottieBody: Bool {
        guard !reduceMotion,
              !reducedDecoration,
              Self.firstMatchingAsset(styleID: styleID, state: state) == nil,
              let lottieCharacter = CozyLottieMascot.lottiePrefix(forStyleID: styleID)
        else {
            return false
        }
        return CozyLottieMascot.isBundled(character: lottieCharacter)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30 * 60)) { context in
            mascot(moment: MascotMoment.current(at: context.date))
        }
    }

    private func mascot(moment: MascotMoment) -> some View {
        ZStack {
            // No backdrop shape — the Lottie character has its own internal
            // composition, and any added Circle/RadialGradient was reading as
            // a halo "framing" the mascot inside a rounded-rectangle card,
            // producing the "half circle half square" effect the user kept
            // flagging. The mascot now sits cleanly against the host card.

            mascotBody(moment: moment)
                .scaleEffect(state == .complete && !reduceMotion && !reducedDecoration ? 1.025 : 1)
                // Polish pass — flattens layers via compositingGroup then
                // applies Refactoring-UI two-shadow elevation (crisp + soft)
                // plus a top-of-head plush gloss radial gradient. Adds depth
                // to vector primitives without rewriting each body.
                .compositingGroup()
                .overlay(alignment: .top) {
                    if !reducedDecoration {
                        RadialGradient(
                            colors: [Color.white.opacity(0.22), Color.white.opacity(0)],
                            center: .top,
                            startRadius: size * 0.05,
                            endRadius: size * 0.55
                        )
                        .blendMode(.plusLighter)
                        .frame(width: size, height: size)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
                }
                .shadow(color: Color.black.opacity(0.05), radius: size * 0.012, y: size * 0.006)
                .shadow(color: Color.black.opacity(0.12), radius: size * 0.08, y: size * 0.04)
                // Idle life — breath + blink + tail wag, three independent
                // periods (1.5/5.5/9 s, relatively prime so they never sync
                // into a metronome). Apple Motion HIG + Tamagotchi 2-frame
                // idle precedent. Fully short-circuits under Reduce Motion or
                // the explicit reducedDecoration toggle.
                .modifier(MascotIdleLife(
                    reduceMotion: reduceMotion,
                    reducedDecoration: reducedDecoration || usesLottieBody,
                    size: size,
                    // Skip the SwiftUI eyelid overlay when a Lottie animation
                    // is driving the body — Pancake the Shiba already blinks
                    // internally; stacking both produced a horizontal black
                    // bar flicker across the head every 5.5s.
                    skipExternalEyeBlink: {
                        guard let lottieCharacter = CozyLottieMascot.lottiePrefix(forStyleID: styleID) else { return false }
                        return CozyLottieMascot.isBundled(character: lottieCharacter)
                    }()
                ))

            if !reducedDecoration {
                TwinkleBuddy(size: size * 0.26, color: moment.accent)
                    .offset(x: size * 0.30, y: -size * 0.30)
                    .accessibilityHidden(true)
            }

            stateAccessory
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(CozyMascotStyle.named(styleID).title): \(state.accessibilityLabel)")
    }

    @ViewBuilder
    private func mascotBody(moment: MascotMoment) -> some View {
        // Image-asset override: if the user has bundled raster art in
        // Assets.xcassets following the naming convention
        // `mascot.{styleID}.{state}` (or the broader fallback chain), render
        // the Image instead of the SwiftUI vector body. This unblocks
        // dropping in artist / AI / CC0 art without rewriting Swift per
        // mascot. See docs/MASCOT_ART.md for the full naming + spec.
        if let assetName = Self.firstMatchingAsset(styleID: styleID, state: state) {
            Image(assetName)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.92, height: size * 0.92)
        } else if !reduceMotion,
                  !reducedDecoration,
                  let lottieCharacter = CozyLottieMascot.lottiePrefix(forStyleID: styleID),
                  CozyLottieMascot.isBundled(character: lottieCharacter) {
            // Lottie cuteness path: bundled JSONs under permissive licenses
            // (Lottie Simple for Pancake/Mochi, MIT for Cativity/Biscuit).
            // Reduce Motion / reducedDecoration users fall back to the
            // SwiftUI vector body, which has its own gentle idle life.
            CozyLottieMascot(characterID: lottieCharacter, state: state, size: size * 0.92)
        } else {
            switch styleID {
            case "biscuit":
                biscuitCatBody(moment: moment)
            case "mango", "frog", "twinkle":          // legacy keys preserved
                mangoBunBody(moment: moment)
            case "custard", "pudding", "cloud":       // legacy keys preserved
                custardPupBody(moment: moment)
            default:
                dogBody(moment: moment)
            }
        }
    }

    // Asset-resolution fallback chain — tries style-specific art only. The
    // older generic `mascot-idle/focus/complete` images are intentionally not
    // part of this fallback because they made every mascot option render as
    // the same legacy dog instead of the selected Lottie/vector character.
    // Returns nil when no style asset is present so the Lottie/vector path can run.
    nonisolated static func firstMatchingAsset(styleID: String, state: MascotState) -> String? {
        let stateKey = state.assetKey
        let stateCategory = state.categoryKey
        let candidates = [
            "mascot.\(styleID).\(stateKey)",
            "mascot.\(styleID).\(stateCategory)",
            "mascot.\(styleID)"
        ]
        for name in candidates {
            if NSImage(named: name) != nil { return name }
        }
        return nil
    }

    private func dogBody(moment: MascotMoment) -> some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.08))
                .frame(width: size * 0.56, height: size * 0.14)
                .offset(y: size * 0.33)

            Capsule()
                .fill(Color(hex: "#FFF5EA"))
                .frame(width: size * 0.54, height: size * 0.38)
                .offset(y: size * 0.22)

            HStack(spacing: size * 0.22) {
                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.16, height: size * 0.16)
                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.16, height: size * 0.16)
            }
            .offset(y: size * 0.35)

            Group {
                RoundedRectangle(cornerRadius: size * 0.13, style: .continuous)
                    .fill(Color(hex: "#F2E4DA"))
                    .frame(width: size * 0.21, height: size * 0.42)
                    .rotationEffect(.degrees(-23))
                    .offset(x: -size * 0.23, y: -size * 0.02)
                RoundedRectangle(cornerRadius: size * 0.13, style: .continuous)
                    .fill(Color(hex: "#F2E4DA"))
                    .frame(width: size * 0.21, height: size * 0.42)
                    .rotationEffect(.degrees(23))
                    .offset(x: size * 0.23, y: -size * 0.02)
            }
            .shadow(color: Color.black.opacity(0.07), radius: size * 0.025, y: size * 0.01)

            // Face — macOS 15 MeshGradient gives painterly fur variance
            // (warm cream center, cooler cream edges) instead of a flat white
            // circle. 4×4 mesh with smoothsColors: true; cubic interpolation.
            // Outer rim multiplied for sub-surface scatter look, top of head
            // overlaid with a screen-blended highlight for plush gloss.
            MeshGradient(
                width: 4, height: 4,
                points: [
                    [0.0, 0.0], [0.33, 0.0], [0.66, 0.0], [1.0, 0.0],
                    [0.0, 0.33], [0.30, 0.30], [0.70, 0.30], [1.0, 0.33],
                    [0.0, 0.66], [0.30, 0.70], [0.70, 0.70], [1.0, 0.66],
                    [0.0, 1.0], [0.33, 1.0], [0.66, 1.0], [1.0, 1.0]
                ],
                colors: [
                    Color.white,                  Color.white,                  Color.white,                  Color.white,
                    Color.white,                  Color(hex: "#FFFCF6"),        Color(hex: "#FFFCF6"),        Color.white,
                    Color(hex: "#FFF6E8"),        Color(hex: "#FFF1DA"),        Color(hex: "#FFF1DA"),        Color(hex: "#FFF6E8"),
                    Color(hex: "#FFE9CB"),        Color(hex: "#FFE0B8"),        Color(hex: "#FFE0B8"),        Color(hex: "#FFE9CB")
                ],
                smoothsColors: true
            )
            .mask(Circle().frame(width: size * 0.58, height: size * 0.58))
            .frame(width: size * 0.58, height: size * 0.58)
            .overlay(
                // Rim light along the top — screen blend, masked to the top half
                Circle()
                    .strokeBorder(Color.white.opacity(0.85), lineWidth: size * 0.025)
                    .frame(width: size * 0.58, height: size * 0.58)
                    .mask(
                        LinearGradient(colors: [.white, .clear],
                                       startPoint: .top, endPoint: .center)
                    )
                    .blur(radius: size * 0.012)
                    .blendMode(.screen)
            )
            .shadow(color: accent.opacity(0.18), radius: size * 0.08, y: size * 0.035)

            Group {
                Circle().fill(Color.white).frame(width: size * 0.18, height: size * 0.18).offset(x: -size * 0.16, y: -size * 0.25)
                Circle().fill(Color.white).frame(width: size * 0.21, height: size * 0.21).offset(x: 0, y: -size * 0.30)
                Circle().fill(Color.white).frame(width: size * 0.18, height: size * 0.18).offset(x: size * 0.16, y: -size * 0.25)
            }

            Capsule()
                .fill(Color(hex: "#FFF7EF"))
                .frame(width: size * 0.24, height: size * 0.15)
                .offset(y: size * 0.08)

            eyes
                .offset(y: -size * 0.02)

            Capsule()
                .fill(CozyPalette.ink.opacity(0.78))
                .frame(width: state == .landing ? size * 0.082 : size * 0.060, height: state == .landing ? size * 0.030 : size * 0.040)
                .offset(y: size * 0.055)

            HStack(spacing: size * 0.25) {
                Circle().fill(CozyPalette.stickerPink.opacity(0.70)).frame(width: size * 0.065, height: size * 0.045)
                Circle().fill(CozyPalette.stickerPink.opacity(0.70)).frame(width: size * 0.065, height: size * 0.045)
            }
            .offset(y: size * 0.10)

            Path { path in
                path.move(to: CGPoint(x: size * 0.46, y: size * 0.55))
                path.addQuadCurve(
                    to: CGPoint(x: size * 0.54, y: size * 0.55),
                    control: CGPoint(x: size * 0.50, y: size * 0.60)
                )
            }
            .stroke(CozyPalette.ink.opacity(0.72), style: StrokeStyle(lineWidth: max(1.4, size * 0.018), lineCap: .round))
            .frame(width: size, height: size)

            if state == .focus || state == .deepFocus {
                focusHeadphones
            }

            if state == .complete && !reducedDecoration {
                CelebrationSprinkles(size: size, color: CozyPalette.persimmon)
                    .accessibilityHidden(true)
            }

            if !reducedDecoration {
                Image(systemName: moment.symbolName)
                    .font(.system(size: size * 0.13, weight: .bold, design: .rounded))
                    .foregroundStyle(moment.accent)
                    .offset(x: -size * 0.26, y: -size * 0.24)
                    .accessibilityHidden(true)
            }
        }
    }

    // Biscuit — static fallback for Reduce Motion / reduced-decoration modes.
    // Keeps the cat visually distinct from Mochi even when Lottie is disabled.
    private func biscuitCatBody(moment: MascotMoment) -> some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.08))
                .frame(width: size * 0.60, height: size * 0.10)
                .offset(y: size * 0.34)

            HStack(spacing: size * 0.30) {
                Triangle()
                    .fill(CozyPalette.peach)
                    .frame(width: size * 0.24, height: size * 0.24)
                    .rotationEffect(.degrees(-10))
                Triangle()
                    .fill(CozyPalette.peach)
                    .frame(width: size * 0.24, height: size * 0.24)
                    .rotationEffect(.degrees(10))
            }
            .offset(y: -size * 0.30)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [CozyPalette.peach, CozyPalette.persimmon.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.72, height: size * 0.72)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.40), lineWidth: max(0.8, size * 0.012))
                        .blur(radius: size * 0.004)
                )
                .shadow(color: moment.accent.opacity(0.18), radius: size * 0.08, y: size * 0.05)

            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .fill(CozyPalette.warmCream.opacity(0.74))
                .frame(width: size * 0.18, height: size * 0.38)
                .rotationEffect(.degrees(16))
                .offset(x: size * 0.14, y: size * 0.03)

            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .fill(CozyPalette.warmCream.opacity(0.36))
                .frame(width: size * 0.12, height: size * 0.34)
                .rotationEffect(.degrees(16))
                .offset(x: -size * 0.06, y: size * 0.00)

            eyes
                .scaleEffect(1.12)
                .offset(y: -size * 0.03)

            Capsule()
                .fill(CozyPalette.ink.opacity(0.76))
                .frame(width: size * 0.052, height: size * 0.026)
                .offset(y: size * 0.055)

            Path { path in
                path.move(to: CGPoint(x: size * 0.43, y: size * 0.60))
                path.addQuadCurve(to: CGPoint(x: size * 0.50, y: size * 0.65), control: CGPoint(x: size * 0.47, y: size * 0.66))
                path.addQuadCurve(to: CGPoint(x: size * 0.57, y: size * 0.60), control: CGPoint(x: size * 0.53, y: size * 0.66))
            }
            .stroke(CozyPalette.ink.opacity(0.62), style: StrokeStyle(lineWidth: max(1.2, size * 0.014), lineCap: .round))
            .frame(width: size, height: size)

            HStack(spacing: size * 0.34) {
                whiskers.rotationEffect(.degrees(180))
                whiskers
            }
            .offset(y: size * 0.06)

            if state == .focus || state == .deepFocus { focusHeadphones }
            if state == .complete && !reducedDecoration {
                CelebrationSprinkles(size: size, color: CozyPalette.persimmon)
                    .accessibilityHidden(true)
            }
        }
    }

    private var whiskers: some View {
        VStack(spacing: size * 0.025) {
            Capsule().frame(width: size * 0.16, height: max(1, size * 0.008))
            Capsule().frame(width: size * 0.14, height: max(1, size * 0.008))
        }
        .foregroundStyle(CozyPalette.ink.opacity(0.28))
    }

    // Matcha — cottagecore sage frog. Replaces the retired Twinkle (5-point
    // star) per research: Lorenz baby-schema demands round forms, not spiky
    // polygons; cottagecore frog plushies are an active 2026 TikTok trend.
    // Mango — original "ugly-cute monster bun" mascot, occupying the Pop-Mart
    // shape-language category (round body, tall ears, big eyes, two soft fangs)
    // without copying any specific trademarked character. Peach + warmCream
    // palette so she reads as soft / dessert-flavored, not edgy.
    private func mangoBunBody(moment: MascotMoment) -> some View {
        ZStack {
            // Ground shadow
            Ellipse()
                .fill(Color.black.opacity(0.08))
                .frame(width: size * 0.62, height: size * 0.10)
                .offset(y: size * 0.34)

            // Tall floppy ears behind the head — outer peach with warmCream inner.
            // Slight outward rotation gives the bun-eared "monster elf" silhouette.
            HStack(spacing: size * 0.34) {
                ZStack {
                    Capsule().fill(CozyPalette.peach)
                        .frame(width: size * 0.20, height: size * 0.46)
                    Capsule().fill(CozyPalette.warmCream)
                        .frame(width: size * 0.10, height: size * 0.30)
                }
                .rotationEffect(.degrees(-10))
                ZStack {
                    Capsule().fill(CozyPalette.peach)
                        .frame(width: size * 0.20, height: size * 0.46)
                    Capsule().fill(CozyPalette.warmCream)
                        .frame(width: size * 0.10, height: size * 0.30)
                }
                .rotationEffect(.degrees(10))
            }
            .offset(y: -size * 0.30)

            // Round body — MeshGradient gives the peach a hand-painted falloff
            // (light at top, deeper at bottom) so it stops reading as a flat disc.
            MeshGradient(
                width: 4, height: 4,
                points: [
                    [0.0, 0.0], [0.33, 0.0], [0.66, 0.0], [1.0, 0.0],
                    [0.0, 0.33], [0.33, 0.33], [0.66, 0.33], [1.0, 0.33],
                    [0.0, 0.66], [0.33, 0.66], [0.66, 0.66], [1.0, 0.66],
                    [0.0, 1.0], [0.33, 1.0], [0.66, 1.0], [1.0, 1.0]
                ],
                colors: [
                    Color(hex: "#FFE9D4"), Color(hex: "#FFE3C9"), Color(hex: "#FFE3C9"), Color(hex: "#FFE9D4"),
                    Color(hex: "#FFD7B8"), Color(hex: "#FFCFA8"), Color(hex: "#FFCFA8"), Color(hex: "#FFD7B8"),
                    Color(hex: "#FFC498"), Color(hex: "#F2B589"), Color(hex: "#F2B589"), Color(hex: "#FFC498"),
                    Color(hex: "#E8A57A"), Color(hex: "#D89569"), Color(hex: "#D89569"), Color(hex: "#E8A57A")
                ],
                smoothsColors: true
            )
            .mask(Ellipse().frame(width: size * 0.78, height: size * 0.72))
            .frame(width: size * 0.78, height: size * 0.72)
            .overlay {
                if !reducedDecoration {
                    Ellipse()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.55), Color.white.opacity(0.0)],
                                startPoint: .top, endPoint: .center
                            ),
                            lineWidth: max(0.8, size * 0.012)
                        )
                        .frame(width: size * 0.78, height: size * 0.72)
                        .blendMode(.screen)
                        .allowsHitTesting(false)
                }
            }
            .shadow(color: moment.accent.opacity(0.20),
                    radius: size * 0.08, y: size * 0.05)

            // Soft cream belly so the silhouette has dessert-bun layering
            Ellipse()
                .fill(CozyPalette.warmCream)
                .frame(width: size * 0.40, height: size * 0.26)
                .offset(y: size * 0.12)

            // Cheeks (peach blush wash)
            HStack(spacing: size * 0.40) {
                Circle().fill(CozyPalette.stickerPink.opacity(0.50))
                    .frame(width: size * 0.10, height: size * 0.06)
                Circle().fill(CozyPalette.stickerPink.opacity(0.50))
                    .frame(width: size * 0.10, height: size * 0.06)
            }
            .offset(y: size * 0.02)

            // Big bug eyes — shared `eyes` helper for state-aware pupils,
            // positioned upper-center to read as "all eyes."
            eyes
                .scaleEffect(1.25)
                .offset(y: -size * 0.10)

            // Tiny dot nose
            Capsule()
                .fill(CozyPalette.ink.opacity(0.80))
                .frame(width: size * 0.05, height: size * 0.025)
                .offset(y: size * 0.045)

            // Two soft fangs — friendly, not predatory. Small triangle paths
            // under the nose, warmCream filled with ink outline.
            HStack(spacing: size * 0.06) {
                softFang
                softFang
            }
            .offset(y: size * 0.10)

            // Hint of a gentle smile-line under the fangs
            Path { p in
                p.move(to: CGPoint(x: size * 0.40, y: size * 0.66))
                p.addQuadCurve(to: CGPoint(x: size * 0.60, y: size * 0.66),
                               control: CGPoint(x: size * 0.50, y: size * 0.72))
            }
            .stroke(CozyPalette.ink.opacity(0.55),
                    style: StrokeStyle(lineWidth: max(1.0, size * 0.012), lineCap: .round))
            .frame(width: size, height: size)

            if state == .focus || state == .deepFocus { focusHeadphones }
            if state == .complete && !reducedDecoration {
                CelebrationSprinkles(size: size, color: CozyPalette.persimmon)
                    .accessibilityHidden(true)
            }
        }
    }

    // Single soft fang shape — used twice by mangoBunBody. Triangle path with
    // a slight rounded base so it never reads as aggressive.
    private var softFang: some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: size * 0.044, y: 0))
            p.addQuadCurve(to: CGPoint(x: size * 0.022, y: size * 0.055),
                           control: CGPoint(x: size * 0.044, y: size * 0.04))
            p.addQuadCurve(to: CGPoint(x: 0, y: 0),
                           control: CGPoint(x: 0, y: size * 0.04))
        }
        .fill(CozyPalette.warmCream)
        .frame(width: size * 0.044, height: size * 0.055)
        .overlay(
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: size * 0.044, y: 0))
            }
            .stroke(CozyPalette.ink.opacity(0.40), lineWidth: max(0.6, size * 0.005))
            .frame(width: size * 0.044, height: size * 0.055)
        )
    }

    // Custard — round dessert puppy that lives in the Sanrio Character Ranking
    // 2026 #1 silhouette family (perfectly circular cream body, short droopy
    // ears, small beret accent). Sharper / cuter than the retired Pudding by
    // making the body unambiguously Circle (not Ellipse) and shrinking the
    // beret so it reads as accessory rather than the character's whole top.
    private func custardPupBody(moment: MascotMoment) -> some View {
        ZStack {
            // Ground shadow
            Ellipse()
                .fill(Color.black.opacity(0.08))
                .frame(width: size * 0.60, height: size * 0.10)
                .offset(y: size * 0.34)

            // Short droopy ears tucked close behind the head
            HStack(spacing: size * 0.62) {
                Capsule()
                    .fill(CozyPalette.peach)
                    .frame(width: size * 0.20, height: size * 0.26)
                    .rotationEffect(.degrees(-22))
                Capsule()
                    .fill(CozyPalette.peach)
                    .frame(width: size * 0.20, height: size * 0.26)
                    .rotationEffect(.degrees(22))
            }
            .offset(y: -size * 0.02)

            // Perfectly round cream body — MeshGradient gives a hand-painted
            // ivory→cream→buttery falloff so it has dimension at hero size.
            MeshGradient(
                width: 4, height: 4,
                points: [
                    [0.0, 0.0], [0.33, 0.0], [0.66, 0.0], [1.0, 0.0],
                    [0.0, 0.33], [0.33, 0.33], [0.66, 0.33], [1.0, 0.33],
                    [0.0, 0.66], [0.33, 0.66], [0.66, 0.66], [1.0, 0.66],
                    [0.0, 1.0], [0.33, 1.0], [0.66, 1.0], [1.0, 1.0]
                ],
                colors: [
                    Color(hex: "#FFFCF6"), Color(hex: "#FFF8EE"), Color(hex: "#FFF8EE"), Color(hex: "#FFFCF6"),
                    Color(hex: "#FFF3E2"), Color(hex: "#FFEAD0"), Color(hex: "#FFEAD0"), Color(hex: "#FFF3E2"),
                    Color(hex: "#FFE1C2"), Color(hex: "#F8D5B0"), Color(hex: "#F8D5B0"), Color(hex: "#FFE1C2"),
                    Color(hex: "#F0C499"), Color(hex: "#E6B383"), Color(hex: "#E6B383"), Color(hex: "#F0C499")
                ],
                smoothsColors: true
            )
            .mask(Circle().frame(width: size * 0.78, height: size * 0.78))
            .frame(width: size * 0.78, height: size * 0.78)
            .overlay {
                if !reducedDecoration {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.50), Color.white.opacity(0.0)],
                                startPoint: .top, endPoint: .center
                            ),
                            lineWidth: max(0.8, size * 0.012)
                        )
                        .frame(width: size * 0.78, height: size * 0.78)
                        .blendMode(.screen)
                        .allowsHitTesting(false)
                }
            }
            .overlay(
                Circle()
                    .stroke(CozyPalette.ink.opacity(0.06),
                            lineWidth: max(0.5, size * 0.006))
                    .frame(width: size * 0.78, height: size * 0.78)
            )
            .shadow(color: moment.accent.opacity(0.20),
                    radius: size * 0.08, y: size * 0.05)

            // Small beret with a tiny stem loop on top — accessory, not full hat
            ZStack {
                Ellipse()
                    .fill(CozyPalette.persimmon)
                    .frame(width: size * 0.38, height: size * 0.14)
                Circle()
                    .fill(CozyPalette.persimmon)
                    .frame(width: size * 0.07, height: size * 0.07)
                    .offset(x: -size * 0.10, y: -size * 0.04)
            }
            .offset(y: -size * 0.32)

            // Eyes
            eyes.offset(y: -size * 0.04)

            // Cream snout patch
            Capsule()
                .fill(CozyPalette.warmCream)
                .frame(width: size * 0.22, height: size * 0.14)
                .offset(y: size * 0.07)
                .overlay(
                    Capsule()
                        .stroke(CozyPalette.ink.opacity(0.08),
                                lineWidth: max(0.5, size * 0.005))
                        .frame(width: size * 0.22, height: size * 0.14)
                        .offset(y: size * 0.07)
                )

            // Persimmon micro-dot nose
            Circle()
                .fill(CozyPalette.persimmon)
                .frame(width: size * 0.05, height: size * 0.05)
                .offset(y: size * 0.025)

            // Gentle smile
            Path { p in
                p.move(to: CGPoint(x: size * 0.44, y: size * 0.62))
                p.addQuadCurve(to: CGPoint(x: size * 0.56, y: size * 0.62),
                               control: CGPoint(x: size * 0.50, y: size * 0.68))
            }
            .stroke(CozyPalette.ink.opacity(0.72),
                    style: StrokeStyle(lineWidth: max(1.4, size * 0.018), lineCap: .round))
            .frame(width: size, height: size)

            // Cheek blush
            HStack(spacing: size * 0.30) {
                Circle().fill(CozyPalette.stickerPink.opacity(0.65))
                    .frame(width: size * 0.08, height: size * 0.05)
                Circle().fill(CozyPalette.stickerPink.opacity(0.65))
                    .frame(width: size * 0.08, height: size * 0.05)
            }
            .offset(y: size * 0.16)

            if state == .focus || state == .deepFocus { focusHeadphones }
            if state == .complete && !reducedDecoration {
                CelebrationSprinkles(size: size, color: CozyPalette.persimmon)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private var eyes: some View {
        if state == .deepFocus {
            HStack(spacing: size * 0.14) {
                Capsule().fill(CozyPalette.ink).frame(width: size * 0.075, height: size * 0.020)
                Capsule().fill(CozyPalette.ink).frame(width: size * 0.075, height: size * 0.020)
            }
        } else if state == .landing {
            HStack(spacing: size * 0.15) {
                Circle().fill(CozyPalette.ink).frame(width: size * 0.060, height: size * 0.060)
                Circle().fill(CozyPalette.ink).frame(width: size * 0.060, height: size * 0.060)
            }
        } else {
            ZStack {
                HStack(spacing: size * 0.16) {
                    Circle().fill(CozyPalette.ink).frame(width: size * 0.050, height: size * 0.050)
                    Circle().fill(CozyPalette.ink).frame(width: size * 0.050, height: size * 0.050)
                }

                HStack(spacing: size * 0.17) {
                    Circle().fill(Color.white.opacity(0.85)).frame(width: size * 0.016, height: size * 0.016)
                    Circle().fill(Color.white.opacity(0.85)).frame(width: size * 0.016, height: size * 0.016)
                }
                .offset(x: -size * 0.012, y: -size * 0.015)
            }
        }
    }

    private var focusHeadphones: some View {
        ZStack {
            Path { path in
                path.addArc(
                    center: CGPoint(x: size * 0.50, y: size * 0.46),
                    radius: size * 0.31,
                    startAngle: .degrees(40),
                    endAngle: .degrees(140),
                    clockwise: true
                )
            }
            .stroke(accent, style: StrokeStyle(lineWidth: max(2, size * 0.035), lineCap: .round))
            .frame(width: size, height: size)

            HStack(spacing: size * 0.41) {
                RoundedRectangle(cornerRadius: size * 0.03, style: .continuous)
                    .fill(accent)
                    .frame(width: size * 0.07, height: size * 0.13)
                RoundedRectangle(cornerRadius: size * 0.03, style: .continuous)
                    .fill(accent)
                    .frame(width: size * 0.07, height: size * 0.13)
            }
            .offset(y: -size * 0.03)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var stateAccessory: some View {
        switch state {
        case .idle:
            EmptyView()
        case .settling:
            Image(systemName: "leaf.fill")
                .font(.system(size: size * 0.18, weight: .bold, design: .rounded))
                .foregroundStyle(CozyPalette.focusJade)
                .offset(x: size * 0.25, y: size * 0.25)
                .accessibilityHidden(true)
        case .focus:
            Image(systemName: "book.closed.fill")
                .font(.system(size: size * 0.18, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .offset(x: size * 0.25, y: size * 0.25)
                .accessibilityHidden(true)
        case .deepFocus:
            Image(systemName: "headphones")
                .font(.system(size: size * 0.18, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .offset(x: size * 0.25, y: size * 0.25)
                .accessibilityHidden(true)
        case .landing:
            Image(systemName: "sun.max.fill")
                .font(.system(size: size * 0.18, weight: .bold, design: .rounded))
                .foregroundStyle(CozyPalette.persimmon)
                .offset(x: size * 0.27, y: size * 0.20)
                .accessibilityHidden(true)
        case .breakTime:
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: size * 0.18, weight: .bold, design: .rounded))
                .foregroundStyle(CozyPalette.persimmon)
                .offset(x: size * 0.27, y: size * 0.22)
                .accessibilityHidden(true)
        case .complete:
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: size * 0.21, weight: .bold, design: .rounded))
                .foregroundStyle(CozyPalette.persimmon)
                .offset(x: size * 0.28, y: -size * 0.05)
                .accessibilityHidden(true)
        case .overdue:
            Image(systemName: "drop.fill")
                .font(.system(size: size * 0.18, weight: .bold, design: .rounded))
                .foregroundStyle(CozyPalette.mistBlue)
                .offset(x: size * 0.28, y: -size * 0.10)
                .accessibilityHidden(true)
        case .countdown:
            Image(systemName: "party.popper.fill")
                .font(.system(size: size * 0.18, weight: .bold, design: .rounded))
                .foregroundStyle(CozyPalette.stickerPink)
                .offset(x: size * 0.26, y: size * 0.21)
                .accessibilityHidden(true)
        }
    }
}

// MascotIdleLife — three independent ambient loops that make the mascot
// feel breathing-alive instead of frozen. Periods are relatively prime
// (1.5 s / 5.5 s / 9 s) so the visual rhythm never locks into a metronome.
// Honors `accessibilityReduceMotion` AND the `reducedDecoration` user toggle —
// either short-circuits the modifier to a static pass-through.
struct MascotIdleLife: ViewModifier {
    let reduceMotion: Bool
    let reducedDecoration: Bool
    let size: CGFloat
    /// When true, the SwiftUI blink-eyelid overlay is skipped — the underlying
    /// renderer (Lottie) already has its own blink, and stacking ours on top
    /// produces a horizontal black bar that flickers across the head every
    /// 5.5 s (user reported this as "something glitches on the mascot head").
    var skipExternalEyeBlink: Bool = false

    func body(content: Content) -> some View {
        if reduceMotion || reducedDecoration {
            content   // truly static
        } else {
            // 10fps for card/avatar sizes (≤88pt) — barely perceptible at small scale,
            // dramatically reduces concurrent frame callbacks on Today's grid.
            TimelineView(.animation(minimumInterval: size >= 120 ? 1.0 / 30.0 : 1.0 / 10.0)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                // Breath: 3 s full cycle, ±1.5 % scale. Apple's 1.025 ceiling
                // for "alive but not distracting."
                let breathPhase = sin(t * .pi / 1.5)
                let breathScale = 1.0 + 0.015 * breathPhase
                // Blink: ~5.5 s cycle, last ≈190 ms is "lid down."
                let blinkCycle = (t.truncatingRemainder(dividingBy: 5.5)) / 5.5
                let isBlinking = blinkCycle > 0.965 && !skipExternalEyeBlink
                content
                    .scaleEffect(breathScale, anchor: .center)
                    .overlay {
                        if isBlinking {
                            // Eyelid mask: a slim horizontal capsule across
                            // where the eyes typically sit. Positioned via the
                            // size parameter so it scales with the mascot.
                            Capsule()
                                .fill(Color.black.opacity(0.65))
                                .frame(width: size * 0.30, height: size * 0.04)
                                .offset(y: -size * 0.12)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
            }
        }
    }
}

extension MascotView {
    // Sugar so call-sites can write `MascotView(state: .idle, size: .card)` —
    // the enum init resolves first when `.card` style dot-syntax is used.
    init(state: MascotState, size: MascotSize) {
        self.init(state: state, size: size.points)
    }

    init(state: MascotState, size: MascotSize, styleID: String) {
        self.init(state: state, size: size.points, styleIDOverride: styleID)
    }

    init(state: MascotState, size: CGFloat, styleID: String) {
        self.init(state: state, size: size, styleIDOverride: styleID)
    }
}

struct MascotDisplayFrame<Content: View>: View {
    let size: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(width: size, height: size)
            .contentShape(Rectangle())
    }
}

struct EquippedMascotView: View {
    let state: MascotState
    let size: CGFloat
    let rewards: [RewardItem]

    // MD-002: at most 2 decorations on any mascot card per state. Prior
    // implementation rendered up to 3 wearables which read as crowded
    // (user feedback: "stars overlap on Mochi's head"). Pairing two stickers
    // from disjoint MascotAnchor groups guarantees they cannot collide.
    private var equippedWearables: [RewardItem] {
        rewards
            .filter { reward in
                reward.isEquipped && (
                    reward.category.localizedCaseInsensitiveContains("accessory")
                        || reward.category.localizedCaseInsensitiveContains("outfit")
                )
            }
            .prefix(2)
            .map { $0 }
    }

    var body: some View {
        let bodySize = size * 0.78
        MascotDisplayFrame(size: size) {
            ZStack(alignment: .center) {
                MascotView(state: state, size: bodySize)
                // MD-003: stickers hidden at < 80pt (avatar) per Discord/Apple Fitness pattern
                if size >= 80 {
                    ForEach(Array(equippedWearables.enumerated()), id: \.element.id) { index, reward in
                        Image(systemName: reward.symbolName)
                            .font(.system(size: bodySize * 0.15, weight: .bold))
                            // TC-002 OK: data-driven reward color, not a literal palette value
                            .foregroundStyle(Color(hex: reward.colorHex))
                            .padding(bodySize * 0.06)
                            // TC-002 OK: data-driven reward color background
                            .background(Circle().fill(Color(hex: reward.colorHex).opacity(0.16)))
                            .offset(anchor(for: index).offset(for: bodySize))
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilityLabel)
    }

    // MD-001: stickers go on named anchors, not raw .offset literals.
    // Index 0 lands top-right (corners group); index 1 lands in the
    // companion / side-kick slot (companion group). Different groups by
    // construction, so the two stickers cannot occupy overlapping space.
    private func anchor(for index: Int) -> MascotAnchor {
        index == 0 ? .topRight : .sideKick
    }
}

extension EquippedMascotView {
    init(state: MascotState, size: MascotSize, rewards: [RewardItem]) {
        self.init(state: state, size: size.points, rewards: rewards)
    }
}

struct NextUnlockView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    let database: CozyDatabase

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    var body: some View {
        let summary = CozyProgression.summary(for: database)
        if let item = CozyProgression.nearestUnlock(in: database) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: item.colorHex).opacity(0.16))
                    Image(systemName: item.symbolName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color(hex: item.colorHex))
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Next unlock: \(item.name)")
                        .font(.callout.weight(.bold))
                        .lineLimit(1)
                    Text(unlockCopy(for: item, summary: summary))
                        .font(.caption)
                        .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous)
                    .fill(CozyPalette.quietContainer(colorScheme))
            )
            .accessibilityIdentifier("progression.nextUnlock")
        }
    }

    private func unlockCopy(for item: ShopCatalogItem, summary: ProgressionSummary) -> String {
        let levelGap = max(0, item.requiredLevel - summary.level)
        let coinGap = max(0, item.coinCost - summary.coinsAvailable)
        if levelGap > 0 {
            return "Level \(item.requiredLevel) soon · \(coinGap) paws to save"
        }
        if coinGap > 0 {
            return "\(coinGap) paws to go · costs \(item.coinCost)"
        }
        return "Ready in the shop · \(item.coinCost) paws"
    }
}

struct CelebrationSprinkles: View {
    let size: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                Capsule()
                    .fill(index.isMultiple(of: 2) ? color : CozyPalette.stickerPink)
                    .frame(width: size * 0.035, height: size * 0.10)
                    .rotationEffect(.degrees(Double(index) * 32))
                    .offset(
                        x: cos(Double(index) * .pi / 3) * size * 0.34,
                        y: sin(Double(index) * .pi / 3) * size * 0.31 - size * 0.12
                    )
            }
        }
        .frame(width: size, height: size)
    }
}

struct TwinkleBuddy: View {
    let size: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            StarShape()
                .fill(color)
                .shadow(color: color.opacity(0.24), radius: size * 0.18, y: size * 0.05)
            HStack(spacing: size * 0.14) {
                Circle().fill(CozyPalette.ink).frame(width: size * 0.09, height: size * 0.09)
                Circle().fill(CozyPalette.ink).frame(width: size * 0.09, height: size * 0.09)
            }
            .offset(y: -size * 0.02)
            Path { path in
                path.move(to: CGPoint(x: size * 0.42, y: size * 0.58))
                path.addQuadCurve(to: CGPoint(x: size * 0.58, y: size * 0.58), control: CGPoint(x: size * 0.50, y: size * 0.66))
            }
            .stroke(CozyPalette.ink.opacity(0.68), style: StrokeStyle(lineWidth: max(1.0, size * 0.06), lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) * 0.48
        let inner = outer * 0.46
        var path = Path()

        for index in 0..<10 {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = CGFloat(index) * .pi / 5 - .pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

// EmptyStateView — researched recipe B. NN/g: "A blank container is not
// neutral — it reduces confidence, damages discoverability, and slows task
// completion." Mailchimp/Finch/Linear pattern: small-caps eyebrow → mascot
// → title → 1-2 sentence "what will appear here" → optional CTA pair.
// Mascot bumped from 86pt to 112pt (the canonical hero size in the Mochi
// ladder). Eyebrow + secondary CTA are additive — old call-sites stay valid.
struct EmptyStateView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let eyebrow: String?
    let title: String
    let message: String
    let mascotState: MascotState
    let primaryAction: (title: String, action: () -> Void)?
    let secondaryAction: (title: String, action: () -> Void)?

    init(
        title: String,
        message: String,
        mascotState: MascotState,
        eyebrow: String? = nil,
        primaryActionTitle: String? = nil,
        primaryAction: (() -> Void)? = nil,
        secondaryActionTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.message = message
        self.mascotState = mascotState
        if let primaryActionTitle, let primaryAction {
            self.primaryAction = (primaryActionTitle, primaryAction)
        } else {
            self.primaryAction = nil
        }
        if let secondaryActionTitle, let secondaryAction {
            self.secondaryAction = (secondaryActionTitle, secondaryAction)
        } else {
            self.secondaryAction = nil
        }
    }

    // Legacy convenience initializer — preserves the original 4-arg API so
    // existing call-sites keep compiling without touch-up.
    init(title: String, message: String, mascotState: MascotState, actionTitle: String?, action: (() -> Void)?) {
        self.init(
            title: title,
            message: message,
            mascotState: mascotState,
            eyebrow: nil,
            primaryActionTitle: actionTitle,
            primaryAction: action
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            MascotView(state: mascotState, size: 112)
                .accessibilityHidden(true)
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 380)
                .fixedSize(horizontal: false, vertical: true)
            if primaryAction != nil || secondaryAction != nil {
                HStack(spacing: 12) {
                    if let secondary = secondaryAction {
                        Button(secondary.title, action: secondary.action)
                            .cozyGhostButton(minWidth: 132)
                    }
                    if let primary = primaryAction {
                        Button(primary.title, action: primary.action)
                            .cozyPrimaryButton(minWidth: 160)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct ProgressRingView: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: 16)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.2), value: progress)
        }
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

struct CozyTimerChrome: View {
    let progress: Double
    let color: Color
    let skin: CozyTimerSkin
    let shape: CozyTimerShape

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        switch shape {
        case .ring:
            ProgressRingView(progress: clampedProgress, color: color)
        case .capsule:
            ZStack {
                RoundedRectangle(cornerRadius: 44, style: .continuous)
                    .fill(skin.secondary.opacity(0.24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 44, style: .continuous)
                            .stroke(color.opacity(0.28), lineWidth: 3)
                    )
                GeometryReader { proxy in
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.36), skin.secondary.opacity(0.76)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: max(18, proxy.size.height * clampedProgress))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
                }
                Image(systemName: skin.symbolName)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(color.opacity(0.24))
                    .offset(y: -56)
            }
            .accessibilityLabel("Timer pill progress")
            .accessibilityValue("\(Int(clampedProgress * 100)) percent")
        case .hourglass:
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(skin.secondary.opacity(0.20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(color.opacity(0.30), lineWidth: 2)
                    )
                Image(systemName: "hourglass")
                    .font(.system(size: 118, weight: .black))
                    .foregroundStyle(color.opacity(0.22))
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(color.opacity(0.34))
                        .frame(height: 36 + (86 * clampedProgress))
                        .padding(.horizontal, 46)
                        .padding(.bottom, 28)
                }
            }
            .accessibilityLabel("Timer hourglass progress")
            .accessibilityValue("\(Int(clampedProgress * 100)) percent")
        }
    }
}

// CozyProgressionRing — researched recipe G. Apple-Fitness-Ring pattern:
// the track is *always* visible even at 0% so the empty state reads as
// "you're on the journey," not "you're failing." Progress floor 2% means a
// brand-new account still shows a sliver of accent — the goal is visible.
// Animates with a soft spring on value changes; honors Reduce Motion.
struct CozyProgressionRing: View {
    enum LabelStyle { case level(Int), value(String) }

    let progress: Double                  // 0...1 (clamped + floored)
    let label: LabelStyle
    var symbolName: String? = "pawprint.fill"
    var size: CGFloat = 96
    var lineWidth: CGFloat = 10
    var accent: Color = CozyPalette.focusJade
    var trackOpacityLight: Double = 0.18
    var trackOpacityDark: Double = 0.30

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var clamped: Double { min(max(progress, 0), 1) }
    // Floor at 2% so even "zero" reads as "started." This matches Apple Fitness'
    // never-empty ring convention — a track that is fully unfilled visually
    // amounts to a zero state, which Apple deliberately avoids.
    private var displayed: Double { max(clamped, 0.02) }

    private var labelText: (line1: String, line2: String) {
        switch label {
        case .level(let n): return ("Lv", "\(n)")
        case .value(let v): return ("", v)
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(colorScheme == .dark ? trackOpacityDark : trackOpacityLight),
                        lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: displayed)
                .stroke(accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.85),
                           value: displayed)
            VStack(spacing: 2) {
                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: size * 0.20, weight: .bold))
                        .foregroundStyle(accent)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if !labelText.line1.isEmpty {
                        Text(labelText.line1)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(labelText.line2)
                        .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityValue("\(Int(clamped * 100)) percent")
    }
}

struct CozyLinearProgressBar: View {
    let value: Double
    var total: Double = 1
    let color: Color

    private var clampedProgress: Double {
        guard total > 0 else { return 0 }
        return min(max(value / total, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(0.12))
                Capsule()
                    .fill(color)
                    .frame(width: max(0, proxy.size.width * clampedProgress))
                    .opacity(clampedProgress == 0 ? 0 : 1)
            }
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityValue("\(Int(clampedProgress * 100)) percent")
    }
}

struct SoftMetricBadge: View {
    let title: String
    let value: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(CozyType.cardTitle)
                Text(title)
                    .font(CozyType.captionStrong)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.14))
        )
        .foregroundStyle(color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }
}

struct RarityIcon: View {
    let symbol: String
    let rarity: RewardRarity
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous)
                .fill(Color(hex: rarity.colorHex).opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous)
                        .stroke(Color(hex: rarity.colorHex).opacity(0.35), lineWidth: 1)
                )
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(Color(hex: rarity.colorHex))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Cozy item art (Shop + Inventory shared visual)

/// Recipe-driven sticker art for ShopCatalogItem / RewardItem. Replaces the prior
/// "flat fill + monochrome SF Symbol" treatment that made all 18 items look identical.
/// Adds: plush gradient backdrop, palette-rendered focal symbol with cream highlight
/// tone, glossy white inner rim, Sanrio-style sparkle satellite at top-right, soft
/// outer shadow for elevation, optional rarity ring derived from `requiredLevel`, and
/// per-category motif (chromatic ring for timers, steam wisp for treats, warm-cream
/// shelf for room decor, hanger chip for outfits, heart satellite for accessories).
struct CozyItemArt: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let symbolName: String
    let colorHex: String
    let category: String
    /// Drives the rarity ring. Pass `requiredLevel` from shop, nil from inventory.
    var requiredLevel: Int? = nil
    /// Explicit rarity override — Inventory views pass this when they want
    /// shimmer on owned `.special`/`.dream` items without exposing the
    /// rarity ring (which is shop-only).
    var explicitRarity: RewardRarity? = nil
    var size: CGFloat = 64
    /// When true, .special / .dream rarity items pulse a slow 4 s gloss-band
    /// sweep. Material 3 surface-glow precedent. Use for owned / inventory
    /// items; leave false for shop tiles so unowned rare items stay calm.
    var shouldShimmer: Bool = false

    private var base: Color { Color(hex: colorHex) }
    private var rarity: RewardRarity {
        if let explicit = explicitRarity { return explicit }
        guard let lvl = requiredLevel else { return .everyday }
        switch lvl {
        case ...2: return .everyday
        case 3...4: return .cozy
        case 5...7: return .special
        default: return .dream
        }
    }
    private var ringColor: Color { Color(hex: rarity.colorHex) }
    private var radius: CGFloat { size * 0.22 }

    var body: some View {
        ZStack {
            // 1. Plush gradient backdrop
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(
                    colors: [base.opacity(0.34), base.opacity(0.12)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))

            // 2. Category motif (behind the focal glyph)
            categoryMotif

            // 3. Focal SF Symbol — palette mode with cream highlight tone
            Image(systemName: symbolName)
                .resizable().scaledToFit()
                .symbolRenderingMode(.palette)
                .foregroundStyle(base, Color.white.opacity(0.85), base.opacity(0.6))
                .frame(width: size * 0.52, height: size * 0.52)
                .shadow(color: .white.opacity(0.55), radius: 2, y: -1)
                .shadow(color: .black.opacity(0.12), radius: 5, y: 3)

            // 4. Sanrio-style sparkle satellite at top-right
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.20, weight: .semibold))
                .foregroundStyle(base.opacity(0.72))
                .shadow(color: .white.opacity(0.6), radius: 1)
                .offset(x: size * 0.30, y: -size * 0.30)
                .accessibilityHidden(true)

            // 5. Inner highlight rim (glossy plush)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

            // 6. Rarity ring (Shop only; nil-safe for Inventory)
            if requiredLevel != nil {
                RoundedRectangle(cornerRadius: radius + 1, style: .continuous)
                    .strokeBorder(ringColor.opacity(0.55), lineWidth: 1.5)
                    .padding(-2)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size, height: size)
        .compositingGroup()
        .overlay(shimmerOverlay)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .accessibilityLabel(Text(category))
    }

    @ViewBuilder private var shimmerOverlay: some View {
        // Material 3 surface-glow shimmer — only for owned .special / .dream
        // items, gated by reduceMotion. A 4 s gloss-band sweep keeps the rare
        // tier visibly "alive" without competing with the focal glyph.
        if shouldShimmer && !reduceMotion && (rarity == .special || rarity == .dream) {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let phase = (t.truncatingRemainder(dividingBy: 4.0)) / 4.0
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.30),
                        Color.white.opacity(0)
                    ],
                    startPoint: UnitPoint(x: CGFloat(phase) - 0.3, y: 0),
                    endPoint:   UnitPoint(x: CGFloat(phase) + 0.3, y: 1)
                )
                .blendMode(.plusLighter)
                .mask(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
                .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder private var categoryMotif: some View {
        let cat = category.lowercased()
        if cat.contains("timer") {
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [base, base.opacity(0.3), base, base.opacity(0.3), base],
                        center: .center),
                    lineWidth: 2)
                .frame(width: size * 0.70, height: size * 0.70)
                .opacity(0.55)
        } else if cat.contains("treat") {
            Image(systemName: "wind")
                .font(.system(size: size * 0.18, weight: .light))
                .foregroundStyle(base.opacity(0.5))
                .offset(y: -size * 0.32)
        } else if cat.contains("room") {
            VStack {
                Spacer()
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#FFEDD9").opacity(0.0),
                                 Color(hex: "#FFEDD9").opacity(0.55)],
                        startPoint: .top, endPoint: .bottom))
                    .frame(height: size * 0.32)
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else if cat.contains("outfit") {
            Image(systemName: "tag.fill")
                .font(.system(size: size * 0.16, weight: .semibold))
                .foregroundStyle(base.opacity(0.55))
                .rotationEffect(.degrees(-12))
                .offset(x: -size * 0.30, y: -size * 0.30)
        } else if cat.contains("accessory") {
            Image(systemName: "heart.fill")
                .font(.system(size: size * 0.16, weight: .semibold))
                .foregroundStyle(base.opacity(0.55))
                .offset(x: size * 0.28, y: size * 0.28)
        }
    }
}
