import AppKit
import Charts
import CozyCore
import SwiftUI
@preconcurrency import UserNotifications

struct HabitsView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    @State private var newHabitTitle = ""
    @State private var targetPerWeek = 4

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CozyLayout.sectionSpacing) {
                SectionHeader(title: "Habits", subtitle: "Gentle consistency with grace days.", mascotState: .complete)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: CozyLayout.formRowSpacing) {
                        habitField
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(alignment: .top, spacing: CozyLayout.formRowSpacing) {
                            targetStepper
                            addButton
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    VStack(alignment: .leading, spacing: CozyLayout.formRowSpacing) {
                        habitField
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(alignment: .top, spacing: CozyLayout.formRowSpacing) {
                            targetStepper
                            addButton
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .cozyCard()

                if dataStore.habits.isEmpty {
                    EmptyStateView(
                        title: "No habits yet",
                        message: "Pick something gentle enough to repeat.",
                        mascotState: .complete,
                        actionTitle: "Add a tiny habit"
                    ) {
                        newHabitTitle = "One focused block"
                        addHabit()
                    }
                        .frame(minHeight: 280)
                } else {
                    LazyVGrid(columns: CozyLayout.twoColumnCards, spacing: CozyLayout.gridSpacing) {
                        ForEach(dataStore.habits.sorted { $0.createdAt < $1.createdAt }) { habit in
                            HabitCard(habit: habit)
                        }
                    }
                }
            }
            .cozyPageFrame()
        }
        .accessibilityIdentifier("screen.habits")
    }

    private var habitField: some View {
        CozyLabeledControl(title: "Habit", symbolName: "leaf", minWidth: 240) {
            VStack(alignment: .leading, spacing: 6) {
                TextField("New habit", text: $newHabitTitle)
                    .onSubmit(addHabit)
                    .accessibilityIdentifier("habit.title")
                    .cozyTextInput(minWidth: 240, alignment: .leading)
                if cleanHabitTitle.isEmpty {
                    CozyFieldHint(text: "Name the habit first.")
                }
            }
        }
        .layoutPriority(1)
    }

    private var targetStepper: some View {
        CozyLabeledControl(title: "Weekly goal", symbolName: "target") {
            CozyStepperField(value: $targetPerWeek, range: 1...7) { "\($0)/week" }
                .accessibilityIdentifier("habit.target")
        }
    }

    private var addButton: some View {
        CozyLabeledControl(title: "Action", symbolName: "plus.circle", minWidth: 142) {
            Button {
                addHabit()
            } label: {
                Label("Add Habit", systemImage: "plus")
            }
            .cozyPrimaryButton(minWidth: 138, fullWidth: true)
            .disabled(cleanHabitTitle.isEmpty)
            .help(cleanHabitTitle.isEmpty ? "Type a habit name first." : "Add this habit.")
            .accessibilityHint(cleanHabitTitle.isEmpty ? "Type a habit name first." : "Add this habit.")
            .accessibilityIdentifier("habit.add")
        }
    }

    private func addHabit() {
        guard !cleanHabitTitle.isEmpty else { return }
        dataStore.addHabit(Habit(title: cleanHabitTitle, targetPerWeek: targetPerWeek, stickerName: theme.symbolName))
        CozyFeedback.play(.add)
        newHabitTitle = ""
    }

    private var cleanHabitTitle: String {
        newHabitTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct HabitCard: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @AppStorage("hideStreaks") private var hideStreaks = false
    let habit: Habit
    @State private var isConfirmingDelete = false
    @State private var habitFeedback: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: habit.stickerName)
                    .font(.title2)
                    .foregroundStyle(CozyHabitColor.primary)
                VStack(alignment: .leading) {
                    Text(habit.title)
                        .font(.headline)
                    Text("\(HabitMath.completionsInCurrentWeek(keys: habit.completionKeys, now: Date())) / \(habit.targetPerWeek) this week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    toggleHabit(on: Date())
                } label: {
                    Image(systemName: HabitMath.isComplete(keys: habit.completionKeys, on: Date()) ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .frame(width: CozyLayout.hitSize, height: CozyLayout.hitSize)
                }
                .buttonStyle(.plain)
                .cozyPressable(pressedScale: 0.90, hoverScale: 1.08)
                .contentShape(Circle())
                .foregroundStyle(CozyHabitColor.primary)
                .help("Toggle today")
                .accessibilityLabel("Toggle \(habit.title) for today")
                .accessibilityIdentifier("habit.toggle")
                Button(role: .destructive) {
                    withAnimation(.snappy(duration: 0.18)) {
                        isConfirmingDelete.toggle()
                    }
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 18, height: 18)
                }
                .cozyIconButton(size: CozyLayout.compactHitSize)
                .help("Delete habit")
                .accessibilityLabel("Delete \(habit.title)")
            }

            HStack(spacing: 6) {
                ForEach(lastSevenDays, id: \.self) { day in
                    Button {
                        toggleHabit(on: day)
                    } label: {
                        VStack(spacing: 4) {
                            Text(day, format: .dateTime.weekday(.narrow))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                            Circle()
                                .fill(HabitMath.isComplete(keys: habit.completionKeys, on: day) ? CozyHabitColor.primary : CozyPalette.lavenderMist)
                                .overlay(
                                    Circle()
                                        .stroke(CozyHabitColor.primary.opacity(0.28), lineWidth: 1)
                                )
                                .frame(width: 20, height: 20)
                        }
                        .frame(width: CozyLayout.hitSize, height: CozyLayout.hitSize)
                    }
                    .buttonStyle(.plain)
                    .cozyPressable(pressedScale: 0.82, hoverScale: 1.18)
                    .contentShape(Circle())
                    .help("Toggle \(habit.title) for \(CozyFormatters.shortDate.string(from: day))")
                    .accessibilityLabel("\(habit.title), \(CozyFormatters.shortDate.string(from: day))")
                    .accessibilityValue(HabitMath.isComplete(keys: habit.completionKeys, on: day) ? "Complete" : "Not complete")
                }
            }

            if let habitFeedback {
                Label(habitFeedback, systemImage: "sparkles")
                    .font(CozyType.captionStrong)
                    .foregroundStyle(CozyPalette.focusJade)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if hideStreaks {
                Text("Momentum: \(HabitMath.completionsInCurrentWeek(keys: habit.completionKeys, now: Date())) gentle checks this week")
                    .font(.callout.weight(.semibold))
            } else {
                Text("Current rhythm: \(HabitMath.currentStreak(keys: habit.completionKeys, through: Date(), graceDays: habit.graceDays)) days")
                    .font(.callout.weight(.semibold))
            }

            if isConfirmingDelete {
                HStack(spacing: 10) {
                    Label("Delete this habit?", systemImage: "exclamationmark.triangle.fill")
                        .font(CozyType.captionStrong)
                        .foregroundStyle(CozyPalette.overdue)
                    Spacer()
                    Button("Keep") {
                        withAnimation(.snappy(duration: 0.18)) {
                            isConfirmingDelete = false
                        }
                    }
                    .cozyGhostButton(minWidth: 64)
                    Button(role: .destructive) {
                        dataStore.deleteHabit(id: habit.id)
                        CozyFeedback.play(.delete)
                    } label: {
                        Text("Delete")
                    }
                    .cozyDestructiveButton(minWidth: 76)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(CozyPalette.overdue.opacity(0.08))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .cozyCard()
    }

    private var lastSevenDays: [Date] {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed()
    }

    private func toggleHabit(on day: Date) {
        let wasComplete = HabitMath.isComplete(keys: habit.completionKeys, on: day)
        dataStore.toggleHabit(id: habit.id, at: day)
        CozyFeedback.play(wasComplete ? .undo : .complete)
        withAnimation(.snappy(duration: 0.18)) {
            habitFeedback = wasComplete ? "Check removed" : "+8 XP rhythm"
        }
    }
}

struct TodayHabitCard: View {
    @EnvironmentObject private var dataStore: AppDataStore

    var body: some View {
        Button {
            NotificationCenter.default.post(name: .cozyOpenSection, object: AppSection.habits.rawValue)
        } label: {
            HStack(spacing: 14) {
                MascotView(state: .complete, size: 70)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Habit check")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(titleText)
                        .font(.headline)
                    Text(subtitleText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .compactDashboardTile()
            .cozyCard()
        }
        .cozyPressable()
    }

    private var titleText: String {
        dataStore.habits.isEmpty ? "No habits yet" : "\(completedToday) / \(dataStore.habits.count) done today"
    }

    private var subtitleText: String {
        dataStore.habits.isEmpty ? "Tap to add one tiny habit" : "Tap to stamp today's rhythm"
    }

    private var completedToday: Int {
        dataStore.habits.filter { HabitMath.isComplete(keys: $0.completionKeys, on: Date()) }.count
    }
}

struct ProgressionCard: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("mascotName") private var mascotName = "Mochi"
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    var body: some View {
        let summary = dataStore.progression
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 18) {
                EquippedMascotView(state: summary.progressToNextLevel > 0.72 ? .complete : .idle, size: 86, rewards: dataStore.rewards)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(mascotName) Lv. \(summary.level)")
                                .font(.title2.weight(.bold))
                            Text(summary.petStage.rawValue)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(CozyPalette.focusJade)
                        }
                        Spacer()
                        Label("\(summary.coinsAvailable)", systemImage: "pawprint.fill")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(theme.reward)
                            .accessibilityLabel("\(summary.coinsAvailable) paws")
                    }
                    CozyLinearProgressBar(value: summary.progressToNextLevel, color: CozyPalette.focusJade)
                        .accessibilityLabel("Progress to next level")
                        .accessibilityValue("\(Int(summary.progressToNextLevel * 100)) percent")
                    Text("\(summary.xp) XP earned. \(summary.nextLevelXP - summary.xp) XP until the next room glow-up.")
                        .font(.callout)
                        .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                }
            }
            NextUnlockView(database: dataStore.database)
        }
        .cozyCard()
        .accessibilityIdentifier("progression.card")
    }
}

