import CozyCore
import SwiftUI
import AppKit

struct FocusView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var timerStore: FocusTimerStore
    @EnvironmentObject private var notifications: NotificationService
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    @AppStorage("mascotName") private var mascotName = "Mochi"
    @AppStorage("selectedTimerSkin") private var selectedTimerSkin = CozyTimerSkin.defaultID
    @AppStorage("selectedTimerShape") private var selectedTimerShape = CozyTimerShape.ring.rawValue
    @AppStorage("showMotivationQuotes") private var showMotivationQuotes = true
    @AppStorage("quoteStyle") private var quoteStyle = CozyQuoteStyle.cozy.rawValue

    @State private var selectedTaskID: UUID?
    @State private var customMinutes = 25
    @State private var reflection = ""
    @State private var pendingBoostID = FocusBoost.default.id
    @State private var completionSummary: FocusCompletionSummary?
    @State private var setupRollsUsed = 0
    @AppStorage("focus.activeBoostID") private var activeBoostID = ""

    private var incompleteTasks: [TaskItem] {
        dataStore.tasks.filter { !$0.isCompleted }
    }

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    private var selectedTask: TaskItem? {
        guard let selectedTaskID else { return nil }
        return incompleteTasks.first { $0.id == selectedTaskID }
    }

    private var selectedTaskTitle: String {
        selectedTask?.title ?? "Quick focus"
    }

    private var pendingBoost: FocusBoost {
        FocusBoost.named(pendingBoostID)
    }

    private var activeBoost: FocusBoost {
        FocusBoost.named(activeBoostID)
    }

    private var canRollSetupBoost: Bool {
        timerStore.canStartNewSession && setupRollsUsed == 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CozyLayout.sectionSpacing) {
                SectionHeader(
                    title: "Focus",
                    subtitle: timerStore.isActive ? "\(mascotName) is keeping time." : "One task, one clock, one soft win.",
                    mascotState: timerStore.isActive ? mascotState(for: timerStore.phase(at: timerStore.currentDate)) : .idle
                )
                if let completionSummary {
                    completionReview(for: completionSummary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: CozyLayout.gridSpacing) {
                        timerPanel
                            .frame(maxWidth: 600)
                        focusSideColumn
                            .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)
                    }
                    VStack(alignment: .leading, spacing: CozyLayout.gridSpacing) {
                        timerPanel
                        focusSideColumn
                    }
                }
            }
            .cozyPageFrame()
        }
        .onAppear {
            selectFirstTaskIfNeeded()
        }
        .onChange(of: dataStore.tasks) {
            selectFirstTaskIfNeeded()
        }
        .accessibilityIdentifier("screen.focus")
    }

    private var timerPanel: some View {
        TimelineView(.periodic(from: .now, by: timerStore.isActive ? 1 : 60)) { context in
            let remaining = timerStore.remaining(at: context.date)
            let progress = timerStore.progress(at: context.date)
            let phase = timerStore.phase(at: context.date)
            let accent = timerAccent(for: phase)
            let shape = CozyTimerShape(rawValue: selectedTimerShape) ?? .ring
            let elapsedMinute = Int(max(0, (timerStore.snapshot.duration - remaining) / 60))

            VStack(spacing: 14) {
                FocusPhaseHeader(phase: phase, boost: activeBoostID.isEmpty ? nil : activeBoost)
                MascotView(state: mascotState(for: phase), size: 100)
                CozyTimerChrome(progress: progress, color: accent, skin: timerSkin, shape: shape)
                    .frame(width: 206, height: 206)
                    .overlay {
                        VStack(spacing: 6) {
                            Text(CozyFormatters.timerString(remaining))
                                .font(CozyType.timer)
                                .monospacedDigit()
                            Text((timerStore.isActive || timerStore.needsCompletionReview) ? timerStore.activeTaskTitle : "Ready")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .padding()
                    }
                    .overlay(alignment: .top) {
                        FocusMilestoneBeads(progress: progress, color: accent)
                            .offset(y: -14)
                    }

                ViewThatFits(in: .horizontal) {
                    timerControls
                    VStack(spacing: 8) {
                        timerControls
                    }
                }

                if showMotivationQuotes {
                    MotivationQuotePill(
                        quote: quotePreference.quote(for: phase, minute: elapsedMinute),
                        color: accent
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .cozyCard()
            .onChange(of: Int(context.date.timeIntervalSince1970)) {
                timerStore.refreshCompletion(at: context.date)
            }
        }
    }

    private var focusSideColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            if timerStore.isActive {
                FocusRunningCompanionCard(phase: timerStore.phase(at: timerStore.currentDate), boost: activeBoost)
            } else {
                FocusSetupCard(
                    selectedTaskID: $selectedTaskID,
                    customMinutes: $customMinutes,
                    incompleteTasks: incompleteTasks,
                    pendingBoost: pendingBoost,
                    canRoll: canRollSetupBoost,
                    rollCount: setupRollsUsed,
                    onRoll: rollBoost,
                    onStart: startFocus
                )
                FocusRewardPreview(durationMinutes: customMinutes, boost: pendingBoost)
            }
        }
    }

    private func completionReview(for summary: FocusCompletionSummary) -> some View {
        FocusCompletionReview(summary: summary, reflection: $reflection) {
            saveReflectionIfNeeded(for: summary)
            completionSummary = nil
            reflection = ""
        } startAnother: {
            saveReflectionIfNeeded(for: summary)
            completionSummary = nil
            reflection = ""
            customMinutes = 5
            startFocus()
        } openRewards: {
            saveReflectionIfNeeded(for: summary)
            NotificationCenter.default.post(name: .cozyOpenSection, object: AppSection.rewards.rawValue)
        }
        .onDisappear {
            saveReflectionIfNeeded(for: summary)
        }
    }

    private var timerControls: some View {
        HStack(spacing: 10) {
            if timerStore.needsCompletionReview {
                Button {
                    completeFocus()
                } label: {
                    Label("Save session", systemImage: "checkmark.seal.fill")
                }
                .cozyPrimaryButton(minWidth: 132)
                .accessibilityIdentifier("focus.claimReward")
            } else if timerStore.isRunning {
                Button {
                    pauseFocus()
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .cozyPrimaryButton(minWidth: 112)
                .accessibilityIdentifier("focus.pause")
            } else if timerStore.isPaused {
                Button {
                    resumeFocus()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                }
                .cozyPrimaryButton(minWidth: 112)
                .accessibilityIdentifier("focus.resume")
            } else {
                Button {
                    startFocus()
                } label: {
                    Label("Start Focus", systemImage: "play.fill")
                }
                .cozyPrimaryButton(minWidth: 132)
                .disabled(!timerStore.canStartNewSession)
                .accessibilityIdentifier("focus.timer.start")
            }

            if !timerStore.needsCompletionReview {
                Button {
                    completeFocus()
                } label: {
                    Label(wrapButtonTitle, systemImage: "checkmark.seal.fill")
                }
                .cozySecondaryButton(minWidth: 128)
                .disabled(!timerStore.isActive && timerStore.snapshot.state != .completed)
                .accessibilityIdentifier("focus.complete")
            }

            Button {
                stopFocus()
            } label: {
                Label("End gently", systemImage: "hand.raised.fill")
            }
            .cozySecondaryButton(minWidth: 118)
            .disabled(!timerStore.isActive)
            .accessibilityIdentifier("focus.stop")
        }
    }

    private var wrapButtonTitle: String {
        guard timerStore.isActive else { return "Complete" }
        return FocusRewardResolver.isRewardEligible(snapshot: timerStore.snapshot, at: timerStore.currentDate)
            ? "Wrap and save"
            : "Save partial"
    }

    private func startFocus() {
        guard timerStore.canStartNewSession else { return }
        activeBoostID = pendingBoostID
        completionSummary = nil
        timerStore.start(taskTitle: selectedTaskTitle, taskID: selectedTask?.id, duration: TimeInterval(customMinutes * 60))
        scheduleFocusCompletion()
    }

    private func pauseFocus() {
        timerStore.pause()
        Task { await notifications.cancelFocusNotifications() }
    }

    private func resumeFocus() {
        timerStore.resume()
        scheduleFocusCompletion()
    }

    private func stopFocus() {
        timerStore.cancel()
        setupRollsUsed = 0
        Task { await notifications.cancelFocusNotifications() }
    }

    private func completeFocus() {
        guard timerStore.isActive || timerStore.needsCompletionReview else { return }
        let now = Date()
        let boost = activeBoostID.isEmpty ? pendingBoost : activeBoost
        let reward = FocusRewardResolver.resolve(
            snapshot: timerStore.snapshot,
            taskTitle: timerStore.activeTaskTitle,
            boost: boost,
            existingRewards: dataStore.rewards,
            now: now
        )
        timerStore.complete(at: now)
        Task { await notifications.cancelFocusNotifications() }
        dataStore.addFocusSession(reward.session)
        if let item = reward.adventureRoll?.reward {
            dataStore.unlockReward(item)
        }
        if reward.shouldCompleteTask, let taskID = timerStore.activeTaskID {
            dataStore.completeTask(id: taskID, at: now)
        }
        completionSummary = FocusCompletionSummary(
            sessionID: reward.sessionID,
            taskTitle: timerStore.activeTaskTitle,
            minutes: reward.minutes,
            paws: reward.totalPaws,
            xp: reward.xp,
            boost: reward.isRewardEligible ? boost : nil,
            adventureRoll: reward.adventureRoll,
            isRewardEligible: reward.isRewardEligible,
            completedTask: reward.shouldCompleteTask
        )
        CozyFeedback.play(reward.isRewardEligible ? .reward : .complete)
        timerStore.reset(duration: TimeInterval(customMinutes * 60))
        activeBoostID = ""
        if reward.isRewardEligible {
            pendingBoostID = FocusBoost.next(after: pendingBoostID).id
        }
        setupRollsUsed = 0
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

    private func saveReflectionIfNeeded(for summary: FocusCompletionSummary) {
        let note = reflection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return }
        dataStore.updateFocusMood(sessionID: summary.sessionID, moodNote: note)
    }

    private func selectFirstTaskIfNeeded() {
        if let selectedTaskID, incompleteTasks.contains(where: { $0.id == selectedTaskID }) {
            return
        }
        selectedTaskID = incompleteTasks.first?.id
    }

    private func rollBoost() {
        guard canRollSetupBoost else { return }
        withAnimation(.snappy(duration: 0.18)) {
            pendingBoostID = FocusBoost.random(excluding: pendingBoostID).id
            setupRollsUsed += 1
        }
        CozyFeedback.play(.reward)
    }

    private func mascotState(for phase: FocusPhase) -> MascotState {
        switch phase {
        case .prepare: return .idle
        case .settling: return .settling
        case .deepFocus: return .deepFocus
        case .finalMinute: return .landing
        case .wrap: return .complete
        case .breakTime: return .breakTime
        }
    }

    private func ringColor(for phase: FocusPhase) -> Color {
        switch phase {
        case .prepare: return timerSkin.color
        case .settling: return CozyPalette.mistBlue
        case .deepFocus: return timerSkin.color
        case .finalMinute: return theme.reward
        case .wrap: return CozyPalette.habitLavender
        case .breakTime: return CozyPalette.coolBlue
        }
    }

    private var timerSkin: CozyTimerSkin {
        if let equippedSkin = dataStore.rewards.first(where: { reward in
            reward.isEquipped && reward.category.localizedCaseInsensitiveContains("timer skin")
        }), let id = CozyTimerSkin.id(matching: equippedSkin.name) {
            return CozyTimerSkin.named(id)
        }
        return CozyTimerSkin.named(selectedTimerSkin)
    }

    private var quotePreference: CozyQuoteStyle {
        CozyQuoteStyle(rawValue: quoteStyle) ?? .cozy
    }

    private func timerAccent(for phase: FocusPhase) -> Color {
        ringColor(for: phase)
    }
}

struct MotivationQuotePill: View {
    let quote: String
    let color: Color

    var body: some View {
        Label(quote, systemImage: "quote.bubble.fill")
            .font(.callout.weight(.semibold))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.11))
            )
            .foregroundStyle(color)
            .accessibilityIdentifier("focus.motivationQuote")
    }
}

