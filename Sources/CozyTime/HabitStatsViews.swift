import AppKit
import Charts
import CozyCore
import SwiftUI
@preconcurrency import UserNotifications

struct HabitsView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    @State private var newHabitTitle = ""
    @State private var targetPerWeek = 4
    // UX HIGH #85 — ⌘N (when Habits selected) moves focus to this field.
    private enum HabitField: Hashable { case title }
    @FocusState private var focusedField: HabitField?

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CozyLayout.sectionSpacing) {
                // Empty state should not suggest "victory" — only show
                // .complete mascot when there's actual habit activity today.
                SectionHeader(
                    title: "Habits",
                    subtitle: "Gentle consistency with grace days.",
                    mascotState: dataStore.habits.isEmpty ? .idle : .complete
                )

                habitComposer

                if dataStore.habits.isEmpty {
                    EmptyStateView(
                        title: "Pick a first habit",
                        message: "Something gentle enough to repeat. Mochi celebrates the showing-up, not the streak count.",
                        mascotState: .complete,
                        eyebrow: "Habits",
                        primaryActionTitle: "Add a tiny habit",
                        primaryAction: {
                            newHabitTitle = "One focused block"
                            addHabit()
                        }
                    )
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
        // UX HIGH #85 — ⌘N (when Habits selected) moves focus into the
        // inline habit-title field instead of opening a separate composer.
        .onReceive(NotificationCenter.default.publisher(for: .cozyNewHabit)) { _ in
            focusedField = .title
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

    private var habitComposer: some View {
        VStack(alignment: .leading, spacing: CozyLayout.formRowSpacing) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: CozyLayout.formRowSpacing) {
                    habitTitleField
                        .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
                    weeklyGoalControl
                        .frame(width: 176, alignment: .leading)
                    habitAddButton
                        .frame(width: 156, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: CozyLayout.formRowSpacing) {
                    habitTitleField
                    HStack(alignment: .top, spacing: CozyLayout.formRowSpacing) {
                        weeklyGoalControl
                            .frame(minWidth: 176, alignment: .leading)
                        habitAddButton
                            .frame(minWidth: 156, alignment: .leading)
                    }
                }

                VStack(alignment: .leading, spacing: CozyLayout.formRowSpacing) {
                    habitTitleField
                    weeklyGoalControl
                    habitAddButton
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(CozyLayout.cardPadding)
        .cozyCard()
    }

    private var habitTitleField: some View {
        CozyLabeledControl(
            title: "Habit",
            symbolName: "leaf",
            minWidth: 220,
            hint: cleanHabitTitle.isEmpty ? "Give it a name first — anything gentle counts" : nil
        ) {
            TextField("New habit...", text: $newHabitTitle)
                .onSubmit(addHabit)
                .focused($focusedField, equals: .title)
                .font(CozyType.body)
                .cozyTextInput(minWidth: 220, alignment: .leading)
                .accessibilityIdentifier("habit.title")
        }
        .layoutPriority(1)
    }

    private var weeklyGoalControl: some View {
        CozyLabeledControl(title: "Goal", symbolName: "calendar.badge.checkmark", minWidth: 176) {
            HStack(spacing: 8) {
                Button {
                    targetPerWeek = max(1, targetPerWeek - 1)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 20, height: 20)
                }
                .cozyIconButton(size: CozyLayout.compactHitSize)
                .disabled(targetPerWeek <= 1)
                .accessibilityLabel("Decrease weekly goal")

                Text("\(targetPerWeek)/week")
                    .font(CozyType.captionStrong)
                    .monospacedDigit()
                    .frame(minWidth: 62)

                Button {
                    targetPerWeek = min(7, targetPerWeek + 1)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 20, height: 20)
                }
                .cozyIconButton(size: CozyLayout.compactHitSize)
                .disabled(targetPerWeek >= 7)
                .accessibilityLabel("Increase weekly goal")
            }
            .cozyControlShell(minWidth: 176)
        }
    }

    private var habitAddButton: some View {
        CozyLabeledControl(title: "Action", symbolName: "plus.circle", minWidth: 156) {
            Button {
                addHabit()
            } label: {
                Label("Add", systemImage: "plus")
            }
            .cozyPrimaryButton(minWidth: 128, fullWidth: true)
            .disabled(cleanHabitTitle.isEmpty)
            .help(cleanHabitTitle.isEmpty ? "Type a habit name first." : "Add this habit.")
            .accessibilityHint(cleanHabitTitle.isEmpty ? "Type a habit name first." : "Add this habit.")
            .accessibilityIdentifier("habit.add")
        }
    }
}

struct HabitCard: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hideStreaks") private var hideStreaks = false
    @AppStorage("hasCheckedFirstHabit") private var hasCheckedFirstHabit = false
    let habit: Habit
    @State private var isConfirmingDelete = false
    @State private var habitFeedback: String?
    @State private var editingHabit: Habit?
    @State private var showFirstHabitToast = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Visual audit CRITICAL #3: with default .center, the leading
            // icon visually dropped below the title baseline whenever the
            // title wrapped to 2 lines. .firstTextBaseline anchors the icon
            // to the title's cap-height.
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: habit.stickerName)
                    .font(CozyType.cardTitle)
                    .foregroundStyle(CozyHabitColor.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.title)
                        .font(CozyType.rowTitle)
                        .lineLimit(2)
                        .layoutPriority(1)
                    Text("\(HabitMath.completionsInCurrentWeek(keys: habit.completionKeys, now: Date())) / \(habit.targetPerWeek) this week")
                        .font(CozyType.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    toggleHabit(on: Date())
                } label: {
                    Image(systemName: HabitMath.isComplete(keys: habit.completionKeys, on: Date()) ? "checkmark.circle.fill" : "circle")
                        .font(CozyType.cardTitle)
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
                    withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
                        isConfirmingDelete.toggle()
                    }
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 20, height: 20)
                }
                .cozyIconButton(size: CozyLayout.hitSize)
                .help("Delete habit")
                .accessibilityLabel("Delete \(habit.title)")
            }

            HStack(spacing: 6) {
                ForEach(lastSevenDays, id: \.self) { day in
                    let isToday = Calendar.autoupdatingCurrent.isDateInToday(day)
                    let isDone = HabitMath.isComplete(keys: habit.completionKeys, on: day)
                    Button {
                        toggleHabit(on: day)
                    } label: {
                        VStack(spacing: 4) {
                            // `.abbreviated` (Sun/Mon/Tue) instead of `.narrow`
                            // which collapses Sat/Sun both to "S" — WCAG +
                            // legibility win for low-vision users.
                            Text(day, format: .dateTime.weekday(.abbreviated))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(isToday ? CozyHabitColor.primary : .secondary)
                            // Visible circle bumped 20→28pt so the clickable
                            // affordance matches WCAG 2.5.8 (24pt minimum
                            // visible target). 44pt hit area preserved below.
                            ZStack {
                                Circle()
                                    .fill(isDone ? CozyHabitColor.primary : CozyPalette.lavenderMist)
                                    .overlay(
                                        Circle()
                                            .stroke(isToday ? CozyHabitColor.primary : CozyHabitColor.primary.opacity(0.28),
                                                    lineWidth: isToday ? 2 : 1)
                                    )
                                if isDone {
                                    Image(systemName: "checkmark")
                                        .font(CozyType.badge)
                                        .foregroundStyle(CozyPalette.surface)
                                        .symbolEffect(.bounce.down.byLayer, options: .nonRepeating, value: reduceMotion ? false : isDone)
                                }
                            }
                            .frame(width: 28, height: 28)
                        }
                        .frame(width: CozyLayout.hitSize, height: CozyLayout.hitSize)
                    }
                    .buttonStyle(.plain)
                    .cozyPressable(pressedScale: 0.82, hoverScale: 1.18)
                    .contentShape(Circle())
                    .help("Toggle \(habit.title) for \(CozyFormatters.shortDate.string(from: day))")
                    .accessibilityLabel("\(habit.title), \(CozyFormatters.shortDate.string(from: day))\(isToday ? ", today" : "")")
                    .accessibilityValue(isDone ? "Complete" : "Not complete")
                }
            }

            if let habitFeedback {
                Label(habitFeedback, systemImage: "sparkles")
                    .font(CozyType.captionStrong)
                    .foregroundStyle(CozyPalette.focusJade)
                    .transition(.opacity)
            }

            HabitHeatmap(habit: habit) { day in
                toggleHabit(on: day)
            }

            if hideStreaks {
                let n = HabitMath.completionsInCurrentWeek(keys: habit.completionKeys, now: Date())
                Text("Momentum: \(n) gentle \(n == 1 ? "check" : "checks") this week")
                    .font(CozyType.body.weight(.semibold))
            } else {
                let streak = HabitMath.currentStreak(keys: habit.completionKeys, through: Date(), graceDays: habit.graceDays)
                if streak == 0 {
                    // Avoid the streak-shaming "0 days" reading on fresh habits. Empty rhythm
                    // gets a soft invitation instead. (UX audit F15.)
                    Text("Fresh rhythm — tap any day to start.")
                        .font(CozyType.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Current rhythm: \(streak) \(streak == 1 ? "day" : "days")")
                        .font(CozyType.body.weight(.semibold))
                }
            }

            if isConfirmingDelete {
                HStack(spacing: 10) {
                    Label("Delete this habit?", systemImage: "exclamationmark.triangle.fill")
                        .font(CozyType.captionStrong)
                        .foregroundStyle(CozyPalette.overdue)
                    Spacer()
                    Button("Keep") {
                        withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
                            isConfirmingDelete = false
                        }
                    }
                    .cozyGhostButton(minWidth: 76)
                    Button(role: .destructive) {
                        dataStore.deleteHabit(id: habit.id)
                        CozyFeedback.play(.delete)
                    } label: {
                        Text("Delete")
                    }
                    .cozyDestructiveButton(minWidth: 76)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous)
                        .fill(CozyPalette.overdue.opacity(0.08))
                )
                .transition(.opacity)
            }
        }
        .cozyCard()
        .overlay(alignment: .topTrailing) {
            FirstMomentToast(
                isPresented: $showFirstHabitToast,
                message: "First habit check saved."
            )
            .padding(12)
            .allowsHitTesting(false)
        }
        .contextMenu {
            Button {
                toggleHabit(on: Date())
            } label: {
                Label("Mark today done", systemImage: "checkmark.circle")
            }
            Button {
                editingHabit = habit
            } label: {
                Label("Edit name…", systemImage: "pencil")
            }
            Button(role: .destructive) {
                dataStore.deleteHabit(id: habit.id)
                CozyFeedback.play(.delete)
            } label: {
                Label("Delete habit", systemImage: "trash")
            }
        }
        .sheet(item: $editingHabit) { habitToEdit in
            HabitRenameSheet(habit: habitToEdit) { newTitle in
                renameHabit(habitToEdit, to: newTitle)
            }
        }
    }

    private func renameHabit(_ original: Habit, to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != original.title else { return }
        dataStore.updateHabit(
            Habit(
                id: original.id,
                title: trimmed,
                createdAt: original.createdAt,
                targetPerWeek: original.targetPerWeek,
                completionKeys: original.completionKeys,
                stickerName: original.stickerName,
                graceDays: original.graceDays
            )
        )
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
        if !wasComplete && !hasCheckedFirstHabit {
            hasCheckedFirstHabit = true
            presentFirstHabitToast()
        }
        withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
            habitFeedback = wasComplete ? "Unchecked — no worries" : "+8 XP rhythm"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(CozyMotion.gentle(reduceMotion, duration: 0.25)) { habitFeedback = nil }
        }
    }

    private func presentFirstHabitToast() {
        showFirstHabitToast = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1800))
            showFirstHabitToast = false
        }
    }
}

