import CozyCore
import SwiftUI
import AppKit

struct FocusView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var timerStore: FocusTimerStore
    @EnvironmentObject private var notifications: NotificationService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    @State private var petScale: CGFloat = 1.0
    @State private var pawReactScale: CGFloat = 1.0
    @AppStorage("focus.activeBoostID") private var activeBoostID = ""
    // Persist the last duration so the menu-bar quick-start and ⌘-shortcut both
    // honor what the user actually picked instead of resetting to 25 every time.
    @AppStorage("focus.lastFocusMinutes") private var lastFocusMinutes = 25

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
                        .transition(.opacity)
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
        let date = timerStore.currentDate
        let remaining = timerStore.remaining(at: date)
        let progress = timerStore.progress(at: date)
        let phase = timerStore.phase(at: date)
        let accent = timerAccent(for: phase)
        let shape = CozyTimerShape(rawValue: selectedTimerShape) ?? .ring
        let elapsedMinute = Int(max(0, (timerStore.snapshot.duration - remaining) / 60))

        return VStack(spacing: 20) {
            FocusPhaseHeader(phase: phase, boost: activeBoostID.isEmpty ? nil : activeBoost)
            MascotView(state: mascotState(for: phase), size: .hero)
                .accessibilityHidden(true)
                .scaleEffect(max(petScale, pawReactScale))
                .onTapGesture {
                    guard !reduceMotion else { return }
                    Task {
                        withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) { petScale = 1.12 }
                        try? await Task.sleep(for: .milliseconds(175))
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.60)) { petScale = 1.0 }
                    }
                }
                .onChange(of: dataStore.progression.coinsAvailable) { _, _ in
                    guard !reduceMotion else { return }
                    Task {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.40)) { pawReactScale = 1.14 }
                        try? await Task.sleep(for: .milliseconds(200))
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.68)) { pawReactScale = 1.0 }
                    }
                }
            CozyTimerChrome(progress: progress, color: accent, skin: timerSkin, shape: shape)
                .frame(width: 208, height: 208)
                .background(FocusRingAura(phase: phase, accent: accent))
                .overlay {
                    VStack(spacing: 6) {
                        Text(CozyFormatters.timerString(remaining))
                            .font(CozyType.timer)
                            .monospacedDigit()
                        Text(timerStore.isActive || timerStore.needsCompletionReview ? "Focus" : "Let's go")
                            .font(CozyType.rowTitle)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                    }
                    .padding(16)
                }
                .overlay(alignment: .topTrailing) {
                    PawCounterPill()
                        .offset(x: 12, y: -8)
                }
            // Phase dots below the ring — progress reads: ring fills → dots light up.
            FocusMilestoneBeads(progress: progress, color: accent)
            if timerStore.isActive || timerStore.needsCompletionReview {
                Text(timerStore.activeTaskTitle)
                    .font(CozyType.rowTitle)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 260, minHeight: 40)
            }
            // Paw-boundary ticker — every 5 min of credited focus, placed
            // in its own reserved row so it never floats across the timer
            // chrome or checkpoint beads.
            PawTickerOverlay(accent: accent)
                .frame(height: 32)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            // Extra 6pt gap above the controls so the buttons aren't
            // visually crowding the ring. Combined with the parent
            // VStack's 14pt spacing this gives 20pt — on-grid, more
            // breathable, doesn't widen the other rows.
            ViewThatFits(in: .horizontal) {
                timerControls
                    .padding(.top, 8)
                VStack(spacing: 8) {
                    timerControls
                }
                .padding(.top, 8)
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
    }

    private var focusSideColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
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
            // Honor the user's last-picked duration instead of forcing a
            // magic 5-minute reset. If they just did 90 minutes and want to
            // do another block, they almost certainly don't want a 5-min stub.
            customMinutes = max(1, lastFocusMinutes)
            startFocus()
        } openRewards: {
            saveReflectionIfNeeded(for: summary)
            completionSummary = nil
            reflection = ""
            NotificationCenter.default.post(name: .cozyOpenSection, object: AppSection.rewards.rawValue)
        }
        .onDisappear {
            saveReflectionIfNeeded(for: summary)
        }
    }

    private var timerControls: some View {
        // Force equal-width columns so the primary / secondary / discard buttons no longer
        // drift between 132 / 112 / 128 / 118 pt widths every state change. `frame(maxWidth:
        // .infinity)` makes each button claim its share of the row; `fixedSize(horizontal:
        // false, vertical: true)` keeps labels readable without horizontal compression.
        HStack(spacing: 10) {
            if timerStore.needsCompletionReview {
                Button {
                    completeFocus()
                } label: {
                    Label("Save this win", systemImage: "checkmark.seal.fill")
                        .frame(maxWidth: .infinity)
                }
                .cozyPrimaryButton(minWidth: 132)
                .accessibilityIdentifier("focus.claimReward")
            } else if timerStore.isRunning {
                Button {
                    pauseFocus()
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .cozyPrimaryButton(minWidth: 132)
                .accessibilityIdentifier("focus.pause")
            } else if timerStore.isPaused {
                Button {
                    resumeFocus()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .cozyPrimaryButton(minWidth: 132)
                .accessibilityIdentifier("focus.resume")
            } else {
                Button {
                    startFocus()
                } label: {
                    Label("Start Focus", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
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
                        .frame(maxWidth: .infinity)
                }
                .cozySecondaryButton(minWidth: 132)
                .disabled(!timerStore.isActive && timerStore.snapshot.state != .completed)
                .accessibilityIdentifier("focus.complete")
            }

            Button {
                stopFocus()
            } label: {
                Label("Cancel session", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
            }
            // Ghost style — destructive action should NOT visually compete with
            // Pause / Save partial. Apple HIG sibling-button hierarchy: primary
            // visual weight goes to the affirmative action.
            .cozyGhostButton(minWidth: 132)
            .disabled(!timerStore.isActive)
            .help("Stop without saving any progress")
            .accessibilityLabel("Cancel session without saving")
            .accessibilityIdentifier("focus.stop")
        }
        // SwiftUI-native haptic feedback (macOS 14+). Three triggers cover the
        // three main state transitions: start/resume → .impact; pause → .stop;
        // completion review saved → .success.
        .sensoryFeedback(.impact(weight: .medium), trigger: timerStore.isRunning)
        .sensoryFeedback(.stop, trigger: timerStore.isPaused)
        .sensoryFeedback(.success, trigger: timerStore.needsCompletionReview)
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
        lastFocusMinutes = customMinutes        // remembered for menu-bar / ⌘-shortcut
        completionSummary = nil
        reflection = ""
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
        // After cancel, the snapshot retains its elapsed/remaining values so
        // the timer ring continued to display "17:52 Ready" instead of a
        // fresh "25:00 Ready". Reset to the user's current `customMinutes`
        // pick so idle-state matches the sidebar's "Ready for a tiny session".
        timerStore.reset(duration: TimeInterval(max(1, customMinutes) * 60))
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
            lifetimeSessionCount: dataStore.focusSessions.count,
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
        withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
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
            .font(CozyType.body.weight(.semibold))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous)
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
                    .font(CozyType.cardTitle)
                    .foregroundStyle(theme.reward)
                Text("Session reward")
                    .font(CozyType.rowTitle)
                Spacer()
                Label("+\(estimatedPaws)", systemImage: "pawprint.fill")
                    .font(CozyType.controlStrong)
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
        // Mirrors FocusRewardResolver post-rebalance: xp/12 + 1 paw per 15 min
        // + boost bonus. Stays in lockstep so the pre-session preview never
        // over-promises.
        max(1, (durationMinutes * 2) / 12) + max(1, durationMinutes / 15) + boost.bonusPaws
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
                    .font(CozyType.cardTitle)
                Text("Pick a task, pick a length, then start. Everything else can wait.")
                    .font(CozyType.body)
                    .foregroundStyle(.secondary)
            }

            CozyLabeledControl(title: "Task", symbolName: "checklist") {
                FocusTaskPicker(selectedTaskID: $selectedTaskID, incompleteTasks: incompleteTasks)
                .accessibilityIdentifier("focus.taskPicker")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Duration")
                    .font(CozyType.captionStrong)
                    .foregroundStyle(.secondary)
                CozyDurationPicker(
                    minutes: $customMinutes,
                    accent: CozyPalette.focusJade,
                    identifierPrefix: "focus"
                )
            }

            Divider()

            // Visual audit IMPORTANT #4: when the caption wraps to 2 lines
            // the 48pt icon dropped below the title baseline at default
            // .center. .top with a 2pt nudge on the icon aligns it with the
            // rarity label's cap-height.
            HStack(alignment: .top, spacing: 12) {
                RarityIcon(symbol: pendingBoost.symbol, rarity: pendingBoost.rarity, size: 48)
                    .id(pendingBoost.id)
                    .transition(.opacity)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(pendingBoost.rarity.rawValue) boost")
                        .font(CozyType.captionStrong)
                        .foregroundStyle(CozyPalette.catalogColor(pendingBoost.rarity.colorHex))
                    Text(pendingBoost.title)
                        .font(CozyType.rowTitle)
                    Text(pendingBoost.caption)
                        .font(CozyType.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button {
                    onRoll()
                } label: {
                    Image(systemName: "dice.fill")
                        .frame(width: 24, height: 24)
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
                Label("Start \(CozyFormatters.durationLabel(TimeInterval(customMinutes * 60))) focus", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .cozyPrimaryButton(fullWidth: true)
            .accessibilityIdentifier("focus.start")
        }
        .cozyCard()
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
            .frame(maxWidth: .infinity, minHeight: CozyLayout.controlHeight, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
        .cozyControlShell(minWidth: 260, alignment: .leading)
        .accessibilityLabel("Task")
        .accessibilityValue(selectedTitle)
    }
}

struct FocusRunningCompanionCard: View {
    @EnvironmentObject private var timerStore: FocusTimerStore
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    let phase: FocusPhase
    let boost: FocusBoost

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                RarityIcon(symbol: phaseSymbol, rarity: boost.rarity, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(phase.label)
                        .font(CozyType.rowTitle)
                    Text(phase.microcopy)
                        .font(CozyType.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Divider()

            // Live reward forecast — the same CozyProgressionRing pattern users
            // see on the Habits screen, mirrored here so the reward economy is
            // visible during the focus session (not silently aggregated at end).
            // Hybrid: ring is the progress signal, number is a ghost preview
            // ("+N on save"). Adventure-roll bonus is intentionally excluded —
            // it's resolved at save, and the preview must never over-promise.
            FocusRunningRewardForecast(
                creditedDuration: TimerEngine.creditedDuration(for: timerStore.snapshot, at: timerStore.currentDate),
                duration: timerStore.snapshot.duration,
                boost: boost
            )

            Label("\(boost.title): +\(boost.bonusPaws) paws when saved", systemImage: boost.symbol)
                .font(CozyType.body.weight(.semibold))
                .foregroundStyle(theme.reward)
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

// FocusRunningRewardForecast — researched recipe H3. Live "ghost preview" of
// paws/XP that will land on save, paired with a CozyProgressionRing showing
// session progress. NN/g: "lack of information often equates to a lack of
// control." Apple Fitness pattern: the same ring shown elsewhere (Habits)
// reappears here for consistency. Adventure-roll duplicate-paws bonus is
// excluded from the preview — it resolves at save (Progression.swift), so
// previewing it would risk over-promising.
struct FocusRunningRewardForecast: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let creditedDuration: TimeInterval
    let duration: TimeInterval
    let boost: FocusBoost

    private var isEligible: Bool {
        creditedDuration >= FocusRewardResolver.minimumRewardDuration
    }

    private var basePaws: Int {
        guard isEligible else { return 0 }
        // 1 paw / 15 min — mirrors the post-rebalance resolver above.
        return max(1, Int(creditedDuration / 900))
    }

    private var xpPreview: Int {
        guard isEligible else { return 0 }
        let minutes = max(1, Int((creditedDuration / 60).rounded(.up)))
        return minutes * 2
    }

    private var pawForecast: Int {
        guard isEligible else { return 0 }
        // xp/12 — mirrors the post-rebalance resolver.
        return max(1, xpPreview / 12) + basePaws + boost.bonusPaws
    }

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, creditedDuration / duration)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            CozyProgressionRing(
                progress: progress,
                label: .value(isEligible ? "\(pawForecast)" : "—"),
                symbolName: "pawprint.fill",
                size: 72,
                lineWidth: 8,
                accent: CozyPalette.focusJade
            )
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text(isEligible ? "Earning now" : "Keep going — paws unlock at 5 min")
                    .font(CozyType.captionStrong)
                    .foregroundStyle(.secondary)
                Text(isEligible
                    ? "+\(pawForecast) paws · \(xpPreview) XP"
                    : "Almost there — keep going")
                    .font(CozyType.controlStrong)
                    .foregroundStyle(CozyPalette.focusJade)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.25),
                               value: pawForecast)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isEligible
            ? "Forecast: \(pawForecast) paws, \(xpPreview) experience on save"
            : "Reward unlocks at five minutes of focus")
    }
}

struct RewardPreviewRow: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 24)
                .foregroundStyle(.secondary)
            Text(title)
                .font(CozyType.body)
            Spacer()
            Text(value)
                .font(CozyType.body.weight(.semibold))
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
            .font(CozyType.controlStrong)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(CozyPalette.softMint.opacity(0.58)))
            .foregroundStyle(CozyPalette.focusJade)
            .fixedSize()
    }

    private var microcopy: some View {
        Text(phase.microcopy)
            .font(CozyType.body)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
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
        HStack(spacing: 6) {
            ForEach(milestones, id: \.0) { milestone in
                let reached = progress >= milestone.0
                Circle()
                    .fill(reached ? color : Color.secondary.opacity(0.28))
                    // SP-001: stay on the allowed grid (8/12) instead of
                    // 7/10. Visually identical to within a pixel and keeps
                    // the design lint clean.
                    .frame(width: reached ? 12 : 8, height: reached ? 12 : 8)
                    .animation(CozyMotion.snappy(reduceMotion, duration: 0.18), value: reached)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(completedCount) of \(milestones.count) focus phases reached")
    }
}

// PawAwardPop — KeyframeAnimator pop on the paw pill when coinsAvailable
// increments. Three tracks: scale, rotation, vertical drift.
private struct PawAwardPop: ViewModifier {
    let trigger: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct AnimValues {
        var scale: Double = 1.0
        var rotation: Double = 0.0
        var offsetY: Double = 0.0
    }

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .keyframeAnimator(initialValue: AnimValues(), trigger: trigger) { view, values in
                    view
                        .scaleEffect(values.scale)
                        .rotationEffect(.degrees(values.rotation))
                        .offset(y: values.offsetY)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        SpringKeyframe(1.4, duration: 0.15)
                        SpringKeyframe(1.0, duration: 0.25)
                    }
                    KeyframeTrack(\.rotation) {
                        LinearKeyframe(-8.0, duration: 0.12)
                        SpringKeyframe(0.0, duration: 0.2)
                    }
                    KeyframeTrack(\.offsetY) {
                        LinearKeyframe(-12.0, duration: 0.15)
                        SpringKeyframe(0.0, duration: 0.3)
                    }
                }
        }
    }
}

