import CozyCore
import Foundation

enum SelfTestFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case let .failed(message): message
        }
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw SelfTestFailure.failed(message) }
}

func expectEqual<T: Equatable>(_ lhs: T, _ rhs: T, _ message: String) throws {
    guard lhs == rhs else { throw SelfTestFailure.failed("\(message): \(lhs) != \(rhs)") }
}

func testTimerEngine() throws {
    let start = Date(timeIntervalSinceReferenceDate: 1_000)
    let running = TimerEngine.start(at: start, duration: 25 * 60)
    try expect(abs(TimerEngine.remainingTime(for: running, at: start.addingTimeInterval(5 * 60)) - 20 * 60) < 0.001, "timer remaining is date based")

    let paused = TimerEngine.pause(running, at: start.addingTimeInterval(5 * 60))
    try expect(abs(TimerEngine.remainingTime(for: paused, at: start.addingTimeInterval(15 * 60)) - 20 * 60) < 0.001, "pause freezes elapsed time")

    let resumed = TimerEngine.resume(paused, at: start.addingTimeInterval(15 * 60))
    try expect(abs(TimerEngine.remainingTime(for: resumed, at: start.addingTimeInterval(20 * 60)) - 15 * 60) < 0.001, "resume preserves pause interval")
    try expectEqual(TimerEngine.completeIfNeeded(running, at: start.addingTimeInterval(25 * 60)).state, .completed, "timer completes when elapsed")
}

func testHabitMath() throws {
    let calendar = Calendar(identifier: .gregorian)
    let today = calendar.date(from: DateComponents(year: 2026, month: 5, day: 13))!
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
    let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

    let added = HabitMath.toggleCompletion(keys: "", on: today, calendar: calendar)
    try expect(HabitMath.isComplete(keys: added, on: today, calendar: calendar), "habit toggle adds today")
    let removed = HabitMath.toggleCompletion(keys: added, on: today, calendar: calendar)
    try expect(!HabitMath.isComplete(keys: removed, on: today, calendar: calendar), "habit toggle removes today")

    let keys = [
        CozyCalendar.dayKey(yesterday, calendar: calendar),
        CozyCalendar.dayKey(twoDaysAgo, calendar: calendar)
    ].joined(separator: "\n")
    try expectEqual(HabitMath.currentStreak(keys: keys, through: today, graceDays: 1, calendar: calendar), 2, "streak allows grace day")
}

func testTaskFilters() throws {
    let calendar = Calendar(identifier: .gregorian)
    let today = calendar.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: 10))!
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

    let tasks = [
        TaskFilterRecord(title: "Low", dueDate: today, completedAt: nil, priority: 0),
        TaskFilterRecord(title: "Done", dueDate: today, completedAt: today, priority: 2),
        TaskFilterRecord(title: "High", dueDate: today, completedAt: nil, priority: 2),
        TaskFilterRecord(title: "Tomorrow", dueDate: tomorrow, completedAt: nil, priority: 2)
    ]

    try expectEqual(TaskFilters.today(tasks, now: today, calendar: calendar).map(\.title), ["High", "Low"], "today filter")
}

func testNotificationPlanner() throws {
    let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    let start = Date(timeIntervalSinceReferenceDate: 1_000)
    let draft = NotificationPlanner.focusCompletion(sessionID: id, taskTitle: "Write outline", startDate: start, duration: 25 * 60, accumulatedPause: 60)

    try expectEqual(draft.identifier, "focus-complete-AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", "notification identifier")
    try expect(draft.body.contains("Write outline"), "notification body includes task")
    try expectEqual(draft.fireDate, start.addingTimeInterval(26 * 60), "notification fire date")
}

do {
    try testTimerEngine()
    try testHabitMath()
    try testTaskFilters()
    try testNotificationPlanner()
    print("CozyCoreSelfTest passed")
} catch {
    fputs("CozyCoreSelfTest failed: \(error)\n", stderr)
    exit(1)
}