struct StatsView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CozyLayout.sectionSpacing) {
                SectionHeader(title: "Stats", subtitle: "Progress without shame metrics.", mascotState: .complete)
                LazyVGrid(columns: CozyLayout.metricColumns, spacing: CozyLayout.gridSpacing) {
                    StatCard(title: "Focus time", value: "\(totalFocusMinutes)m", symbol: "timer", color: CozyPalette.focusJade)
                    StatCard(title: "Tasks complete", value: "\(completedTasks)", symbol: "checkmark.circle.fill", color: CozyPalette.berry)
                    StatCard(title: "Habits today", value: "\(completedHabitsToday)/\(dataStore.habits.count)", symbol: "sparkles", color: CozyHabitColor.primary)
                    StatCard(title: "Mochi level", value: "\(dataStore.progression.level)", symbol: "pawprint.fill", color: theme.reward)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Focus trend")
                        .font(.title2.weight(.bold))
                    ZStack {
                        Chart(focusChartData) { item in
                            BarMark(
                                x: .value("Day", item.day),
                                y: .value("Minutes", item.minutes)
                            )
                            .foregroundStyle(CozyStatsColor.focus)
                        }
                        .chartYAxisLabel("Minutes")

                        if totalFocusMinutes == 0 {
                            VStack(spacing: 10) {
                                MascotView(state: .settling, size: 72)
                                Text("No focus history yet")
                                    .font(.headline)
                                Button {
                                    NotificationCenter.default.post(name: .cozyOpenSection, object: AppSection.focus.rawValue)
                                } label: {
                                    Label("Open Focus", systemImage: "timer")
                                }
                                .cozyPrimaryButton(minWidth: 132)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.ultraThinMaterial)
                        }
                    }
                    .frame(height: 220)
                }
                .cozyCard()
            }
            .cozyPageFrame()
        }
        .accessibilityIdentifier("screen.stats")
    }

    private var totalFocusMinutes: Int {
        dataStore.focusSessions.reduce(0) { $0 + $1.completedMinutes }
    }

    private var completedTasks: Int {
        dataStore.tasks.filter(\.isCompleted).count
    }

    private var completedHabitsToday: Int {
        dataStore.habits.filter { HabitMath.isComplete(keys: $0.completionKeys, on: Date()) }.count
    }

    private var focusChartData: [FocusChartItem] {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset -> FocusChartItem? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let minutes = dataStore.focusSessions
                .filter { calendar.isDate($0.reportingDate, inSameDayAs: date) }
                .reduce(0) { $0 + $1.completedMinutes }
            return FocusChartItem(day: CozyFormatters.dayName.string(from: date), minutes: minutes)
        }
        .reversed()
    }
}

