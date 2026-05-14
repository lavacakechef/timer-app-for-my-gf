import Foundation

public struct TaskFilterRecord: Equatable, Sendable {
    public var title: String
    public var dueDate: Date?
    public var completedAt: Date?
    public var priority: Int

    public init(
        title: String,
        dueDate: Date?,
        completedAt: Date?,
        priority: Int = 0
    ) {
        self.title = title
        self.dueDate = dueDate
        self.completedAt = completedAt
        self.priority = priority
    }

    public var isCompleted: Bool {
        completedAt != nil
    }
}

public enum TaskFilters {
    public static func today(
        _ tasks: [TaskFilterRecord],
        now: Date,
        calendar: Calendar = CozyCalendar.shared
    ) -> [TaskFilterRecord] {
        tasks
            .filter { !$0.isCompleted && CozyCalendar.isToday($0.dueDate, now: now, calendar: calendar) }
            .sorted(by: sortByPriorityThenDueDate)
    }

    public static func upcoming(
        _ tasks: [TaskFilterRecord],
        now: Date,
        calendar: Calendar = CozyCalendar.shared
    ) -> [TaskFilterRecord] {
        tasks
            .filter { !$0.isCompleted && CozyCalendar.isUpcoming($0.dueDate, now: now, calendar: calendar) }
            .sorted(by: sortByPriorityThenDueDate)
    }

    public static func overdue(
        _ tasks: [TaskFilterRecord],
        now: Date,
        calendar: Calendar = CozyCalendar.shared
    ) -> [TaskFilterRecord] {
        let startOfToday = calendar.startOfDay(for: now)
        return tasks
            .filter { task in
                guard let dueDate = task.dueDate else { return false }
                return !task.isCompleted && dueDate < startOfToday
            }
            .sorted(by: sortByPriorityThenDueDate)
    }

    public static func sortByPriorityThenDueDate(_ lhs: TaskFilterRecord, _ rhs: TaskFilterRecord) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority > rhs.priority
        }

        switch (lhs.dueDate, rhs.dueDate) {
        case let (left?, right?):
            return left < right
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        case (nil, nil):
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}
