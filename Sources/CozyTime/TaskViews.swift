import CozyCore
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var timerStore: FocusTimerStore

    private var todayTasks: [TaskItem] {
        dataStore.tasks.filter { !$0.isCompleted && CozyCalendar.isToday($0.dueDate) }
            .sorted { TaskFilters.sortByPriorityThenDueDate($0.filterRecord, $1.filterRecord) }
    }

    private var attentionCountdown: CountdownEvent? {
        dataStore.countdowns.sorted { lhs, rhs in
            let leftPhase = lhs.phase()
            let rightPhase = rhs.phase()
            if leftPhase.isOverdue != rightPhase.isOverdue {
                return leftPhase.isOverdue
            }
            return lhs.targetDate < rhs.targetDate
        }
        .first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CozyLayout.sectionSpacing) {
                SectionHeader(
                    title: "Today",
                    subtitle: "Pick one tiny step, earn paws, and let Mochi grow with you.",
                    mascotState: todayMascotState
                )

                FirstSessionCard()
                QuickAddBar(defaultDueDate: Date())
                DailyQuestCard()

                LazyVGrid(columns: CozyLayout.adaptiveColumns(minimum: 280), spacing: CozyLayout.gridSpacing) {
                    FocusPreviewCard()
                    if let attentionCountdown {
                        CountdownCompactCard(event: attentionCountdown)
                    }
                    TodayHabitCard()
                    DeskRoomMiniCard()
                }

                Text("Today’s Tasks")
                    .font(.title2.weight(.bold))
                if todayTasks.isEmpty {
                    EmptyStateView(
                        title: "Today is open",
                        message: "Add one tiny task or start a quick focus session.",
                        mascotState: .idle,
                        actionTitle: "Open Focus"
                    ) {
                        NotificationCenter.default.post(name: .cozyOpenSection, object: AppSection.focus.rawValue)
                    }
                        .frame(minHeight: 260)
                } else {
                    TaskList(tasks: todayTasks)
                }
            }
            .cozyPageFrame()
        }
        .accessibilityIdentifier("screen.today")
    }

    private var todayMascotState: MascotState {
        guard timerStore.isActive else { return .idle }
        switch timerStore.phase(at: timerStore.currentDate) {
        case .prepare: return .idle
        case .settling: return .settling
        case .deepFocus: return .deepFocus
        case .finalMinute: return .landing
        case .wrap: return .complete
        case .breakTime: return .breakTime
        }
    }
}

struct UpcomingView: View {
    @EnvironmentObject private var dataStore: AppDataStore

    private var upcomingTasks: [TaskItem] {
        dataStore.tasks.filter { !$0.isCompleted && CozyCalendar.isUpcoming($0.dueDate) }
            .sorted { TaskFilters.sortByPriorityThenDueDate($0.filterRecord, $1.filterRecord) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CozyLayout.sectionSpacing) {
                SectionHeader(title: "Upcoming", subtitle: "A calm look at what is next.", mascotState: .countdown)
                QuickAddBar(defaultDueDate: Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: Date()))
                TaskList(tasks: upcomingTasks)
            }
            .cozyPageFrame()
        }
        .accessibilityIdentifier("screen.upcoming")
    }
}

struct TasksView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @State private var listFilter = "All"

    private var listNames: [String] {
        ["All"] + Array(Set(dataStore.tasks.map(\.listName))).sorted()
    }

    private var filteredTasks: [TaskItem] {
        dataStore.tasks
            .filter { listFilter == "All" || $0.listName == listFilter }
            .sorted { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
                return TaskFilters.sortByPriorityThenDueDate(lhs.filterRecord, rhs.filterRecord)
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CozyLayout.sectionSpacing) {
                SectionHeader(title: "Tasks", subtitle: "Lists, tags, priorities, and soft deadlines.", mascotState: .idle)
                QuickAddBar(defaultDueDate: nil)
                ScrollView(.horizontal, showsIndicators: false) {
                    CozySegmentedControl(
                        options: listNames.map { CozySegmentOption($0, title: $0) },
                        selection: $listFilter,
                        minSegmentWidth: 94
                    )
                }
                .accessibilityIdentifier("tasks.listFilter")
                TaskList(tasks: filteredTasks)
            }
            .cozyPageFrame()
        }
        .accessibilityIdentifier("screen.tasks")
    }
}

