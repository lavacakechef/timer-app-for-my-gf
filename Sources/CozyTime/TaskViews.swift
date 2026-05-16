import CozyCore
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var timerStore: FocusTimerStore
    // Mascot name personalization (Apple HIG: "Personalize content with the
    // user's name and preferences where possible"). Today subtitle previously
    // hard-coded "Mochi" so renaming the mascot in Settings (e.g. "Pepper")
    // failed to propagate here even though Focus subtitle did.
    @AppStorage("mascotName") private var mascotName = "Mochi"

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
                    subtitle: "Pick one tiny step, earn paws, and let \(mascotName) grow with you.",
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
                    .font(CozyType.cardTitle)
                if todayTasks.isEmpty {
                    // Hero card above already owns the focus path. Empty Today CTA stays
                    // on Today and offers adding a task — don't bounce her elsewhere.
                    EmptyStateView(
                        title: "Today is open",
                        message: "Add one tiny task, or use the hero card above to start a focus session.",
                        mascotState: .idle,
                        eyebrow: "Today",
                        primaryActionTitle: "Open Tasks",
                        primaryAction: {
                            NotificationCenter.default.post(name: .cozyOpenSection, object: AppSection.tasks.rawValue)
                        }
                    )
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

// Time filter for the Tasks screen — replaces the old standalone Upcoming
// section. "All" is the default; "Upcoming" is what the redirected legacy
// .upcoming sidebar route lands on; "Today" / "Done" are extra utility filters.
enum TaskTimeFilter: String, CaseIterable, Identifiable {
    case all, today, upcoming, done
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: "All"
        case .today: "Today"
        case .upcoming: "Upcoming"
        case .done: "Done"
        }
    }
}