/// 12-week × 7-day heatmap of habit completions. Cells are tap-to-toggle.
/// Never red for misses — cozy/no-shame palette (DESIGN_SYSTEM rule).
private struct HabitHeatmap: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    let habit: Habit
    let toggle: (Date) -> Void

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last 12 weeks")
                .font(CozyType.captionStrong)
                .foregroundStyle(CozyPalette.secondaryText(colorScheme))
            HStack(alignment: .top, spacing: 4) {
                ForEach(weeks, id: \.self) { week in
                    VStack(spacing: 4) {
                        ForEach(week, id: \.self) { day in
                            HabitHeatmapCell(
                                day: day,
                                isDone: HabitMath.isComplete(keys: habit.completionKeys, on: day),
                                hitColor: theme.accent.opacity(0.65),
                                missColor: CozyPalette.quietContainer(colorScheme),
                                habitTitle: habit.title
                            ) {
                                toggle(day)
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("habit.heatmap")
    }

    /// 12 columns of 7 days each, oldest-first, ending today.
    private var weeks: [[Date]] {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: Date())
        let totalDays = 12 * 7
        let start = calendar.date(byAdding: .day, value: -(totalDays - 1), to: today) ?? today
        let days: [Date] = (0..<totalDays).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
        return stride(from: 0, to: days.count, by: 7).map {
            Array(days[$0..<min($0 + 7, days.count)])
        }
    }
}

private struct HabitHeatmapCell: View {
    let day: Date
    let isDone: Bool
    let hitColor: Color
    let missColor: Color
    let habitTitle: String
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            Rectangle()
                .fill(isDone ? hitColor : missColor)
                .frame(width: 12, height: 12)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help("\(habitTitle), \(CozyFormatters.shortDate.string(from: day))")
        .accessibilityLabel("\(habitTitle), \(CozyFormatters.shortDate.string(from: day))")
        .accessibilityValue(isDone ? "Complete" : "Not complete")
    }
}

private struct HabitRenameSheet: View {
    @Environment(\.dismiss) private var dismiss
    let habit: Habit
    let commit: (String) -> Void
    @State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename habit")
                .font(CozyType.heroCardTitle)
            CozyLabeledControl(title: "Name", symbolName: "leaf", minWidth: 240) {
                TextField("Habit name", text: $draft)
                    .onSubmit(save)
                    .cozyTextInput(minWidth: 240, alignment: .leading)
                    .accessibilityIdentifier("habit.rename.field")
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .cozyGhostButton(minWidth: 92)
                Button("Save") { save() }
                    .cozyPrimaryButton(minWidth: 92)
                    .disabled(trimmed.isEmpty)
                    .accessibilityIdentifier("habit.rename.save")
            }
        }
        .padding(20)
        .frame(minWidth: CozyLayout.sheetIdealWidthSmall)
        .onAppear { draft = habit.title }
    }

    private var trimmed: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        commit(trimmed)
        dismiss()
    }
}

