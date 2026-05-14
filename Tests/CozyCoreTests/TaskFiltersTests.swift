import XCTest
@testable import CozyCore

final class TaskFiltersTests: XCTestCase {
    func testTodayFilterExcludesCompletedAndSortsByPriority() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: 10)))
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: today))

        let tasks = [
            TaskFilterRecord(title: "Low", dueDate: today, completedAt: nil, priority: 0),
            TaskFilterRecord(title: "Done", dueDate: today, completedAt: today, priority: 2),
            TaskFilterRecord(title: "High", dueDate: today, completedAt: nil, priority: 2),
            TaskFilterRecord(title: "Tomorrow", dueDate: tomorrow, completedAt: nil, priority: 2)
        ]

        let result = TaskFilters.today(tasks, now: today, calendar: calendar)
        XCTAssertEqual(result.map(\.title), ["High", "Low"])
    }

    func testOverdueFilterOnlyReturnsPastIncompleteTasks() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: 10)))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))

        let tasks = [
            TaskFilterRecord(title: "Past", dueDate: yesterday, completedAt: nil, priority: 0),
            TaskFilterRecord(title: "Past done", dueDate: yesterday, completedAt: today, priority: 0),
            TaskFilterRecord(title: "Today", dueDate: today, completedAt: nil, priority: 0)
        ]

        XCTAssertEqual(TaskFilters.overdue(tasks, now: today, calendar: calendar).map(\.title), ["Past"])
    }
}