private extension View {
    func pawAwardPop(trigger: Bool) -> some View {
        modifier(PawAwardPop(trigger: trigger))
    }
}

// PawCounterPill — persistent paw-total badge overlaid on the timer ring
// (top-trailing corner). Pulses its border when the paw count increments,
// gated by Reduce Motion (AM-001). Shows live coinsAvailable which is the
// canonical displayed paw total throughout the app.
private struct PawCounterPill: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var dataStore: AppDataStore
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    @State private var pulse = false
    @State private var popTrigger = false

    private var theme: CozyTheme { CozyTheme.named(selectedTheme) }

    var body: some View {
        let strokeColor: Color = pulse && !reduceMotion ? CozyPalette.wasabi.opacity(0.72) : theme.reward.opacity(0.22)
        Label("\(dataStore.progression.coinsAvailable)", systemImage: "pawprint.fill")
            .font(CozyType.captionStrong)
            .foregroundStyle(theme.reward)
            .padding(.horizontal, CozyLayout.badgePaddingSmallH)
            .padding(.vertical, CozyLayout.badgePaddingSmallV)
            .background(
                Capsule(style: .continuous)
                    .fill(theme.reward.opacity(0.12))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(strokeColor, lineWidth: 1.5)
                    )
            )
            .pawAwardPop(trigger: popTrigger)
            .accessibilityLabel("Paws: \(dataStore.progression.coinsAvailable)")
            .onChange(of: dataStore.progression.coinsAvailable) { _, _ in
                guard !reduceMotion else { return }
                popTrigger.toggle()
                pulse = true
                withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.9)) { pulse = false }
            }
    }
}

