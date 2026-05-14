import XCTest
@testable import CozyCore

final class NotificationPlannerTests: XCTestCase {
    func testFocusCompletionDraftUsesSessionTiming() {
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        let draft = NotificationPlanner.focusCompletion(
            sessionID: id,
            taskTitle: "Write outline",
            startDate: start,
            duration: 25 * 60,
            accumulatedPause: 60
        )

        XCTAssertEqual(draft.identifier, "focus-complete-AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
        XCTAssertEqual(draft.title, "Time for a tiny win")
        XCTAssertTrue(draft.body.contains("Write outline"))
        XCTAssertEqual(draft.fireDate, start.addingTimeInterval(26 * 60))
    }

    func testCountdownMilestoneDraft() throws {
        let calendar = Calendar(identifier: .gregorian)
        let target = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)))
        let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

        let draft = try XCTUnwrap(NotificationPlanner.countdownMilestone(eventID: id, title: "Trip", targetDate: target, daysBefore: 3, calendar: calendar))

        XCTAssertEqual(draft.identifier, "countdown-11111111-2222-3333-4444-555555555555-3")
        XCTAssertEqual(draft.fireDate, calendar.date(byAdding: .day, value: -3, to: target))
    }
}