struct FocusChartItem: Identifiable {
    let id = UUID()
    let day: String
    let minutes: Int
}

struct StatCard: View {
    let title: String
    let value: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(color)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                Text(value)
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
            }
            Spacer()
        }
        .frame(minHeight: 58, alignment: .center)
        .cozyCard()
    }
}

struct RewardsRoomView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @State private var selectedMode: RewardsRoomMode = .room

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CozyLayout.sectionSpacing) {
                SectionHeader(title: "Rewards Room", subtitle: "Earn paws, dress Mochi, and decorate the desk.", mascotState: .complete)
                CozySegmentedControl(
                    options: RewardsRoomMode.allCases.map { mode in
                        CozySegmentOption(mode, title: mode.title, symbolName: mode.symbolName)
                    },
                    selection: $selectedMode,
                    minSegmentWidth: 110
                )
                .accessibilityIdentifier("rewards.mode")

                switch selectedMode {
                case .room:
                    roomContent
                case .shop:
                    shopContent
                case .inventory:
                    inventoryContent
                }
            }
            .cozyPageFrame()
        }
        .accessibilityIdentifier("screen.rewards")
    }

    private var roomContent: some View {
        VStack(alignment: .leading, spacing: CozyLayout.sectionSpacing) {
            LatestUnlockStrip()
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: CozyLayout.gridSpacing) {
                    ProgressionCard()
                        .frame(width: 400)
                    DeskRoomScene()
                        .frame(maxWidth: .infinity)
                }
                VStack(alignment: .leading, spacing: CozyLayout.gridSpacing) {
                    ProgressionCard()
                    DeskRoomScene()
                }
            }
            AdventureRulesCard()
            MilestoneShelf()
        }
    }

    private var shopContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mochi Shop")
                    .font(.title2.weight(.bold))
                Spacer()
                Label("\(dataStore.progression.coinsAvailable)", systemImage: "pawprint.fill")
                    .font(.headline.weight(.bold))
            }
            LazyVGrid(columns: CozyLayout.adaptiveColumns(minimum: 220), spacing: CozyLayout.gridSpacing) {
                ForEach(CozyProgression.shopCatalog) { item in
                    ShopItemCard(item: item)
                }
            }
        }
    }

    private var inventoryContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inventory")
                .font(.title2.weight(.bold))
            if dataStore.rewards.isEmpty {
                EmptyStateView(
                    title: "Room is waiting",
                    message: "Complete a tiny session to stamp your first sticker.",
                    mascotState: .complete,
                    actionTitle: "Start a tiny focus"
                ) {
                    NotificationCenter.default.post(name: .cozyOpenSection, object: AppSection.focus.rawValue)
                }
                .frame(minHeight: 220)
            } else {
                LazyVGrid(columns: CozyLayout.adaptiveColumns(minimum: 180), spacing: CozyLayout.gridSpacing) {
                    ForEach(dataStore.rewards.sorted { $0.unlockedAt < $1.unlockedAt }) { reward in
                        RewardCard(reward: reward)
                    }
                }
            }
        }
    }
}

enum RewardsRoomMode: String, CaseIterable, Identifiable {
    case room
    case shop
    case inventory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .room: "Room"
        case .shop: "Shop"
        case .inventory: "Inventory"
        }
    }

    var symbolName: String {
        switch self {
        case .room: "house.fill"
        case .shop: "bag.fill"
        case .inventory: "shippingbox.fill"
        }
    }
}