struct TodayHabitCard: View {
    @EnvironmentObject private var dataStore: AppDataStore

    var body: some View {
        Button {
            NotificationCenter.default.post(name: .cozyOpenSection, object: AppSection.habits.rawValue)
        } label: {
            HStack(spacing: 16) {
                MascotView(state: .complete, size: .card)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Habit check")
                        .font(CozyType.captionStrong)
                        .foregroundStyle(.secondary)
                    Text(titleText)
                        .font(CozyType.rowTitle)
                    Text(subtitleText)
                        .font(CozyType.body)
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
        dataStore.habits.isEmpty ? "Start a gentle habit" : "\(completedToday) / \(dataStore.habits.count) done today"
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

    private var levelRingCopy: String {
        let summary = dataStore.progression
        if summary.xp == 0 {
            return "Just starting out — first XP unlocks at any focus block."
        }
        return "\(summary.xp) XP earned. \(summary.nextLevelXP - summary.xp) XP until the next room glow-up."
    }

    var body: some View {
        let summary = dataStore.progression
        VStack(alignment: .leading, spacing: 16) {
            // Visual audit IMPORTANT #2: ring (96pt) + right VStack (~140pt
            // with title pill + mascot + body) vertically centered = ring
            // dropped below title baseline. .top aligns ring's level number
            // with the title row.
            HStack(alignment: .top, spacing: 16) {
                // Mascot + ring stacked side-by-side. The ring's always-visible
                // track is the "you're on the journey" cue (Apple Fitness pattern).
                ZStack {
                    CozyProgressionRing(
                        progress: summary.progressToNextLevel,
                        label: .level(summary.level),
                        symbolName: "pawprint.fill",
                        size: 96,
                        accent: CozyPalette.focusJade
                    )
                    .accessibilityLabel("Level \(summary.level), \(Int(summary.progressToNextLevel * 100)) percent to next level")
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(mascotName) Lv. \(summary.level)")
                                .font(CozyType.heroCardTitle)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            // Pet stage as a styled pill (was loose text wedged
                            // beneath the title — screenshot feedback flagged it
                            // as "cramped"). Capsule + tinted fill matches the
                            // rest of the badge family.
                            Text(summary.petStage.rawValue)
                                .font(CozyType.captionStrong)
                                .foregroundStyle(CozyPalette.focusJade)
                                .padding(.horizontal, CozyLayout.badgePaddingMediumH)
                                .padding(.vertical, CozyLayout.badgePaddingSmallV)
                                .background(
                                    Capsule().fill(CozyPalette.focusJade.opacity(colorScheme == .dark ? 0.18 : 0.12))
                                )
                        }
                        Spacer()
                        Label("\(summary.coinsAvailable)", systemImage: "pawprint.fill")
                            .font(CozyType.cardTitle)
                            .foregroundStyle(theme.rewardText(colorScheme))
                            .accessibilityLabel("\(summary.coinsAvailable) paws")
                    }
                    EquippedMascotView(state: summary.progressToNextLevel > 0.72 ? .complete : .idle, size: .avatar, rewards: dataStore.rewards)
                        .accessibilityHidden(true)
                    Text(levelRingCopy)
                        .font(CozyType.body)
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
                SectionHeader(
                    title: "Stats",
                    subtitle: "Your soft receipts — no judgment, just patterns.",
                    mascotState: totalFocusMinutes == 0 ? .idle : .complete
                )
                LazyVGrid(columns: CozyLayout.metricColumns, spacing: CozyLayout.gridSpacing) {
                    StatCard(title: "Focus time", value: "\(totalFocusMinutes)m", symbol: "timer", color: CozyPalette.focusJade)
                    StatCard(title: "Tasks complete", value: "\(completedTasks)", symbol: "checkmark.circle.fill", color: CozyPalette.berry)
                    StatCard(title: "Habits today", value: "\(completedHabitsToday)/\(dataStore.habits.count)", symbol: "sparkles", color: CozyHabitColor.primary)
                    StatCard(title: "Mochi's level", value: "\(dataStore.progression.level)", symbol: "pawprint.fill", color: theme.reward)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Focus trend")
                        .font(CozyType.cardTitle)
                    ZStack {
                        Chart(focusChartData) { item in
                            BarMark(
                                x: .value("Day", item.day),
                                y: .value("Minutes", item.minutes)
                            )
                            .foregroundStyle(CozyStatsColor.focus)
                            .cornerRadius(4)
                        }
                        .chartYAxisLabel("Minutes")
                        .chartXAxis {
                            AxisMarks { AxisValueLabel().font(CozyType.caption) }
                        }

                        if totalFocusMinutes == 0 {
                            VStack(spacing: 10) {
                                MascotView(state: .settling, size: .card)
                                    .accessibilityHidden(true)
                                Text("Save one focus to start tracking")
                                    .font(CozyType.rowTitle)
                                // CTA goes to Focus, not Rewards — generating
                                // stats data requires saving a focus session
                                // (not visiting the shop). Prior copy routed
                                // away from where the work happens.
                                Button {
                                    NotificationCenter.default.post(name: .cozyOpenSection, object: AppSection.focus.rawValue)
                                } label: {
                                    Label("Start a tiny focus", systemImage: "timer")
                                }
                                .cozyPrimaryButton(minWidth: 132)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.ultraThinMaterial)
                        }
                    }
                    .frame(height: 220)
                }
                .cozyCard()

                WeeklyDigestCard()
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
    // Use `day` as the identity instead of a fresh UUID per access. The parent
    // `focusChartData` is a computed property; with `id = UUID()` SwiftUI Chart's
    // diffing treated every recompute as a new bar set and re-animated everything.
    var id: String { day }
    let day: String
    let minutes: Int
}

/// 7-day rollup of focus sessions, paws earned, and habit checks. Cozy
/// summary — no comparisons, no streak shaming.
struct WeeklyDigestCard: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName

    private var theme: CozyTheme { CozyTheme.named(selectedTheme) }

    var body: some View {
        let summary = digest
        let delta = sessionsDeltaPercent
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.16))
                Image(systemName: "calendar.badge.clock")
                    .font(CozyType.cardTitle)
                    .foregroundStyle(theme.accent)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Last 7 days")
                        .font(CozyType.captionStrong)
                        .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                    // UX LOW #106: small "+12% vs last 7 days" chip beside
                    // the eyebrow. Up = focusJade, flat/down = secondaryText
                    // (no red — DESIGN_SYSTEM tone forbids punitive cues).
                    if let delta {
                        WeeklyDeltaChip(percent: delta)
                    }
                }
                Text(summary.headline)
                    .font(CozyType.rowTitle)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(summary.detail)
                    .font(CozyType.body)
                    .foregroundStyle(CozyPalette.secondaryText(colorScheme))
            }
            Spacer(minLength: 0)
        }
        .cozyCard()
        .accessibilityIdentifier("stats.weeklyDigest")
        .accessibilityLabel("Last 7 days: \(summary.headline). \(summary.detail)")
    }

    private var digest: WeeklyDigestSummary {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: Date())
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: today) else {
            return WeeklyDigestSummary(focusBlocks: 0, focusMinutes: 0, paws: 0, habitChecks: 0)
        }
        let sessions = dataStore.focusSessions.filter { session in
            let day = calendar.startOfDay(for: session.reportingDate)
            return day >= weekStart && day <= today
        }
        let focusBlocks = sessions.count
        let focusMinutes = sessions.reduce(0) { $0 + $1.completedMinutes }
        let paws = sessions.reduce(0) { $0 + max(0, $1.rewardPoints) }
        let habitChecks = dataStore.habits.reduce(0) { running, habit in
            let weekHits = (0..<7).reduce(0) { count, offset -> Int in
                guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return count }
                return count + (HabitMath.isComplete(keys: habit.completionKeys, on: day) ? 1 : 0)
            }
            return running + weekHits
        }
        return WeeklyDigestSummary(
            focusBlocks: focusBlocks,
            focusMinutes: focusMinutes,
            paws: paws,
            habitChecks: habitChecks
        )
    }

    /// UX LOW #106 — focus-session count delta of the current 7-day window
    /// vs the prior 7-day window, expressed as an integer percentage. Nil
    /// when the prior window had no sessions (avoids divide-by-zero AND
    /// avoids reading "+∞%" on fresh installs).
    private var sessionsDeltaPercent: Int? {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: Date())
        guard let thisStart = calendar.date(byAdding: .day, value: -6, to: today),
              let priorStart = calendar.date(byAdding: .day, value: -13, to: today),
              let priorEnd = calendar.date(byAdding: .day, value: -7, to: today) else {
            return nil
        }
        let thisWeek = dataStore.focusSessions.filter { session in
            let day = calendar.startOfDay(for: session.reportingDate)
            return day >= thisStart && day <= today
        }.count
        let lastWeek = dataStore.focusSessions.filter { session in
            let day = calendar.startOfDay(for: session.reportingDate)
            return day >= priorStart && day <= priorEnd
        }.count
        guard lastWeek > 0 else { return nil }
        let ratio = Double(thisWeek - lastWeek) / Double(lastWeek)
        return Int((ratio * 100).rounded())
    }
}