// PawTickerOverlay — transient "+1 paw" drifters spawned each time the
// FocusTimerStore crosses a 5-minute credited-duration boundary. Apple
// Fitness boundary-celebration precedent: small mid-session validation
// instead of silent grinding. Reduce-Motion fallback dissolves instead of
// drifting upward (per Apple's "highlight fade / color shift" criteria).
private struct PawTickerOverlay: View {
    @EnvironmentObject private var timerStore: FocusTimerStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    let accent: Color

    private struct Floater: Identifiable {
        let id = UUID()
        var phase: CGFloat = 0
    }

    @State private var floaters: [Floater] = []

    var body: some View {
        ZStack {
            ForEach(floaters) { floater in
                Label("+1", systemImage: "pawprint.fill")
                    .font(CozyType.controlStrong)
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(CozyPalette.cardFill(colorScheme).opacity(0.96)))
                    .shadow(color: CozyPalette.lofiInk.opacity(0.12), radius: 4, y: 2)
                    .offset(y: reduceMotion ? 0 : -16 * floater.phase)
                    .opacity(Double(1 - floater.phase))
                    .accessibilityHidden(true)
            }
        }
        .onReceive(timerStore.pawBoundaryDidCross) { _ in
            spawnFloater()
        }
    }

    private func spawnFloater() {
        let floater = Floater()
        floaters.append(floater)
        // Soft tick via CozyFeedback's existing `.add` cue (Pop sound) —
        // intentionally lower-key than the reward sound used for completions.
        CozyFeedback.play(.add)

        if reduceMotion {
            // Dissolve only: no upward offset; fade in→out via the phase ramp.
            withAnimation(CozyMotion.gentle(reduceMotion, duration: 0.6)) {
                advanceFloater(id: floater.id, to: 1.0)
            }
        } else {
            withAnimation(CozyMotion.gentle(reduceMotion, duration: 0.9)) {
                advanceFloater(id: floater.id, to: 1.0)
            }
        }
        // Cleanup after the animation completes so the array doesn't grow.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            floaters.removeAll { $0.id == floater.id }
        }
    }

    private func advanceFloater(id: UUID, to phase: CGFloat) {
        guard let idx = floaters.firstIndex(where: { $0.id == id }) else { return }
        floaters[idx].phase = phase
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
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.reward.opacity(0.16))
                Image(systemName: boost.symbol)
                    .font(CozyType.cardTitle)
                    .foregroundStyle(theme.reward)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text("Tiny boost")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(boost.title)
                    .font(CozyType.rowTitle)
                Text(boost.caption)
                    .font(CozyType.body)
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
                    .frame(width: 24, height: 24)
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
        lifetimeSessionCount: Int = 0,
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
        // Economy rebalance (researched, Scenario B): paw faucet slowed ~3.5×.
        //   basePaws: 1 paw per 5 min → 1 per 15 min
        //   totalPaws compounding: xp/4 → xp/12
        // Realized rate drops from ~45 paws/hr to ~12 paws/hr, closer to
        // Forest's documented 18-22 coins/hr precedent. XP still grants in
        // full so level progress is unchanged — only the spend currency
        // slows. Tone-safe: nothing is ever subtracted.
        let basePaws = eligible ? max(1, Int(creditedDuration / 900)) : 0
        let adventureRoll = eligible
            ? CozyProgression.adventureRoll(
                seed: seed,
                completedMinutes: minutes,
                existingRewards: existingRewards,
                lifetimeSessionCount: lifetimeSessionCount
            )
            : nil
        let rewardPaws = eligible ? basePaws + boost.bonusPaws + (adventureRoll?.duplicatePaws ?? 0) : 0
        let totalPaws = eligible ? max(1, xp / 12) + rewardPaws : 0
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