struct LatestUnlockStrip: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    private var latestRewards: [RewardItem] {
        Array(dataStore.rewards.sorted { $0.unlockedAt > $1.unlockedAt }.prefix(3))
    }

    var body: some View {
        HStack(spacing: 12) {
            if latestRewards.isEmpty {
                NextUnlockView(database: dataStore.database)
            } else {
                Label("Latest unlocks", systemImage: "gift.fill")
                    .font(.headline)
                    .foregroundStyle(CozyPalette.focusJade)
                ForEach(latestRewards) { reward in
                    Label(reward.name, systemImage: reward.symbolName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Color(hex: reward.colorHex).opacity(0.14))
                        )
                        .foregroundStyle(Color(hex: reward.colorHex))
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, minHeight: latestRewards.isEmpty ? 96 : 76, alignment: .topLeading)
        .cozyCard()
    }
}

struct AdventureRulesCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RarityIcon(symbol: "dice.fill", rarity: .cozy, size: 52)
            VStack(alignment: .leading, spacing: 6) {
                Text("Adventure rolls")
                    .font(.headline)
                Text("Each saved focus can reveal one free cosmetic find. Odds are visible, duplicates become paws, and the shop stays direct-buy.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(CozyProgression.adventureOddsText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .cozyCard()
    }
}

struct DeskRoomMiniCard: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    var body: some View {
        Button {
            NotificationCenter.default.post(name: .cozyOpenSection, object: AppSection.rewards.rawValue)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(CozyPalette.quietContainer(colorScheme))
                        EquippedMascotView(state: .idle, size: 52, rewards: dataStore.rewards)
                            .offset(x: -12, y: 8)
                        Image(systemName: bestRoomSymbol)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(theme.reward)
                            .offset(x: 28, y: -20)
                    }
                    .frame(width: 86, height: 70)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Room glow-up")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("\(dataStore.rewards.count) things unlocked")
                            .font(.headline)
                        Text("Tap to equip and decorate")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                NextUnlockView(database: dataStore.database)
            }
            .compactDashboardTile()
            .cozyCard()
        }
        .cozyPressable()
    }

    private var bestRoomSymbol: String {
        dataStore.rewards.last?.symbolName ?? "sparkles"
    }
}

struct DeskRoomScene: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    @AppStorage("mascotName") private var mascotName = "Mochi"

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    private var visibleRewards: [RewardItem] {
        Array(dataStore.rewards.suffix(7))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(mascotName)’s desk room")
                        .font(.title3.weight(.bold))
                    Text("Focus turns into a place she can customize.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label("\(dataStore.progression.coinsAvailable)", systemImage: "pawprint.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(theme.reward)
            }

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color(hex: "#211C24"), Color(hex: "#362B3B")]
                                : [CozyPalette.softMint.opacity(0.66), CozyPalette.lavenderMist.opacity(0.42)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        ForEach(Array(visibleRewards.prefix(4).enumerated()), id: \.element.id) { offset, reward in
                            RoomRewardIcon(reward: reward, size: offset == 0 ? 42 : 34)
                        }
                        Spacer()
                        Image(systemName: "lightbulb.led.fill")
                            .font(.title.weight(.bold))
                            .foregroundStyle(CozyPalette.wasabi.opacity(visibleRewards.isEmpty ? 0.28 : 0.86))
                    }
                    .padding(18)
                    Spacer()
                }

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(CozyPalette.focusJade.opacity(colorScheme == .dark ? 0.20 : 0.13))
                    .frame(height: 58)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)

                HStack(alignment: .bottom, spacing: 22) {
                    EquippedMascotView(state: dataStore.progression.level > 1 ? .complete : .idle, size: 112, rewards: dataStore.rewards)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(dataStore.progression.petStage.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(roomMood)
                            .font(.headline.weight(.bold))
                            .lineLimit(2)
                    }
                    Spacer()
                    ForEach(Array(visibleRewards.suffix(3).enumerated()), id: \.element.id) { offset, reward in
                        RoomRewardIcon(reward: reward, size: offset == 1 ? 48 : 38)
                    }
                }
                .padding(22)
            }
            .frame(minHeight: 236)
            .accessibilityLabel("Decorated desk room with \(visibleRewards.count) unlocked items")
        }
        .cozyCard()
    }

    private var roomMood: String {
        switch dataStore.progression.level {
        case 1: "A starter nook with room to grow."
        case 2...3: "Mochi has a real study corner now."
        case 4...6: "The desk is starting to feel lived in."
        default: "A cozy room built from showing up."
        }
    }
}

struct RoomRewardIcon: View {
    let reward: RewardItem
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: reward.colorHex).opacity(0.18))
            Image(systemName: reward.symbolName)
                .font(.system(size: size * 0.44, weight: .bold))
                .foregroundStyle(Color(hex: reward.colorHex))
        }
        .frame(width: size, height: size)
        .accessibilityLabel(reward.name)
    }
}

struct MilestoneShelf: View {
    @EnvironmentObject private var dataStore: AppDataStore

    private var milestones: [(String, String, String, Bool)] {
        [
            ("First stamp", "Complete one focus", "star.circle.fill", !dataStore.focusSessions.isEmpty),
            ("Task sparkle", "Finish any task", "checkmark.seal.fill", dataStore.tasks.contains { $0.isCompleted }),
            ("Habit glow", "Check a habit", "sparkles", dataStore.habits.contains { HabitMath.isComplete(keys: $0.completionKeys, on: Date()) }),
            ("Room owner", "Buy one item", "house.fill", purchasedCount > 0)
        ]
    }