/// UX LOW #106 — small chip rendered beside the weekly-digest eyebrow.
/// Up = focusJade, flat/down = secondaryText. Never red — the cozy palette
/// forbids punitive cues, so a quiet week doesn't shame the user.
private struct WeeklyDeltaChip: View {
    @Environment(\.colorScheme) private var colorScheme
    let percent: Int

    private var symbolName: String {
        if percent > 0 { return "arrow.up.right" }
        if percent < 0 { return "arrow.down.right" }
        return "equal"
    }

    private var tint: Color {
        percent > 0 ? CozyPalette.focusJade : CozyPalette.secondaryText(colorScheme)
    }

    private var label: String {
        let sign = percent > 0 ? "+" : ""
        return "\(sign)\(percent)% vs last 7 days"
    }

    var body: some View {
        Label(label, systemImage: symbolName)
            .font(CozyType.badge)
            .foregroundStyle(tint)
            .padding(.horizontal, CozyLayout.badgePaddingSmallH)
            .padding(.vertical, CozyLayout.badgePaddingSmallV)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(colorScheme == .dark ? 0.20 : 0.12))
            )
            .accessibilityLabel("Focus sessions \(label)")
            .accessibilityIdentifier("stats.weeklyDelta")
    }
}

private struct WeeklyDigestSummary {
    let focusBlocks: Int
    let focusMinutes: Int
    let paws: Int
    let habitChecks: Int