// MARK: - FocusRingAura

/// Ambient MeshGradient circle behind CozyTimerChrome. Opacity rises from
/// 0.12 (prepare) → 0.45 (deepFocus) so the ring gains a warm halo as the
/// user settles into concentration. 5 fps keeps CPU cost minimal.
/// Reduce Motion: static RadialGradient fallback, no animation.
private struct FocusRingAura: View {
    let phase: FocusPhase
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var targetOpacity: Double {
        switch phase {
        case .prepare:                 return 0.12
        case .settling:                return 0.28
        case .deepFocus, .finalMinute: return 0.45
        case .wrap, .breakTime:        return 0.18
        }
    }

    var body: some View {
        auraLayer
            .frame(width: 248, height: 248)
            .clipShape(Circle())
            .opacity(targetOpacity)
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.2), value: targetOpacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var auraLayer: some View {
        if reduceMotion {
            Circle().fill(
                RadialGradient(
                    colors: [accent.opacity(0.55), accent.opacity(0.0)],
                    center: .center, startRadius: 0, endRadius: 124
                )
            )
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 5.0)) { ctx in
                animatedAura(t: ctx.date.timeIntervalSince1970)
            }
        }
    }

    private func animatedAura(t: Double) -> some View {
        let w: Double = 2 * .pi / 6
        let a: Float  = 0.06
        let cx = 0.5 + Float(sin(t * w)) * a
        let cy = 0.5 + Float(cos(t * w + 1.6)) * a
        return MeshGradient(
            width: 3, height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [cx,  cy  ], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ],
            colors: [
                .clear,               accent.opacity(0.10), .clear,
                accent.opacity(0.10), accent.opacity(0.70), accent.opacity(0.10),
                .clear,               accent.opacity(0.10), .clear
            ],
            background: .clear,
            smoothsColors: true
        )
    }
}