struct QuickAddBar: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var timerStore: FocusTimerStore
    @EnvironmentObject private var notifications: NotificationService
    let defaultDueDate: Date?

    @State private var title = ""
    @State private var listName = "Inbox"
    @State private var priority = 1
    @State private var estimatedMinutes = 25
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var isExpanded = false
    @State private var lastAddedTask: TaskItem?

    init(defaultDueDate: Date?) {
        self.defaultDueDate = defaultDueDate
        _dueDate = State(initialValue: defaultDueDate ?? Date())
        _hasDueDate = State(initialValue: defaultDueDate != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CozyLayout.formRowSpacing) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: CozyLayout.formRowSpacing) {
                    titleField
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(alignment: .top, spacing: CozyLayout.formRowSpacing) {
                        detailsButton
                        addButton
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }

                VStack(alignment: .leading, spacing: CozyLayout.formRowSpacing) {
                    titleField
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(alignment: .top, spacing: CozyLayout.formRowSpacing) {
                        detailsButton
                        addButton
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            }

            if isExpanded {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: CozyLayout.formRowSpacing) {
                        listField
                        dueDateField
                        durationStepper
                        priorityPicker
                    }

                    VStack(alignment: .leading, spacing: CozyLayout.formRowSpacing) {
                        listField
                        dueDateField
                        durationStepper
                        priorityPicker
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Label("\(cleanListName) · \(dueSummary) · \(estimatedMinutes)m · \(priorityLabel)", systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("quickAdd.summary")
            }

            if let lastAddedTask {
                quickAddFeedback(task: lastAddedTask)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .cozyCard()
        .animation(.snappy(duration: 0.18), value: isExpanded)
    }

    private var titleField: some View {
        CozyLabeledControl(title: "Task", symbolName: "checklist", minWidth: 220) {
            VStack(alignment: .leading, spacing: 6) {
                TextField("Add a tiny task...", text: $title)
                    .onSubmit(addTask)
                    .accessibilityIdentifier("quickAdd.title")
                    .cozyTextInput(minWidth: 220, alignment: .leading)
                if cleanTitle.isEmpty {
                    CozyFieldHint(text: "Type a task title to add it.")
                }
            }
        }
        .layoutPriority(1)
    }

    private var detailsButton: some View {
        CozyLabeledControl(title: "Options", symbolName: "slider.horizontal.3", minWidth: 104) {
            Button {
                isExpanded.toggle()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .frame(width: 22, height: 22)
            }
            .cozyIconButton(size: CozyLayout.hitSize)
            .help(isExpanded ? "Hide task details" : "Show task details")
            .accessibilityLabel(isExpanded ? "Hide task details" : "Show task details")
            .accessibilityIdentifier("quickAdd.details")
        }
    }

    private var listField: some View {
        CozyLabeledControl(title: "List", symbolName: "tray.full") {
            TextField("List", text: $listName)
                .accessibilityIdentifier("quickAdd.list")
                .cozyTextInput(width: 150, alignment: .leading)
        }
    }

    private var dueDateField: some View {
        CozyLabeledControl(title: "Due", symbolName: "calendar", minWidth: hasDueDate ? 230 : 190) {
            VStack(alignment: .leading, spacing: 8) {
                CozyToggleRow(
                    title: hasDueDate ? dueSummary : "No due date",
                    symbolName: "calendar",
                    subtitle: hasDueDate ? "Click date to change it" : "Keep this task flexible",
                    isOn: $hasDueDate
                )
                .accessibilityIdentifier("quickAdd.hasDueDate")
                if hasDueDate {
                    CozyDateInput(date: $dueDate)
                        .accessibilityIdentifier("quickAdd.dueDate")
                }
            }
        }
    }

    private var durationStepper: some View {
        CozyLabeledControl(title: "Estimate", symbolName: "clock") {
            CozyStepperField(value: $estimatedMinutes, range: 5...180, step: 5) { "\($0)m" }
                .accessibilityIdentifier("quickAdd.duration")
        }
    }

    private var priorityPicker: some View {
        CozyLabeledControl(title: "Priority", symbolName: "flag") {
            CozySegmentedControl(
                options: [
                    CozySegmentOption(0, title: "Low"),
                    CozySegmentOption(1, title: "Med"),
                    CozySegmentOption(2, title: "Top")
                ],
                selection: $priority,
                minSegmentWidth: 52
            )
                .accessibilityIdentifier("quickAdd.priority")
        }
    }

    private var addButton: some View {
        CozyLabeledControl(title: "Action", symbolName: "plus.circle", minWidth: 132) {
            Button {
                addTask()
            } label: {
                Label("Add", systemImage: "plus")
            }
            .cozyPrimaryButton(minWidth: 128, fullWidth: true)
            .disabled(cleanTitle.isEmpty)
            .help(cleanTitle.isEmpty ? "Type a task title first." : "Add this task.")
            .accessibilityHint(cleanTitle.isEmpty ? "Type a task title first." : "Add this task.")
            .keyboardShortcut(.return, modifiers: [.command])
            .accessibilityIdentifier("quickAdd.add")
        }
    }

    private func quickAddFeedback(task: TaskItem) -> some View {
        HStack(spacing: 8) {
            Label("Task added", systemImage: "checkmark.circle.fill")
                .font(CozyType.captionStrong)
                .foregroundStyle(CozyPalette.focusJade)
            Spacer()
            Button("Undo") {
                dataStore.deleteTask(id: task.id)
                lastAddedTask = nil
                CozyFeedback.play(.undo)
            }
            .cozyGhostButton(minWidth: 64)
            Button {
                guard timerStore.canStartNewSession else { return }
                UserDefaults.standard.set(FocusBoost.default.id, forKey: "focus.activeBoostID")
                timerStore.start(taskTitle: task.title, taskID: task.id, duration: TimeInterval(task.estimatedMinutes * 60))
                scheduleFocusCompletion()
                NotificationCenter.default.post(name: .cozyOpenSection, object: AppSection.focus.rawValue)
            } label: {
                Label("Start focus", systemImage: "play.fill")
            }
            .cozySecondaryButton(minWidth: 118)
            .disabled(!timerStore.canStartNewSession)
        }
        .padding(.top, 2)
    }

    private var priorityLabel: String {
        switch priority {
        case 2...: "Top"
        case 1: "Med"
        default: "Low"
        }
    }

    private var cleanListName: String {
        let clean = listName.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "Inbox" : clean
    }

    private var dueSummary: String {
        guard hasDueDate else { return "No date" }
        if CozyCalendar.isToday(dueDate) { return "Due today" }
        let tomorrow = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: Calendar.autoupdatingCurrent.startOfDay(for: Date()))
        if let tomorrow, Calendar.autoupdatingCurrent.isDate(dueDate, inSameDayAs: tomorrow) {
            return "Due tomorrow"
        }
        return "Due \(CozyFormatters.shortDate.string(from: dueDate))"
    }

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addTask() {
        guard !cleanTitle.isEmpty else { return }
        let task = TaskItem(
            title: cleanTitle,
            dueDate: hasDueDate ? dueDate : nil,
            priority: priority,
            listName: cleanListName,
            estimatedMinutes: estimatedMinutes
        )
        dataStore.addTask(task)
        CozyFeedback.play(.add)
        lastAddedTask = task
        title = ""
    }

    private func scheduleFocusCompletion() {
        guard let startDate = timerStore.snapshot.startDate else { return }
        let draft = NotificationPlanner.focusCompletion(
            sessionID: UUID(),
            taskTitle: timerStore.activeTaskTitle,
            startDate: startDate,
            duration: timerStore.snapshot.duration,
            accumulatedPause: timerStore.snapshot.accumulatedPause
        )
        Task {
            await notifications.cancelFocusNotifications()
            await notifications.schedule(draft)
        }
    }
}

struct FirstSessionCard: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var timerStore: FocusTimerStore
    @EnvironmentObject private var notifications: NotificationService
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    @AppStorage("mascotName") private var mascotName = "Mochi"

    @State private var starterTitle = "First tiny session"
    @State private var messageIndex = 0
    @State private var petPulse = false

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    private var focusMinutesToday: Int {
        dataStore.focusSessions
            .filter { Calendar.autoupdatingCurrent.isDateInToday($0.reportingDate) }
            .reduce(0) { $0 + $1.completedMinutes }
    }

    private var heroMessage: String {
        let messages = [
            "Click Mochi for a tiny mood boost.",
            "Tiny focus counts. Paws unlock decor.",
            "One clean block beats ten noisy tabs."
        ]
        return messages[messageIndex % messages.count]
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 20) {
                heroMascotPanel
                    .frame(width: 220)
                heroActionPanel
            }

            VStack(alignment: .leading, spacing: 18) {
                heroMascotPanel
                heroActionPanel
            }
        }
        .cozyHeroCard()
        .accessibilityIdentifier("firstSession.card")
    }

    private var heroMascotPanel: some View {
        VStack(spacing: 12) {
            mascotButton
            VStack(spacing: 4) {
                Label("Pet \(mascotName)", systemImage: "hand.tap.fill")
                    .font(.caption.weight(.bold))
                Text(timerStore.isActive ? "Keeping time" : "Ready to start")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(CozyPalette.secondaryText(colorScheme))
            }
            .multilineTextAlignment(.center)
            themeBadge
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 238)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(CozyPalette.quietContainer(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(CozyPalette.cardBorder(colorScheme), lineWidth: 1)
        )
    }

    private var mascotButton: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
                petPulse.toggle()
                messageIndex += 1
            }
        } label: {
            EquippedMascotView(state: timerStore.isActive ? activeMascotState : .idle, size: petPulse ? 136 : 128, rewards: dataStore.rewards)
        }
        .cozyPressable(pressedScale: 0.94, hoverScale: 1.035)
        .contentShape(Circle())
        .help("Pet \(mascotName)")
        .accessibilityLabel("Pet \(mascotName)")
    }

    private var heroActionPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(timerStore.isActive ? "Now focusing" : "Start a cozy block")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .lineLimit(2)
                Text(timerStore.isActive ? "\(mascotName) is keeping the room quiet." : heroMessage)
                    .font(.callout)
                    .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                    .lineLimit(2)
            }

            startControls

            LazyVGrid(columns: metricColumns, spacing: 10) {
                SoftMetricBadge(title: "focus today", value: "\(focusMinutesToday)m", symbol: "timer", color: CozyPalette.focusJade)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SoftMetricBadge(title: "Mochi", value: "Lv. \(dataStore.progression.level)", symbol: "pawprint.fill", color: theme.reward)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SoftMetricBadge(title: "paws", value: "\(dataStore.progression.coinsAvailable)", symbol: "sparkles", color: CozyPalette.habitLavender)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            NextUnlockView(database: dataStore.database)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var startControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            starterTitleField
            VStack(alignment: .leading, spacing: 6) {
                Label("Length", systemImage: "timer")
                    .font(CozyType.captionStrong)
                    .foregroundStyle(.secondary)
                presetButtons
            }
        }
    }

    private var starterTitleField: some View {
        CozyLabeledControl(title: "Focus title", symbolName: "sparkle.magnifyingglass", minWidth: 220) {
            TextField("What are you focusing on?", text: $starterTitle)
                .onSubmit { start(minutes: 25) }
                .accessibilityIdentifier("firstSession.title")
                .cozyTextInput(minWidth: 220, minHeight: 38, alignment: .leading)
        }
        .layoutPriority(1)
    }

    private var presetButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                focusPresetButton(minutes: 5, symbol: "bolt.fill", isPrimary: false)
                    .accessibilityIdentifier("firstSession.start.5")
                focusPresetButton(minutes: 15, symbol: "timer", isPrimary: false)
                    .accessibilityIdentifier("firstSession.start.15")
                focusPresetButton(minutes: 25, symbol: "timer", isPrimary: true)
                    .accessibilityIdentifier("firstSession.start.25")
            }
            LazyVGrid(columns: CozyLayout.adaptiveColumns(minimum: 94), spacing: 8) {
                focusPresetButton(minutes: 5, symbol: "bolt.fill", isPrimary: false)
                    .accessibilityIdentifier("firstSession.start.5")
                focusPresetButton(minutes: 15, symbol: "timer", isPrimary: false)
                    .accessibilityIdentifier("firstSession.start.15")
                focusPresetButton(minutes: 25, symbol: "timer", isPrimary: true)
                    .accessibilityIdentifier("firstSession.start.25")
            }
        }
    }

    private func focusPresetButton(minutes: Int, symbol: String, isPrimary: Bool) -> some View {
        Button {
            start(minutes: minutes)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.caption.weight(.black))
                Text("\(minutes)m")
                    .font(.callout.weight(.bold))
            }
            .frame(minWidth: 92, minHeight: CozyLayout.hitSize)
            .foregroundStyle(isPrimary ? .white : CozyPalette.focusJade)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isPrimary ? CozyPalette.focusJade : CozyPalette.cardFill(colorScheme).opacity(colorScheme == .dark ? 0.46 : 0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isPrimary ? Color.white.opacity(0.20) : CozyPalette.focusJade.opacity(0.22), lineWidth: 1)
            )
        }
        .cozyPressable(pressedScale: 0.965, hoverScale: 1.015)
        .disabled(!timerStore.canStartNewSession)
        .opacity(timerStore.canStartNewSession ? 1 : 0.45)
    }

    private var metricColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 120), spacing: 10),
            GridItem(.flexible(minimum: 120), spacing: 10),
            GridItem(.flexible(minimum: 120), spacing: 10)
        ]
    }

    private var themeBadge: some View {
        Label(theme.id, systemImage: theme.symbolName)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(CozyPalette.cardFill(colorScheme).opacity(colorScheme == .dark ? 0.50 : 0.72))
            )
            .overlay(
                Capsule()
                    .stroke(theme.accent.opacity(0.26), lineWidth: 1)
            )
    }

    private var activeMascotState: MascotState {
        switch timerStore.phase(at: timerStore.currentDate) {
        case .prepare: return .idle
        case .settling: return .settling
        case .deepFocus: return .deepFocus
        case .finalMinute: return .landing
        case .wrap: return .complete
        case .breakTime: return .breakTime
        }
    }

    private func start(minutes: Int) {
        guard timerStore.canStartNewSession else { return }
        let cleanTitle = starterTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = cleanTitle.isEmpty ? "Quick focus" : cleanTitle
        if let existingTask = dataStore.tasks.first(where: { $0.title == title && !$0.isCompleted }) {
            timerStore.start(taskTitle: title, taskID: existingTask.id, duration: TimeInterval(minutes * 60))
        } else {
            let task = TaskItem(title: title, dueDate: Date(), priority: 1, estimatedMinutes: minutes)
            dataStore.addTask(task)
            CozyFeedback.play(.add)
            timerStore.start(taskTitle: title, taskID: task.id, duration: TimeInterval(minutes * 60))
        }
        scheduleFocusCompletion()
    }

    private func scheduleFocusCompletion() {
        guard let startDate = timerStore.snapshot.startDate else { return }
        let draft = NotificationPlanner.focusCompletion(
            sessionID: UUID(),
            taskTitle: timerStore.activeTaskTitle,
            startDate: startDate,
            duration: timerStore.snapshot.duration,
            accumulatedPause: timerStore.snapshot.accumulatedPause
        )
        Task {
            await notifications.cancelFocusNotifications()
            await notifications.schedule(draft)
        }
    }
}

