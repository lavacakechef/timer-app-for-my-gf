import Foundation

public enum TimerRunState: String, Codable, CaseIterable, Sendable {
    case idle
    case running
    case paused
    case completed
    case cancelled
}

public enum FocusPhase: String, Codable, CaseIterable, Sendable {
    case prepare
    case settling
    case deepFocus
    case finalMinute
    case wrap
    case breakTime

    public var label: String {
        switch self {
        case .prepare: "Prepare"
        case .settling: "Settling in"
        case .deepFocus: "Deep focus"
        case .finalMinute: "Final minute"
        case .wrap: "Wrap the win"
        case .breakTime: "Break"
        }
    }

    public var microcopy: String {
        switch self {
        case .prepare: "Pick one tiny step. Mochi will keep the room quiet."
        case .settling: "First stretch. Let the room get still."
        case .deepFocus: "Quiet mode. Stay with the one thing."
        case .finalMinute: "Gentle finish. No rush, just land the session."
        case .wrap: "Save the win before starting another block."
        case .breakTime: "Refill water, stretch, and let your eyes rest."
        }
    }
}

public struct FocusTimerSnapshot: Codable, Equatable, Sendable {
    public var state: TimerRunState
    public var startDate: Date?
    public var duration: TimeInterval
    public var pausedAt: Date?
    public var accumulatedPause: TimeInterval
    public var completedAt: Date?
    public var cancelledAt: Date?

    public init(
        state: TimerRunState = .idle,
        startDate: Date? = nil,
        duration: TimeInterval = 25 * 60,
        pausedAt: Date? = nil,
        accumulatedPause: TimeInterval = 0,
        completedAt: Date? = nil,
        cancelledAt: Date? = nil
    ) {
        self.state = state
        self.startDate = startDate
        self.duration = duration
        self.pausedAt = pausedAt
        self.accumulatedPause = accumulatedPause
        self.completedAt = completedAt
        self.cancelledAt = cancelledAt
    }
}

public enum TimerEngine {
    public static func start(
        at date: Date,
        duration: TimeInterval
    ) -> FocusTimerSnapshot {
        FocusTimerSnapshot(
            state: .running,
            startDate: date,
            duration: max(1, duration)
        )
    }

    public static func pause(
        _ snapshot: FocusTimerSnapshot,
        at date: Date
    ) -> FocusTimerSnapshot {
        guard snapshot.state == .running else { return snapshot }
        var next = snapshot
        next.state = .paused
        next.pausedAt = date
        return next
    }

    public static func resume(
        _ snapshot: FocusTimerSnapshot,
        at date: Date
    ) -> FocusTimerSnapshot {
        guard snapshot.state == .paused, let pausedAt = snapshot.pausedAt else { return snapshot }
        var next = snapshot
        next.state = .running
        next.accumulatedPause += max(0, date.timeIntervalSince(pausedAt))
        next.pausedAt = nil
        return next
    }

    public static func cancel(
        _ snapshot: FocusTimerSnapshot,
        at date: Date
    ) -> FocusTimerSnapshot {
        var next = snapshot
        next.state = .cancelled
        next.cancelledAt = date
        next.pausedAt = nil
        return next
    }

    public static func complete(
        _ snapshot: FocusTimerSnapshot,
        at date: Date
    ) -> FocusTimerSnapshot {
        var next = snapshot
        next.state = .completed
        next.completedAt = date
        next.pausedAt = nil
        return next
    }

    public static func completeIfNeeded(
        _ snapshot: FocusTimerSnapshot,
        at date: Date
    ) -> FocusTimerSnapshot {
        guard snapshot.state == .running, remainingTime(for: snapshot, at: date) <= 0 else {
            return snapshot
        }
        return complete(snapshot, at: date)
    }

    public static func elapsedTime(
        for snapshot: FocusTimerSnapshot,
        at date: Date
    ) -> TimeInterval {
        guard let startDate = snapshot.startDate else { return 0 }
        let effectiveNow: Date
        if snapshot.state == .paused, let pausedAt = snapshot.pausedAt {
            effectiveNow = pausedAt
        } else if let completedAt = snapshot.completedAt {
            effectiveNow = completedAt
        } else if let cancelledAt = snapshot.cancelledAt {
            effectiveNow = cancelledAt
        } else {
            effectiveNow = date
        }

        return max(0, effectiveNow.timeIntervalSince(startDate) - snapshot.accumulatedPause)
    }

    public static func remainingTime(
        for snapshot: FocusTimerSnapshot,
        at date: Date
    ) -> TimeInterval {
        guard snapshot.state != .idle else { return snapshot.duration }
        return max(0, snapshot.duration - elapsedTime(for: snapshot, at: date))
    }

    public static func progress(
        for snapshot: FocusTimerSnapshot,
        at date: Date
    ) -> Double {
        guard snapshot.duration > 0 else { return 1 }
        return min(1, max(0, elapsedTime(for: snapshot, at: date) / snapshot.duration))
    }

    public static func creditedDuration(
        for snapshot: FocusTimerSnapshot,
        at date: Date,
        minimum: TimeInterval = 0
    ) -> TimeInterval {
        guard snapshot.state != .idle, snapshot.state != .cancelled else { return 0 }
        let elapsed = elapsedTime(for: snapshot, at: date)
        return min(snapshot.duration, max(minimum, elapsed))
    }

    public static func focusPhase(
        for snapshot: FocusTimerSnapshot,
        at date: Date
    ) -> FocusPhase {
        switch snapshot.state {
        case .idle, .cancelled:
            return .prepare
        case .completed:
            return .wrap
        case .paused:
            return .breakTime
        case .running:
            if remainingTime(for: snapshot, at: date) <= 60 {
                return .finalMinute
            }
            if progress(for: snapshot, at: date) < 0.10 {
                return .settling
            }
            return .deepFocus
        }
    }
}
