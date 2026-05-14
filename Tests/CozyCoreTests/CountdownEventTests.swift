import XCTest
@testable import CozyCore

final class CountdownEventTests: XCTestCase {
    func testCountdownPhasesCoverTodayTomorrowFinalWeekLongRangeAndOverdue() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSinceReferenceDate: 10_000)
        let today = calendar.startOfDay(for: now)

        XCTAssertEqual(event(target: today).phase(now: today, calendar: calendar), .today)
        XCTAssertEqual(event(target: calendar.date(byAdding: .day, value: 1, to: today)!).phase(now: today, calendar: calendar), .tomorrow)
        XCTAssertEqual(event(target: calendar.date(byAdding: .day, value: 5, to: today)!).phase(now: today, calendar: calendar), .finalWeek(5))
        XCTAssertEqual(event(target: calendar.date(byAdding: .day, value: 20, to: today)!).phase(now: today, calendar: calendar), .warmingUp(20))
        XCTAssertEqual(event(target: calendar.date(byAdding: .day, value: 60, to: today)!).phase(now: today, calendar: calendar), .longRange(60))
        XCTAssertEqual(event(target: calendar.date(byAdding: .day, value: -2, to: today)!).phase(now: today, calendar: calendar), .overdue(2))
    }

    func testCountdownProgressHandlesSameDayAndPastTargets() {
        let now = Date(timeIntervalSinceReferenceDate: 10_000)

        XCTAssertEqual(event(created: now, target: now).progress(now: now), 1)
        XCTAssertEqual(event(created: now, target: now.addingTimeInterval(-10)).progress(now: now), 1)
        XCTAssertEqual(event(created: now, target: now.addingTimeInterval(100)).progress(now: now.addingTimeInterval(50)), 0.5, accuracy: 0.001)
    }

    private func event(created: Date = Date(timeIntervalSinceReferenceDate: 9_000), target: Date) -> CountdownEvent {
        CountdownEvent(title: "Trip", targetDate: target, createdAt: created)
    }
}