struct DailyQuestCard: View {
    @EnvironmentObject private var dataStore: AppDataStore

    private var quests: [(String, String, String, Bool)] {
        [
            ("Complete a focus block", "+XP and paws", "timer", dataStore.focusSessions.contains { $0.isRewardEligible && Calendar.autoupdatingCurrent.isDateInToday($0.reportingDate) }),
            ("Complete one task", "+12 XP sticker", "checkmark.circle.fill", dataStore.tasks.contains { task in
                guard let completedAt = task.completedAt else { return false }
                return Calendar.autoupdatingCurrent.isDateInToday(completedAt)
            }),
            ("Check one habit", "+8 XP rhythm", "sparkles", dataStore.habits.contains { HabitMath.isComplete(keys: $0.completionKeys, on: Date()) })
        ]
    }

    private var completedCount: Int {
        quests.filter(\.3).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today’s cozy quests")
                        .font(.title3.weight(.bold))
                    Text("\(completedCount) of \(quests.count) done. Any one of these counts today.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(Double(completedCount) / Double(quests.count) * 100))%")
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .foregroundStyle(CozyPalette.berry)
            }

            CozyLinearProgressBar(value: Double(completedCount), total: Double(quests.count), color: CozyPalette.berry)
                .accessibilityLabel("Daily quest progress")

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    questItems
                }

                LazyVGrid(columns: CozyLayout.adaptiveColumns(minimum: 220), spacing: 10) {
                    questItems
                }
            }
        }
        .cozyCard()
        .accessibilityIdentifier("dailyQuest.card")
    }

    @ViewBuilder
    private var questItems: some View {
        ForEach(Array(quests.enumerated()), id: \.offset) { index, quest in
            QuestPill(title: quest.0, reward: quest.1, symbol: quest.2, isDone: quest.3, accent: questAccent(index: index)) {
                openQuest(index: index)
            }
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
        }
    }

    private func questAccent(index: Int) -> Color {
        switch index {
        case 0: return CozyPalette.focusJade
        case 1: return CozyPalette.berry
        default: return CozyPalette.habitLavender
        }
    }

    private func openQuest(index: Int) {
        let section: AppSection = switch index {
        case 0: .focus
        case 1: .tasks
        default: .habits
        }
        NotificationCenter.default.post(name: .cozyOpenSection, object: section.rawValue)
    }
}

