import XCTest
@testable import CozyCore

final class TimerEngineTests: XCTestCase {
    func testRemainingTimeIsDateBased() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let snapshot = TimerEngine.start(at: start, duration: 25 * 60)
        let fiveMinutesLater = start.addingTimeInterval(5 * 60)

        XCTAssertEqual(TimerEngine.remainingTime(for: snapshot, at: fiveMinutesLater), 20 * 60, accuracy: 0.001)
        XCTAssertEqual(TimerEngine.progress(for: snapshot, at: fiveMinutesLater), 0.2, accuracy: 0.001)
    }

    func testPauseFreezesElapsedTimeUntilResume() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let running = TimerEngine.start(at: start, duration: 25 * 60)
        let paused = TimerEngine.pause(running, at: start.addingTimeInterval(5 * 60))
        let laterWhilePaused = start.addingTimeInterval(15 * 60)

        XCTAssertEqual(TimerEngine.remainingTime(for: paused, at: laterWhilePaused), 20 * 60, accuracy: 0.001)

        let resumed = TimerEngine.resume(paused, at: laterWhilePaused)
        let fiveMoreMinutes = laterWhilePaused.addingTimeInterval(5 * 60)

        XCTAssertEqual(TimerEngine.remainingTime(for: resumed, at: fiveMoreMinutes), 15 * 60, accuracy: 0.001)
    }

    func testCompletesOnlyWhenDurationHasElapsed() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let running = TimerEngine.start(at: start, duration: 10)

        XCTAssertEqual(TimerEngine.completeIfNeeded(running, at: start.addingTimeInterval(9)).state, .running)
        XCTAssertEqual(TimerEngine.completeIfNeeded(running, at: start.addingTimeInterval(10)).state, .completed)
    }

    func testFocusPhaseTracksSessionProgress() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let running = TimerEngine.start(at: start, duration: 10 * 60)

        XCTAssertEqual(TimerEngine.focusPhase(for: FocusTimerSnapshot(), at: start), .prepare)
        XCTAssertEqual(TimerEngine.focusPhase(for: running, at: start.addingTimeInterval(30)), .settling)
        XCTAssertEqual(TimerEngine.focusPhase(for: running, at: start.addingTimeInterval(3 * 60)), .deepFocus)
        XCTAssertEqual(TimerEngine.focusPhase(for: running, at: start.addingTimeInterval(9 * 60 + 10)), .finalMinute)
        XCTAssertEqual(TimerEngine.focusPhase(for: TimerEngine.complete(running, at: start.addingTimeInterval(10 * 60)), at: start.addingTimeInterval(10 * 60)), .wrap)
    }

    func testCreditedDurationUsesElapsedTimeForEarlyWrap() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let running = TimerEngine.start(at: start, duration: 25 * 60)

        XCTAssertEqual(
            TimerEngine.creditedDuration(for: running, at: start.addingTimeInterval(7 * 60 + 12)),
            7 * 60 + 12,
            accuracy: 0.001
        )
    }

    func testCreditedDurationDoesNotInventMinimumCredit() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let running = TimerEngine.start(at: start, duration: 25 * 60)

        XCTAssertEqual(
            TimerEngine.creditedDuration(for: running, at: start.addingTimeInterval(4)),
            4,
            accuracy: 0.001
        )
    }

    func testCreditedDurationDoesNotExceedPlannedDuration() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let running = TimerEngine.start(at: start, duration: 5 * 60)
        let completed = TimerEngine.complete(running, at: start.addingTimeInterval(5 * 60))

        XCTAssertEqual(
            TimerEngine.creditedDuration(for: completed, at: start.addingTimeInterval(20 * 60)),
            5 * 60,
            accuracy: 0.001
        )
    }
}