    var headline: String {
        if focusBlocks == 0 && habitChecks == 0 && paws == 0 {
            return "A quiet week — every restart counts."
        }
        return "\(focusBlocks) focus \(focusBlocks == 1 ? "block" : "blocks") · \(paws) \(paws == 1 ? "paw" : "paws") · \(habitChecks) habit \(habitChecks == 1 ? "check" : "checks")"
    }

    var detail: String {
        if focusMinutes == 0 {
            return "Tap any tiny start to add minutes here."
        }
        return "\(focusMinutes) focused \(focusMinutes == 1 ? "minute" : "minutes") logged."
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(CozyType.cardTitle)
                .foregroundStyle(color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(CozyType.captionStrong)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                Text(value)
                    .font(CozyType.cardTitle)
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
    @AppStorage("selectedRewardsMode") private var selectedModeRaw: String = RewardsRoomMode.room.rawValue

    private var modeBinding: Binding<RewardsRoomMode> {
        Binding(
            get: { RewardsRoomMode(rawValue: selectedModeRaw) ?? .room },
            set: { selectedModeRaw = $0.rawValue }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CozyLayout.sectionSpacing) {
                SectionHeader(title: "Rewards Room", subtitle: "Earn paws, dress Mochi, and decorate the desk.", mascotState: .complete)
                CozySegmentedControl(
                    options: RewardsRoomMode.allCases.map { mode in
                        CozySegmentOption(mode, title: mode.title, symbolName: mode.symbolName)
                    },
                    selection: modeBinding,
                    minSegmentWidth: 110
                )
                .accessibilityIdentifier("rewards.mode")

                switch modeBinding.wrappedValue {
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
                    .font(CozyType.heroCardTitle)
                Spacer()
                Label("\(dataStore.progression.coinsAvailable)", systemImage: "pawprint.fill")
                    .font(CozyType.cardTitle)
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
                .font(CozyType.heroCardTitle)
            if dataStore.rewards.isEmpty {
                EmptyStateView(
                    title: "Mochi's room is waiting",
                    message: "Complete one tiny focus session and the first surprise lands here. Cosmetic only, free, no streak math.",
                    mascotState: .complete,
                    eyebrow: "Rewards",
                    primaryActionTitle: "Start a tiny focus",
                    primaryAction: {
                        NotificationCenter.default.post(name: .cozyOpenSection, object: AppSection.focus.rawValue)
                    }
                )
                .frame(minHeight: 220)
            } else {
                LazyVGrid(columns: CozyLayout.adaptiveColumns(minimum: 230), spacing: CozyLayout.gridSpacing) {
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
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    private var latestRewards: [RewardItem] {
        Array(dataStore.rewards.sorted { $0.unlockedAt > $1.unlockedAt }.prefix(3))
    }

    var body: some View {
        if latestRewards.isEmpty {
            NextUnlockView(database: dataStore.database)
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    latestUnlockLabel
                    ForEach(latestRewards) { reward in
                        latestUnlockChip(reward)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 10) {
                    latestUnlockLabel
                    LazyVGrid(columns: CozyLayout.adaptiveColumns(minimum: 160), spacing: 8) {
                        ForEach(latestRewards) { reward in
                            latestUnlockChip(reward)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
            .cozyCard()
        }
    }

    private var latestUnlockLabel: some View {
        Label("Latest unlocks", systemImage: "gift.fill")
            .font(CozyType.rowTitle)
            .foregroundStyle(theme.reward)
    }

    private func latestUnlockChip(_ reward: RewardItem) -> some View {
        Label(reward.name, systemImage: reward.symbolName)
            .font(CozyType.body.weight(.semibold))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CozyLayout.subCardRadius, style: .continuous)
                    .fill(CozyPalette.catalogColor(reward.colorHex).opacity(colorScheme == .dark ? 0.20 : 0.14))
            )
            .foregroundStyle(CozyPalette.catalogColor(reward.colorHex))
    }
}

struct AdventureRulesCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            RarityIcon(symbol: "dice.fill", rarity: .cozy, size: 52)
            VStack(alignment: .leading, spacing: 6) {
                Text("Adventure rolls")
                    .font(CozyType.rowTitle)
                Text("Each saved focus can reveal one free cosmetic find. Odds are visible, duplicates become paws, and the shop stays direct-buy.")
                    .font(CozyType.body)
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
                HStack(spacing: 16) {
                    // Round diorama — the previous rounded-rect background made
                    // the circular mascot look like it was overlapping a square
                    // tile. Soft circle + clip ensures everything reads as a
                    // single rounded medallion with a tiny accent icon attached.
                    ZStack {
                        Circle()
                            .fill(CozyPalette.quietContainer(colorScheme))
                        EquippedMascotView(state: .idle, size: .avatar, rewards: dataStore.rewards)
                            .accessibilityHidden(true)
                    }
                    .frame(width: 70, height: 70)
                    .overlay(alignment: .topTrailing) {
                        ZStack {
                            Circle()
                                .fill(theme.reward.opacity(0.18))
                            Image(systemName: bestRoomSymbol)
                                .font(CozyType.badge)
                                .foregroundStyle(theme.rewardText(colorScheme))
                        }
                        .frame(width: 28, height: 28)
                        .offset(x: 4, y: -4)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Room glow-up")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("\(dataStore.rewards.count) things unlocked")
                            .font(CozyType.rowTitle)
                        Text("Tap to equip and decorate")
                            .font(CozyType.body)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                if CozyProgression.nearestUnlock(in: dataStore.database) != nil {
                    NextUnlockView(database: dataStore.database)
                } else {
                    everythingUnlockedTeaser
                }
            }
            .compactDashboardTile()
            .cozyCard()
        }
        .cozyPressable()
    }

    private var everythingUnlockedTeaser: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(CozyPalette.focusJade.opacity(0.16))
                Image(systemName: "sparkles")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(CozyPalette.focusJade)
            }
            .frame(width: 32, height: 32)

            Text("Mochi has more surprises brewing — keep earning paws")
                .font(CozyType.captionStrong)
                .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: CozyLayout.subCardRadius, style: .continuous)
                .fill(CozyPalette.quietContainer(colorScheme))
        )
        .accessibilityIdentifier("progression.allUnlocked")
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
        let placed = dataStore.rewards
            .filter { $0.isEquipped && $0.category.localizedCaseInsensitiveContains("room decor") }
            .sorted { $0.unlockedAt > $1.unlockedAt }
        let recentFill = dataStore.rewards
            .filter { reward in !placed.contains(where: { $0.id == reward.id }) }
            .sorted { $0.unlockedAt > $1.unlockedAt }
        return Array((placed + recentFill).prefix(7))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(mascotName)’s desk room")
                        .font(CozyType.cardTitle)
                    Text("Focus turns into a place she can customize.")
                        .font(CozyType.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label("\(dataStore.progression.coinsAvailable)", systemImage: "pawprint.fill")
                    .font(CozyType.cardTitle)
                    .foregroundStyle(theme.rewardText(colorScheme))
            }

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [CozyPalette.lofiInk, CozyPalette.darkRaised]
                                : [CozyPalette.softMint.opacity(0.66), CozyPalette.lavenderMist.opacity(0.42)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 0) {
                    if visibleRewards.isEmpty {
                        VStack(spacing: 10) {
                            MascotView(state: .idle, size: .card)
                                .frame(maxWidth: .infinity)
                                .accessibilityHidden(true)
                            Text("Save your first focus and Mochi starts decorating")
                                .font(CozyType.rowTitle)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                        .padding(20)
                    } else {
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(visibleRewards.prefix(4)) { reward in
                                RoomRewardIcon(reward: reward, size: 40)
                            }
                            Spacer()
                            Image(systemName: "lightbulb.led.fill")
                                .font(.title.weight(.bold))
                                .frame(width: 40, height: 40)
                                .foregroundStyle(CozyPalette.wasabi.opacity(0.86))
                        }
                        .padding(16)
                        Spacer()
                    }
                }

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(CozyPalette.focusJade.opacity(colorScheme == .dark ? 0.20 : 0.13))
                    .frame(height: 58)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                // Tight cluster — mascot + text + reward icons feel like one
                // unit instead of three things spread across a wide row. The
                // previous Spacer was pushing the icons to the far edge,
                // leaving a giant empty middle.
                HStack(alignment: .center, spacing: 16) {
                    EquippedMascotView(state: dataStore.progression.level > 1 ? .complete : .idle, size: .card, rewards: dataStore.rewards)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(dataStore.progression.petStage.rawValue)
                            .font(CozyType.captionStrong)
                            .foregroundStyle(.secondary)
                        Text(roomMood)
                            .font(CozyType.cardTitle)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 8) {
                        ForEach(visibleRewards.suffix(3)) { reward in
                            RoomRewardIcon(reward: reward, size: 36)
                        }
                    }
                }
                .padding(20)
            }
            // Visual audit CRITICAL #1: previous 236pt left only ~12pt
            // between the top icon row and the mascot cluster — they read as
            // crowded. 280pt gives both clusters enough breathing room.
            .frame(minHeight: 280)
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
    @EnvironmentObject private var dataStore: AppDataStore
    @AppStorage("selectedRewardsMode") private var selectedModeRaw: String = RewardsRoomMode.room.rawValue
    let reward: RewardItem
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(CozyPalette.catalogColor(reward.colorHex).opacity(0.18))
            Image(systemName: reward.symbolName)
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(CozyPalette.catalogColor(reward.colorHex))
                .frame(width: size * 0.48, height: size * 0.48)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(reward.name)
        .contextMenu {
            if !reward.isEquipped {
                Button {
                    dataStore.equipReward(id: reward.id)
                    CozyFeedback.play(.complete)
                } label: {
                    Label("Equip", systemImage: "sparkles")
                }
            }
            Button {
                selectedModeRaw = RewardsRoomMode.inventory.rawValue
                NotificationCenter.default.post(name: .cozyOpenSection, object: AppSection.rewards.rawValue)
            } label: {
                Label("Show details", systemImage: "info.circle")
            }
        }
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
                .font(CozyType.heroCardTitle)
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
                    .font(CozyType.cardTitle)
                    .foregroundStyle(isUnlocked ? theme.reward : .secondary)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(CozyType.rowTitle)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    @AppStorage("selectedTimerSkin") private var selectedTimerSkin = CozyTimerSkin.defaultID
    @AppStorage("selectedTimerShape") private var selectedTimerShape = CozyTimerShape.ring.rawValue
    let item: ShopCatalogItem
    // Hover state — two-stage per NN/g timing guidelines: instant ≤100 ms
    // scale+shadow on enter, 300 ms intent threshold before the deeper
    // rotation3D tilt engages so a fly-by mouse pass doesn't trigger heavy
    // motion.
    @State private var isHovered = false
    @State private var deepHover = false
    @State private var pointerLocation: CGPoint = .zero

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
                CozyItemArt(
                    symbolName: item.symbolName,
                    colorHex: item.colorHex,
                    category: item.category,
                    requiredLevel: item.requiredLevel,
                    size: 64,
                    shouldShimmer: isPurchased   // shimmer once it's owned
                )
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    CozyPill(title: statusText, intent: .accent(statusColor), size: .small)
                    Label("\(item.coinCost)", systemImage: "pawprint.fill")
                        .font(CozyType.controlStrong)
                        .foregroundStyle(theme.rewardText(colorScheme))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(CozyType.rowTitle)
                Text(item.category)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CozyRewardColor.category)
                Text(item.description)
                    .font(CozyType.body)
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
                    .font(CozyType.captionStrong)
                    .foregroundStyle(.secondary)
            }