    private var purchasedCount: Int {
        dataStore.rewards.filter { reward in
            CozyProgression.shopCatalog.contains { $0.name == reward.name && $0.category == reward.category }
        }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestones")
                .font(.title2.weight(.bold))
            LazyVGrid(columns: CozyLayout.adaptiveColumns(minimum: 190), spacing: CozyLayout.gridSpacing) {
                ForEach(Array(milestones.enumerated()), id: \.offset) { _, milestone in
                    MilestoneBadge(title: milestone.0, subtitle: milestone.1, symbol: milestone.2, isUnlocked: milestone.3)
                }
            }
        }
    }
}

struct MilestoneBadge: View {
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    let title: String
    let subtitle: String
    let symbol: String
    let isUnlocked: Bool

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((isUnlocked ? theme.reward : CozyPalette.lavenderMist).opacity(isUnlocked ? 0.20 : 0.45))
                Image(systemName: isUnlocked ? symbol : "lock.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isUnlocked ? theme.reward : .secondary)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .cozyCard()
    }
}

struct ShopItemCard: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    @AppStorage("selectedTimerSkin") private var selectedTimerSkin = CozyTimerSkin.defaultID
    @AppStorage("selectedTimerShape") private var selectedTimerShape = CozyTimerShape.ring.rawValue
    let item: ShopCatalogItem

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    private var isPurchased: Bool {
        CozyProgression.isPurchased(item, rewards: dataStore.rewards)
    }

    private var purchasedReward: RewardItem? {
        dataStore.rewards.first { $0.name == item.name && $0.category == item.category }
    }

    private var isEquipped: Bool {
        purchasedReward?.isEquipped == true
    }

    private var canPurchase: Bool {
        CozyProgression.canPurchase(item, database: dataStore.database)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: item.colorHex).opacity(0.16))
                    Image(systemName: item.symbolName)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color(hex: item.colorHex))
                }
                .frame(width: 56, height: 56)
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(statusText)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(statusColor.opacity(0.16)))
                        .foregroundStyle(statusColor)
                    Label("\(item.coinCost)", systemImage: "pawprint.fill")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(theme.reward)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                Text(item.category)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CozyRewardColor.category)
                Text(item.description)
                    .font(.callout)
                    .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                    .lineLimit(2)
            }

            HStack {
                Button(actionTitle) {
                    let wasPurchased = isPurchased
                    dataStore.purchase(item)
                    applyCosmeticSelection()
                    CozyFeedback.play(wasPurchased ? .complete : .reward)
                }
                .cozyPrimaryButton(minWidth: 96)
                .disabled((!canPurchase && !isPurchased) || isEquipped)
                .help(actionHelp)
                .accessibilityIdentifier("shop.buy.\(item.id)")
                Spacer()
                Text("Lv. \(item.requiredLevel)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(footerText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minHeight: 16, alignment: .leading)
        }
        .cozyCard()
    }

    private var actionTitle: String {
        if isEquipped { return item.category == "Room decor" ? "Placed" : "Equipped" }
        if isPurchased { return item.category == "Room decor" ? "Place" : "Equip" }
        if dataStore.progression.level < item.requiredLevel { return "Locked" }
        if dataStore.progression.coinsAvailable < item.coinCost { return "Save" }
        return "Buy"
    }

    private var statusText: String {
        if isEquipped { return item.category == "Room decor" ? "PLACED" : "ON MOCHI" }
        if isPurchased { return "OWNED" }
        if dataStore.progression.level < item.requiredLevel { return "SOON" }
        if dataStore.progression.coinsAvailable < item.coinCost { return "SAVE" }
        return "READY"
    }

    private var statusColor: Color {
        if isPurchased { return CozyPalette.focusJade }
        if canPurchase { return theme.reward }
        return .secondary
    }

    private var footerText: String {
        if isEquipped { return item.category == "Room decor" ? "Placed in the room." : "Mochi is wearing this." }
        if isPurchased { return item.category == "Room decor" ? "Ready to place." : "Ready to equip." }
        if dataStore.progression.level < item.requiredLevel { return "Unlocks at level \(item.requiredLevel)." }
        if dataStore.progression.coinsAvailable < item.coinCost {
            return "\(item.coinCost - dataStore.progression.coinsAvailable) paws to go."
        }
        return "Ready to buy."
    }

    private var actionHelp: String {
        if isEquipped { return "Already active" }
        if isPurchased { return "Equip this cosmetic" }
        if dataStore.progression.level < item.requiredLevel { return "Reach level \(item.requiredLevel) to unlock" }
        if dataStore.progression.coinsAvailable < item.coinCost { return "\(item.coinCost - dataStore.progression.coinsAvailable) more paws needed" }
        return "Buy and equip this cosmetic"
    }

    private func applyCosmeticSelection() {
        if item.category.localizedCaseInsensitiveContains("timer skin"),
           let id = CozyTimerSkin.id(matching: item.name) {
            selectedTimerSkin = id
        }
        if item.category.localizedCaseInsensitiveContains("timer frame") {
            if item.name.localizedCaseInsensitiveContains("pill") {
                selectedTimerShape = CozyTimerShape.capsule.rawValue
            } else if item.name.localizedCaseInsensitiveContains("hourglass") {
                selectedTimerShape = CozyTimerShape.hourglass.rawValue
            }
        }
    }
}