struct QuestPill: View {
    let title: String
    let reward: String
    let symbol: String
    let isDone: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isDone ? "checkmark.seal.fill" : symbol)
                    .font(.title3.weight(.bold))
                    .frame(width: 24)
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                    Text(isDone ? "done" : reward)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isDone ? "checkmark" : "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accent.opacity(isDone ? 0.14 : 0.09))
            )
        }
        .cozyPressable()
        .accessibilityIdentifier("dailyQuest.item")
    }
}

struct TaskList: View {
    @EnvironmentObject private var dataStore: AppDataStore
    let tasks: [TaskItem]

    var body: some View {
        if tasks.isEmpty {
            VStack(spacing: 12) {
                EmptyStateView(title: "Nothing here yet", message: "Capture one small next step.", mascotState: .idle)
                    .frame(minHeight: 180)
                StarterTaskChips()
            }
        } else {
            LazyVStack(spacing: 10) {
                ForEach(tasks) { task in
                    TaskRow(task: task)
                }
            }
        }
    }
}

struct StarterTaskChips: View {
    @EnvironmentObject private var dataStore: AppDataStore

    private let starters: [(String, Int, String)] = [
        ("Study 25m", 25, "book.closed.fill"),
        ("Clean desk", 10, "sparkles"),
        ("Reply to one message", 5, "paperplane.fill")
    ]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                starterButtons
            }
            VStack(alignment: .leading, spacing: 8) {
                starterButtons
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("task.starterChips")
    }

    @ViewBuilder
    private var starterButtons: some View {
        ForEach(starters, id: \.0) { title, minutes, symbol in
            Button {
                dataStore.addTask(TaskItem(title: title, dueDate: Date(), priority: 1, estimatedMinutes: minutes))
                CozyFeedback.play(.add)
            } label: {
                Label(title, systemImage: symbol)
                    .lineLimit(1)
            }
            .cozySecondaryButton(minWidth: 118)
        }
    }
}

