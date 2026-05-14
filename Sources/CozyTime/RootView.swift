import CozyCore
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case today
    case upcoming
    case calendar
    case tasks
    case countdowns
    case focus
    case habits
    case stats
    case rewards
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
        case .rewards: "Rewards Room"
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
        case .rewards: "shippingbox.fill"
        case .settings: "gearshape.fill"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var timerStore: FocusTimerStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    @State private var selectedSection: AppSection? = Self.initialSelectedSection()

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    private let sidebarGroups: [(title: String, sections: [AppSection])] = [
        ("Start", [.today, .focus, .tasks]),
        ("Plan", [.upcoming, .calendar, .countdowns]),
        ("Grow", [.habits, .stats, .rewards]),
        ("App", [.settings])
    ]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(sidebarGroups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.sections) { section in
                            sidebarButton(for: section)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
            .accessibilityLabel("CozyTime sections")
            .safeAreaInset(edge: .bottom) {
                SidebarTimerStatus()
                    .environmentObject(timerStore)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        } detail: {
            Group {
                switch selectedSection ?? .today {
                case .today:
                    TodayView()
                case .upcoming:
                    UpcomingView()
                case .calendar:
                    CalendarPlannerView()
                case .tasks:
                    TasksView()
                case .countdowns:
                    CountdownsView()
                case .focus:
                    FocusView()
                case .habits:
                    HabitsView()
                case .stats:
                    StatsView()
                case .rewards:
                    RewardsRoomView()
                case .settings:
                    SettingsScreen()
                }
            }
            .cozyBackground()
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\((selectedSection ?? .today).title) screen")
        }
        .onReceive(NotificationCenter.default.publisher(for: .cozyOpenSection)) { notification in
            guard let rawValue = notification.object as? String,
                  let section = AppSection(rawValue: rawValue) else { return }
            selectedSection = section
        }
        .onAppear {
            NotificationCenter.default.post(name: .cozyRootViewReady, object: nil)
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
        case .rewards:
            return theme.reward
        case .settings:
            return CozyPalette.secondaryText(colorScheme)
        }
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
            return CozyPalette.selectionFill.opacity(colorScheme == .dark ? 0.20 : 0.78)
        }
        if isHovering {
            return CozyPalette.selectionFill.opacity(colorScheme == .dark ? 0.11 : 0.42)
        }
        return .clear
    }

    var body: some View {
        Button {
            selectedSection = section
        } label: {
            HStack(spacing: 10) {
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
        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
        .listRowBackground(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(rowFill)
                .padding(.vertical, 1)
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
            MascotView(state: mascotState, size: 72)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(CozyType.pageTitle)
                    .foregroundStyle(CozyPalette.primaryText(colorScheme))
                Text(subtitle)
                    .font(CozyType.body)
                    .foregroundStyle(CozyPalette.secondaryText(colorScheme))
            }
            Spacer()
        }
        .padding(.bottom, 6)
    }
}

struct SidebarTimerStatus: View {
    @EnvironmentObject private var timerStore: FocusTimerStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.periodic(from: .now, by: timerStore.isActive ? 1 : 60)) { context in
            VStack(alignment: .leading, spacing: 8) {
                Label(statusTitle(at: context.date), systemImage: timerStore.needsCompletionReview ? "checkmark.seal.fill" : "timer")
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                if timerStore.isActive || timerStore.needsCompletionReview {
                    Text(timerStore.needsCompletionReview ? "Claim reward" : CozyFormatters.timerString(timerStore.remaining(at: context.date)))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(CozyPalette.focusJade)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(CozyPalette.raisedFill(colorScheme).opacity(0.92))
            )
            .accessibilityIdentifier("sidebar.timerStatus")
        }
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
