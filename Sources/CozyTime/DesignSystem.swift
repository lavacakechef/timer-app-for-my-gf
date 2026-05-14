import CozyCore
import AppKit
import SwiftUI

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

enum CozyType {
    static let pageTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let cardTitle = Font.system(.title3, design: .rounded).weight(.bold)
    static let metric = Font.system(size: 34, weight: .black, design: .rounded)
    static let timer = Font.system(size: 42, weight: .black, design: .rounded)
    static let body = Font.callout
    static let control = Font.callout.weight(.medium)
    static let controlStrong = Font.callout.weight(.bold)
    static let caption = Font.caption
    static let captionStrong = Font.caption.weight(.semibold)
    static let badge = Font.caption2.weight(.bold)
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

    static func quietContainer(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkRaised.opacity(0.72) : Color(hex: "#FFF5F0")
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
            case .delete: NSSound.Name("Funk")
            }
        }
    }

    static func play(_ cue: Cue) {
        guard UserDefaults.standard.bool(forKey: "soundsEnabled") else { return }
        if NSSound(named: cue.soundName)?.play() != true {
            NSSound.beep()
        }
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
            symbolName: "ribbon.fill"
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

    static let all: [CozyMascotStyle] = [
        CozyMascotStyle(id: "maltese", title: "Maltese", subtitle: "Soft puppy buddy", symbolName: "pawprint.fill"),
        CozyMascotStyle(id: "twinkle", title: "Twinkle", subtitle: "Tiny star sprite", symbolName: "sparkles"),
        CozyMascotStyle(id: "cloud", title: "Cloud Pup", subtitle: "Sleepy cloud friend", symbolName: "cloud.fill")
    ]

    static func named(_ id: String) -> CozyMascotStyle {
        all.first { $0.id == id } ?? all[0]
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
    let theme: CozyTheme
    var isSelected = false

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(theme.secondary.opacity(0.55))
                Image(systemName: theme.symbolName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.accent)
            }
            .frame(width: 28, height: 28)
            Text(theme.id)
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
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
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(backgroundFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(iconBorder, lineWidth: isFocused && isEnabled ? 2 : 1)
                )
                .scaleEffect(!reduceMotion && configuration.isPressed ? 0.96 : 1)
                .opacity(isEnabled ? 1 : 0.58)
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .focused($isFocused)
                .focusable(true)
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
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(border, lineWidth: isFocused && isEnabled ? 2 : 1)
                )
                .shadow(color: shadow, radius: kind == .primary && isEnabled ? 10 : 0, y: kind == .primary && isEnabled ? 4 : 0)
                .scaleEffect(!reduceMotion && configuration.isPressed ? 0.985 : 1)
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .focused($isFocused)
                .focusable(true)
                .animation(.snappy(duration: 0.14), value: configuration.isPressed)
                .animation(.snappy(duration: 0.16), value: isHovering)
                .onHover { isHovering = $0 }
        }

        private var foreground: Color {
            guard isEnabled else { return CozyPalette.secondaryText(colorScheme) }
            switch kind {
            case .primary:
                return .white
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
                    if let subtitle {
                        Text(subtitle)
                            .font(CozyType.caption)
                            .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 10)
                switchTrack
            }
            .padding(.horizontal, 12)
            .padding(.vertical, subtitle == nil ? 9 : 10)
            .frame(maxWidth: .infinity, minHeight: CozyLayout.controlHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: isFocused && isEnabled ? 2 : isHovering && isEnabled ? 1.35 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .focused($isFocused)
        .focusable(true)
        .onHover { isHovering = $0 }
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }

    private var switchTrack: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? theme.accent : CozyPalette.cardBorder(colorScheme))
                .frame(width: 46, height: 26)
            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
                .padding(.horizontal, 3)
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
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isExpanded ? theme.secondary.opacity(colorScheme == .dark ? 0.14 : 0.30) : CozyPalette.quietContainer(colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isExpanded ? theme.accent.opacity(0.26) : CozyPalette.cardBorder(colorScheme), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

            if isExpanded {
                content
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
                    .transition(.opacity.combined(with: reduceMotion ? .identity : .move(edge: .top)))
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
}

struct CozyCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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
                            .stroke(CozyPalette.cardBorder(colorScheme), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.055), radius: 10, y: 3)
            .foregroundStyle(CozyPalette.primaryText(colorScheme))
    }
}