// CozyConfettiBurst — native SwiftUI one-shot confetti overlay for session
// completion. Uses TimelineView + Canvas; no external dependency. 30 pieces
// burst from the top-center, arc outward, fall with gravity, and fade.
// Self-dismisses after 2.4 s. Caller gates by reduceMotion before inserting.
private struct CozyConfettiBurst: View {
    private struct Piece: Identifiable {
        let id: Int
        let color: Color
        let vx: Double    // normalised horizontal velocity (-1…1)
        let vy: Double    // normalised initial upward velocity
        let vr: Double    // rotation speed deg/s
        let w, h: Double  // piece dimensions
        let startDelay: Double
    }

    private static let palette: [Color] = [
        Color(hex: "#FFB4A2"), Color(hex: "#DDD6F3"),
        Color(hex: "#B4D4E7"), Color(hex: "#D9F06A"),
        Color(hex: "#F7C5A0"), Color(hex: "#C9E8FF")
    ]

    private let pieces: [Piece] = (0..<32).map { i in
        let colors = CozyConfettiBurst.palette
        return Piece(
            id: i,
            color: colors[i % colors.count],
            vx: Double.random(in: -1.0...1.0),
            vy: Double.random(in: 0.6...1.2),
            vr: Double.random(in: -360...360),
            w: Double.random(in: 8...14),
            h: Double.random(in: 5...9),
            startDelay: Double.random(in: 0...0.25)
        )
    }

    @State private var startDate: Date = .now
    @State private var visible = true

    var body: some View {
        if visible {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                let elapsed = ctx.date.timeIntervalSince(startDate)
                Canvas { context, size in
                    for piece in pieces {
                        let t = max(0, elapsed - piece.startDelay)
                        guard t > 0 else { continue }
                        // physics: x linear, y parabolic (gravity), fade after 1.4s
                        let x = size.width * 0.5 + piece.vx * t * size.width * 0.45
                        let y = size.height * 0.08 - piece.vy * t * size.height * 0.6
                              + 0.5 * 420 * t * t   // gravity constant
                        let alpha = max(0, 1 - (t - 1.0) / 0.8)
                        guard alpha > 0 && y < size.height + 20 else { continue }
                        let angle = Angle.degrees(piece.vr * t)
                        var ctx2 = context
                        ctx2.opacity = alpha
                        ctx2.translateBy(x: x, y: y)
                        ctx2.rotate(by: angle)
                        ctx2.fill(
                            Path(CGRect(x: -piece.w / 2, y: -piece.h / 2,
                                        width: piece.w, height: piece.h)
                                    .applying(.init(translationX: 0, y: 0))),
                            with: .color(piece.color)
                        )
                    }
                }
                .allowsHitTesting(false)
            }
            .onAppear {
                startDate = .now
                Task {
                    try? await Task.sleep(for: .seconds(2.4))
                    visible = false
                }
            }
        }
    }
}

