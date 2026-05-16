import CozyCore
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case today
    case calendar
    case tasks
    // Legacy routes — no longer in the visible sidebar (per gf-requested
    // sidebar simplification). Notifications can still post these and the
    // router redirects them to a sensible destination (Tasks / Calendar).
    case upcoming     // → redirects to .tasks (Upcoming is a time filter inside Tasks)
    case countdowns   // → redirects to .calendar (Countdowns now live on Calendar)
    case focus
    case habits
    case stats
    case rewards
    case shop         // → sidebar shortcut that opens Rewards Room on the Shop tab
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .upcoming: "Upcoming"
        case .calendar: "Calendar"
        case .tasks: "Tasks"
        case .countdowns: "Countdowns"
        case .focus: "Focus"
        case .habits: "Habits"
        case .stats: "Stats"
        case .rewards: "Desk Room"
        case .shop: "Shop"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max.fill"
        case .upcoming: "calendar.badge.clock"
        case .calendar: "calendar"
        case .tasks: "checklist"
        case .countdowns: "hourglass"
        case .focus: "timer"
        case .habits: "sparkles"
        case .stats: "chart.bar.xaxis"
        case .rewards: "sparkles.rectangle.stack.fill"
        case .shop: "bag.fill"
        case .settings: "gearshape.fill"
        }
    }

    // Resolves legacy routes (upcoming, countdowns) to their new homes after
    // the sidebar consolidation. Use this when responding to navigation
    // notifications so existing call-sites (e.g. CountdownCompactCard,
    // CozyTimeApp ⌘-shortcuts) keep working without code-mod.
    var resolvedDestination: AppSection {
        switch self {
        case .upcoming: .tasks
        case .countdowns: .calendar
        default: self
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var timerStore: FocusTimerStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    // Shared with RewardsRoomView so the sidebar Shop shortcut can pre-select
    // the shop tab before navigation lands.
    @AppStorage("selectedRewardsMode") private var selectedRewardsMode: String = "room"
    // UX MED #97: persist selected sidebar section across launches via
    // SceneStorage. Falls back to the section provided by -cozy-start-section
    // launch arg / .cozyOpenSection notification on first run.
    @SceneStorage("cozy.selectedSection") private var storedSection: String = ""
    @State private var selectedSection: AppSection? = Self.initialSelectedSection()

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    // Sidebar slimmed from 10 → 7 visible sections per gf feedback:
    //   - "Upcoming" removed (redundant with Tasks; now a filter inside Tasks)
    //   - "Countdowns" removed (folded into Calendar — date-pinned events
    //     live alongside calendar days)
    private let sidebarGroups: [(title: String, subtitle: String, sections: [AppSection])] = [
        ("Start", "Focus & task quick-add", [.today, .focus, .tasks]),
        ("Plan", "Tasks & countdowns", [.calendar]),
        ("Grow", "Habits, rewards & shop", [.habits, .stats, .rewards, .shop]),
        ("App", "Settings & help", [.settings])
    ]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(sidebarGroups, id: \.title) { group in
                    Section(header: SidebarGroupHeader(title: group.title, subtitle: group.subtitle)) {
                        ForEach(group.sections) { section in
                            sidebarButton(for: section)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            // 220pt is the Apple HIG floor for primary sidebars (per macOS sidebar
            // guidance: "225-275 pts as a minimum width"). Previous 180 caused
            // labels to truncate at default-window width.
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 300)
            .accessibilityLabel("CozyTime sections")
            .safeAreaInset(edge: .bottom) {
                SidebarTimerStatus()
                    .environmentObject(timerStore)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        } detail: {
            Group {
                switch selectedSection ?? .today {
                case .today:
                    TodayView()
                case .upcoming:
                    // Redirected destination — Upcoming now lives as a time filter
                    // inside Tasks. Render Tasks pre-filtered to .upcoming.
                    TasksView(initialTimeFilter: .upcoming)
                case .calendar:
                    CalendarPlannerView()
                case .tasks:
                    TasksView()
                case .countdowns:
                    // Redirected destination — Countdowns now live inside Calendar.
                    CalendarPlannerView()
                case .focus:
                    FocusView()
                case .habits:
                    HabitsView()
                case .stats:
                    StatsView()
                case .rewards:
                    RewardsRoomView()
                case .shop:
                    RewardsRoomView()
                case .settings:
                    SettingsScreen()
                }
            }
            .cozyBackground()
            .safeAreaInset(edge: .top, spacing: 0) {
                CozyDataStoreErrorBanner()
                    .environmentObject(dataStore)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                // Welcome-back reassurance — only shown on the first launch
                // after CFBundleShortVersionString bumps. Reads real counts
                // from the data store so the user sees "your N focus
                // sessions and M unlocks are safe" instead of generic copy.
                WelcomeBackBanner(
                    focusSessionCount: dataStore.focusSessions.count,
                    unlockedRewardCount: dataStore.rewards.count
                )
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\((selectedSection ?? .today).title) screen")
        }
        .onReceive(NotificationCenter.default.publisher(for: .cozyOpenSection)) { notification in
            guard let rawValue = notification.object as? String,
                  let section = AppSection(rawValue: rawValue) else { return }
            // Resolve legacy routes (.upcoming → .tasks, .countdowns → .calendar)
            // so old notifications keep landing somewhere sensible.
            selectedSection = section.resolvedDestination
        }
        // UX HIGH #85: ⌘N context-aware. Commands posts `.cozyNewItem`; we
        // resolve which section is active and re-post the matching scoped
        // notification so each composer can subscribe via .onReceive without
        // knowing about the others.
        .onReceive(NotificationCenter.default.publisher(for: .cozyNewItem)) { _ in
            switch (selectedSection ?? .today).resolvedDestination {
            case .habits:
                NotificationCenter.default.post(name: .cozyNewHabit, object: nil)
            case .calendar:
                NotificationCenter.default.post(name: .cozyNewCountdown, object: nil)
            default:
                // Today / Tasks / everything-else: focus the task quick-add bar.
                // If the user is on a section without a composer (e.g. Stats /
                // Rewards / Settings), navigate to Tasks first so the keystroke
                // still produces a useful affordance.
                if (selectedSection ?? .today).resolvedDestination != .tasks
                    && (selectedSection ?? .today).resolvedDestination != .today {
                    selectedSection = .tasks
                }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .cozyNewTask, object: nil)
                }
            }
        }
        .onAppear {
            // Restore last-selected section from SceneStorage if no launch
            // arg explicitly requested one (and the launch arg path didn't
            // already pick something other than .today on first run).
            if !storedSection.isEmpty,
               let restored = AppSection(rawValue: storedSection),
               selectedSection == .today {
                selectedSection = restored.resolvedDestination
            }
            NotificationCenter.default.post(name: .cozyRootViewReady, object: nil)
        }
        .onChange(of: selectedSection) { _, newValue in
            storedSection = newValue?.rawValue ?? ""
            // When the sidebar Shop shortcut is tapped, pre-select the shop
            // tab inside RewardsRoomView before the view renders.
            if newValue == .shop {
                selectedRewardsMode = "shop"
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("CozyTime")
        .tint(theme.accent)
    }

    private static func initialSelectedSection() -> AppSection {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-cozy-start-section"),
              arguments.indices.contains(flagIndex + 1),
              let section = AppSection(rawValue: arguments[flagIndex + 1]) else {
            return .today
        }
        return section
    }

    private func sidebarButton(for section: AppSection) -> some View {
        SidebarRowButton(
            section: section,
            selectedSection: $selectedSection,
            accent: sectionColor(section)
        )
    }

    private func sectionColor(_ section: AppSection) -> Color {
        switch section {
        case .today, .tasks:
            return theme.accent
        case .focus:
            return CozyPalette.focusJade
        case .upcoming, .calendar, .countdowns:
            return CozyPalette.countdownBerry
        case .habits:
            return CozyPalette.habitLavender
        case .stats:
            return CozyPalette.skyBlue
        case .rewards, .shop:
            return theme.reward
        case .settings:
            return CozyPalette.secondaryText(colorScheme)
        }
    }
}

// U3.8 — hover subtitles on sidebar group labels.
// The subtitle fades in on pointer-enter and out on pointer-leave.
// Animation is gated on reduceMotion: CozyMotion.gentle returns nil (instant)
// when Reduce Motion is enabled, satisfying AM-001.
private struct SidebarGroupHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let subtitle: String
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(CozyType.captionStrong)
                .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                .textCase(.uppercase)
                .tracking(0.5)
            if isHovered {
                Text(subtitle)
                    .font(CozyType.footnote.italic())
                    .foregroundStyle(CozyPalette.secondaryText(colorScheme).opacity(0.7))
                    .transition(.opacity)
            }
        }
        .animation(CozyMotion.gentle(reduceMotion, duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

private struct SidebarRowButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let section: AppSection
    @Binding var selectedSection: AppSection?
    let accent: Color
    @State private var isHovering = false

    private var isSelected: Bool {
        selectedSection == section
    }

    private var rowFill: Color {
        if isSelected {
            // T2.3: dark-mode active row was 0.20 (barely visible against
            // raisedFill); 0.40 reads as a clear themed selection.
            return CozyPalette.selectionFill.opacity(colorScheme == .dark ? 0.40 : 0.78)
        }
        if isHovering {
            return CozyPalette.selectionFill.opacity(colorScheme == .dark ? 0.18 : 0.42)
        }
        return .clear
    }

    var body: some View {
        Button {
            selectedSection = section
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected || isHovering ? accent : CozyPalette.secondaryText(colorScheme))
                    .frame(width: 24, alignment: .center)
                Text(section.title)
                    .foregroundStyle(CozyPalette.primaryText(colorScheme))
                Spacer(minLength: 0)
                if isHovering && !isSelected {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
        .listRowBackground(
            RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
                .fill(rowFill)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
        )
        .accessibilityLabel(section.title)
        .accessibilityIdentifier("sidebar.\(section.rawValue)")
    }
}

struct SectionHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String
    let mascotState: MascotState

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            MascotView(state: mascotState, size: .card)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(CozyType.pageTitle)
                    .foregroundStyle(CozyPalette.primaryText(colorScheme))
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(CozyType.body)
                    .foregroundStyle(CozyPalette.secondaryText(colorScheme))
            }
            Spacer()
        }
        .padding(.bottom, 8)
    }
}

