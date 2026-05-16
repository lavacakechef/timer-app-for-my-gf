import Foundation

public struct NotificationDraft: Equatable, Sendable {
    public var identifier: String
    public var title: String
    public var body: String
    public var fireDate: Date
    public var isTimeSensitive: Bool
    /// Thread identifier so multiple notifications of the same kind group
    /// in Notification Center instead of stacking as separate rows.
    /// Apple UserNotifications docs: "Use this property to group related
    /// notifications together visually."
    public var threadIdentifier: String

    public init(
        identifier: String,
        title: String,
        body: String,
        fireDate: Date,
        isTimeSensitive: Bool = false,
        threadIdentifier: String = ""
    ) {
        self.identifier = identifier
        self.title = title
        self.body = body
        self.fireDate = fireDate
        self.isTimeSensitive = isTimeSensitive
        self.threadIdentifier = threadIdentifier
    }
}

public enum NotificationPlanner {
    public static func focusCompletion(
        sessionID: UUID,
        taskTitle: String,
        startDate: Date,
        duration: TimeInterval,
        accumulatedPause: TimeInterval = 0
    ) -> NotificationDraft {
        let fireDate = startDate.addingTimeInterval(duration + accumulatedPause)
        let cleanTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let task = cleanTitle.isEmpty ? "your focus session" : cleanTitle
        return NotificationDraft(
            identifier: "focus-complete-\(sessionID.uuidString)",
            title: "Time for a tiny win",
            body: "\(task) is ready to wrap. Short session counts.",
            fireDate: fireDate,
            isTimeSensitive: true,
            threadIdentifier: "cozy.focus"
        )
    }

    public static func countdownMilestone(
        eventID: UUID,
        title: String,
        targetDate: Date,
        daysBefore: Int,
        calendar: Calendar = CozyCalendar.shared
    ) -> NotificationDraft? {
        guard let fireDate = calendar.date(byAdding: .day, value: -daysBefore, to: targetDate) else {
            return nil
        }

        return NotificationDraft(
            identifier: "countdown-\(eventID.uuidString)-\(daysBefore)",
            title: "\(title) is getting close",
            body: daysBefore == 0
                ? "Today is the day."
                : "\(daysBefore) \(daysBefore == 1 ? "day" : "days") left. Pick the next tiny step.",
            fireDate: fireDate,
            threadIdentifier: "cozy.countdown.\(eventID.uuidString)"
        )
    }
}
