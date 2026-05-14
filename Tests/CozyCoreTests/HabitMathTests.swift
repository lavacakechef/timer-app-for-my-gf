import XCTest
@testable import CozyCore

final class HabitMathTests: XCTestCase {
    func testToggleCompletionAddsAndRemovesToday() throws {
        let calendar = Calendar(identifier: .gregorian)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 13)))

        let added = HabitMath.toggleCompletion(keys: "", on: date, calendar: calendar)
        XCTAssertTrue(HabitMath.isComplete(keys: added, on: date, calendar: calendar))

        let removed = HabitMath.toggleCompletion(keys: added, on: date, calendar: calendar)
        XCTAssertFalse(HabitMath.isComplete(keys: removed, on: date, calendar: calendar))
    }

    func testCurrentStreakUsesGraceDayWithoutPunitiveReset() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 13)))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))
        let twoDaysAgo = try XCTUnwrap(calendar.date(byAdding: .day, value: -2, to: today))

        let keys = [
            CozyCalendar.dayKey(yesterday, calendar: calendar),
            CozyCalendar.dayKey(twoDaysAgo, calendar: calendar)
        ].joined(separator: "\n")

        XCTAssertEqual(HabitMath.currentStreak(keys: keys, through: today, graceDays: 1, calendar: calendar), 2)
        XCTAssertEqual(HabitMath.currentStreak(keys: keys, through: today, graceDays: 0, calendar: calendar), 0)
    }
}
