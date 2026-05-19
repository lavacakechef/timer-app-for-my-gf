import AppKit
import CozyCore
import SwiftUI

enum CountdownsPresentation {
    case full
    case composerOnly
}

struct CountdownsView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var notifications: NotificationService
    private let presentation: CountdownsPresentation

    @State private var title = ""
    @State private var targetDate = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var remindersEnabled = false
    @State private var lastAddedCountdown: CountdownEvent?
    @State private var lastAddedCountdownScheduledAlerts = 0

    init(presentation: CountdownsPresentation = .full) {
        self.presentation = presentation
    }

    var body: some View {
        ScrollView {
            content
                .modifier(CountdownsContentFrame(presentation: presentation))
        }
        .accessibilityIdentifier(presentation == .full ? "screen.countdowns" : "countdown.composer")
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: CozyLayout.sectionSpacing) {
            if presentation == .full {
                SectionHeader(
                    title: "Countdowns",
                    subtitle: "Turn future moments into things to look forward to.",
                    mascotState: .countdown
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("New countdown")
                        .font(CozyType.heroCardTitle)
                    Text("Name the moment, pick the date, then save it to Calendar.")
                        .font(CozyType.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            countdownComposer

            if presentation == .full {
                if dataStore.countdowns.isEmpty {
                    EmptyStateView(
                        title: "Pick a first day to look forward to",
                        message: "An exam, a trip, a birthday, a tiny release date. Mochi nudges you the day before.",
                        mascotState: .countdown,
                        eyebrow: "Countdowns",
                        primaryActionTitle: "Create a 7-day countdown",
                        primaryAction: {
                            title = "First cozy countdown"
                            addCountdown()
                        }
                    )
                        .frame(minHeight: 280)
                } else {
                    // TODO(UX-86): drag-to-reorder needs a `List` container and a
                    // `CountdownEvent.sortIndex` persisted field before `.onMove`
                    // can replace the current targetDate sort. Keeping LazyVStack
                    // until both pieces exist.
                    LazyVStack(spacing: CozyLayout.gridSpacing) {
                        ForEach(dataStore.countdowns.sorted { $0.targetDate < $1.targetDate }) { event in
                            CountdownCard(event: event)
                        }
                    }
                }
            }
        }
    }

    private var countdownComposer: some View {
        VStack(alignment: .leading, spacing: CozyLayout.formRowSpacing) {
            titleField

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: CozyLayout.formRowSpacing) {
                    datePicker
                        .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
                    reminderToggle
                        .frame(width: 220, alignment: .leading)
                    addButton
                        .frame(width: 156, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: CozyLayout.formRowSpacing) {
                    datePicker
                    reminderToggle
                    addButton
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            dateQuickChoicesRow

            if let lastAddedCountdown {
                countdownAddFeedback(event: lastAddedCountdown)
                    .transition(.opacity)
            }
        }
        .cozyCard()
    }

    private struct CountdownsContentFrame: ViewModifier {
        let presentation: CountdownsPresentation

        func body(content: Content) -> some View {
            if presentation == .full {
                content.cozyPageFrame()
            } else {
                content
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var titleField: some View {
        CozyLabeledControl(
            title: "Countdown",
            symbolName: "hourglass",
            minWidth: 260,
            hint: cleanTitle.isEmpty ? "Name the countdown first." : nil
        ) {
            TextField("Trip, exam, release...", text: $title)
                .onSubmit(addCountdown)
                .accessibilityIdentifier("countdown.title")
                .cozyTextInput(minWidth: 260, alignment: .leading)
        }
        .layoutPriority(1)
    }

    private var datePicker: some View {
        CozyLabeledControl(title: "Date", symbolName: "calendar", minWidth: 220) {
            CozyDateInput(date: $targetDate, label: "Countdown date", includeInlineQuickChoices: false)
                .accessibilityIdentifier("countdown.date")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Quick-pick chips ("Tomorrow / 7 days / 30 days") rendered as a full-width
    /// row underneath the date + action columns. Previously these lived inside
    /// the DATE column's vertical stack, which made the column taller than the
    /// ACTION column and produced a visibly jagged form row.
    private var dateQuickChoicesRow: some View {
        CozyDateInput(date: $targetDate, label: "Countdown date", includeInlineQuickChoices: false).quickChoicesRow
            .accessibilityIdentifier("countdown.date.quickPicks")
    }

    private var addButton: some View {
        CozyLabeledControl(title: "Action", symbolName: "plus.circle", minWidth: 220) {
            Button {
                addCountdown()
            } label: {
                Label("Add", systemImage: "plus")
            }
            .cozyPrimaryButton(minWidth: 128, fullWidth: true)
            .disabled(cleanTitle.isEmpty || isPastTargetDate)
            .help(addButtonHelp)
            .accessibilityHint(addButtonHelp)
            .accessibilityIdentifier("countdown.add")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reminderToggle: some View {
        CozyLabeledControl(title: "Alerts", symbolName: "bell.badge", minWidth: 220) {
            CozyToggleRow(
                title: "Reminders",
                subtitle: "7d, 1d, today",
                isOn: $remindersEnabled
            )
            .accessibilityIdentifier("countdown.reminders")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addCountdown() {
        guard !cleanTitle.isEmpty, !isPastTargetDate else { return }
        let event = CountdownEvent(
            title: cleanTitle,
            targetDate: targetDate,
            stickerName: autoSticker(for: cleanTitle),
            remindersEnabled: remindersEnabled
        )
        dataStore.addCountdown(event)
        lastAddedCountdownScheduledAlerts = remindersEnabled ? -1 : 0
        if remindersEnabled {
            Task {
                guard await MainActor.run(body: { dataStore.countdowns.contains { $0.id == event.id } }) else { return }
                let scheduledCount = await notifications.scheduleCountdownMilestones(for: event)
                await MainActor.run {
                    guard dataStore.countdowns.contains(where: { $0.id == event.id }) else {
                        Task { await notifications.cancelCountdownNotifications(for: event.id) }
                        return
                    }
                    if scheduledCount == 0 {
                        dataStore.updateCountdown(withID: event.id, remindersEnabled: false)
                    }
                    lastAddedCountdownScheduledAlerts = scheduledCount
                }
            }
        }
        CozyFeedback.play(.add)
        lastAddedCountdown = event
        title = ""
    }

    private func countdownAddFeedback(event: CountdownEvent) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Label(countdownAddFeedbackText(for: event), systemImage: countdownAddFeedbackSymbol(for: event))
                    .font(CozyType.captionStrong)
                    .foregroundStyle(event.remindersEnabled && lastAddedCountdownScheduledAlerts == 0 ? CozyPalette.persimmon : CozyPalette.focusJade)
                Text(event.title)
                    .font(CozyType.captionStrong)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("Undo") {
                dataStore.deleteCountdown(id: event.id)
                Task { await notifications.cancelCountdownNotifications(for: event.id) }
                lastAddedCountdown = nil
                CozyFeedback.play(.undo)
            }
            .cozyGhostButton(minWidth: 76)
            Button {
                addPrepTask(for: event)
                lastAddedCountdown = nil
            } label: {
                Label("Add prep task", systemImage: "checklist")
            }
            .cozySecondaryButton(minWidth: 132)
        }
        .padding(.top, 2)
        .accessibilityIdentifier("countdown.add.feedback")
    }

    private func countdownAddFeedbackText(for event: CountdownEvent) -> String {
        guard event.remindersEnabled else { return "Countdown saved" }
        if lastAddedCountdownScheduledAlerts < 0 { return "Countdown saved. Scheduling alerts..." }
        return lastAddedCountdownScheduledAlerts > 0
            ? "Countdown saved with \(lastAddedCountdownScheduledAlerts) alerts"
            : "Countdown saved. Alerts need notification permission."
    }

    private func countdownAddFeedbackSymbol(for event: CountdownEvent) -> String {
        event.remindersEnabled && lastAddedCountdownScheduledAlerts == 0 ? "bell.slash.fill" : "checkmark.circle.fill"
    }

    private func addPrepTask(for event: CountdownEvent) {
        let task = TaskItem(
            title: "Prep for \(event.title)",
            dueDate: Date(),
            priority: 1,
            listName: "Countdowns",
            tagText: "prep",
            estimatedMinutes: 15
        )
        dataStore.addTask(task)
        CozyFeedback.play(.add)
    }

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isPastTargetDate: Bool {
        Calendar.autoupdatingCurrent.startOfDay(for: targetDate) < Calendar.autoupdatingCurrent.startOfDay(for: Date())
    }

    private var addButtonHelp: String {
        if cleanTitle.isEmpty { return "Type a countdown title first." }
        if isPastTargetDate { return "Pick today or a future date." }
        return "Add this countdown."
    }

    private func autoSticker(for title: String) -> String {
        let lower = title.lowercased()
        if lower.contains("exam") || lower.contains("study") || lower.contains("test") { return "book.closed.fill" }
        if lower.contains("trip") || lower.contains("flight") || lower.contains("travel") { return "suitcase.fill" }
        if lower.contains("birthday") || lower.contains("party") { return "party.popper.fill" }
        if lower.contains("date") || lower.contains("anniversary") { return "heart.fill" }
        if lower.contains("release") || lower.contains("deadline") || lower.contains("ship") { return "sparkles" }
        return "rosette"
    }
}

struct CountdownCard: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var notifications: NotificationService
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingDetails = false
    @State private var isConfirmingDelete = false
    @State private var isEditing = false
    @State private var draftTitle = ""
    @State private var draftDate = Date()
    @State private var draftNotes = ""
    @State private var draftRemindersEnabled = false
    @State private var savedEditFeedback = false
    @State private var savedEditAlertCount: Int?
    let event: CountdownEvent

    var body: some View {
        let phase = event.phase()
        VStack(alignment: .leading, spacing: 16) {
            // Visual audit CRITICAL #4: row mixed a 56pt sticker, ~28pt phase
            // badge, ~32pt reminder pill, and 44pt buttons. Default .center
            // alignment drifted chip mid-heights relative to the buttons.
            // Explicit .center + tight spacing aligns to a shared band.
            HStack(alignment: .center, spacing: 10) {
                CountdownStickerFrame(event: event, phase: phase)
                Spacer()
                CountdownPhaseBadge(phase: phase, color: daysColor)
                reminderStatus
                Button {
                    withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
                        syncDraft()
                        isEditing.toggle()
                        savedEditFeedback = false
                        isConfirmingDelete = false
                    }
                } label: {
                    Image(systemName: isEditing ? "xmark" : "pencil")
                        .frame(width: 24, height: 24)
                }
                .cozyIconButton(size: CozyLayout.hitSize)
                .contentShape(Rectangle())
                .help(isEditing ? "Close countdown edit" : "Edit countdown")
                .accessibilityLabel(isEditing ? "Close countdown edit" : "Edit \(event.title)")
                Button(role: .destructive) {
                    withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
                        isConfirmingDelete.toggle()
                        isEditing = false
                    }
                } label: {
                    Image(systemName: isConfirmingDelete ? "xmark" : "trash")
                        .frame(width: 24, height: 24)
                }
                .cozyIconButton(size: CozyLayout.hitSize)
                .contentShape(Rectangle())
                .help(isConfirmingDelete ? "Cancel delete" : "Delete countdown")
                .accessibilityLabel("Delete \(event.title)")
            }
            if isConfirmingDelete {
                deleteConfirmation
                    .transition(.opacity)
            }
            if isEditing {
                editPanel
                    .transition(.opacity)
            } else if savedEditFeedback {
                Label(savedEditText, systemImage: savedEditAlertCount == 0 ? "bell.slash.fill" : "checkmark.circle.fill")
                    .font(CozyType.captionStrong)
                    .foregroundStyle(savedEditAlertCount == 0 ? CozyPalette.persimmon : CozyPalette.focusJade)
                    .transition(.opacity)
            }
            Text(event.title)
                .font(CozyType.cardTitle)
                .lineLimit(2)
            Text(daysText)
                .font(CozyType.metric)
                .foregroundStyle(daysColor)
            Text(phaseMicrocopy(phase))
                .font(CozyType.controlStrong)
                .foregroundStyle(.secondary)
            CozyLinearProgressBar(value: event.progress(), color: daysColor)
                .accessibilityLabel("Countdown progress")
                .accessibilityValue("\(Int(event.progress() * 100)) percent")
            CountdownMilestoneRail(days: event.daysRemaining(), color: daysColor)
            CountdownPrepPrompt(event: event, phase: phase)
            if phase.isOverdue {
                CountdownRecoveryActions(event: event)
            }

            CozyDisclosureSection(title: "Milestones and dates", symbolName: "calendar", isExpanded: $showingDetails) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Started \(CozyFormatters.shortDate.string(from: event.createdAt))", systemImage: "flag.fill")
                        Spacer()
                        Label(CozyFormatters.shortDate.string(from: event.targetDate), systemImage: "party.popper.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    if !event.notes.isEmpty {
                        Text(event.notes)
                            .font(CozyType.body)
                    }
                }
                .padding(.top, 4)
            }
        }
        .cozyCard()
        .contextMenu {
            Button {
                withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
                    syncDraft()
                    isEditing = true
                    savedEditFeedback = false
                    isConfirmingDelete = false
                }
            } label: {
                Label("Edit…", systemImage: "pencil")
            }
            Button {
                // Best-effort jump to the system Calendar app. The "ical://"
                // scheme is the documented macOS handler URL; if a future
                // Calendar app version drops support we silently no-op.
                if let url = URL(string: "ical://") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("Open in Calendar app", systemImage: "calendar")
            }
            Divider()
            Button(role: .destructive) {
                deleteCountdown()
                CozyFeedback.play(.delete)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .onAppear(perform: syncDraft)
        .onChange(of: event) {
            if !isEditing {
                syncDraft()
            }
        }
        .accessibilityIdentifier("countdown.card")
    }

    private var daysText: String {
        let days = event.daysRemaining()
        if days == 0 { return "Today" }
        if days > 0 { return "\(days) \(days == 1 ? "day" : "days")" }
        let abs = abs(days)
        return "\(abs) \(abs == 1 ? "day" : "days") ago"
    }

    private var daysColor: Color {
        event.daysRemaining() < 0 ? CozyPalette.overdue : CozyPalette.countdownBerry
    }

    private var deleteConfirmation: some View {
        HStack(spacing: 10) {
            Label("Delete this countdown?", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CozyPalette.overdue)
            Spacer()
            Button("Keep") {
                withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
                    isConfirmingDelete = false
                }
            }
            .cozyGhostButton(minWidth: 76)
            Button(role: .destructive) {
                deleteCountdown()
                CozyFeedback.play(.delete)
            } label: {
                Text("Delete")
            }
            .cozyDestructiveButton(minWidth: 76)
            .accessibilityIdentifier("countdown.delete.confirm")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous)
                .fill(CozyPalette.overdue.opacity(0.08))
        )
        .accessibilityIdentifier("countdown.delete.prompt")
    }

    private var reminderStatus: some View {
        Label(event.remindersEnabled ? "Alerts on" : "Visual only", systemImage: event.remindersEnabled ? "bell.badge.fill" : "eye.fill")
            .font(CozyType.captionStrong)
            .foregroundStyle(event.remindersEnabled ? CozyPalette.focusJade : .secondary)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(
                Capsule(style: .continuous)
                    .fill((event.remindersEnabled ? CozyPalette.softMint : CozyPalette.lavenderMist).opacity(0.55))
            )
            .accessibilityIdentifier("countdown.reminder.status")
    }

    private var editPanel: some View {
        VStack(alignment: .leading, spacing: CozyLayout.formRowSpacing) {
            CozyResponsiveFormRow {
                editTitleField
            } trailing: {
                editDateField
                editReminderToggle
            } auxiliary: {
                editDateQuickChoicesRow
            }
            CozyLabeledControl(title: "Notes", symbolName: "note.text", minWidth: 260) {
                TextField("Tiny prep note...", text: $draftNotes)
                    .cozyTextInput(minWidth: 260, alignment: .leading)
                    .accessibilityIdentifier("countdown.edit.notes")
            }
            HStack(spacing: 8) {
                CozyFieldHint(text: editHelpText, isError: !canSaveEdit)
                Spacer()
                Button("Cancel") {
                    withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
                        syncDraft()
                        isEditing = false
                    }
                }
                .cozyGhostButton(minWidth: 76)
                Button {
                    saveEdit()
                } label: {
                    Label("Save", systemImage: "checkmark")
                }
                .cozyPrimaryButton(minWidth: 92)
                .disabled(!canSaveEdit)
                .accessibilityIdentifier("countdown.edit.save")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
                .fill(CozyPalette.quietContainer(colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
                        .stroke(CozyPalette.neutralBorder, lineWidth: 1)
                )
        )
        .accessibilityIdentifier("countdown.edit.panel")
    }

    private var editTitleField: some View {
        CozyLabeledControl(title: "Name", symbolName: "hourglass", minWidth: 220) {
            TextField("Countdown name", text: $draftTitle)
                .cozyTextInput(minWidth: 220, alignment: .leading)
                .accessibilityIdentifier("countdown.edit.title")
        }
    }

    private var editDateField: some View {
        CozyLabeledControl(title: "Date", symbolName: "calendar", minWidth: 220) {
            CozyDateInput(date: $draftDate, label: "Countdown date", includeInlineQuickChoices: false)
                .accessibilityIdentifier("countdown.edit.date")
        }
    }

    private var editDateQuickChoicesRow: some View {
        CozyDateInput(date: $draftDate, label: "Countdown date", includeInlineQuickChoices: false).quickChoicesRow
            .accessibilityIdentifier("countdown.edit.date.quickPicks")
    }

    private var editReminderToggle: some View {
        CozyLabeledControl(title: "Alerts", symbolName: "bell.badge", minWidth: 220) {
            CozyToggleRow(
                title: "Reminders",
                subtitle: "7d, 1d, today",
                isOn: $draftRemindersEnabled
            )
            .accessibilityIdentifier("countdown.edit.reminders")
        }
    }

    private func deleteCountdown() {
        let eventID = event.id
        dataStore.deleteCountdown(id: eventID)
        Task { await notifications.cancelCountdownNotifications(for: eventID) }
    }

    private var cleanDraftTitle: String {
        draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSaveEdit: Bool {
        !cleanDraftTitle.isEmpty
            && Calendar.autoupdatingCurrent.startOfDay(for: draftDate) >= Calendar.autoupdatingCurrent.startOfDay(for: Date())
    }

    private var editHelpText: String {
        if cleanDraftTitle.isEmpty { return "Name the countdown before saving." }
        if !canSaveEdit { return "Pick today or a future date." }
        return draftRemindersEnabled ? "Alerts will be rescheduled after saving." : "Saved as a visual countdown."
    }

    private func syncDraft() {
        draftTitle = event.title
        draftDate = event.targetDate
        draftNotes = event.notes
        draftRemindersEnabled = event.remindersEnabled
    }

    private func saveEdit() {
        guard canSaveEdit else { return }
        let updated = CountdownEvent(
            id: event.id,
            title: cleanDraftTitle,
            targetDate: draftDate,
            createdAt: event.createdAt,
            themeName: event.themeName,
            stickerName: event.stickerName,
            notes: draftNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            remindersEnabled: draftRemindersEnabled
        )
        dataStore.updateCountdown(updated)
            Task {
                let scheduledCount: Int
                if updated.remindersEnabled {
                    scheduledCount = await notifications.scheduleCountdownMilestones(for: updated)
                } else {
                    await notifications.cancelCountdownNotifications(for: updated.id)
                    scheduledCount = -1
                }
                await MainActor.run {
                    savedEditAlertCount = scheduledCount
                    if updated.remindersEnabled && scheduledCount == 0 {
                        dataStore.updateCountdown(withID: updated.id, remindersEnabled: false)
                    }
                }
            }
        CozyFeedback.play(.complete)
        withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
            isEditing = false
            savedEditFeedback = true
        }
    }

    private var savedEditText: String {
        guard let savedEditAlertCount else {
            return event.remindersEnabled ? "Countdown updated" : "Countdown updated"
        }
        if savedEditAlertCount > 0 { return "Countdown updated with \(savedEditAlertCount) alerts" }
        if savedEditAlertCount == 0 { return "Countdown updated. Alerts need notification permission." }
        return "Countdown updated"
    }

    private func phaseMicrocopy(_ phase: CountdownPhase) -> String {
        switch phase {
        case .longRange:
            return "Dream board mode. One tiny prep note is enough."
        case .warmingUp:
            return "Prep season. Make the next step cute and small."
        case .finalWeek:
            return "Final sparkle week. Pick one setup task today."
        case .tomorrow:
            return "Pack the tiny bag. Future you gets the assist."
        case .today:
            return "It’s happening. Celebrate, then save one memory."
        case .overdue:
            return "Soft reset. Reschedule, finish, or let it go."
        }
    }
}

struct CountdownRecoveryActions: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var notifications: NotificationService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmingLetGo = false
    @State private var addedResetTaskID: UUID?
    let event: CountdownEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    recoveryButtons
                }
                VStack(alignment: .leading, spacing: 8) {
                    recoveryButtons
                }
            }
            if confirmingLetGo {
                HStack(spacing: 8) {
                    Text("Remove this countdown?")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Keep") {
                        withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
                            confirmingLetGo = false
                        }
                    }
                    .cozyGhostButton(minWidth: 76)
                    Button(role: .destructive) {
                        let eventID = event.id
                        dataStore.deleteCountdown(id: eventID)
                        Task { await notifications.cancelCountdownNotifications(for: eventID) }
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
            if addedResetTaskID != nil {
                Text("Reset task added")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(CozyPalette.focusJade)
                    .transition(.opacity)
            }
        }
        .accessibilityIdentifier("countdown.recovery")
        .onAppear(perform: syncExistingResetTask)
    }

    @ViewBuilder
    private var recoveryButtons: some View {
        Button {
            reschedule(days: 1)
            CozyFeedback.play(.undo)
        } label: {
            Label("Move to tomorrow", systemImage: "calendar.badge.plus")
        }
        .cozySecondaryButton(minWidth: 160)

        Button {
            addResetTask()
            CozyFeedback.play(.add)
        } label: {
            Label(addedResetTaskID == nil ? "Add reset task" : "Reset task added", systemImage: addedResetTaskID == nil ? "arrow.clockwise" : "checkmark.circle.fill")
        }
        .cozySecondaryButton(minWidth: 150)
        .disabled(addedResetTaskID != nil)

        Button(role: .destructive) {
            withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
                confirmingLetGo.toggle()
            }
        } label: {
            Label("Let go", systemImage: "trash")
        }
        .cozyDestructiveButton(minWidth: 96)
    }

    private func reschedule(days: Int) {
        let targetDate = Calendar.autoupdatingCurrent.date(byAdding: .day, value: days, to: Date()) ?? Date()
        dataStore.rescheduleCountdown(id: event.id, to: targetDate)
        let updated = CountdownEvent(
            id: event.id,
            title: event.title,
            targetDate: targetDate,
            createdAt: event.createdAt,
            themeName: event.themeName,
            stickerName: event.stickerName,
            notes: event.notes,
            remindersEnabled: event.remindersEnabled
        )
            Task {
                let scheduledCount: Int
                if updated.remindersEnabled {
                    scheduledCount = await notifications.scheduleCountdownMilestones(for: updated)
                } else {
                    await notifications.cancelCountdownNotifications(for: updated.id)
                    scheduledCount = -1
                }
                await MainActor.run {
                    if updated.remindersEnabled && scheduledCount == 0 {
                        dataStore.updateCountdown(withID: updated.id, remindersEnabled: false)
                    }
                }
            }
    }

    private func addResetTask() {
        let title = "Reset \(event.title)"
        if let existingID = existingTaskID(title: title, tag: "reset") {
            withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
                addedResetTaskID = existingID
            }
            return
        }
        let task = TaskItem(title: title, dueDate: Date(), priority: 1, tagText: "reset", estimatedMinutes: 15)
        dataStore.addTask(task)
        withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
            addedResetTaskID = task.id
        }
    }

    private func syncExistingResetTask() {
        addedResetTaskID = existingTaskID(title: "Reset \(event.title)", tag: "reset")
    }

    private func existingTaskID(title: String, tag: String) -> UUID? {
        dataStore.tasks.first { task in
            !task.isCompleted
                && task.title == title
                && task.tagText == tag
                && CozyCalendar.isToday(task.dueDate)
        }?.id
    }
}