struct RewardCard: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @AppStorage("selectedTimerSkin") private var selectedTimerSkin = CozyTimerSkin.defaultID
    @AppStorage("selectedTimerShape") private var selectedTimerShape = CozyTimerShape.ring.rawValue
    let reward: RewardItem

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(hex: reward.colorHex).opacity(0.16))
                    .frame(height: 86)
                Image(systemName: reward.symbolName)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Color(hex: reward.colorHex))
            }
            Text(reward.name)
                .font(.headline)
                .lineLimit(2)
            Text(reward.category)
                .font(.caption)
                .foregroundStyle(.secondary)
            if canEquip {
                Button(equipTitle) {
                    dataStore.equipReward(id: reward.id)
                    applyCosmeticSelection()
                    CozyFeedback.play(.complete)
                }
                .cozySecondaryButton(minWidth: 92)
                .disabled(reward.isEquipped)
                .help(reward.isEquipped ? "Already active" : "Equip this cosmetic")
                .accessibilityIdentifier("inventory.equip.\(reward.id.uuidString)")
            } else {
                Text("Collected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 196, alignment: .top)
        .cozyCard()
    }

    private var canEquip: Bool {
        reward.category.localizedCaseInsensitiveContains("outfit")
            || reward.category.localizedCaseInsensitiveContains("accessory")
            || reward.category.localizedCaseInsensitiveContains("skin")
            || reward.category.localizedCaseInsensitiveContains("timer frame")
            || reward.category.localizedCaseInsensitiveContains("room decor")
    }

    private var equipTitle: String {
        if reward.isEquipped {
            return reward.category.localizedCaseInsensitiveContains("room decor") ? "Placed" : "Equipped"
        }
        return reward.category.localizedCaseInsensitiveContains("room decor") ? "Place" : "Equip"
    }

    private func applyCosmeticSelection() {
        if reward.category.localizedCaseInsensitiveContains("timer skin"),
           let id = CozyTimerSkin.id(matching: reward.name) {
            selectedTimerSkin = id
        }
        if reward.category.localizedCaseInsensitiveContains("timer frame") {
            if reward.name.localizedCaseInsensitiveContains("pill") {
                selectedTimerShape = CozyTimerShape.capsule.rawValue
            } else if reward.name.localizedCaseInsensitiveContains("hourglass") {
                selectedTimerShape = CozyTimerShape.hourglass.rawValue
            }
        }
    }
}