private struct TaskMetadataItem: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String
}

struct TaskRow: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var timerStore: FocusTimerStore
    @EnvironmentObject private var notifications: NotificationService
    @Environment(\.colorScheme) private var colorScheme
    let task: TaskItem
    @State private var lastCompletionAction: Bool?
    @State private var isEditing = false
    @State private var isConfirmingDelete = false
    @State private var editTitle = ""
    @State private var editMinutes = 25

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    toggleCompletion()
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .frame(width: CozyLayout.hitSize, height: CozyLayout.hitSize)
                }
                .buttonStyle(.plain)
                .cozyPressable(pressedScale: 0.90, hoverScale: 1.08)
                .contentShape(Circle())
                .foregroundStyle(task.isCompleted ? CozyPalette.focusJade : .secondary)
                .help(task.isCompleted ? "Mark incomplete" : "Complete task")
                .accessibilityLabel(task.isCompleted ? "Mark \(task.title) incomplete" : "Complete \(task.title)")
                .accessibilityIdentifier("task.complete")

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(task.title)
                            .font(.headline)
                            .lineLimit(2)
                            .layoutPriority(1)
                            .strikethrough(task.isCompleted)
                        PriorityBadge(priority: task.priority)
                            .fixedSize()
                        Spacer()
                    }
                    if !task.notes.isEmpty {
                        Text(task.notes)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    metadataGrid
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .layoutPriority(1)

                VStack(alignment: .trailing, spacing: 8) {
                    Button {
                        guard timerStore.canStartNewSession else { return }
                        UserDefaults.standard.set(FocusBoost.default.id, forKey: "focus.activeBoostID")
                        timerStore.start(taskTitle: task.title, taskID: task.id, duration: TimeInterval(task.estimatedMinutes * 60))
                        scheduleFocusCompletion()
                    } label: {
                        Label("Focus", systemImage: "play.fill")
                            .frame(width: 76)
                    }
                    .cozySecondaryButton(minWidth: 96)
                    .disabled(task.isCompleted || !timerStore.canStartNewSession)
                    .help(task.isCompleted ? "Task is already complete" : timerStore.canStartNewSession ? "Start a focus session for this task" : "A timer is already active")
                    .accessibilityIdentifier("task.focus")
                    .fixedSize()

                    HStack(spacing: 8) {
                        Button {
                            beginEditing()
                        } label: {
                            Image(systemName: "pencil")
                                .frame(width: 18, height: 18)
                        }
                        .cozyIconButton(size: CozyLayout.compactHitSize)
                        .help("Edit task")
                        .accessibilityLabel("Edit \(task.title)")

                        Button(role: .destructive) {
                            withAnimation(.snappy(duration: 0.18)) {
                                isConfirmingDelete.toggle()
                                isEditing = false
                            }
                        } label: {
                            Image(systemName: "trash")
                                .frame(width: 18, height: 18)
                        }
                        .cozyIconButton(size: CozyLayout.compactHitSize)
                        .help("Delete task")
                        .accessibilityLabel("Delete \(task.title)")
                    }
                }
            }
            if isEditing {
                editPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if isConfirmingDelete {
                deletePanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if let lastCompletionAction {
                completionFeedback(wasCompleted: lastCompletionAction)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .cozyCard()
        .accessibilityIdentifier("task.row")
    }

    private var editPanel: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: CozyLayout.formRowSpacing) {
                editTitleField
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(alignment: .top, spacing: CozyLayout.formRowSpacing) {
                    editEstimateField
                    editActions
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: CozyLayout.formRowSpacing) {
                editTitleField
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(alignment: .top, spacing: CozyLayout.formRowSpacing) {
                    editEstimateField
                    editActions
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(CozyPalette.quietContainer(colorScheme))
        )
    }

    private var editTitleField: some View {
        CozyLabeledControl(title: "Edit task", symbolName: "pencil", minWidth: 220) {
            VStack(alignment: .leading, spacing: 6) {
                TextField("Task title", text: $editTitle)
                    .cozyTextInput(minWidth: 220, alignment: .leading)
                if cleanEditTitle.isEmpty {
                    CozyFieldHint(text: "Task title cannot be empty.", isError: true)
                }
            }
        }
    }

    private var editEstimateField: some View {
        CozyLabeledControl(title: "Estimate", symbolName: "timer") {
            CozyStepperField(value: $editMinutes, range: 5...180, step: 5) { "\($0)m" }
        }
    }

    private var editActions: some View {
        CozyLabeledControl(title: "Action", symbolName: "checkmark.circle", minWidth: 174) {
            HStack(spacing: 8) {
                Button("Cancel") {
                    withAnimation(.snappy(duration: 0.18)) {
                        isEditing = false
                    }
                }
                .cozyGhostButton(minWidth: 70)

                Button("Save") {
                    saveEdit()
                }
                .cozyPrimaryButton(minWidth: 82)
                .disabled(cleanEditTitle.isEmpty)
            }
        }
    }

    private var deletePanel: some View {
        HStack(spacing: 10) {
            Label("Delete this task?", systemImage: "exclamationmark.triangle.fill")
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
                dataStore.deleteTask(id: task.id)
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
    }

    private func toggleCompletion() {
        let willComplete = !task.isCompleted
        withAnimation(.snappy(duration: 0.18)) {
            dataStore.toggleTaskCompletion(id: task.id)
            lastCompletionAction = willComplete
        }
        CozyFeedback.play(willComplete ? .complete : .undo)
    }

    private func undoCompletionAction() {
        withAnimation(.snappy(duration: 0.18)) {
            dataStore.toggleTaskCompletion(id: task.id)
            lastCompletionAction = nil
        }
        CozyFeedback.play(.undo)
    }

    private func beginEditing() {
        editTitle = task.title
        editMinutes = task.estimatedMinutes
        withAnimation(.snappy(duration: 0.18)) {
            isEditing = true
            isConfirmingDelete = false
        }
    }

    private var cleanEditTitle: String {
        editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveEdit() {
        guard !cleanEditTitle.isEmpty else { return }
        var updated = task
        updated.title = cleanEditTitle
        updated.estimatedMinutes = editMinutes
        dataStore.updateTask(updated)
        withAnimation(.snappy(duration: 0.18)) {
            isEditing = false
        }
        CozyFeedback.play(.add)
    }

    private func completionFeedback(wasCompleted: Bool) -> some View {
        HStack(spacing: 8) {
            Label(wasCompleted ? "Nice finish logged" : "Moved back to active", systemImage: wasCompleted ? "sparkles" : "arrow.uturn.backward")
                .lineLimit(1)
            Spacer()
            Button("Undo") {
                undoCompletionAction()
            }
            .cozyGhostButton(minWidth: 64)
        }
        .font(.caption.weight(.semibold))
        .padding(.leading, 32)
        .foregroundStyle(wasCompleted ? CozyPalette.focusJade : .secondary)
        .accessibilityIdentifier("task.feedback")
    }

    private var metadataGrid: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                metadataLabels
            }
            LazyVGrid(columns: CozyLayout.adaptiveColumns(minimum: 92), alignment: .leading, spacing: 6) {
                metadataLabels
            }
        }
    }

    @ViewBuilder
    private var metadataLabels: some View {
        ForEach(metadataItems) { item in
            Label(item.title, systemImage: item.symbol)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(CozyPalette.quietContainer(colorScheme).opacity(0.72))
                )
        }
    }

    private var metadataItems: [TaskMetadataItem] {
        var items = [TaskMetadataItem(title: task.listName, symbol: "folder")]
        if let dueDate = task.dueDate {
            items.append(TaskMetadataItem(title: CozyFormatters.shortDate.string(from: dueDate), symbol: "calendar"))
        }
        items.append(TaskMetadataItem(title: "\(task.estimatedMinutes)m", symbol: "timer"))
        if !task.tagText.isEmpty {
            items.append(TaskMetadataItem(title: task.tagText, symbol: "tag"))
        }
        return items
    }

    private func scheduleFocusCompletion() {
        guard let startDate = timerStore.snapshot.startDate else { return }
        let draft = NotificationPlanner.focusCompletion(
            sessionID: UUID(),
            taskTitle: timerStore.activeTaskTitle,
            startDate: startDate,
            duration: timerStore.snapshot.duration,
            accumulatedPause: timerStore.snapshot.accumulatedPause
        )
        Task {
            await notifications.cancelFocusNotifications()
            await notifications.schedule(draft)
        }
    }
}

struct PriorityBadge: View {
    let priority: Int

    var body: some View {
        let label = switch priority {
        case 2...: "Top"
        case 1: "Med"
        default: "Low"
        }
        let color = switch priority {
        case 2...: CozyPalette.overdue
        case 1: CozyPalette.persimmon
        default: CozyPalette.focusJade
        }

        Text(label)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }
}