struct FocusRewardPreview: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    let durationMinutes: Int
    let boost: FocusBoost

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gift.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.reward)
                Text("Session reward")
                    .font(.headline)
                Spacer()
                Label("+\(estimatedPaws)", systemImage: "pawprint.fill")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(theme.reward)
            }
            VStack(alignment: .leading, spacing: 8) {
                RewardPreviewRow(title: "Focus XP", value: "+\(durationMinutes * 2)", symbol: "sparkles")
                RewardPreviewRow(title: boost.title, value: "+\(boost.bonusPaws) paws", symbol: boost.symbol)
                RewardPreviewRow(title: "Room progress", value: nextUnlockText, symbol: "house.fill")
            }
        }
        .cozyCard()
        .accessibilityIdentifier("focus.rewardPreview")
    }

    private var estimatedPaws: Int {
        max(1, (durationMinutes * 2) / 4) + max(1, durationMinutes / 5) + boost.bonusPaws
    }

    private var nextUnlockText: String {
        guard let next = CozyProgression.shopCatalog.first(where: { !CozyProgression.isPurchased($0, rewards: dataStore.rewards) }) else {
            return "all starter items owned"
        }
        return "\(next.name) at \(next.coinCost) paws"
    }
}

struct FocusSetupCard: View {
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    @Binding var selectedTaskID: UUID?
    @Binding var customMinutes: Int
    let incompleteTasks: [TaskItem]
    let pendingBoost: FocusBoost
    let canRoll: Bool
    let rollCount: Int
    let onRoll: () -> Void
    let onStart: () -> Void
    @State private var showsBoostDetails = false

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Set up one session")
                    .font(.title3.weight(.bold))
                Text("Pick a task, pick a length, then start. Everything else can wait.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            CozyLabeledControl(title: "Task", symbolName: "checklist") {
                FocusTaskPicker(selectedTaskID: $selectedTaskID, incompleteTasks: incompleteTasks)
                .accessibilityIdentifier("focus.taskPicker")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Duration")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { presetButtons }
                    VStack(alignment: .leading, spacing: 8) {
                        presetButtons
                    }
                }
            }

            Divider()

            HStack(spacing: 12) {
                RarityIcon(symbol: pendingBoost.symbol, rarity: pendingBoost.rarity, size: 48)
                    .id(pendingBoost.id)
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(pendingBoost.rarity.rawValue) boost")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: pendingBoost.rarity.colorHex))
                    Text(pendingBoost.title)
                        .font(.headline)
                    Text(pendingBoost.caption)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button {
                    onRoll()
                } label: {
                    Image(systemName: "dice.fill")
                        .frame(width: 22, height: 22)
                }
                .cozyIconButton(size: CozyLayout.hitSize)
                .disabled(!canRoll)
                .help(canRoll ? "Roll one free positive boost" : "One boost roll per session")
                .accessibilityLabel(canRoll ? "Roll one free positive boost" : "Boost roll already used")
                .accessibilityIdentifier("focus.boost.roll")
            }

            CozyDisclosureSection(
                title: rollCount == 0 ? "Free surprise roll available" : "Boost locked for this session",
                symbolName: "sparkles",
                isExpanded: $showsBoostDetails
            ) {
                Text("Odds: \(CozyProgression.adventureOddsText). No paid rolls, no bad outcomes, no time pressure.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                onStart()
            } label: {
                Label("Start \(customMinutes)m focus", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .cozyPrimaryButton(fullWidth: true)
            .accessibilityIdentifier("focus.start")
        }
        .cozyCard()
    }

    @ViewBuilder
    private var presetButtons: some View {
        durationButton(minutes: 5)
        durationButton(minutes: 15)
        durationButton(minutes: 25)
        durationButton(minutes: 50)
    }

    private func durationButton(minutes: Int) -> some View {
        let isSelected = customMinutes == minutes
        return Button {
            customMinutes = minutes
        } label: {
            HStack(spacing: 6) {
                Image(systemName: minutes <= 15 ? "bolt.fill" : "timer")
                    .font(.caption.weight(.bold))
                Text("\(minutes)m")
                    .font(.callout.weight(.bold))
                    .monospacedDigit()
            }
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity, minHeight: CozyLayout.hitSize)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? CozyPalette.focusJade : CozyPalette.softMint.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? CozyPalette.focusJade.opacity(0.35) : CozyPalette.neutralBorder, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? Color.white : CozyPalette.focusJade)
        }
        .cozyPressable(pressedScale: 0.965, hoverScale: 1.012)
        .accessibilityIdentifier("focus.preset.\(minutes)")
    }
}