struct CountdownCompactCard: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @State private var addedPrepTaskID: UUID?
    let event: CountdownEvent

    var body: some View {
        let phase = event.phase()
        VStack(alignment: .leading, spacing: 12) {
            // Tap the info row → jump to Countdowns. Previously the only clickable
            // surface on this card was the secondary "Add prep task" button at the
            // bottom, so users tapping the title/days-remaining went nowhere.
            Button {
                NotificationCenter.default.post(name: .cozyOpenSection, object: AppSection.countdowns.rawValue)
            } label: {
                HStack(spacing: 16) {
                    CountdownStickerFrame(event: event, phase: phase)
                        .frame(width: 54, height: 54)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(compactPhaseTitle(phase))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(event.title)
                            .font(CozyType.rowTitle)
                            .lineLimit(2)
                        Text(daysText)
                            .font(CozyType.cardTitle)
                            .foregroundStyle(countdownColor)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .cozyPressable()
            .accessibilityIdentifier("countdown.compact.open")
            .help("Open Countdowns")

            Button {
                addPrepTask()
            } label: {
                Label(addedPrepTaskID == nil ? "Add tiny prep task" : "Prep task added", systemImage: addedPrepTaskID == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .cozySecondaryButton(fullWidth: true)
            .disabled(addedPrepTaskID != nil)
            .accessibilityIdentifier("countdown.compact.prep")
        }
        .compactDashboardTile()
        .cozyCard()
        .onAppear(perform: syncExistingPrepTask)
    }

    private var daysText: String {
        let d = event.daysRemaining()
        if d == 0 { return "Today" }
        if d < 0 {
            let overdue = abs(d)
            return "\(overdue) \(overdue == 1 ? "day" : "days") ago"
        }
        return "\(d) \(d == 1 ? "day" : "days") left"
    }

    private var countdownColor: Color {
        event.daysRemaining() < 0 ? CozyPalette.overdue : CozyPalette.countdownBerry
    }

    private func compactPhaseTitle(_ phase: CountdownPhase) -> String {
        switch phase {
        case .longRange: "Dreaming toward"
        case .warmingUp: "Prep season"
        case .finalWeek: "Final week prep"
        case .tomorrow: "Tomorrow’s main thing"
        case .today: "Happening today"
        case .overdue: "Soft reset"
        }
    }

    private func addPrepTask() {
        let phase = event.phase()
        let title = prepPrompt(for: event, phase: phase)
        if let existingID = existingTaskID(title: title, tag: "prep") {
            addedPrepTaskID = existingID
            return
        }
        let task = TaskItem(title: title, dueDate: Date(), priority: 1, tagText: "prep", estimatedMinutes: 15)
        dataStore.addTask(task)
        addedPrepTaskID = task.id
        CozyFeedback.play(.add)
    }

    private func syncExistingPrepTask() {
        addedPrepTaskID = existingTaskID(title: prepPrompt(for: event, phase: event.phase()), tag: "prep")
    }

    private func existingTaskID(title: String, tag: String) -> UUID? {
        dataStore.tasks.first { task in
            !task.isCompleted
                && task.title == title
                && task.tagText == tag
                && CozyCalendar.isToday(task.dueDate)
        }?.id
    }
}

struct CountdownStickerFrame: View {
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    let event: CountdownEvent
    let phase: CountdownPhase

    private var theme: CozyTheme {
        CozyTheme.named(event.themeName.isEmpty ? selectedTheme : event.themeName)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
                .fill(stickerFill.opacity(phase == .today ? 0.24 : 0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
                        .stroke(stickerColor.opacity(phase == .today ? 0.62 : 0.30), lineWidth: 1)
                )
            CozyCatalogGlyph(
                symbolName: event.stickerName,
                color: phase.isOverdue ? CozyPalette.overdue : stickerColor,
                size: 28
            )
        }
        .frame(width: 56, height: 56)
        .accessibilityHidden(true)
    }

    private var stickerColor: Color {
        phase == .today ? theme.reward : CozyPalette.countdownBerry
    }

    private var stickerFill: Color {
        phase == .today ? CozyPalette.peach : CozyPalette.lavenderMist
    }
}

struct CountdownPhaseBadge: View {
    let phase: CountdownPhase
    let color: Color

    var body: some View {
        CozyPill(title: phase.label, intent: .accent(color), size: .regular)
    }
}

struct CountdownMilestoneRail: View {
    let days: Int
    let color: Color

    private let milestones = [30, 14, 7, 3, 1, 0]

    var body: some View {
        // Eyebrow above the chip row so the rail reads as a labeled
        // checkpoint timeline, not a floating row of decorative dots.
        VStack(alignment: .leading, spacing: 6) {
            Text("Milestones")
                .font(CozyType.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(milestones, id: \.self) { milestone in
                    let reached = days <= milestone && days >= 0
                    Text(milestone == 0 ? "Day" : "\(milestone)d")
                        .font(CozyType.captionStrong)
                        .foregroundStyle(reached ? CozyPalette.surface : color.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(reached ? color : color.opacity(0.10))
                        )
                        .overlay(
                            Capsule()
                                .stroke(color.opacity(reached ? 0 : 0.35), lineWidth: 1)
                        )
                        .accessibilityLabel(reached ? "\(milestone) day milestone reached" : "\(milestone) day milestone")
                }
            }
        }
        .accessibilityIdentifier("countdown.milestones")
    }
}

struct CountdownPrepPrompt: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var addedTaskID: UUID?
    @State private var addedTaskWasCreatedHere = false
    let event: CountdownEvent
    let phase: CountdownPhase

    private var didAddTask: Bool {
        addedTaskID != nil
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(CozyType.cardTitle)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(prepPrompt(for: event, phase: phase))
                    .font(CozyType.controlStrong)
                    .lineLimit(2)
                Text("Turn anticipation into one 15m prep block.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if didAddTask {
                    Text("Prep task added")
                        .font(CozyType.captionStrong)
                        .foregroundStyle(CozyPalette.focusJade)
                        .transition(.opacity)
                }
            }
            Spacer()
            Button {
                didAddTask ? undoPrepTask() : addPrepTask()
            } label: {
                Image(systemName: didAddTask ? "arrow.uturn.backward" : "plus")
                    .frame(width: 20, height: 20)
            }
            .cozyIconButton(size: CozyLayout.hitSize)
            .accessibilityLabel(didAddTask ? "Undo prep task for \(event.title)" : "Add prep task for \(event.title)")
            .accessibilityIdentifier(didAddTask ? "countdown.prep.undo" : "countdown.prep.add")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func addPrepTask() {
        let title = prepPrompt(for: event, phase: phase)
        if let existingID = existingTaskID(title: title, tag: "prep") {
            withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
                addedTaskID = existingID
                addedTaskWasCreatedHere = false
            }
            return
        }
        let task = TaskItem(title: title, dueDate: Date(), priority: 1, tagText: "prep", estimatedMinutes: 15)
        dataStore.addTask(task)
        withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
            addedTaskID = task.id
            addedTaskWasCreatedHere = true
        }
        CozyFeedback.play(.add)
    }

    private func undoPrepTask() {
        guard let taskID = addedTaskID else { return }
        let shouldDeleteTask = addedTaskWasCreatedHere
        if shouldDeleteTask {
            dataStore.deleteTask(id: taskID)
        }
        withAnimation(CozyMotion.snappy(reduceMotion, duration: 0.18)) {
            addedTaskID = nil
            addedTaskWasCreatedHere = false
        }
        if shouldDeleteTask {
            CozyFeedback.play(.undo)
        }
    }

    private func existingTaskID(title: String, tag: String) -> UUID? {
        dataStore.tasks.first { task in
            !task.isCompleted
                && task.title == title
                && task.tagText == tag
                && CozyCalendar.isToday(task.dueDate)
        }?.id
    }
}

