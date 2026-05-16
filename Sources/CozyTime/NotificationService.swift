import CozyCore
import AppKit
import Foundation
@preconcurrency import UserNotifications

@MainActor
final class NotificationService: ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var lastSchedulingError: String?

    init() {
        Task {
            await refreshAuthorizationStatus()
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        guard settings.authorizationStatus == .notDetermined else {
            return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        }

        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
        } catch {
            lastSchedulingError = "Notification permission could not be requested."
            await refreshAuthorizationStatus()
        }
        return authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    @discardableResult
    func schedule(_ draft: NotificationDraft) async -> Bool {
        guard !ProcessInfo.processInfo.arguments.contains("-ui-testing") else { return false }
        await requestAuthorizationIfNeeded()
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            lastSchedulingError = "Notifications are off. The timer will still run, but macOS will not alert you."
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = draft.title
        content.body = draft.body
        content.sound = .default
        if draft.isTimeSensitive {
            content.interruptionLevel = .timeSensitive
        }
        // Group related notifications under a shared thread so Notification
        // Center collapses (e.g.) multiple focus completions instead of
        // stacking them as separate rows.
        if !draft.threadIdentifier.isEmpty {
            content.threadIdentifier = draft.threadIdentifier
        }

        let interval = max(1, draft.fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: draft.identifier, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
            lastSchedulingError = nil
            return true
        } catch {
            lastSchedulingError = "CozyTime could not schedule the timer alert."
            return false
        }
    }

    @discardableResult
    func scheduleCountdownMilestones(for event: CountdownEvent, daysBefore: [Int] = [7, 1, 0]) async -> Int {
        guard !ProcessInfo.processInfo.arguments.contains("-ui-testing") else { return 0 }
        await cancelCountdownNotifications(for: event.id)
        var scheduledCount = 0
        for days in daysBefore {
            guard let draft = NotificationPlanner.countdownMilestone(
                eventID: event.id,
                title: event.title,
                targetDate: event.targetDate,
                daysBefore: days
            ), draft.fireDate > Date().addingTimeInterval(30) else {
                continue
            }
            if await schedule(draft) {
                scheduledCount += 1
            }
        }
        if scheduledCount == 0 && lastSchedulingError == nil {
            lastSchedulingError = "No future countdown alerts were scheduled for this date."
        }
        return scheduledCount
    }

    func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    func cancel(identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func cancelFocusNotifications() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let identifiers = requests
            .map(\.identifier)
            .filter { $0.hasPrefix("focus-complete-") }
        guard !identifiers.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func cancelCountdownNotifications(for eventID: UUID) async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let prefix = "countdown-\(eventID.uuidString)-"
        let identifiers = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        guard !identifiers.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