struct FocusTaskPicker: View {
    @Binding var selectedTaskID: UUID?
    let incompleteTasks: [TaskItem]

    private var selectedTitle: String {
        guard let selectedTaskID,
              let task = incompleteTasks.first(where: { $0.id == selectedTaskID }) else {
            return "Quick focus"
        }
        return task.title
    }

    var body: some View {
        Menu {
            Button("Quick focus") {
                selectedTaskID = nil
            }
            if !incompleteTasks.isEmpty {
                Divider()
                ForEach(incompleteTasks) { task in
                    Button(task.title) {
                        selectedTaskID = task.id
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "target")
                    .foregroundStyle(CozyPalette.berry)
                Text(selectedTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer(minLength: 10)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 260, minHeight: CozyLayout.controlHeight, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
        .cozyControlShell(minWidth: 260, alignment: .leading)
        .accessibilityLabel("Task")
        .accessibilityValue(selectedTitle)
    }
}

struct FocusRunningCompanionCard: View {
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    let phase: FocusPhase
    let boost: FocusBoost

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                RarityIcon(symbol: phaseSymbol, rarity: boost.rarity, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(phase.label)
                        .font(.headline)
                    Text(phase.microcopy)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Divider()

            Label("\(boost.title): +\(boost.bonusPaws) paws when saved", systemImage: boost.symbol)
                .font(.callout.weight(.semibold))
                .foregroundStyle(theme.reward)

            Text("Mochi’s mood, checkpoints, and reward preview shift as the timer moves through the session.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cozyCard()
    }

    private var phaseSymbol: String {
        switch phase {
        case .prepare: "sparkles"
        case .settling: "leaf.fill"
        case .deepFocus: "headphones"
        case .finalMinute: "sun.max.fill"
        case .wrap: "checkmark.seal.fill"
        case .breakTime: "cup.and.saucer.fill"
        }
    }
}

struct RewardPreviewRow: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 22)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.callout)
            Spacer()
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

struct FocusPhaseHeader: View {
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    let phase: FocusPhase
    let boost: FocusBoost?

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                phasePill
                microcopy
                Spacer(minLength: 0)
                boostLabel
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    phasePill
                    boostLabel
                }
                microcopy
            }
        }
        .accessibilityIdentifier("focus.phase")
    }

    private var phasePill: some View {
        Label(phase.label, systemImage: phaseSymbol)
            .font(.callout.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(CozyPalette.softMint.opacity(0.58)))
            .foregroundStyle(CozyPalette.focusJade)
            .fixedSize()
    }

    private var microcopy: some View {
        Text(phase.microcopy)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .layoutPriority(1)
    }

    @ViewBuilder
    private var boostLabel: some View {
        if let boost {
            Label(boost.title, systemImage: boost.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.reward)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var phaseSymbol: String {
        switch phase {
        case .prepare: "sparkles"
        case .settling: "leaf.fill"
        case .deepFocus: "headphones"
        case .finalMinute: "sun.max.fill"
        case .wrap: "checkmark.seal.fill"
        case .breakTime: "cup.and.saucer.fill"
        }
    }
}

struct FocusMilestoneBeads: View {
    let progress: Double
    let color: Color

    private let milestones: [(Double, String)] = [
        (0.25, "Settled"),
        (0.50, "Halfway"),
        (0.75, "Landing"),
        (1.00, "Saved")
    ]

    private var completedCount: Int {
        milestones.filter { progress >= $0.0 }.count
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(milestones, id: \.0) { milestone in
                Circle()
                    .fill(progress >= milestone.0 ? color : Color.secondary.opacity(0.35))
                    .frame(width: progress >= milestone.0 ? 10 : 7, height: progress >= milestone.0 ? 10 : 7)
                    .animation(.snappy(duration: 0.18), value: progress >= milestone.0)
                    .accessibilityLabel("\(milestone.1) checkpoint")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.black.opacity(0.08)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(completedCount) of \(milestones.count) focus checkpoints reached")
    }
}

struct FocusBoostCard: View {
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    let boost: FocusBoost
    let canRoll: Bool
    let onRoll: () -> Void

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.reward.opacity(0.16))
                Image(systemName: boost.symbol)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.reward)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text("Tiny boost")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(boost.title)
                    .font(.headline)
                Text(boost.caption)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("All rolls are small positive bonuses.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                onRoll()
            } label: {
                Image(systemName: "dice.fill")
                    .frame(width: 22, height: 22)
            }
            .cozyIconButton(size: CozyLayout.hitSize)
            .disabled(!canRoll)
            .help("Roll a gentle positive boost")
            .accessibilityLabel("Roll a gentle positive boost")
            .accessibilityIdentifier("focus.boost.roll")
        }
        .cozyCard()
        .accessibilityIdentifier("focus.boost")
    }
}