private func prepPrompt(for event: CountdownEvent, phase: CountdownPhase) -> String {
    let title = event.title.lowercased()
    if title.contains("exam") || title.contains("study") || title.contains("test") {
        return phase == .today ? "Review one calm page" : "Do a 15m recall block"
    }
    if title.contains("trip") || title.contains("flight") || title.contains("travel") {
        return phase == .today ? "Check the tiny travel list" : "Make a mini packing list"
    }
    if title.contains("birthday") || title.contains("party") {
        return "Pick a card or message"
    }
    if title.contains("release") || title.contains("deadline") || title.contains("ship") {
        return phase == .today ? "Ship one tiny slice" : "Prepare one release note"
    }
    switch phase {
    case .today:
        return "Save one tiny memory"
    case .overdue:
        return "Choose reset, done, or delete"
    default:
        return "Add one tiny prep step"
    }
}

struct CalendarPlannerView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @State private var dayOffset = -7
    @State private var selectedDay: SelectedCalendarDay?
    @State private var presentingCountdownComposer = false

    // Lowered minimum 118→96 + spacing 10→8 so the 7-column week layout
    // actually fits at typical window widths instead of falling back to the
    // 4-column adaptive grid (which read as a broken calendar).
    private let weekColumns = Array(repeating: GridItem(.flexible(minimum: 96), spacing: 8), count: 7)

    private var allCountdowns: [CountdownEvent] {
        dataStore.countdowns.sorted { $0.targetDate < $1.targetDate }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CozyLayout.sectionSpacing) {
                SectionHeader(title: "Calendar", subtitle: "Two quiet weeks of tasks, countdowns, and focus diary.", mascotState: .countdown)
                calendarControls
                ViewThatFits(in: .horizontal) {
                    LazyVGrid(columns: weekColumns, spacing: 10) {
                        calendarCards
                    }
                    LazyVGrid(columns: CozyLayout.adaptiveColumns(minimum: 180), spacing: 10) {
                        calendarCards
                    }
                }
                // Countdowns now live on the Calendar screen (per gf-requested
                // sidebar consolidation). Inline list + "New countdown" button
                // replaces the standalone Countdowns sidebar section.
                countdownSection
            }
            .cozyPageFrame()
        }
        .sheet(item: $selectedDay) { selection in
            // CalendarDayDetailSheet already has its own "Done" button in the
            // header; adding an overlay X would collide with it (user reported
            // exactly this overlap). Escape-key dismissal still works through
            // the @Environment(.dismiss) in the sheet itself.
            CalendarDayDetailSheet(date: selection.date)
                .environmentObject(dataStore)
        }
        .sheet(isPresented: $presentingCountdownComposer) {
            CountdownsView(presentation: .composerOnly)
                .environmentObject(dataStore)
                .frame(
                    minWidth: CozyLayout.sheetIdealWidthLarge,
                    idealWidth: CozyLayout.sheetIdealWidthLarge,
                    minHeight: CozyLayout.sheetIdealHeightMedium,
                    idealHeight: CozyLayout.sheetIdealHeightLarge
                )
                .modifier(CozySheetDismissAffordance { presentingCountdownComposer = false })
        }
        // UX HIGH #85 — ⌘N (when Calendar selected) opens the countdown
        // composer sheet. Countdowns now live inside Calendar, so the
        // keystroke maps to the section's primary creation affordance.
        .onReceive(NotificationCenter.default.publisher(for: .cozyNewCountdown)) { _ in
            presentingCountdownComposer = true
        }
        .accessibilityIdentifier("screen.calendar")
    }

    @ViewBuilder
    private var countdownSection: some View {
        VStack(alignment: .leading, spacing: CozyLayout.gridSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text("Countdowns")
                    .font(CozyType.cardTitle)
                Spacer()
                Button {
                    presentingCountdownComposer = true
                } label: {
                    Label("New countdown", systemImage: "plus")
                }
                .cozySecondaryButton(minWidth: 156)
                .accessibilityIdentifier("calendar.newCountdown")
            }
            if allCountdowns.isEmpty {
                EmptyStateView(
                    title: "Pick a first day to look forward to",
                    message: "An exam, trip, birthday, or release date — Mochi nudges you the day before.",
                    mascotState: .countdown,
                    eyebrow: "Countdowns",
                    primaryActionTitle: "Add a countdown",
                    primaryAction: { presentingCountdownComposer = true }
                )
                .frame(minHeight: 200)
            } else {
                LazyVStack(spacing: CozyLayout.gridSpacing) {
                    ForEach(allCountdowns) { event in
                        CountdownCard(event: event)
                    }
                }
            }
        }
    }

    private var calendarControls: some View {
        HStack(spacing: 10) {
            Button {
                dayOffset -= 7
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .cozySecondaryButton(minWidth: 92)

            Button {
                dayOffset = -7
            } label: {
                Label("Today", systemImage: "calendar")
            }
            .cozySecondaryButton(minWidth: 96)

            Button {
                dayOffset += 7
            } label: {
                Label("Next", systemImage: "chevron.right")
            }
            .cozySecondaryButton(minWidth: 92)

            Spacer()

            Text(visibleRangeText)
                .font(CozyType.controlStrong)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var calendarCards: some View {
        ForEach(visibleDays, id: \.self) { day in
            CalendarDayCard(
                date: day,
                tasks: tasksForDay(day),
                countdowns: countdownsForDay(day),
                focusSessions: focusSessionsForDay(day)
            ) {
                selectedDay = SelectedCalendarDay(date: day)
            }
        }
    }

    private var visibleRangeText: String {
        guard let first = visibleDays.first, let last = visibleDays.last else { return "" }
        return "\(CozyFormatters.shortDate.string(from: first)) - \(CozyFormatters.shortDate.string(from: last))"
    }

    private var visibleDays: [Date] {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: dayOffset, to: today) else { return [] }
        return (0..<14).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private struct SelectedCalendarDay: Identifiable {
        let id = UUID()
        let date: Date
    }

    private func tasksForDay(_ day: Date) -> [TaskItem] {
        dataStore.tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.autoupdatingCurrent.isDate(dueDate, inSameDayAs: day)
        }
    }

    private func countdownsForDay(_ day: Date) -> [CountdownEvent] {
        dataStore.countdowns.filter { Calendar.autoupdatingCurrent.isDate($0.targetDate, inSameDayAs: day) }
    }

    private func focusSessionsForDay(_ day: Date) -> [FocusSession] {
        dataStore.focusSessions
            .filter { session in
                Calendar.autoupdatingCurrent.isDate(session.reportingDate, inSameDayAs: day)
            }
            .sorted { first, second in
                first.reportingDate > second.reportingDate
            }
    }
}

struct CalendarDayCard: View {
    let date: Date
    let tasks: [TaskItem]
    let countdowns: [CountdownEvent]
    let focusSessions: [FocusSession]
    let onOpen: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    private var isToday: Bool {
        Calendar.autoupdatingCurrent.isDateInToday(date)
    }

    private var visibleTasks: [TaskItem] {
        Array(tasks.prefix(1))
    }

    private var visibleCountdowns: [CountdownEvent] {
        Array(countdowns.prefix(1))
    }

    private var visibleFocusSessions: [FocusSession] {
        Array(focusSessions.prefix(2))
    }

    private var hiddenCount: Int {
        max(0, tasks.count - visibleTasks.count)
            + max(0, countdowns.count - visibleCountdowns.count)
            + max(0, focusSessions.count - visibleFocusSessions.count)
    }

    private var focusMinutes: Int {
        focusSessions.reduce(0) { $0 + $1.completedMinutes }
    }

    private var hasContent: Bool {
        !tasks.isEmpty || !countdowns.isEmpty || !focusSessions.isEmpty
    }

    var body: some View {
        Button {
            onOpen()
        } label: {
            cardContent
        }
        .cozyPressable()
        .accessibilityIdentifier("calendar.day.open")
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(CozyFormatters.dayName.string(from: date))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(Calendar.autoupdatingCurrent.component(.day, from: date))")
                        .font(CozyType.cardTitle)
                }
                Spacer(minLength: 6)
                if focusMinutes > 0 {
                    CozyPill(title: "\(focusMinutes)m", intent: .success, size: .small)
                }
            }

            if !hasContent {
                Text("Open day")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ForEach(visibleFocusSessions) { session in
                CalendarDayLine(
                    title: "\(session.completedMinutes)m \(session.taskTitle)",
                    symbol: "timer",
                    color: CozyPalette.focusJade
                )
                let note = session.moodNote.trimmingCharacters(in: .whitespacesAndNewlines)
                if !note.isEmpty {
                    CalendarDayLine(title: note, symbol: "quote.bubble.fill", color: CozyPalette.habitLavender)
                }
            }
            ForEach(visibleTasks) { task in
                CalendarDayLine(
                    title: task.title,
                    symbol: task.isCompleted ? "checkmark.circle.fill" : "circle",
                    color: task.isCompleted ? CozyPalette.focusJade : CozyPalette.berry
                )
            }
            ForEach(visibleCountdowns) { event in
                CalendarDayLine(title: event.title, symbol: event.stickerName, color: CozyCountdownColor.color(for: event))
            }
            if hiddenCount > 0 {
                Text("+\(hiddenCount) more")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        // Visual audit IMPORTANT #3 (LA-003): cell-to-cell heights in the
        // 7-column LazyVGrid drifted because tall days (focus + task +
        // countdown + +N more) push beyond minHeight while empty days stop
        // at the floor. .frame(maxHeight: .infinity, alignment: .topLeading)
        // ensures every cell in a row resolves to the tallest sibling.
        .frame(minHeight: 162, maxHeight: .infinity, alignment: .topLeading)
        .cozyCard()
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isToday ? theme.accent : Color.clear, lineWidth: 2)
        )
        .accessibilityAddTraits(isToday ? .isSelected : [])
    }
}