            Text(footerText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minHeight: 16, alignment: .leading)
        }
        .cozyCard()
        // Hover affordance — NN/g: instant feedback (≤100 ms) on enter,
        // delayed engagement (300 ms) for the heavier 3D tilt. Reduce-Motion
        // keeps only the shadow change (Apple's "color/highlight shift"
        // substitute for motion).
        .scaleEffect(isHovered && !reduceMotion ? 1.01 : 1.0)
        .shadow(
            color: CozyPalette.softShadow(colorScheme, active: isHovered),
            radius: isHovered ? 10 : 4,
            y: isHovered ? 5 : 2
        )
        .rotation3DEffect(
            .degrees(deepHover && !reduceMotion ? 1.5 : 0),
            axis: (x: -tiltAxis.y, y: tiltAxis.x, z: 0),
            perspective: 0.6
        )
        .animation(CozyMotion.gentle(reduceMotion, duration: 0.18), value: isHovered)
        .animation(CozyMotion.gentle(reduceMotion, duration: 0.22), value: deepHover)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                    if isHovered { deepHover = true }
                }
            } else {
                deepHover = false
            }
        }
        .onContinuousHover { phase in
            if case .active(let pt) = phase { pointerLocation = pt }
        }
    }

    private var tiltAxis: CGPoint {
        // Map cursor position within card (~220×220) to a ±1 tilt vector.
        CGPoint(x: (pointerLocation.x / 220 - 0.5) * 2,
                y: (pointerLocation.y / 220 - 0.5) * 2)
    }

    private var sessionCountMet: Bool {
        item.requiredSessionCount == 0
            || dataStore.focusSessions.count >= item.requiredSessionCount
    }

    private var actionTitle: String {
        if isEquipped { return item.category == "Room decor" ? "Placed" : "Equipped" }
        if isPurchased { return item.category == "Room decor" ? "Place" : "Equip" }
        if dataStore.progression.level < item.requiredLevel { return "Locked" }
        if !sessionCountMet { return "Locked" }
        if dataStore.progression.coinsAvailable < item.coinCost {
            let needed = item.coinCost - dataStore.progression.coinsAvailable
            return "Need \(needed) more"
        }
        return item.coinCost == 0 ? "Unlock" : "Buy"
    }

    private var statusText: String {
        // Sentence case — rest of the app uses sentence case for chip labels. ALL-CAPS
        // reads as shouting in a "cozy" voice (Mailchimp tone). "SAVE" was especially
        // confusing — looked like an action button.
        if isEquipped { return item.category == "Room decor" ? "Placed" : "On Mochi" }
        if isPurchased { return "Owned" }
        if dataStore.progression.level < item.requiredLevel { return "Soon" }
        if !sessionCountMet { return "Soon" }
        if dataStore.progression.coinsAvailable < item.coinCost { return "Saving up" }
        return "Ready"
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
        if !sessionCountMet {
            let remaining = item.requiredSessionCount - dataStore.focusSessions.count
            return "Unlock at \(item.requiredSessionCount) lifetime sessions (\(remaining) to go)."
        }
        if dataStore.progression.coinsAvailable < item.coinCost {
            return "\(item.coinCost - dataStore.progression.coinsAvailable) paws to go."
        }
        return item.coinCost == 0 ? "Free to unlock." : "Ready to buy."
    }

    private var actionHelp: String {
        if isEquipped { return "Already active" }
        if isPurchased { return "Equip this cosmetic" }
        if dataStore.progression.level < item.requiredLevel { return "Reach level \(item.requiredLevel) to unlock" }
        if !sessionCountMet { return "Complete \(item.requiredSessionCount) lifetime sessions to unlock" }
        if dataStore.progression.coinsAvailable < item.coinCost { return "\(item.coinCost - dataStore.progression.coinsAvailable) more paws needed" }
        return item.coinCost == 0 ? "Unlock this special item" : "Buy and equip this cosmetic"
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
            CozyItemArt(
                symbolName: reward.symbolName,
                colorHex: reward.colorHex,
                category: reward.category,
                requiredLevel: nil,
                explicitRarity: CozyProgression.rarity(for: reward),
                size: 86,
                shouldShimmer: true   // Owned rare items glint in Inventory.
            )
            .frame(maxWidth: .infinity)
            Text(reward.name)
                .font(CozyType.rowTitle)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 44, alignment: .top)
            Text(reward.category)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
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
                CozyPill(title: "Collected", symbolName: "checkmark", intent: .success, size: .small)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 224, alignment: .top)
        .cozyCard()
        .contextMenu {
            if canEquip && !reward.isEquipped {
                Button {
                    dataStore.equipReward(id: reward.id)
                    applyCosmeticSelection()
                    CozyFeedback.play(.complete)
                } label: {
                    Label(equipTitle, systemImage: "sparkles")
                }
            }
            Button {
                // No standalone detail view yet — bring the user to the
                // rewards screen so the action lands somewhere coherent.
                NotificationCenter.default.post(name: .cozyOpenSection, object: AppSection.rewards.rawValue)
            } label: {
                Label("Show details", systemImage: "info.circle")
            }
        }
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
    @AppStorage("cozyHapticsEnabled") private var hapticsEnabled = true
    @AppStorage("reducedDecoration") private var reducedDecoration = false
    @AppStorage("hideStreaks") private var hideStreaks = false
    @State private var mascotNameDraft: String = ""
    @State private var mascotNameDebounceTask: Task<Void, Never>?
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
                        // Bind the TextField to a local @State draft, not directly to @AppStorage.
                        // Previously every keystroke wrote UserDefaults and fanned out to 6 views
                        // observing `@AppStorage("mascotName")` (B13). Now we commit only on
                        // Return / blur, and cap length at 24 chars at commit time.
                        TextField("Mascot name", text: $mascotNameDraft)
                            .accessibilityIdentifier("settings.mascotName")
                            .cozyTextInput(minWidth: 220, alignment: .leading)
                            .onAppear { mascotNameDraft = mascotName }
                            .onSubmit { commitMascotName() }
                            .onChange(of: mascotNameDraft) { _, newValue in
                                // Light debounce: also commit if user leaves the field clean
                                // for ~0.4s. We keep typing fluid by committing on a timer
                                // rather than per-keystroke.
                                mascotNameDebounceTask?.cancel()
                                mascotNameDebounceTask = Task { @MainActor in
                                    try? await Task.sleep(for: .milliseconds(400))
                                    guard !Task.isCancelled else { return }
                                    let snapshot = newValue
                                    if snapshot == mascotNameDraft { commitMascotName() }
                                }
                            }
                            .onDisappear {
                                mascotNameDebounceTask?.cancel()
                                commitMascotName()
                            }
                    }

                    LazyVGrid(columns: CozyLayout.adaptiveColumns(minimum: 230), spacing: 10) {
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
                        title: "Soft haptics",
                        symbolName: "hand.tap.fill",
                        subtitle: "Use gentle trackpad taps for wins.",
                        isOn: $hapticsEnabled
                    )
                        .accessibilityIdentifier("settings.haptics")
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
                        .foregroundStyle(.secondary)
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

    private func commitMascotName() {
        let trimmed = mascotNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let final = String(trimmed.prefix(24))
        let resolved = final.isEmpty ? "Mochi" : final
        if mascotName != resolved {
            mascotName = resolved
        }
        if mascotNameDraft != resolved {
            mascotNameDraft = resolved
        }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let style: CozyMascotStyle
    let isSelected: Bool

    /// Render the actual mascot inside the picker tile so picking a style
    /// WYSIWYGs the choice. Falls back to the style's SF Symbol when Reduce
    /// Motion is on or when no Lottie ships for this style — the symbol is
    /// the same one displayed alongside the title, so the tile still
    /// distinguishes mascots in the static fallback.
    @ViewBuilder
    private var previewArt: some View {
        if isSelected,
           !reduceMotion,
           let character = CozyLottieMascot.lottiePrefix(forStyleID: style.id),
           CozyLottieMascot.isBundled(character: character) {
            CozyLottieMascot(characterID: character, state: .idle, size: 40)
        } else {
            Image(systemName: style.symbolName)
                .font(CozyType.cardTitle)
                .foregroundStyle(CozyPalette.berry.opacity(0.78))
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((isSelected ? CozyPalette.stickerPink : CozyPalette.quietContainer(colorScheme)).opacity(isSelected ? 0.40 : 1))
                previewArt
            }
            .frame(width: 70, height: 70)

            VStack(alignment: .leading, spacing: 2) {
                Text(style.title)
                    .font(CozyType.controlStrong)
                    .foregroundStyle(CozyPalette.primaryText(colorScheme))
                Text(style.subtitle)
                    .font(.caption)
                    .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(CozyType.cardTitle)
                    .foregroundStyle(CozyPalette.focusJade)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
                .fill(isSelected ? CozyPalette.selectionFill.opacity(colorScheme == .dark ? 0.16 : 0.62) : Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
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
                .font(CozyType.controlStrong)
                .foregroundStyle(CozyPalette.primaryText(colorScheme))
                .lineLimit(1)
            HStack(spacing: 5) {
                Circle().fill(skin.color)
                    .frame(width: 12, height: 12)
                Circle().fill(skin.secondary)
                    .frame(width: 12, height: 12)
                Circle().fill(CozyPalette.cardFill(colorScheme))
                    .frame(width: 12, height: 12)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .topLeading)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
                .fill(isSelected ? skin.secondary.opacity(0.30) : Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
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
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(CozyType.cardTitle)
                Text(subtitle)
                    .font(CozyType.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 12)

            Divider().opacity(0.4)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(.top, 12)
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