struct FocusCompletionSummary: Equatable {
    let sessionID: UUID
    let taskTitle: String
    let minutes: Int
    let paws: Int
    let xp: Int
    let boost: FocusBoost?
    let adventureRoll: AdventureRollResult?
    let isRewardEligible: Bool
    let completedTask: Bool
}

struct FocusRewardResolution {
    let sessionID: UUID
    let session: FocusSession
    let minutes: Int
    let xp: Int
    let rewardPaws: Int
    let totalPaws: Int
    let adventureRoll: AdventureRollResult?
    let isRewardEligible: Bool
    let shouldCompleteTask: Bool
}

enum FocusRewardResolver {
    static let minimumRewardDuration: TimeInterval = 5 * 60

    static func activeBoostFromDefaults(_ defaults: UserDefaults = .standard) -> FocusBoost {
        FocusBoost.named(defaults.string(forKey: "focus.activeBoostID") ?? "")
    }

    static func isRewardEligible(snapshot: FocusTimerSnapshot, at date: Date) -> Bool {
        let requiredDuration = min(minimumRewardDuration, snapshot.duration)
        return TimerEngine.creditedDuration(for: snapshot, at: date) >= requiredDuration
    }

    static func shouldCompleteTask(snapshot: FocusTimerSnapshot, at date: Date) -> Bool {
        isRewardEligible(snapshot: snapshot, at: date)
            && TimerEngine.remainingTime(for: snapshot, at: date) <= 0.5
    }

    static func resolve(
        snapshot: FocusTimerSnapshot,
        taskTitle: String,
        boost: FocusBoost,
        existingRewards: [RewardItem],
        now: Date,
        seed: Int = Int.random(in: 0..<10_000)
    ) -> FocusRewardResolution {
        let creditedDuration = TimerEngine.creditedDuration(for: snapshot, at: now)
        let eligible = isRewardEligible(snapshot: snapshot, at: now)
        let completesTask = shouldCompleteTask(snapshot: snapshot, at: now)
        let minutes = eligible
            ? max(1, Int((creditedDuration / 60).rounded(.up)))
            : max(0, Int((creditedDuration / 60).rounded(.down)))
        let xp = eligible ? minutes * 2 : 0
        let basePaws = eligible ? max(1, Int(creditedDuration / 300)) : 0
        let adventureRoll = eligible
            ? CozyProgression.adventureRoll(
                seed: seed,
                completedMinutes: minutes,
                existingRewards: existingRewards
            )
            : nil
        let rewardPaws = eligible ? basePaws + boost.bonusPaws + (adventureRoll?.duplicatePaws ?? 0) : 0
        let totalPaws = eligible ? max(1, xp / 4) + rewardPaws : 0
        let sessionID = UUID()

        return FocusRewardResolution(
            sessionID: sessionID,
            session: FocusSession(
                id: sessionID,
                taskTitle: taskTitle,
                startDate: snapshot.startDate ?? now,
                duration: creditedDuration,
                accumulatedPause: snapshot.accumulatedPause,
                completedAt: now,
                moodNote: "",
                rewardPoints: rewardPaws
            ),
            minutes: minutes,
            xp: xp,
            rewardPaws: rewardPaws,
            totalPaws: totalPaws,
            adventureRoll: adventureRoll,
            isRewardEligible: eligible,
            shouldCompleteTask: completesTask
        )
    }
}