struct CalendarDayDetailSheet: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @Environment(\.dismiss) private var dismiss
    let date: Date

    private var tasks: [TaskItem] {
        dataStore.tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.autoupdatingCurrent.isDate(dueDate, inSameDayAs: date)
        }
    }

    private var countdowns: [CountdownEvent] {
        dataStore.countdowns.filter { Calendar.autoupdatingCurrent.isDate($0.targetDate, inSameDayAs: date) }
    }

    private var focusSessions: [FocusSession] {
        dataStore.focusSessions
            .filter { Calendar.autoupdatingCurrent.isDate($0.reportingDate, inSameDayAs: date) }
            .sorted { $0.reportingDate > $1.reportingDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(CozyFormatters.weekdayDate.string(from: date))
                        .font(CozyType.cardTitle)
                    Text("\(focusMinutes)m focus · \(tasks.count) tasks · \(countdowns.count) countdowns")
                        .font(CozyType.control)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .cozySecondaryButton(minWidth: 82)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    diarySection(title: "Focus diary", symbol: "timer", empty: "No focus sessions logged.", isEmpty: focusSessions.isEmpty) {
                        ForEach(focusSessions) { session in
                            CalendarDetailRow(
                                title: "\(session.completedMinutes)m \(session.taskTitle)",
                                subtitle: session.moodNote.isEmpty ? "Saved focus session" : session.moodNote,
                                symbol: "timer",
                                color: CozyPalette.focusJade,
                                destination: .focus,
                                navigate: openSection
                            )
                        }
                    }
                    diarySection(title: "Tasks", symbol: "checklist", empty: "No tasks due.", isEmpty: tasks.isEmpty) {
                        ForEach(tasks) { task in
                            CalendarDetailRow(
                                title: task.title,
                                subtitle: task.isCompleted ? "Done" : "\(task.listName) · \(task.estimatedMinutes)m",
                                symbol: task.isCompleted ? "checkmark.circle.fill" : "circle",
                                color: task.isCompleted ? CozyPalette.focusJade : CozyPalette.berry,
                                destination: .tasks,
                                navigate: openSection
                            )
                        }
                    }
                    diarySection(title: "Countdowns", symbol: "hourglass", empty: "No countdowns on this day.", isEmpty: countdowns.isEmpty) {
                        ForEach(countdowns) { event in
                            CalendarDetailRow(
                                title: event.title,
                                subtitle: event.phase().label,
                                symbol: event.stickerName,
                                color: CozyCountdownColor.color(for: event),
                                destination: .countdowns,
                                navigate: openSection
                            )
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 520, height: 580)
    }

    private var focusMinutes: Int {
        focusSessions.reduce(0) { $0 + $1.completedMinutes }
    }

    private func openSection(_ section: AppSection) {
        dismiss()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .cozyOpenSection, object: section.rawValue)
        }
    }

    @ViewBuilder
    private func diarySection<Content: View>(
        title: String,
        symbol: String,
        empty: String,
        isEmpty: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(CozyType.controlStrong)
            if isEmpty {
                Text(empty)
                    .font(CozyType.captionStrong)
                    .foregroundStyle(.secondary)
            } else {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cozyCard()
    }
}