struct SidebarTimerStatus: View {
    @EnvironmentObject private var timerStore: FocusTimerStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName

    var body: some View {
        let theme = CozyTheme.named(selectedTheme)
        TimelineView(.periodic(from: .now, by: timerStore.isActive ? 1 : 60)) { context in
            // UX LOW #102 — idle sidebar pill collapses to a slim 28pt "Start
            // a session" affordance. Full pill (mascot + timer + progress)
            // only renders while the timer is active or waiting for review;
            // idle state shouldn't dominate the lower sidebar where
            // nothing's happening yet.
            if timerStore.isActive || timerStore.needsCompletionReview {
                activePill(theme: theme, at: context.date)
            } else {
                idleAffordance(theme: theme)
            }
        }
    }

    @ViewBuilder
    private func activePill(theme: CozyTheme, at date: Date) -> some View {
        Button {
            NotificationCenter.default.post(name: .cozyOpenSection, object: AppSection.focus.rawValue)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    MascotView(state: timerStore.isActive ? .focus : .idle, size: .inline)
                        .accessibilityHidden(true)
                    Text(timerStore.needsCompletionReview
                         ? CozyFormatters.timerString(0)
                         : CozyFormatters.timerString(timerStore.remaining(at: date)))
                        .font(CozyType.metricSmall)
                        .monospacedDigit()
                        .foregroundStyle(theme.accent)
                    Spacer(minLength: 4)
                }
                Text(statusTitle(at: date))
                    .font(.caption)
                    .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if timerStore.isActive {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(theme.accent.opacity(0.18))
                                .frame(height: 2)
                            Capsule()
                                .fill(theme.accent)
                                .frame(width: geo.size.width * timerStore.progress(at: date), height: 2)
                        }
                    }
                    .frame(height: 2)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
                    .fill(theme.accent.opacity(colorScheme == .dark ? 0.10 : 0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
                    .stroke(theme.accent.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .cozyPressable(pressedScale: 0.985, hoverScale: 1.005)
        .padding(.bottom, 8)
        .help("Open the running focus session")
        .accessibilityLabel("Open running focus session")
        .accessibilityIdentifier("sidebar.timerStatus")
    }

    @ViewBuilder
    private func idleAffordance(theme: CozyTheme) -> some View {
        Button {
            NotificationCenter.default.post(name: .cozyOpenSection, object: AppSection.focus.rawValue)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.accent)
                Text("Start a session")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CozyPalette.primaryText(colorScheme))
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CozyLayout.subCardRadius, style: .continuous)
                    .fill(theme.accent.opacity(colorScheme == .dark ? 0.10 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CozyLayout.subCardRadius, style: .continuous)
                    .stroke(theme.accent.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .cozyPressable(pressedScale: 0.985, hoverScale: 1.005)
        .padding(.bottom, 8)
        .help("Open Focus")
        .accessibilityLabel("Open Focus")
        .accessibilityIdentifier("sidebar.timerStatus")
    }

    private func statusTitle(at date: Date) -> String {
        if timerStore.needsCompletionReview {
            return "\(timerStore.activeTaskTitle) finished"
        }
        if timerStore.isActive {
            return timerStore.activeTaskTitle
        }
        return "Ready for a tiny session"
    }
}

private struct CozyDataStoreErrorBanner: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let message = bannerMessage {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(CozyPalette.overdue)
                    .imageScale(.medium)
                Text(message)
                    .font(CozyType.body.weight(.semibold))
                    .foregroundStyle(CozyPalette.primaryText(colorScheme))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
            }
            .padding(.horizontal, CozyLayout.cardPadding)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(CozyPalette.overdue.opacity(colorScheme == .dark ? 0.18 : 0.12))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Save warning: \(message)")
        }
    }

    private var bannerMessage: String? {
        if let containerFailure = dataStore.containerFailureMessage {
            return containerFailure
        }
        return dataStore.lastSaveError
    }
}