struct FocusCompletionReview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    let summary: FocusCompletionSummary
    @Binding var reflection: String
    let done: () -> Void
    let startAnother: () -> Void
    let openRewards: () -> Void
    @State private var revealStep = 0

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                MascotView(state: .complete, size: 62)
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.isRewardEligible ? "Soft win saved" : "Partial focus saved")
                        .font(.title3.weight(.bold))
                    Text(summary.taskTitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    completionMetrics
                }
                VStack(alignment: .leading, spacing: 8) {
                    completionMetrics
                }
            }

            if revealStep >= 1, let boost = summary.boost {
                Label("\(boost.title): +\(boost.bonusPaws) paws", systemImage: boost.symbol)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(theme.reward)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else if !summary.isRewardEligible {
                CozyFieldHint(text: "No reward roll this time. Focus for at least 5 minutes to earn XP and paws.")
            }

            if revealStep >= 2, let adventureRoll = summary.adventureRoll {
                AdventureRevealView(result: adventureRoll)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            TextField("Optional note: what moved forward?", text: $reflection, axis: .vertical)
                .accessibilityIdentifier("focus.reflection")
                .lineLimit(2, reservesSpace: true)
                .cozyTextInput(minHeight: 62, alignment: .topLeading)
                .accessibilityLabel("Focus reflection")

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    completionButtons
                }
                VStack(alignment: .leading, spacing: 8) {
                    completionButtons
                }
            }
        }
        .cozyCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Focus completion review")
        .task(id: summary.sessionID) {
            revealStep = 0
            guard !reduceMotion else {
                revealStep = 2
                return
            }
            try? await Task.sleep(nanoseconds: 180_000_000)
            withAnimation(.snappy(duration: 0.20)) { revealStep = 1 }
            try? await Task.sleep(nanoseconds: 220_000_000)
            withAnimation(.snappy(duration: 0.22)) { revealStep = 2 }
        }
    }

    @ViewBuilder
    private var completionMetrics: some View {
        SoftMetricBadge(title: "focus", value: "\(summary.minutes)m", symbol: "timer", color: CozyPalette.focusJade)
        if revealStep >= 1, summary.isRewardEligible {
            SoftMetricBadge(title: "XP", value: "+\(summary.xp)", symbol: "sparkles", color: CozyPalette.habitLavender)
                .transition(.opacity.combined(with: .move(edge: .top)))
            SoftMetricBadge(title: "paws", value: "+\(summary.paws)", symbol: "pawprint.fill", color: theme.reward)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private var completionButtons: some View {
        Button(reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Done" : "Save win", action: done)
            .cozySecondaryButton(minWidth: 96)
            .accessibilityIdentifier("focus.doneReview")
        Button("Start 5m", action: startAnother)
            .cozySecondaryButton(minWidth: 96)
            .accessibilityIdentifier("focus.startAnother")
        if summary.isRewardEligible {
            Button("Rewards Room", action: openRewards)
                .cozyPrimaryButton(minWidth: 132)
                .accessibilityIdentifier("focus.rewardsRoom")
        }
    }
}

struct AdventureRevealView: View {
    let result: AdventureRollResult

    var body: some View {
        HStack(spacing: 12) {
            RarityIcon(symbol: result.reward?.symbolName ?? "pawprint.fill", rarity: result.rarity, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(result.rarity.rawValue) adventure roll")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: result.rarity.colorHex))
                Text(revealTitle)
                    .font(.headline)
                    .lineLimit(2)
                Text(revealDetail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: result.rarity.colorHex).opacity(0.12))
        )
        .accessibilityIdentifier("focus.adventureReveal")
    }

    private var revealTitle: String {
        if let reward = result.reward {
            return "Mochi found \(reward.name)"
        }
        return "Duplicate became +\(result.duplicatePaws) paws"
    }

    private var revealDetail: String {
        if let reward = result.reward {
            return "\(reward.category). Cosmetic only, free, and optional."
        }
        return "No second currency. Owned surprises turn into progress."
    }
}

struct FocusBoost: Identifiable, Equatable {
    let id: String
    let title: String
    let caption: String
    let symbol: String
    let bonusPaws: Int
    let rarity: RewardRarity

    static let all: [FocusBoost] = [
        FocusBoost(id: "sparkle-paw", title: "Sparkle Paw", caption: "A tiny bonus for showing up.", symbol: "sparkles", bonusPaws: 1, rarity: .everyday),
        FocusBoost(id: "tea-break", title: "Tea Break", caption: "A care treat appears after the block.", symbol: "cup.and.saucer.fill", bonusPaws: 1, rarity: .everyday),
        FocusBoost(id: "lofi-flow", title: "Lofi Flow", caption: "Mochi keeps the room extra quiet.", symbol: "headphones", bonusPaws: 2, rarity: .cozy),
        FocusBoost(id: "room-glow", title: "Room Glow", caption: "A little decor progress boost.", symbol: "lightbulb.led.fill", bonusPaws: 2, rarity: .cozy),
        FocusBoost(id: "star-map", title: "Star Map", caption: "A special route through the session.", symbol: "map.fill", bonusPaws: 3, rarity: .special),
        FocusBoost(id: "aurora-room", title: "Aurora Room", caption: "A dream glow for one focused block.", symbol: "wand.and.stars", bonusPaws: 4, rarity: .dream)
    ]

    static let `default` = all[0]

    static func named(_ id: String) -> FocusBoost {
        all.first { $0.id == id } ?? .default
    }

    static func random(excluding id: String) -> FocusBoost {
        let rarity = CozyProgression.adventureRarity(for: Int.random(in: 0..<10_000))
        let rarityCandidates = all.filter { $0.rarity == rarity && $0.id != id }
        if let boost = rarityCandidates.randomElement() {
            return boost
        }
        let candidates = all.filter { $0.id != id }
        return candidates.randomElement() ?? .default
    }

    static func next(after id: String) -> FocusBoost {
        guard let index = all.firstIndex(where: { $0.id == id }) else { return .default }
        return all[(index + 1) % all.count]
    }
}

extension Notification.Name {
    static let cozyOpenSection = Notification.Name("CozyTimeOpenSection")
    static let cozyRootViewReady = Notification.Name("CozyTimeRootViewReady")
}

struct FocusPreviewCard: View {
    @EnvironmentObject private var timerStore: FocusTimerStore

    var body: some View {
        Button {
            NotificationCenter.default.post(name: .cozyOpenSection, object: AppSection.focus.rawValue)
        } label: {
            TimelineView(.periodic(from: .now, by: timerStore.isActive ? 1 : 60)) { context in
                let hasTimerStatus = timerStore.isActive || timerStore.needsCompletionReview
                HStack(spacing: 14) {
                    MascotView(state: hasTimerStatus ? mascotState(for: timerStore.phase(at: context.date)) : .idle, size: 70)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(previewEyebrow(at: context.date))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(hasTimerStatus ? timerStore.activeTaskTitle : "Start one small session")
                            .font(.headline)
                        Text(previewMetric(at: context.date))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(CozyFocusColor.color(for: timerStore.phase(at: context.date)))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .compactDashboardTile()
                .cozyCard()
            }
        }
        .cozyPressable()
        .accessibilityIdentifier("today.focusPreview.open")
    }

    private func previewEyebrow(at date: Date) -> String {
        if timerStore.needsCompletionReview { return "Reward waiting" }
        if timerStore.isActive { return timerStore.phase(at: date).label }
        return "Ready to focus"
    }

    private func previewMetric(at date: Date) -> String {
        if timerStore.needsCompletionReview { return "Claim focus reward" }
        if timerStore.isActive { return CozyFormatters.timerString(timerStore.remaining(at: date)) }
        return "Roll a tiny boost"
    }

    private func mascotState(for phase: FocusPhase) -> MascotState {
        switch phase {
        case .prepare: return .idle
        case .settling: return .settling
        case .deepFocus: return .deepFocus
        case .finalMinute: return .landing
        case .wrap: return .complete
        case .breakTime: return .breakTime
        }
    }
}

struct MenuBarPanelView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var timerStore: FocusTimerStore
    @EnvironmentObject private var notifications: NotificationService
    @AppStorage("mascotName") private var mascotName = "Mochi"
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    @State private var quickTask = ""
    @State private var lastMenuBarSaveMessage: String?

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                timerHero
                if let lastMenuBarSaveMessage {
                    menuBarSaveSummary(message: lastMenuBarSaveMessage)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                todayProgressCard
                focusDiaryCard
                quickCaptureCard
                bottomActions
            }
            .padding(14)
        }
        .frame(width: 360)
        .tint(theme.accent)
    }

    private var timerHero: some View {
        TimelineView(.periodic(from: .now, by: timerStore.isActive ? 1 : 60)) { context in
            let phase = timerStore.phase(at: context.date)
            let accent = CozyFocusColor.color(for: phase)
            let hasTimer = timerStore.isActive || timerStore.needsCompletionReview

            MenuBarSurface {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        MascotView(state: menuBarMascotState, size: 58)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(menuBarHeadline)
                                .font(.headline.weight(.bold))
                                .lineLimit(1)
                            Text(menuBarSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 8)
                        MenuBarPhasePill(title: menuBarModeLabel(at: context.date), color: accent)
                    }

                    Text(menuBarTimerText(at: context.date))
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(accent)
                        .accessibilityIdentifier("menubar.timer")

                    if hasTimer {
                        VStack(alignment: .leading, spacing: 5) {
                            CozyLinearProgressBar(value: timerStore.progress(at: context.date), color: accent)
                            HStack {
                                Text(phase.microcopy)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(Int(timerStore.progress(at: context.date) * 100))%")
                                    .monospacedDigit()
                            }
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        }
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            menuBarPrimaryButton
                            menuBarSecondaryButton
                        }
                        VStack(spacing: 8) {
                            menuBarPrimaryButton
                            menuBarSecondaryButton
                        }
                    }
                }
            }
        }
    }

    private var todayProgressCard: some View {
        MenuBarSurface {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Today", systemImage: "calendar")
                        .font(.callout.weight(.bold))
                    Spacer()
                    Text("\(dailyQuestCompleted)/3")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                CozyLinearProgressBar(value: Double(dailyQuestCompleted), total: 3, color: CozyPalette.berry)
                    .accessibilityLabel("Menu bar daily progress")

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        menuBarStats
                    }
                    LazyVGrid(columns: CozyLayout.adaptiveColumns(minimum: 96), spacing: 8) {
                        menuBarStats
                    }
                }
            }
        }
        .accessibilityIdentifier("menubar.todaySummary")
    }

    private var focusDiaryCard: some View {
        MenuBarSurface {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Label("Focus diary", systemImage: "book.closed.fill")
                        .font(.callout.weight(.bold))
                    Spacer()
                    Button {
                        openSection(.calendar)
                    } label: {
                        Label("Calendar", systemImage: "calendar")
                    }
                    .labelStyle(.iconOnly)
                    .cozyIconButton(size: CozyLayout.compactHitSize)
                    .help("Open calendar")
                    .accessibilityLabel("Open calendar")
                }

                if let latestTodayFocusSession {
                    MenuBarValueRow(title: "Last", value: "\(latestTodayFocusSession.completedMinutes)m")
                    Text(latestTodayFocusSession.taskTitle)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    if let completedAt = latestTodayFocusSession.completedAt {
                        Text("Saved \(CozyFormatters.shortTime.string(from: completedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    let note = latestTodayFocusSession.moodNote.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !note.isEmpty {
                        Label(note, systemImage: "quote.bubble.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                } else {
                    Text("No focus saved today")
                        .font(.callout.weight(.semibold))
                    Text("Completed sessions will appear here, in Stats, and on the Calendar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .accessibilityIdentifier("menubar.focusDiary")
    }

    private var quickCaptureCard: some View {
        MenuBarSurface {
            VStack(alignment: .leading, spacing: 9) {
                Label("Capture", systemImage: "plus.bubble.fill")
                    .font(.callout.weight(.bold))
                HStack(spacing: 8) {
                    TextField("Task or focus title", text: $quickTask)
                        .onSubmit(addQuickTask)
                        .accessibilityIdentifier("menubar.quickAdd")
                        .cozyTextInput(minHeight: 36, alignment: .leading)
                        .layoutPriority(1)
                    Button {
                        addQuickTask()
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 18, height: 18)
                    }
                    .cozyIconButton(size: CozyLayout.compactHitSize)
                    .disabled(pendingQuickTaskTitle.isEmpty)
                    .help("Add task")
                    .accessibilityIdentifier("menubar.quickAddButton")
                }
            }
        }
    }

    private var bottomActions: some View {
        HStack(spacing: 8) {
            Button {
                CozyAppDelegate.openMainWindowIfNeeded()
            } label: {
                Label("Open App", systemImage: "macwindow")
                    .frame(maxWidth: .infinity)
            }
            .cozySecondaryButton(fullWidth: true)

            Button {
                openSection(.stats)
            } label: {
                Label("Progress", systemImage: "chart.bar.fill")
                    .frame(maxWidth: .infinity)
            }
            .cozySecondaryButton(fullWidth: true)
        }
    }

    private var menuBarPrimaryButton: some View {
        Button {
            togglePrimaryTimer()
        } label: {
            Label(primaryTimerTitle, systemImage: primaryTimerSymbol)
                .frame(maxWidth: .infinity)
        }
        .cozyPrimaryButton(fullWidth: true)
        .accessibilityIdentifier("menubar.primaryTimer")
    }

    @ViewBuilder
    private var menuBarSecondaryButton: some View {
        if timerStore.needsCompletionReview {
            Button {
                completeMenuBarFocus()
            } label: {
                Label("Save session", systemImage: "tray.and.arrow.down.fill")
                    .frame(maxWidth: .infinity)
            }
            .cozySecondaryButton(fullWidth: true)
            .accessibilityIdentifier("menubar.saveWithoutNote")
        } else if timerStore.isActive {
            Button {
                timerStore.cancel()
                Task { await notifications.cancelFocusNotifications() }
            } label: {
                Label("Set down", systemImage: "hand.raised.fill")
                    .frame(maxWidth: .infinity)
            }
            .cozySecondaryButton(fullWidth: true)
            .accessibilityIdentifier("menubar.stop")
        } else {
            Button {
                openSection(.calendar)
            } label: {
                Label("Diary", systemImage: "book.closed")
                    .frame(maxWidth: .infinity)
            }
            .cozySecondaryButton(fullWidth: true)
        }
    }

    private func togglePrimaryTimer() {
        if timerStore.needsCompletionReview {
            openSection(.focus)
        } else if timerStore.isRunning {
            timerStore.pause()
            Task { await notifications.cancelFocusNotifications() }
        } else if timerStore.isPaused {
            timerStore.resume()
            scheduleMenuBarFocusCompletion()
        } else {
            startMenuBarFocus()
        }
    }

    private func menuBarTimerText(at date: Date) -> String {
        if timerStore.isActive || timerStore.needsCompletionReview {
            return CozyFormatters.timerString(timerStore.remaining(at: date))
        }
        return "No active timer"
    }

    private var primaryTimerTitle: String {
        if timerStore.isRunning { return "Pause timer" }
        if timerStore.isPaused { return "Resume timer" }
        if timerStore.needsCompletionReview { return "Review reward" }
        return pendingQuickTaskTitle.isEmpty ? "Start 25m focus" : "Start typed focus"
    }

    private var primaryTimerSymbol: String {
        if timerStore.isRunning { return "pause.fill" }
        if timerStore.isPaused { return "play.fill" }
        return timerStore.needsCompletionReview ? "gift.fill" : "timer"
    }

    private var menuBarHeadline: String {
        if timerStore.needsCompletionReview { return "Reward waiting" }
        if timerStore.isPaused { return "Paused focus" }
        if timerStore.isRunning { return timerStore.phase(at: timerStore.currentDate).label }
        return "Ready for focus"
    }

    private var menuBarSubtitle: String {
        if timerStore.isActive || timerStore.needsCompletionReview {
            return timerStore.activeTaskTitle
        }
        return "\(mascotName) saved \(todayFocusMinutes)m today"
    }

    private func menuBarModeLabel(at date: Date) -> String {
        if timerStore.needsCompletionReview { return "Save" }
        if timerStore.isPaused { return "Paused" }
        if timerStore.isRunning { return timerStore.phase(at: date).label }
        return "Idle"
    }

    private var menuBarMascotState: MascotState {
        switch timerStore.phase(at: timerStore.currentDate) {
        case .prepare: return .idle
        case .settling: return .settling
        case .deepFocus: return .deepFocus
        case .finalMinute: return .landing
        case .wrap: return .complete
        case .breakTime: return .breakTime
        }
    }

    private var todayIncompleteCount: Int {
        dataStore.tasks.filter { !$0.isCompleted && CozyCalendar.isToday($0.dueDate) }.count
    }

    private var completedHabitsToday: Int {
        dataStore.habits.filter { HabitMath.isComplete(keys: $0.completionKeys, on: Date()) }.count
    }

    private var habitSummaryText: String {
        dataStore.habits.isEmpty ? "0/0" : "\(completedHabitsToday)/\(dataStore.habits.count)"
    }

    @ViewBuilder
    private var menuBarStats: some View {
        MenuBarStatTile(value: "\(todayFocusMinutes)m", title: "focus", symbol: "timer", color: CozyPalette.focusJade)
        MenuBarStatTile(value: "\(todayIncompleteCount)", title: "tasks left", symbol: "checklist", color: CozyPalette.berry)
        MenuBarStatTile(value: habitSummaryText, title: "habits", symbol: "sparkles", color: CozyPalette.habitLavender)
    }

    private var completedTasksToday: Int {
        dataStore.tasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return Calendar.autoupdatingCurrent.isDateInToday(completedAt)
        }.count
    }

    private var todayFocusMinutes: Int {
        dataStore.focusSessions
            .filter { session in CozyCalendar.isToday(session.reportingDate) }
            .reduce(0) { $0 + $1.completedMinutes }
    }

    private var dailyQuestCompleted: Int {
        let focusDone = todayFocusMinutes > 0 ? 1 : 0
        let taskDone = completedTasksToday > 0 ? 1 : 0
        let habitDone = completedHabitsToday > 0 ? 1 : 0
        return focusDone + taskDone + habitDone
    }

    private var latestTodayFocusSession: FocusSession? {
        dataStore.focusSessions
            .filter { session in CozyCalendar.isToday(session.reportingDate) }
            .sorted { first, second in
                first.reportingDate > second.reportingDate
            }
            .first
    }

    private var pendingQuickTaskTitle: String {
        quickTask.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addQuickTask() {
        let clean = pendingQuickTaskTitle
        guard !clean.isEmpty else { return }
        dataStore.addTask(TaskItem(title: clean, dueDate: Date(), priority: 1))
        CozyFeedback.play(.add)
        quickTask = ""
    }

    private func startMenuBarFocus() {
        guard timerStore.canStartNewSession else { return }
        UserDefaults.standard.set(FocusBoost.default.id, forKey: "focus.activeBoostID")
        let clean = pendingQuickTaskTitle
        if clean.isEmpty {
            timerStore.start(taskTitle: "Quick focus", duration: 25 * 60)
        } else {
            let task = TaskItem(title: clean, dueDate: Date(), priority: 1)
            dataStore.addTask(task)
            timerStore.start(taskTitle: task.title, taskID: task.id, duration: 25 * 60)
            quickTask = ""
        }
        scheduleMenuBarFocusCompletion()
    }

    private func openSection(_ section: AppSection) {
        CozyAppDelegate.openSection(section)
    }

    private func completeMenuBarFocus() {
        guard timerStore.isActive || timerStore.needsCompletionReview else { return }
        let now = Date()
        let savedTaskTitle = timerStore.activeTaskTitle
        let boost = FocusRewardResolver.activeBoostFromDefaults()
        let reward = FocusRewardResolver.resolve(
            snapshot: timerStore.snapshot,
            taskTitle: timerStore.activeTaskTitle,
            boost: boost,
            existingRewards: dataStore.rewards,
            now: now
        )
        timerStore.complete(at: now)
        Task { await notifications.cancelFocusNotifications() }
        dataStore.addFocusSession(reward.session)
        if let item = reward.adventureRoll?.reward {
            dataStore.unlockReward(item)
        }
        if reward.shouldCompleteTask, let taskID = timerStore.activeTaskID {
            dataStore.completeTask(id: taskID, at: now)
        }
        CozyFeedback.play(reward.isRewardEligible ? .reward : .complete)
        withAnimation(.snappy(duration: 0.18)) {
            lastMenuBarSaveMessage = reward.isRewardEligible
                ? "\(reward.minutes)m \(savedTaskTitle) · +\(reward.xp) XP · +\(reward.rewardPaws) paws"
                : "\(reward.minutes)m saved. Focus rewards start at 5m."
        }
        timerStore.reset()
        UserDefaults.standard.set("", forKey: "focus.activeBoostID")
    }

    private func menuBarSaveSummary(message: String) -> some View {
        MenuBarSurface {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(CozyPalette.focusJade)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Saved to diary")
                        .font(.callout.weight(.bold))
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button {
                    openSection(.calendar)
                } label: {
                    Image(systemName: "calendar")
                        .frame(width: 16, height: 16)
                }
                .cozyIconButton(size: CozyLayout.compactHitSize)
                .help("Open calendar diary")
                .accessibilityLabel("Open calendar diary")
            }
        }
        .accessibilityIdentifier("menubar.saveSummary")
    }

    private func scheduleMenuBarFocusCompletion() {
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

private struct MenuBarSurface<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(CozyPalette.raisedFill(colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(CozyPalette.cardBorder(colorScheme), lineWidth: 1)
                    )
            )
    }
}

private struct MenuBarPhasePill: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(color.opacity(0.13))
            )
            .foregroundStyle(color)
            .accessibilityLabel(title)
    }
}

private struct MenuBarStatTile: View {
    @Environment(\.colorScheme) private var colorScheme
    let value: String
    let title: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.caption2.weight(.bold))
                    .frame(width: 14, alignment: .leading)
                    .foregroundStyle(color)
                Text(value)
                    .font(.callout.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .foregroundStyle(CozyPalette.primaryText(colorScheme))
            }
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                .lineLimit(1)
        }
        .padding(9)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.10))
        )
    }
}

private struct MenuBarValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.bold))
                .monospacedDigit()
        }
    }
}

private enum CozyFocusColor {
    static func color(for phase: FocusPhase) -> Color {
        switch phase {
        case .prepare, .settling, .deepFocus:
            return CozyPalette.focusJade
        case .finalMinute:
            return CozyPalette.persimmon
        case .wrap:
            return CozyPalette.habitLavender
        case .breakTime:
            return CozyPalette.skyBlue
        }
    }
}