private struct CalendarDetailRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    let destination: AppSection?
    let navigate: (AppSection) -> Void

    init(
        title: String,
        subtitle: String,
        symbol: String,
        color: Color,
        destination: AppSection? = nil,
        navigate: @escaping (AppSection) -> Void = { _ in }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.color = color
        self.destination = destination
        self.navigate = navigate
    }

    var body: some View {
        Button {
            if let destination {
                navigate(destination)
            }
        } label: {
            rowContent
        }
        .buttonStyle(.plain)
        .cozyPressable()
        .disabled(destination == nil)
        .accessibilityIdentifier(destination.map { "calendar.detail.row.\($0.rawValue)" } ?? "calendar.detail.row")
        .accessibilityHint(destination == nil ? "" : "Open \(destination?.title ?? "section")")
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(CozyType.controlStrong)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CozyType.controlStrong)
                    .lineLimit(2)
                Text(subtitle)
                    .font(CozyType.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if destination != nil {
                Image(systemName: "chevron.right")
                    .font(CozyType.captionStrong)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: CozyLayout.controlRadius, style: .continuous)
                .fill(color.opacity(0.08))
        )
    }
}

private struct CalendarDayLine: View {
    let title: String
    let symbol: String
    let color: Color

    var body: some View {
        Label {
            Text(title)
                .lineLimit(1)
        } icon: {
            Image(systemName: symbol)
                .font(.caption2.weight(.bold))
                .frame(width: 16, alignment: .center)
        }
        .font(.caption)
        .foregroundStyle(color)
    }
}

private enum CozyCountdownColor {
    static func color(for event: CountdownEvent) -> Color {
        event.daysRemaining() < 0 ? CozyPalette.overdue : CozyPalette.countdownBerry
    }
}