struct FocusCompletionReview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var dataStore: AppDataStore
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    let summary: FocusCompletionSummary
    @Binding var reflection: String
    let done: () -> Void
    let startAnother: () -> Void
    let openRewards: () -> Void
    @State private var revealStep = 0
    @State private var presentingUnlockSheet = false
    @State private var showStamp = false
    @State private var rewardPulse = false
    @State private var showConfetti = false
    @FocusState private var reflectionFocused: Bool

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    // The unlock sheet is reserved for *moments*: rare rolls (.special / .dream)
    // OR the user's first-ever unlocked reward. Everyday/cozy rolls keep the
    // inline `AdventureRevealView` strip so we don't over-celebrate.
    private var shouldPresentUnlockSheet: Bool {
        guard let roll = summary.adventureRoll, roll.reward != nil else { return false }
        if roll.rarity == .special || roll.rarity == .dream { return true }
        return dataStore.rewards.count <= 1
    }

    private var isFirstEverUnlock: Bool {
        dataStore.rewards.count <= 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showStamp && !reduceMotion {
                Text("✓")
                    .font(CozyType.timer)
                    .foregroundStyle(theme.reward.opacity(0.85))
                    .scaleEffect(showStamp ? 1.0 : 0.4)
                    .opacity(showStamp ? 1.0 : 0)
                    .transition(.opacity.combined(with: .scale(scale: 0.4)))
                    .allowsHitTesting(false)
            }
            HStack(alignment: .top, spacing: 12) {
                MascotView(state: .complete, size: .avatar)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.isRewardEligible ? "Mochi's proud of that one." : "Saved — even a small start counts")
                        .font(CozyType.cardTitle)
                    Text(summary.taskTitle)
                        .font(CozyType.body)
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
                    .font(CozyType.body.weight(.semibold))
                    .foregroundStyle(theme.reward)
                    .transition(.opacity)
            } else if !summary.isRewardEligible {
                CozyFieldHint(text: "Saved. Even tiny sips count — paws unlock from 5 minutes and up.")
            }

            if revealStep >= 2, let adventureRoll = summary.adventureRoll {
                AdventureRevealView(result: adventureRoll)
                    .transition(.opacity)
            }

            TextField("What did Mochi help you get done?", text: $reflection, axis: .vertical)
                .accessibilityIdentifier("focus.reflection")
                .lineLimit(2, reservesSpace: true)
                .cozyTextInput(minHeight: 62, alignment: .topLeading)
                .focused($reflectionFocused)
                .accessibilityLabel("Focus reflection")
                // macOS 15 #110 — opt the reflection field into the full
                // Writing Tools menu (proofread, rewrite, summarize). The
                // note is short-form prose, so the system's writing helpers
                // are exactly the kind of friction-removal we want here.
                .writingToolsBehavior(.complete)

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
        .overlay(alignment: .top) {
            if showConfetti {
                CozyConfettiBurst()
                    .frame(maxWidth: .infinity, maxHeight: 320)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Focus completion review")
        .sheet(isPresented: $presentingUnlockSheet) {
            if let roll = summary.adventureRoll {
                CozyUnlockSheet(
                    result: roll,
                    isFirstEver: isFirstEverUnlock,
                    dismiss: { presentingUnlockSheet = false }
                )
            }
        }
        .onChange(of: presentingUnlockSheet) { _, isPresented in
            guard !isPresented else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                reflectionFocused = true
            }
        }
        .task(id: summary.sessionID) {
            revealStep = 0
            presentingUnlockSheet = false
            showStamp = false
            rewardPulse = false
            showConfetti = false
            reflectionFocused = true
            if reduceMotion {
                revealStep = 2
            } else {
                // Swift 5.7+ Task.sleep(for:) idiom — strictly equivalent to the
                // prior nanoseconds form but readable at a glance and the API
                // Apple now recommends for new code.
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(CozyMotion.spring(reduceMotion, response: 0.25, damping: 0.6)) { showStamp = true }
                if summary.isRewardEligible { showConfetti = true }
                CozyFeedback.play(.reward)
                try? await Task.sleep(for: .milliseconds(600))
                withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.3)) { showStamp = false }
                withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.20)) { revealStep = 1 }
                try? await Task.sleep(for: .milliseconds(220))
                withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.22)) { revealStep = 2 }
            }
            // Trigger persimmon pulse on the Rewards Room button if eligible.
            if revealStep >= 1 && summary.isRewardEligible {
                rewardPulse = true
                try? await Task.sleep(for: .milliseconds(3000))
                rewardPulse = false
            }
            // After the reveal lands, decide whether this unlock deserves a moment.
            // Reduce Motion: skip the small extra delay; present immediately.
            if shouldPresentUnlockSheet {
                if !reduceMotion {
                    try? await Task.sleep(for: .milliseconds(240))
                }
                reflectionFocused = false
                presentingUnlockSheet = true
            }
        }
    }

    @ViewBuilder
    private var completionMetrics: some View {
        SoftMetricBadge(title: "focus", value: "\(summary.minutes)m", symbol: "timer", color: CozyPalette.focusJade)
        if revealStep >= 1, summary.isRewardEligible {
            SoftMetricBadge(title: "XP", value: "+\(summary.xp)", symbol: "sparkles", color: CozyPalette.habitLavender)
                .transition(.opacity)
            SoftMetricBadge(title: "paws", value: "+\(summary.paws)", symbol: "pawprint.fill", color: theme.reward)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var completionButtons: some View {
        // Single label — was "Done" / "Save win" depending on reflection text,
        // but both invoke the same `done` closure. Two terms for the same
        // action is a Nielsen consistency violation.
        Button("Done", action: done)
            .cozySecondaryButton(minWidth: 96)
            .accessibilityIdentifier("focus.doneReview")
        // "Start another" uses the last-picked duration instead of a magic 5m,
        // matching the user's most recent intent.
        Button("Start another", action: startAnother)
            .cozySecondaryButton(minWidth: 132)
            .accessibilityIdentifier("focus.startAnother")
        if summary.isRewardEligible {
            Button("Rewards Room", action: openRewards)
                .cozyPrimaryButton(minWidth: 132)
                .accessibilityIdentifier("focus.rewardsRoom")
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(CozyPalette.persimmon.opacity(rewardPulse ? 0.6 : 0), lineWidth: 2)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatCount(3, autoreverses: true), value: rewardPulse)
                )
        }
    }
}