struct SettingsScreen: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var notifications: NotificationService
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    @AppStorage("selectedMascotStyle") private var selectedMascotStyle = CozyMascotStyle.defaultID
    @AppStorage("selectedTimerSkin") private var selectedTimerSkin = CozyTimerSkin.defaultID
    @AppStorage("selectedTimerShape") private var selectedTimerShape = CozyTimerShape.ring.rawValue
    @AppStorage("showMotivationQuotes") private var showMotivationQuotes = true
    @AppStorage("quoteStyle") private var quoteStyle = CozyQuoteStyle.cozy.rawValue
    @AppStorage("mascotName") private var mascotName = "Mochi"
    @AppStorage("soundsEnabled") private var soundsEnabled = false
    @AppStorage("reducedDecoration") private var reducedDecoration = false
    @AppStorage("hideStreaks") private var hideStreaks = false
    @State private var dataActionFeedback: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CozyLayout.sectionSpacing) {
                SectionHeader(
                    title: "Settings",
                    subtitle: "Tune the companion, focus feel, and private install behavior.",
                    mascotState: .idle
                )

                SettingsGroup(title: "Mascot & theme", subtitle: "Keep the app personal without making the workspace noisy.") {
                    CozyLabeledControl(title: "Mascot name", symbolName: "pawprint.fill", minWidth: 220) {
                        TextField("Mascot name", text: $mascotName)
                            .accessibilityIdentifier("settings.mascotName")
                            .cozyTextInput(minWidth: 220, alignment: .leading)
                    }

                    LazyVGrid(columns: CozyLayout.adaptiveColumns(minimum: 170), spacing: 10) {
                        ForEach(CozyMascotStyle.all) { style in
                            Button {
                                selectedMascotStyle = style.id
                            } label: {
                                MascotStyleCard(style: style, isSelected: selectedMascotStyle == style.id)
                            }
                            .cozyPressable()
                            .accessibilityIdentifier("settings.mascot.\(style.id)")
                        }
                    }

                    CozySegmentedControl(
                        options: [
                            CozySegmentOption("system", title: "System", symbolName: "circle.lefthalf.filled"),
                            CozySegmentOption("light", title: "Light", symbolName: "sun.max.fill"),
                            CozySegmentOption("dark", title: "Dark", symbolName: "moon.fill")
                        ],
                        selection: $appearanceMode,
                        minSegmentWidth: 88
                    )
                    .accessibilityIdentifier("settings.appearance")

                    LazyVGrid(columns: CozyLayout.settingsGrid, spacing: CozyLayout.formRowSpacing) {
                        ForEach(CozyTheme.all) { theme in
                            Button {
                                selectedTheme = theme.id
                            } label: {
                                ThemeSwatch(theme: theme, isSelected: selectedTheme == theme.id)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .cozyPressable()
                        }
                    }
                    .accessibilityIdentifier("settings.theme")
                }

                SettingsGroup(title: "Timer look", subtitle: "Choose the display shape, timer skin, and quote tone. Shop skins can override the selected color when equipped.") {
                    LazyVGrid(columns: CozyLayout.settingsGrid, spacing: CozyLayout.formRowSpacing) {
                        ForEach(availableTimerSkins) { skin in
                            Button {
                                selectedTimerSkin = skin.id
                            } label: {
                                TimerSkinCard(skin: skin, isSelected: selectedTimerSkin == skin.id)
                            }
                            .cozyPressable()
                            .accessibilityIdentifier("settings.timerSkin.\(skin.id)")
                        }
                    }
                    if lockedTimerSkinCount > 0 {
                        CozyFieldHint(text: "\(lockedTimerSkinCount) more timer skins unlock through focus rewards and the shop.")
                    }

                    CozySegmentedControl(
                        options: availableTimerShapes.map { shape in
                            CozySegmentOption(shape.rawValue, title: shape.title, symbolName: shape.symbolName)
                        },
                        selection: $selectedTimerShape,
                        minSegmentWidth: 106
                    )
                    .accessibilityIdentifier("settings.timerShape")
                    if !lockedTimerShapeTitles.isEmpty {
                        CozyFieldHint(text: "Locked timer frames: \(lockedTimerShapeTitles.joined(separator: ", ")). Unlock them in Rewards Room.")
                    }

                    CozyToggleRow(
                        title: "Show focus quotes",
                        symbolName: "quote.bubble.fill",
                        subtitle: "Gentle prompts inside timer cards.",
                        isOn: $showMotivationQuotes
                    )
                        .accessibilityIdentifier("settings.showQuotes")

                    CozySegmentedControl(
                        options: CozyQuoteStyle.allCases.map { style in
                            CozySegmentOption(style.rawValue, title: style.title)
                        },
                        selection: $quoteStyle,
                        minSegmentWidth: 92
                    )
                    .disabled(!showMotivationQuotes)
                    .accessibilityIdentifier("settings.quoteStyle")

                    MotivationQuotePill(
                        quote: (CozyQuoteStyle(rawValue: quoteStyle) ?? .cozy).quote(for: .deepFocus, minute: 12),
                        color: CozyTimerSkin.named(selectedTimerSkin).color
                    )
                    .opacity(showMotivationQuotes ? 1 : 0.45)
                }

                SettingsGroup(title: "Focus companion", subtitle: "Controls that affect daily use and the menu bar buddy.") {
                    CozyToggleRow(
                        title: "Show menu bar companion",
                        symbolName: "menubar.rectangle",
                        subtitle: "Keep timer controls available above every app.",
                        isOn: $showMenuBarExtra
                    )
                        .accessibilityIdentifier("settings.showMenuBar")
                    HStack(alignment: .center, spacing: 12) {
                        Label(notificationStatusText, systemImage: notificationStatusSymbol)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(notificationActionTitle) {
                            if notifications.authorizationStatus == .denied {
                                notifications.openNotificationSettings()
                            } else {
                                Task { await notifications.requestAuthorizationIfNeeded() }
                            }
                        }
                        .cozySecondaryButton(minWidth: 148)
                        .accessibilityIdentifier("settings.notifications")
                    }
                    if let lastSchedulingError = notifications.lastSchedulingError {
                        CozyFieldHint(text: lastSchedulingError, isError: notifications.authorizationStatus == .denied)
                    }
                    CozyToggleRow(
                        title: "Soft sounds",
                        symbolName: "speaker.wave.2.fill",
                        subtitle: "Play small local feedback sounds.",
                        isOn: $soundsEnabled
                    )
                        .accessibilityIdentifier("settings.sounds")
                    CozyToggleRow(
                        title: "Reduce decoration",
                        symbolName: "sparkles",
                        subtitle: "Keep the app calmer and less animated.",
                        isOn: $reducedDecoration
                    )
                        .accessibilityIdentifier("settings.reducedDecoration")
                    CozyToggleRow(
                        title: "Use momentum instead of streaks",
                        symbolName: "leaf.fill",
                        subtitle: "Avoid pressure-heavy streak language.",
                        isOn: $hideStreaks
                    )
                        .accessibilityIdentifier("settings.hideStreaks")
                }

                SettingsGroup(title: "Private release", subtitle: "Local-only data and manual install details for this first build.") {
                    Label("Data stays on this Mac. There are no accounts, network sync, or tracking.", systemImage: "lock.shield.fill")
                        .foregroundStyle(.secondary)
                    Label("Unsigned install can require right-click Open or Privacy & Security approval.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(CozyPalette.overdue)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            dataActionButtons
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            dataActionButtons
                        }
                    }
                    if let dataActionFeedback {
                        CozyFieldHint(text: dataActionFeedback)
                            .accessibilityIdentifier("settings.data.feedback")
                    }
                }
            }
            .cozyPageFrame()
        }
        .accessibilityIdentifier("screen.settings")
        .onAppear(perform: repairCosmeticSelectionsIfNeeded)
        .task {
            await notifications.refreshAuthorizationStatus()
        }
        .onChange(of: dataStore.rewards) {
            repairCosmeticSelectionsIfNeeded()
        }
    }

    private var availableTimerSkinIDs: Set<String> {
        let owned = dataStore.rewards.compactMap { reward -> String? in
            guard reward.category.localizedCaseInsensitiveContains("timer skin") else { return nil }
            return CozyTimerSkin.id(matching: reward.name)
        }
        return Set(owned).union([CozyTimerSkin.defaultID])
    }

    private var availableTimerSkins: [CozyTimerSkin] {
        let ids = availableTimerSkinIDs
        return CozyTimerSkin.all.filter { ids.contains($0.id) }
    }

    private var availableTimerShapeIDs: Set<String> {
        let owned = dataStore.rewards.compactMap(timerShapeID(for:))
        return Set(owned).union([CozyTimerShape.ring.rawValue])
    }

    private var availableTimerShapes: [CozyTimerShape] {
        let ids = availableTimerShapeIDs
        return CozyTimerShape.allCases.filter { ids.contains($0.rawValue) }
    }

    private var lockedTimerShapeTitles: [String] {
        let ids = availableTimerShapeIDs
        return CozyTimerShape.allCases.filter { !ids.contains($0.rawValue) }.map(\.title)
    }

    private var lockedTimerSkinCount: Int {
        max(0, CozyTimerSkin.all.count - availableTimerSkins.count)
    }

    private var dataActionButtons: some View {
        Group {
            Button {
                exportBackup(reveal: false)
            } label: {
                Label("Export snapshot", systemImage: "square.and.arrow.up")
            }
            .cozySecondaryButton(minWidth: 148)
            .accessibilityIdentifier("settings.exportBackup")

            Button {
                exportBackup(reveal: true)
            } label: {
                Label("Reveal export", systemImage: "folder")
            }
            .cozyGhostButton(minWidth: 130)
            .accessibilityIdentifier("settings.revealData")
        }
    }

    private func repairCosmeticSelectionsIfNeeded() {
        repairTimerSkinSelectionIfNeeded()
        repairTimerShapeSelectionIfNeeded()
    }

    private func repairTimerSkinSelectionIfNeeded() {
        guard !availableTimerSkinIDs.contains(selectedTimerSkin) else { return }
        selectedTimerSkin = availableTimerSkins.first?.id ?? CozyTimerSkin.defaultID
    }

    private func repairTimerShapeSelectionIfNeeded() {
        guard availableTimerShapeIDs.contains(selectedTimerShape) else {
            selectedTimerShape = CozyTimerShape.ring.rawValue
            return
        }
    }

    private func timerShapeID(for reward: RewardItem) -> String? {
        guard reward.category.localizedCaseInsensitiveContains("timer frame") else { return nil }
        if reward.name.localizedCaseInsensitiveContains("pill") {
            return CozyTimerShape.capsule.rawValue
        }
        if reward.name.localizedCaseInsensitiveContains("hourglass") {
            return CozyTimerShape.hourglass.rawValue
        }
        return nil
    }

    private func exportBackup(reveal: Bool) {
        guard let url = dataStore.exportData() else {
            dataActionFeedback = "Export failed. Try again after restarting CozyTime."
            return
        }
        dataActionFeedback = reveal ? "Opened the latest export." : "Snapshot exported: \(url.lastPathComponent)"
        if reveal {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private var notificationStatusText: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional:
            return "Timer alerts are on"
        case .denied:
            return "Timer alerts are off in macOS"
        case .notDetermined:
            return "Timer alerts need permission"
        @unknown default:
            return "Timer alert status is unknown"
        }
    }

    private var notificationStatusSymbol: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional:
            return "bell.badge.fill"
        case .denied:
            return "bell.slash.fill"
        case .notDetermined:
            return "bell.fill"
        @unknown default:
            return "bell"
        }
    }

    private var notificationActionTitle: String {
        notifications.authorizationStatus == .denied ? "Open Settings" : "Enable Alerts"
    }
}