struct TasksView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @State private var listFilter = "All"
    @State private var timeFilter: TaskTimeFilter

    // Optional initial filter set by the router (Upcoming legacy route opens
    // Tasks with timeFilter pre-set to .upcoming).
    init(initialTimeFilter: TaskTimeFilter = .all) {
        _timeFilter = State(initialValue: initialTimeFilter)
    }

    private var listNames: [String] {
        ["All"] + Array(Set(dataStore.tasks.map(\.listName))).sorted()
    }

    private var filteredTasks: [TaskItem] {
        dataStore.tasks
            .filter { listFilter == "All" || $0.listName == listFilter }
            .filter(timeMatches)
            .sorted { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
                return TaskFilters.sortByPriorityThenDueDate(lhs.filterRecord, rhs.filterRecord)
            }
    }

    private func timeMatches(_ task: TaskItem) -> Bool {
        switch timeFilter {
        case .all:
            return true
        case .today:
            guard let due = task.dueDate else { return false }
            return Calendar.autoupdatingCurrent.isDateInToday(due) && !task.isCompleted
        case .upcoming:
            return !task.isCompleted && CozyCalendar.isUpcoming(task.dueDate)
        case .done:
            return task.isCompleted
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CozyLayout.sectionSpacing) {
                SectionHeader(title: "Tasks", subtitle: "Lists, tags, priorities, and soft deadlines.", mascotState: .idle)
                QuickAddBar(defaultDueDate: timeFilter == .upcoming
                    ? Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: Date())
                    : nil)
                // Time filter — All / Today / Upcoming / Done. Sits above the
                // list-name filter so the user can stack "Today + Inbox", etc.
                CozySegmentedControl(
                    options: TaskTimeFilter.allCases.map { CozySegmentOption($0.rawValue, title: $0.label) },
                    selection: Binding(
                        get: { timeFilter.rawValue },
                        set: { timeFilter = TaskTimeFilter(rawValue: $0) ?? .all }
                    ),
                    minSegmentWidth: 88
                )
                .accessibilityIdentifier("tasks.timeFilter")
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let defaultDueDate: Date?

    @State private var title = ""
    @State private var listName = "Inbox"
    @State private var priority = 1
    @State private var estimatedMinutes = 25
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var isExpanded = false
    @State private var lastAddedTask: TaskItem?
    /// When the user wants to create a new list, this becomes the active draft and
    /// the picker is replaced with an inline text field.
    @State private var isCreatingNewList = false
    @State private var newListDraft = ""

    /// Existing lists deduplicated + sorted, with "Inbox" pinned first.
    private var existingLists: [String] {
        var set = Set(dataStore.tasks.map(\.listName))
        set.insert("Inbox")
        let others = set.subtracting(["Inbox"]).sorted()
        return ["Inbox"] + others
    }

    init(defaultDueDate: Date?) {
        self.defaultDueDate = defaultDueDate
        _dueDate = State(initialValue: defaultDueDate ?? Date())
        _hasDueDate = State(initialValue: defaultDueDate != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CozyLayout.formRowSpacing) {
            CozyResponsiveFormRow {
                titleField
            } trailing: {
                detailsButton
                addButton
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: CozyLayout.formRowSpacing) {
                    CozyResponsiveFieldRow {
                        listField
                        dueDateField
                        durationStepper
                        priorityPicker
                    }

                    if hasDueDate {
                        dueDateQuickChoicesRow
                            .accessibilityIdentifier("quickAdd.dueDate.quickPicks")
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
        .animation(CozyMotion.snappy(reduceMotion, duration: 0.18), value: isExpanded)
    }

    private var titleField: some View {
        CozyLabeledControl(
            title: "Task",
            symbolName: "checklist",
            minWidth: 220,
            hint: cleanTitle.isEmpty ? "Type a task title to add it." : nil
        ) {
            TextField("Add a tiny task...", text: $title)
                .onSubmit(addTask)
                .accessibilityIdentifier("quickAdd.title")
                .cozyTextInput(minWidth: 220, alignment: .leading)
        }
        .layoutPriority(1)
    }

    private var detailsButton: some View {
        CozyLabeledControl(title: "Options", symbolName: "slider.horizontal.3", minWidth: 104) {
            Button {
                isExpanded.toggle()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .frame(width: 24, height: 24)
            }
            .cozyIconButton(size: CozyLayout.hitSize)
            .help(isExpanded ? "Hide task details" : "Show task details")
            .accessibilityLabel(isExpanded ? "Hide task details" : "Show task details")
            .accessibilityIdentifier("quickAdd.details")
        }
    }

    private var listField: some View {
        CozyLabeledControl(title: "List", symbolName: "tray.full") {
            // Picker over existing lists + "+ New list" option that switches to a TextField.
            // The user explicitly asked for a dropdown when picking an existing list, with
            // typing reserved for new-list creation. (Free-typing the same name every time
            // led to mis-spelled duplicates like "inbox" vs "Inbox".)
            if isCreatingNewList {
                HStack(spacing: 6) {
                    TextField("New list name", text: $newListDraft)
                        .accessibilityIdentifier("quickAdd.newList")
                        .cozyTextInput(width: 140, alignment: .leading)
                        .onSubmit { commitNewList() }
                    Button {
                        commitNewList()
                    } label: {
                        Image(systemName: "checkmark")
                            .frame(width: 16, height: 16)
                    }
                    .cozyIconButton(size: CozyLayout.compactHitSize)
                    .disabled(newListDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("Save new list")
                    Button {
                        isCreatingNewList = false
                        newListDraft = ""
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 16, height: 16)
                    }
                    .cozyIconButton(size: CozyLayout.compactHitSize)
                    .help("Cancel")
                }
            } else {
                // Visually-obvious dropdown affordance — gf's screenshot showed the
                // earlier version reading as a text field because the chevron was
                // caption-weight and tiny. Now: leading tray icon, bold body-weight
                // list name, and a prominent up/down chevron pair that says
                // "this is a Menu, click it." Native `.menuIndicator(.visible)` so
                // SwiftUI's own indicator backs up the custom chevron.
                Menu {
                    ForEach(existingLists, id: \.self) { name in
                        Button {
                            listName = name
                        } label: {
                            if name == listName {
                                Label(name, systemImage: "checkmark")
                            } else {
                                Text(name)
                            }
                        }
                    }
                    Divider()
                    Button {
                        newListDraft = ""
                        isCreatingNewList = true
                    } label: {
                        Label("New list…", systemImage: "plus")
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "tray.full.fill")
                            .font(CozyType.body.weight(.semibold))
                            .foregroundStyle(CozyPalette.focusJade)
                        Text(listName)
                            .font(CozyType.body.weight(.semibold))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(CozyPalette.focusJade)
                    }
                    .frame(minWidth: 150, minHeight: CozyLayout.controlHeight, alignment: .leading)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .cozyControlShell(minWidth: 150, alignment: .leading)
                .accessibilityIdentifier("quickAdd.list")
                .help(existingLists.count > 1
                    ? "Pick from \(existingLists.count) lists or add a new one"
                    : "Pick a list or create a new one")
            }
        }
    }

    private func commitNewList() {
        let trimmed = newListDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        listName = String(trimmed.prefix(40))
        newListDraft = ""
        isCreatingNewList = false
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
                    CozyDateInput(date: $dueDate, label: "Task due date", includeInlineQuickChoices: false)
                        .accessibilityIdentifier("quickAdd.dueDate")
                }
            }
        }
    }

    private var dueDateQuickChoicesRow: some View {
        CozyDateInput(date: $dueDate, label: "Task due date", includeInlineQuickChoices: false).quickChoicesRow
    }

    private var durationStepper: some View {
        CozyLabeledControl(title: "Estimate", symbolName: "clock") {
            CozyStepperField(value: $estimatedMinutes, range: 5...180, step: 5) { "\($0)m" }
                .accessibilityIdentifier("quickAdd.duration")
        }
    }

    private var priorityPicker: some View {
        CozyLabeledControl(title: "Priority", symbolName: "flag") {
            // Segment labels now match PriorityBadge's mapping
            // (0 = Low, 1 = Medium, 2 = High). Previously the segment said
            // "Top" for value 2 while the resulting badge displayed "High" —
            // the same priority shown under two different names depending on
            // which surface you looked at.
            CozySegmentedControl(
                options: [
                    CozySegmentOption(0, title: "Low"),
                    CozySegmentOption(1, title: "Med"),
                    CozySegmentOption(2, title: "High")
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
        // Keep labels consistent with `PriorityBadge` (TaskViews.swift) which renders the
        // same priority on each task row. Mixed "Top/Med/Low" footer + "Urgent/High/Medium/Low"
        // badge above looked unintentional.
        switch priority {
        case 3...: "Urgent"
        case 2: "High"
        case 1: "Medium"
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    @AppStorage("mascotName") private var mascotName = "Mochi"

    @State private var starterTitle = "First tiny session"
    @State private var messageIndex = 0
    @State private var petPulse = false
    /// Selected preset duration in minutes. Tapping a chip below SELECTS (highlight) — the
    /// user then taps the explicit "Start" CTA to actually begin. Previously chips silently
    /// started a session, which was the strongest visible affordance on cold-open committing
    /// the user to a 25-minute commitment without warning.
    @State private var selectedMinutes: Int = 25

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
            "Click \(mascotName) for a tiny mood boost.",
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

            VStack(alignment: .leading, spacing: 16) {
                heroMascotPanel
                heroActionPanel
            }
        }
        .cozyHeroCard()
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
            withAnimation(CozyMotion.spring(reduceMotion, response: 0.28, damping: 0.62)) {
                petPulse.toggle()
                messageIndex += 1
            }
        } label: {
            EquippedMascotView(state: timerStore.isActive ? activeMascotState : .idle, size: .hero, rewards: dataStore.rewards)
                .scaleEffect(petPulse ? 1.06 : 1.0)
        }
        .cozyPressable(pressedScale: 0.94, hoverScale: 1.035)
        .contentShape(Circle())
        .help("Pet \(mascotName)")
        .accessibilityLabel("Pet \(mascotName)")
    }

    private var heroActionPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(timerStore.isActive ? "Now focusing" : "Start a cozy block")
                    .font(CozyType.heroCardTitle)
                    .lineLimit(2)
                Text(timerStore.isActive ? "\(mascotName) is keeping the room quiet." : heroMessage)
                    .font(CozyType.body)
                    .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                    .lineLimit(2)
            }

            startControls

            LazyVGrid(columns: metricColumns, spacing: 10) {
                SoftMetricBadge(title: "focus today", value: "\(focusMinutesToday)m", symbol: "timer", color: CozyPalette.focusJade)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SoftMetricBadge(title: mascotName, value: "Lv. \(dataStore.progression.level)", symbol: "pawprint.fill", color: theme.reward)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SoftMetricBadge(title: "paws", value: "\(dataStore.progression.coinsAvailable)", symbol: "sparkles", color: CozyPalette.habitLavender)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            NextUnlockView(database: dataStore.database)
        }
        // Cap horizontal stretch so the action column doesn't run wider than
        // the mascot panel beside it on big windows (visual disconnection).
        .frame(maxWidth: 560, alignment: .leading)
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
        VStack(alignment: .leading, spacing: 12) {
            // CozyDurationPicker: shared chip + slider widget. Same recipe used by
            // FocusSetupCard so duration-picking is one component, not two.
            CozyDurationPicker(
                minutes: $selectedMinutes,
                accent: CozyPalette.focusJade,
                identifierPrefix: "firstSession"
            )

            // Explicit Start CTA so the chips above SELECT only; tapping a chip alone never
            // commits to a session.
            Button {
                start(minutes: selectedMinutes)
            } label: {
                Label("Start \(CozyFormatters.durationLabel(TimeInterval(selectedMinutes * 60))) focus", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .cozyPrimaryButton(fullWidth: true)
            .disabled(!timerStore.canStartNewSession)
            .help(timerStore.canStartNewSession ? "Start a focus session at the selected length" : "A timer is already active")
            .accessibilityIdentifier("firstSession.start")
        }
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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
        VStack(alignment: .leading, spacing: 16) {
            // Header is itself a navigation button → opens Stats. Previously only
            // the three individual quest pills below were clickable, so users
            // tapping the title or the % readout went nowhere ("progress doesn't
            // open" feedback).
            Button {
                NotificationCenter.default.post(name: .cozyOpenSection, object: AppSection.stats.rawValue)
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today’s cozy quests")
                            .font(CozyType.cardTitle)
                        Text("\(completedCount) of \(quests.count) done. Any one of these counts today.")
                            .font(CozyType.body)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(Int(Double(completedCount) / Double(quests.count) * 100))%")
                        .font(CozyType.metricSmall)
                        .foregroundStyle(CozyPalette.berry)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .cozyPressable()
            .accessibilityIdentifier("dailyQuest.openStats")
            .help("Open Stats for the full progress picture")

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
                    .font(CozyType.cardTitle)
                    .frame(width: 24)
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(CozyType.body.weight(.semibold))
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
                RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
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
                EmptyStateView(
                    title: "A spot for your first task",
                    message: "Capture one small next step — anything that nudges the day forward.",
                    mascotState: .idle,
                    eyebrow: "Tasks"
                )
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                        .font(CozyType.cardTitle)
                        .frame(width: 28, height: 28)
                }
                .cozyPressable(pressedScale: 0.90, hoverScale: 1.08)
                .contentShape(Rectangle())
                .foregroundStyle(task.isCompleted ? CozyPalette.focusJade : .secondary)
                .help(task.isCompleted ? "Mark incomplete" : "Complete task")
                .accessibilityLabel(task.isCompleted ? "Mark \(task.title) incomplete" : "Complete \(task.title)")
                .accessibilityIdentifier("task.complete")
                .padding(.top, 2)
                .alignmentGuide(.top) { dimension in dimension[.top] }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(task.title)
                            .font(CozyType.rowTitle)
                            .lineLimit(2)
                            .layoutPriority(1)
                            .strikethrough(task.isCompleted)
                        PriorityBadge(priority: task.priority)
                            .fixedSize()
                        Spacer()
                    }
                    if !task.notes.isEmpty {
                        Text(task.notes)
                            .font(CozyType.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    metadataGrid
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .layoutPriority(1)
                .frame(maxHeight: .infinity, alignment: .top)

                // Focus + edit + delete share one horizontal baseline so the
                // three controls read as a single action row rather than a
                // tall primary button with floating icons beneath it.
                HStack(spacing: 8) {
                    Button {
                        beginEditing()
                    } label: {
                        Image(systemName: "pencil")
                            .frame(width: 20, height: 20)
                    }
                    .cozyIconButton(size: CozyLayout.compactHitSize)
                    .help("Edit task")
                    .accessibilityLabel("Edit \(task.title)")

                    Button(role: .destructive) {
                        withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
                            isConfirmingDelete.toggle()
                            isEditing = false
                        }
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 20, height: 20)
                    }
                    .cozyIconButton(size: CozyLayout.compactHitSize)
                    .help("Delete task")
                    .accessibilityLabel("Delete \(task.title)")

                    Button {
                        guard timerStore.canStartNewSession else { return }
                        UserDefaults.standard.set(FocusBoost.default.id, forKey: "focus.activeBoostID")
                        timerStore.start(taskTitle: task.title, taskID: task.id, duration: TimeInterval(task.estimatedMinutes * 60))
                        scheduleFocusCompletion()
                        NotificationCenter.default.post(name: .cozyOpenSection, object: AppSection.focus.rawValue)
                    } label: {
                        Label("Focus", systemImage: "play.fill")
                            .frame(width: 76)
                    }
                    .cozySecondaryButton(minWidth: 96)
                    .disabled(task.isCompleted || !timerStore.canStartNewSession)
                    .help(task.isCompleted ? "Task is already complete" : timerStore.canStartNewSession ? "Start a focus session for this task" : "A timer is already active")
                    .accessibilityIdentifier("task.focus")
                    .fixedSize()
                }
                .frame(maxHeight: .infinity, alignment: .top)
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
        CozyResponsiveFormRow {
            editTitleField
        } trailing: {
            editEstimateField
            editActions
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
                // Width parity with the Keep/Delete pair in deletePanel and the
                // confirm rows in HabitStatsViews / CountdownViews (76/76).
                // Apple HIG buttons: "When you display two buttons side by side,
                // give them matching widths." Was: 70/82 (12pt drift).
                Button("Cancel") {
                    withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
                        isEditing = false
                    }
                }
                .cozyGhostButton(minWidth: 76)

                Button("Save") {
                    saveEdit()
                }
                .cozyPrimaryButton(minWidth: 76)
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
            // Width parity per HIG sibling-button rule. Was 64/76 (12pt drift).
            Button("Keep") {
                withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
                    isConfirmingDelete = false
                }
            }
            .cozyGhostButton(minWidth: 76)
            Button(role: .destructive) {
                dataStore.deleteTask(id: task.id)
                CozyFeedback.play(.delete)
            } label: {
                Text("Delete")
            }
            .cozyDestructiveButton(minWidth: 76)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(CozyPalette.overdue.opacity(0.08))
        )
    }

    private func toggleCompletion() {
        let willComplete = !task.isCompleted
        withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
            dataStore.toggleTaskCompletion(id: task.id)
            lastCompletionAction = willComplete
        }
        CozyFeedback.play(willComplete ? .complete : .undo)
    }

    private func undoCompletionAction() {
        withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
            dataStore.toggleTaskCompletion(id: task.id)
            lastCompletionAction = nil
        }
        CozyFeedback.play(.undo)
    }

    private func beginEditing() {
        editTitle = task.title
        editMinutes = task.estimatedMinutes
        withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
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
        withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
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
                .padding(.vertical, 4)
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
    @Environment(\.colorScheme) private var colorScheme
    let priority: Int

    // Labels follow Linear / Asana convention (Urgent / High / Medium / Low) instead of
    // the ambiguous "Top" / "Med" shorthand. SF Symbol prefix gives a glanceable severity
    // cue at chip size. Colors map to severity semantics:
    //   3+ = Urgent → overdue (warm red-brown, "act now")
    //   2  = High   → persimmon (orange, "soon")
    //   1  = Medium → wasabi text-safe (warm yellow-green, "steady")
    //   0  = Low    → muted secondary (no urgency / no badge)
    private var priorityLabel: String {
        switch priority {
        case 3...: "Urgent"
        case 2: "High"
        case 1: "Medium"
        default: "Low"
        }
    }

    private var priorityIcon: String {
        switch priority {
        case 3...: "exclamationmark.triangle.fill"
        case 2: "exclamationmark.circle.fill"
        case 1: "circle.fill"
        default: "circle"
        }
    }

    private var priorityColor: Color {
        switch priority {
        case 3...: CozyPalette.overdue
        case 2: CozyPalette.persimmon
        case 1: CozyPalette.wasabiText
        default: CozyPalette.secondaryText(colorScheme)
        }
    }

    var body: some View {
        CozyPill(
            title: priorityLabel,
            symbolName: priorityIcon,
            intent: .accent(priorityColor),
            size: .small
        )
        .accessibilityLabel("Priority: \(priorityLabel)")
    }
}