// CozyUnlockSheet — researched modal-moment for rare/first-ever reward unlocks.
// Pattern: Duolingo XP-earn / Finch energy unlock / Stardew level-up. The inline
// `AdventureRevealView` keeps the everyday/cozy roll calm and quick; this sheet
// is reserved for moments that should actually feel like a moment.
struct CozyUnlockSheet: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    let result: AdventureRollResult
    let isFirstEver: Bool
    let dismiss: () -> Void

    // Two-stage reveal — researched recipe (Duolingo chest + Stardew geode).
    //   .wrapped:  gift box with idle wiggle, tap target
    //   .opening:  brief 180ms wrap fade-out
    //   .revealed: item flies in with spring
    // The deliberate pause between action (tap) and reveal honors the
    // variable-reward dopamine sequence (anticipation > suspense > reveal).
    private enum UnlockStage { case wrapped, opening, revealed }
    @State private var stage: UnlockStage = .wrapped
    @State private var wrapWiggle = false

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    private var rarityColor: Color {
        CozyPalette.catalogColor(result.rarity.colorHex)
    }

    private var eyebrow: String {
        switch stage {
        case .wrapped, .opening:
            return isFirstEver ? "Your first surprise" : "A new \(result.rarity.rawValue.lowercased()) surprise"
        case .revealed:
            return isFirstEver ? "Your first unlock" : "\(result.rarity.rawValue) unlock"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(eyebrow)
                .font(.caption.weight(.semibold))
                .foregroundStyle(rarityColor)
                .textCase(.uppercase)
                .tracking(0.8)
                .accessibilityAddTraits(.isHeader)

            ZStack {
                // Stage 1 — wrapped gift box. Idle wiggle draws the eye to the
                // tappable target. Fades out as the wrap opens.
                if stage != .revealed {
                    Button(action: openWrap) {
                        RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
                            .fill(LinearGradient(
                                colors: [rarityColor.opacity(0.34),
                                         rarityColor.opacity(0.14)],
                                startPoint: .top,
                                endPoint: .bottom))
                            .overlay(
                                Image(systemName: "gift.fill")
                                    .font(CozyType.pageTitle)
                                    .foregroundStyle(rarityColor)
                            )
                            .frame(width: 160, height: 160)
                            .rotationEffect(.degrees(reduceMotion ? 0 : (wrapWiggle ? 3 : -3)))
                            .scaleEffect(stage == .opening ? 1.18 : 1.0)
                            .opacity(stage == .opening ? 0 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tap to open your \(result.rarity.rawValue) surprise")
                    .accessibilityIdentifier("focus.unlockSheet.wrap")
                }

                // Stage 3 — item flies in. Spring bounce after the wrap
                // disappears; sprinkles overlay only on rare tiers.
                if stage == .revealed {
                    RarityIcon(symbol: result.reward?.symbolName ?? "pawprint.fill", rarity: result.rarity, size: 128)
                        .transition(.opacity)
                        .overlay(alignment: .top) {
                            if !reduceMotion, result.rarity == .special || result.rarity == .dream {
                                CelebrationSprinkles(size: 220, color: rarityColor)
                                    .allowsHitTesting(false)
                                    .accessibilityHidden(true)
                            }
                        }
                }
            }
            .frame(width: 220, height: 220)

            VStack(spacing: 6) {
                Text(stage == .revealed ? (result.reward?.name ?? "Bonus paws") : "Tap the gift to peek inside")
                    .font(CozyType.cardTitle)
                    .foregroundStyle(CozyPalette.primaryText(colorScheme))
                    .multilineTextAlignment(.center)
                if let reward = result.reward, stage == .revealed {
                    Text(reward.category.capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                        .textCase(.uppercase)
                        .tracking(0.6)
                }
            }

            Text(detailLine)
                .font(CozyType.body)
                .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(stage == .revealed ? 1 : 0.6)

            Button(action: dismiss) {
                Label(stage == .revealed ? "Take it to the room" : "Tap the gift",
                      systemImage: stage == .revealed ? "sparkles" : "hand.tap.fill")
                    .frame(maxWidth: .infinity)
            }
            .cozyPrimaryButton(fullWidth: true)
            .disabled(stage != .revealed)
            // SM-001: Escape dismisses too. Existing primary CTA already
            // provides the visible affordance, so no extra X needed.
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("focus.unlockSheet.dismiss")
        }
        .padding(28)
        .frame(idealWidth: 360, maxWidth: 480)
        .background(
            // Card-style sheet on cardFill (was theme.canvas — same color as
            // host sheet on macOS). cardFill + rarity border + soft shadow
            // makes the modal pop above the host window.
            RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
                .fill(CozyPalette.cardFill(colorScheme))
                .shadow(color: CozyPalette.lofiInk.opacity(colorScheme == .dark ? 0.32 : 0.10), radius: 22, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
                .stroke(rarityColor.opacity(0.45), lineWidth: 1.5)
        )
        .accessibilityAddTraits(.isModal)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(eyebrow). \(result.reward?.name ?? "Bonus paws").")
        .onAppear {
            // Idle wiggle on the wrap so the user notices it's tappable —
            // never under Reduce Motion (per Apple's reduced-motion criteria,
            // motion-as-affordance is replaced by static visual contrast).
            guard !reduceMotion else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                wrapWiggle = true
            }
        }
    }

    private func openWrap() {
        CozyFeedback.play(.reward)
        if reduceMotion {
            // Cross-dissolve: skip the wrap-scale + spring; jump to revealed.
            stage = .revealed
            return
        }
        withAnimation(CozyMotion.gentle(reduceMotion, duration: 0.18)) { stage = .opening }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(CozyMotion.spring(reduceMotion, response: 0.42, damping: 0.62)) {
                stage = .revealed
            }
        }
    }

    private var detailLine: String {
        if let reward = result.reward {
            if isFirstEver {
                return "\(reward.name) is yours. Cosmetic only. Free. You earned it."
            }
            return "Cosmetic only. Free. Nothing to do — just enjoy."
        }
        return "Duplicate became +\(result.duplicatePaws) paws. Owned surprises turn into progress."
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
                    .foregroundStyle(CozyPalette.catalogColor(result.rarity.colorHex))
                Text(revealTitle)
                    .font(CozyType.rowTitle)
                    .lineLimit(2)
                Text(revealDetail)
                    .font(CozyType.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous)
                .fill(CozyPalette.catalogColor(result.rarity.colorHex).opacity(0.12))
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
    static let cozyDidWakeFromSleep = Notification.Name("CozyTimeDidWakeFromSleep")
}

struct FocusPreviewCard: View {
    @EnvironmentObject private var timerStore: FocusTimerStore

    var body: some View {
        Button {
            NotificationCenter.default.post(name: .cozyOpenSection, object: AppSection.focus.rawValue)
        } label: {
            TimelineView(.periodic(from: .now, by: timerStore.isActive ? 1 : 60)) { context in
                let hasTimerStatus = timerStore.isActive || timerStore.needsCompletionReview
                HStack(spacing: 16) {
                    MascotView(state: hasTimerStatus ? mascotState(for: timerStore.phase(at: context.date)) : .idle, size: .card)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(previewEyebrow(at: context.date))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(hasTimerStatus ? timerStore.activeTaskTitle : "Start one small session")
                            .font(CozyType.rowTitle)
                        Text(previewMetric(at: context.date))
                            .font(CozyType.cardTitle)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("mascotName") private var mascotName = "Mochi"
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    // Menu-bar quick-start respects the last duration the user picked in
    // FocusView, so 25→90 doesn't silently snap back to 25.
    @AppStorage("focus.lastFocusMinutes") private var lastFocusMinutes = 25
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
                        .transition(.opacity)
                }
                todayProgressCard
                focusDiaryCard
                quickCaptureCard
                bottomActions
            }
            .padding(16)
        }
        .frame(minWidth: 340, idealWidth: 360, maxWidth: 480, maxHeight: 640)
        .tint(theme.accent)
    }

    private var timerHero: some View {
        let date = timerStore.currentDate
        let phase = timerStore.phase(at: date)
        let accent = CozyFocusColor.color(for: phase)
        let hasTimer = timerStore.isActive || timerStore.needsCompletionReview

        return MenuBarSurface {
            VStack(alignment: .leading, spacing: 12) {
                menuBarHeroHeader(date: date, accent: accent)

                HStack(alignment: .center, spacing: CozyLayout.formRowSpacing) {
                    MascotView(state: .idle, size: .inline)
                        .accessibilityHidden(true)
                    Text(menuBarTimerText(at: date))
                        .font(CozyType.metric)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(accent)
                        .accessibilityIdentifier("menubar.timer")
                }

                // UX LOW #107: paw count + weekly minutes line beneath
                // the timer state. Tap → reward haptic so the user
                // always has a tiny tactile cue when peeking at the
                // popover (mirrors the "tap a reward" pattern in the
                // Rewards Room).
                menuBarPawsLine

                if hasTimer {
                    VStack(alignment: .leading, spacing: 5) {
                        CozyLinearProgressBar(value: timerStore.progress(at: date), color: accent)
                        HStack {
                            Text(phase.microcopy)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(timerStore.progress(at: date) * 100))%")
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

    private func menuBarHeroHeader(date: Date, accent: Color) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                menuBarHeroIdentity
                Spacer(minLength: 8)
                MenuBarPhasePill(title: menuBarModeLabel(at: date), color: accent)
                    .fixedSize()
            }

            VStack(alignment: .leading, spacing: 8) {
                menuBarHeroIdentity
                MenuBarPhasePill(title: menuBarModeLabel(at: date), color: accent)
                    .fixedSize()
            }
        }
    }

    private var menuBarHeroIdentity: some View {
        HStack(alignment: .top, spacing: 12) {
            MascotView(state: menuBarMascotState, size: .avatar)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(menuBarHeadline)
                    .font(CozyType.cardTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(menuBarSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// UX LOW #107 — small paws + weekly-minutes line under the menu-bar
    /// timer. Tappable for a reward haptic; the count itself is read-only
    /// (the Rewards Room is the actual spend surface, accessible via the
    /// bottomActions "Open App" button).
    private var menuBarPawsLine: some View {
        let coins = dataStore.progression.coinsAvailable
        let minutes = weeklyFocusMinutes
        return Button {
            CozyHaptics.perform(.reward)
        } label: {
            Label("\(coins) paws · \(minutes)m this week", systemImage: "pawprint.fill")
                .font(CozyType.captionStrong)
                .foregroundStyle(theme.reward)
                .padding(.horizontal, CozyLayout.badgePaddingMediumH)
                .padding(.vertical, CozyLayout.badgePaddingSmallV)
                .background(
                    Capsule(style: .continuous)
                        .fill(theme.reward.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(coins) paws available. \(minutes) focus minutes this week.")
        .accessibilityIdentifier("menubar.pawsLine")
    }

    /// Sum of completed minutes across the trailing 7 days (matches the
    /// Stats / WeeklyDigest window). Reused by `menuBarPawsLine` so the
    /// popover and the Stats card never disagree.
    private var weeklyFocusMinutes: Int {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -6, to: today) else { return 0 }
        return dataStore.focusSessions
            .filter { session in
                let day = calendar.startOfDay(for: session.reportingDate)
                return day >= start && day <= today
            }
            .reduce(0) { $0 + $1.completedMinutes }
    }

    private var todayProgressCard: some View {
        MenuBarSurface {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Today", systemImage: "calendar")
                        .font(CozyType.controlStrong)
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
                        .font(CozyType.controlStrong)
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
                        .font(CozyType.body.weight(.semibold))
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
                    HStack(spacing: 10) {
                        MascotView(state: .idle, size: .inline)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("No focus saved today")
                                .font(CozyType.body.weight(.semibold))
                            Text("Finish a session and Mochi will log it here.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("menubar.focusDiary")
    }

    private var quickCaptureCard: some View {
        MenuBarSurface {
            VStack(alignment: .leading, spacing: 9) {
                Label("Add task", systemImage: "plus.bubble.fill")
                    .font(CozyType.controlStrong)
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
                            .frame(width: 20, height: 20)
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
                Label("Save this win", systemImage: "tray.and.arrow.down.fill")
                    .frame(maxWidth: .infinity)
            }
            .cozySecondaryButton(fullWidth: true)
            .accessibilityIdentifier("menubar.saveWithoutNote")
        } else if timerStore.isActive {
            Button {
                timerStore.cancel()
                timerStore.reset(duration: TimeInterval(max(1, lastFocusMinutes) * 60))
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
        // Reflect the actual duration this button will commit (was hardcoded
        // "25m" even though startMenuBarFocus already uses lastFocusMinutes).
        let label = CozyFormatters.durationLabel(TimeInterval(max(1, lastFocusMinutes) * 60))
        return pendingQuickTaskTitle.isEmpty ? "Start \(label) focus" : "Start \(label) focus on typed task"
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
        let duration = TimeInterval(max(1, lastFocusMinutes) * 60)
        if clean.isEmpty {
            timerStore.start(taskTitle: "Quick focus", duration: duration)
        } else {
            let task = TaskItem(title: clean, dueDate: Date(), priority: 1)
            dataStore.addTask(task)
            timerStore.start(taskTitle: task.title, taskID: task.id, duration: duration)
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
            lifetimeSessionCount: dataStore.focusSessions.count,
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
        withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
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
                    .font(CozyType.cardTitle)
                    .foregroundStyle(CozyPalette.focusJade)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Saved to diary")
                        .font(CozyType.controlStrong)
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
        CozyPill(title: title, intent: .accent(color), size: .small)
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
                    .frame(width: 16, alignment: .leading)
                    .foregroundStyle(color)
                Text(value)
                    .font(CozyType.controlStrong)
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
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
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