struct MascotStyleCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let style: CozyMascotStyle
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill((isSelected ? CozyPalette.stickerPink : CozyPalette.quietContainer(colorScheme)).opacity(isSelected ? 0.40 : 1))
                Image(systemName: style.symbolName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isSelected ? CozyPalette.berry : CozyPalette.secondaryText(colorScheme))
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(style.title)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(CozyPalette.primaryText(colorScheme))
                Text(style.subtitle)
                    .font(.caption)
                    .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                    .lineLimit(1)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(CozyPalette.focusJade)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? CozyPalette.selectionFill.opacity(colorScheme == .dark ? 0.16 : 0.62) : Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? CozyPalette.berry.opacity(0.42) : CozyPalette.cardBorder(colorScheme), lineWidth: 1)
        )
        .accessibilityLabel(style.title)
    }
}

struct TimerSkinCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let skin: CozyTimerSkin
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .stroke(skin.color.opacity(0.30), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: 0.68)
                        .stroke(skin.color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: skin.symbolName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(skin.color)
                }
                .frame(width: 42, height: 42)

                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(CozyPalette.focusJade)
                }
            }

            Text(skin.title)
                .font(.callout.weight(.bold))
                .foregroundStyle(CozyPalette.primaryText(colorScheme))
                .lineLimit(1)
            HStack(spacing: 5) {
                Circle().fill(skin.color)
                    .frame(width: 10, height: 10)
                Circle().fill(skin.secondary)
                    .frame(width: 10, height: 10)
                Circle().fill(CozyPalette.cardFill(colorScheme))
                    .frame(width: 10, height: 10)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .topLeading)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? skin.secondary.opacity(0.30) : Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? skin.color.opacity(0.48) : CozyPalette.cardBorder(colorScheme), lineWidth: 1)
        )
        .accessibilityLabel(skin.title)
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    let subtitle: String
    private let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(CozyType.cardTitle)
                Text(subtitle)
                    .font(CozyType.body)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
        .cozyCard()
    }
}

private enum CozyHabitColor {
    static let primary = CozyPalette.habitLavender
}

private enum CozyStatsColor {
    static let focus = CozyPalette.focusJade
}

private enum CozyRewardColor {
    static let category = CozyPalette.skyBlue
}