struct CozyHeroCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
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
                                    .stroke(CozyPalette.cardBorder(colorScheme), lineWidth: 1)
                            )
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.26 : 0.08), radius: 18, y: 8)
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
    func body(content: Content) -> some View {
        content
            .frame(minHeight: CozyLayout.compactTileMinHeight, alignment: .topLeading)
    }
}

struct CozyFieldShell: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName

    var minWidth: CGFloat?
    var width: CGFloat?
    var minHeight: CGFloat = 38
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
            decorated(content)
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
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isEnabled ? CozyPalette.raisedFill(colorScheme) : CozyPalette.quietContainer(colorScheme).opacity(0.62))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: (isFocused || isHovering) && isEnabled ? 1.35 : 1)
            )
            .shadow(color: isFocused ? borderColor.opacity(0.16) : .clear, radius: 8, y: 0)
            .opacity(isEnabled ? 1 : 0.62)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        HStack(spacing: 6) {
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
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            CozyFormCaption(title: title, symbolName: symbolName)
            content
        }
        .frame(minWidth: minWidth ?? CozyLayout.labeledControlMinWidth, alignment: .leading)
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
                    .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .font(CozyType.controlStrong)
                .foregroundStyle(selection == option.id ? Color.white : CozyPalette.primaryText(colorScheme))
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(selection == option.id ? theme.accent : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
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
                .stroke(CozyPalette.cardBorder(colorScheme), lineWidth: 1)
        )
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
    var quickChoices: [CozyDateQuickChoice] = [
        CozyDateQuickChoice("Tomorrow", daysFromToday: 1),
        CozyDateQuickChoice("7 days", daysFromToday: 7),
        CozyDateQuickChoice("30 days", daysFromToday: 30)
    ]

    @Environment(\.colorScheme) private var colorScheme
    @State private var showsCalendar = false

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
                .frame(minWidth: 190, maxWidth: .infinity, minHeight: CozyLayout.controlHeight, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .cozyControlShell(minWidth: 190, alignment: .leading)
            .popover(isPresented: $showsCalendar, arrowEdge: .bottom) {
                calendarPopover
            }
            .accessibilityLabel("Countdown date")
            .accessibilityValue(displayText)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    quickChoiceButtons
                }
                LazyVGrid(columns: CozyLayout.adaptiveColumns(minimum: 78), spacing: 6) {
                    quickChoiceButtons
                }
            }

            if isPastDate {
                CozyFieldHint(text: "Pick today or a future date.", isError: true)
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
            Text("Choose a date")
                .font(CozyType.cardTitle)
            DatePicker("Countdown date", selection: $date, in: Date()..., displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .labelsHidden()
                .frame(minWidth: 280)
            HStack {
                Spacer()
                Button("Done") {
                    showsCalendar = false
                }
                .cozyPrimaryButton(minWidth: 92)
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(CozyPalette.cardFill(colorScheme))
    }
}

extension View {
    func cozyCard() -> some View {
        modifier(CozyCard())
    }

    func cozyHeroCard() -> some View {
        modifier(CozyHeroCard())
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

struct MascotView: View {
    let state: MascotState
    var size: CGFloat = 96

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

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30 * 60)) { context in
            mascot(moment: MascotMoment.current(at: context.date))
        }
    }

    private func mascot(moment: MascotMoment) -> some View {
        ZStack {
            if !reducedDecoration {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.18), moment.accent.opacity(0.20)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
            }

            mascotBody(moment: moment)
                .scaleEffect(state == .complete && !reduceMotion && !reducedDecoration ? 1.025 : 1)

            if !reducedDecoration {
                TwinkleBuddy(size: size * 0.26, color: moment.accent)
                    .offset(x: size * 0.30, y: -size * 0.30)
                    .accessibilityHidden(true)
            }

            stateAccessory
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(CozyMascotStyle.named(selectedMascotStyle).title): \(state.accessibilityLabel)")
    }

    @ViewBuilder
    private func mascotBody(moment: MascotMoment) -> some View {
        switch CozyMascotStyle.named(selectedMascotStyle).id {
        case "twinkle":
            twinkleMascotBody(moment: moment)
        case "cloud":
            cloudPupBody(moment: moment)
        default:
            dogBody(moment: moment)
        }
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

            Circle()
                .fill(Color.white)
                .frame(width: size * 0.58, height: size * 0.58)
                .shadow(color: accent.opacity(0.16), radius: size * 0.08, y: size * 0.035)

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

    private func twinkleMascotBody(moment: MascotMoment) -> some View {
        ZStack {
            StarShape()
                .fill(
                    LinearGradient(
                        colors: [moment.accent, accent.opacity(0.84)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.70, height: size * 0.70)
                .shadow(color: accent.opacity(0.20), radius: size * 0.09, y: size * 0.04)

            eyes
                .offset(y: -size * 0.02)

            Path { path in
                path.move(to: CGPoint(x: size * 0.42, y: size * 0.58))
                path.addQuadCurve(to: CGPoint(x: size * 0.58, y: size * 0.58), control: CGPoint(x: size * 0.50, y: size * 0.66))
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
        }
    }

    private func cloudPupBody(moment: MascotMoment) -> some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.08))
                .frame(width: size * 0.58, height: size * 0.13)
                .offset(y: size * 0.32)

            HStack(spacing: -size * 0.12) {
                Circle().fill(Color.white).frame(width: size * 0.40, height: size * 0.40)
                Circle().fill(Color(hex: "#FFF8F0")).frame(width: size * 0.54, height: size * 0.54)
                Circle().fill(Color.white).frame(width: size * 0.40, height: size * 0.40)
            }
            .shadow(color: moment.accent.opacity(0.18), radius: size * 0.08, y: size * 0.04)

            Capsule()
                .fill(Color(hex: "#FFF7EF"))
                .frame(width: size * 0.24, height: size * 0.15)
                .offset(y: size * 0.08)

            eyes
                .offset(y: -size * 0.03)

            Capsule()
                .fill(CozyPalette.ink.opacity(0.72))
                .frame(width: size * 0.060, height: size * 0.036)
                .offset(y: size * 0.055)

            HStack(spacing: size * 0.25) {
                Circle().fill(CozyPalette.stickerPink.opacity(0.62)).frame(width: size * 0.060, height: size * 0.040)
                Circle().fill(CozyPalette.stickerPink.opacity(0.62)).frame(width: size * 0.060, height: size * 0.040)
            }
            .offset(y: size * 0.095)

            if state == .focus || state == .deepFocus {
                focusHeadphones
            }

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

struct EquippedMascotView: View {
    let state: MascotState
    let size: CGFloat
    let rewards: [RewardItem]

    private var equippedWearables: [RewardItem] {
        rewards
            .filter { reward in
                reward.isEquipped && (
                    reward.category.localizedCaseInsensitiveContains("accessory")
                        || reward.category.localizedCaseInsensitiveContains("outfit")
                )
            }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        ZStack {
            MascotView(state: state, size: size)
            ForEach(Array(equippedWearables.enumerated()), id: \.element.id) { index, reward in
                Image(systemName: reward.symbolName)
                    .font(.system(size: size * 0.15, weight: .bold))
                    .foregroundStyle(Color(hex: reward.colorHex))
                    .padding(size * 0.06)
                    .background(Circle().fill(Color(hex: reward.colorHex).opacity(0.16)))
                    .offset(accessoryOffset(index: index, size: size))
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilityLabel)
    }

    private func accessoryOffset(index: Int, size: CGFloat) -> CGSize {
        switch index {
        case 0: CGSize(width: size * 0.28, height: -size * 0.32)
        case 1: CGSize(width: -size * 0.30, height: -size * 0.08)
        default: CGSize(width: size * 0.18, height: size * 0.24)
        }
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
                RoundedRectangle(cornerRadius: 10, style: .continuous)
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

struct EmptyStateView: View {
    let title: String
    let message: String
    let mascotState: MascotState
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        message: String,
        mascotState: MascotState,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.mascotState = mascotState
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 14) {
            MascotView(state: mascotState, size: 86)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .cozyPrimaryButton(minWidth: 148)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
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
        .frame(height: 7)
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
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.headline.weight(.bold))
                Text(title)
                    .font(.caption2.weight(.semibold))
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
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: rarity.colorHex).opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
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
