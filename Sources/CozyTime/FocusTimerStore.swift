import CozyCore
import Combine
import Foundation

enum FocusDefaults {
    static let lastFocusMinutesKey = "focus.lastFocusMinutes"

    static func rememberedFocusMinutes(in defaults: UserDefaults = .standard) -> Int {
        let raw = defaults.integer(forKey: lastFocusMinutesKey)
        return raw == 0 ? 25 : max(1, raw)
    }
}

@MainActor
final class FocusTimerStore: ObservableObject {
    @Published private(set) var snapshot: FocusTimerSnapshot
    @Published private(set) var currentDate = Date()
    @Published var activeTaskTitle: String
    @Published var activeTaskID: UUID?
    /// Number of 5-minute boundaries the current session has crossed. Resets
    /// on `start`/`reset`/`cancel`. Drives the in-session paw-ticker overlay.
    @Published private(set) var pawsCrossedThisSession: Int = 0
    /// Fires once each time `pawsCrossedThisSession` advances. The focus
    /// screen subscribes to this to spawn the "+1 paw" drifter + ring pulse.
    /// Apple Fitness boundary-celebration precedent; values are not coalesced
    /// so each crossing yields its own visual.
    let pawBoundaryDidCross = PassthroughSubject<Int, Never>()

    private let defaults: UserDefaults
    private let snapshotKey = "focus.snapshot.v1"
    private let titleKey = "focus.activeTaskTitle.v1"
    private let taskIDKey = "focus.activeTaskID.v1"
    private let processActivityReason = "CozyTime has an active focus timer."
    private var ticker: AnyCancellable?
    private var keepsProcessAlive = false
    /// Per-session paw-boundary tracking — credited seconds / 300 (5-min).
    private static let pawBoundarySeconds: Double = 300

    init(defaults: UserDefaults = .standard, now: Date = Date()) {
        self.defaults = defaults
        if let data = defaults.data(forKey: snapshotKey),
           let decoded = try? JSONDecoder().decode(FocusTimerSnapshot.self, from: data) {
            snapshot = Self.recoverIfStale(decoded, now: now)
        } else {
            snapshot = FocusTimerSnapshot()
        }
        activeTaskTitle = defaults.string(forKey: titleKey) ?? "Quick focus"
        if let taskIDString = defaults.string(forKey: taskIDKey) {
            activeTaskID = UUID(uuidString: taskIDString)
        } else {
            activeTaskID = nil
        }
        updateTicker()
        updateProcessActivity()
    }

    /// Guards against the "zombie timer" failure mode: if the user quits mid-focus and walks
    /// away for hours, the persisted snapshot would otherwise be loaded as `.running` and
    /// `refreshCompletion(at:)` would immediately auto-credit a session the user did not
    /// actually do. If we detect that wall-clock has advanced past the duration AND we're
    /// more than a generous grace beyond, treat it as needing the user's manual review.
    /// `complete()` flow puts the snapshot into `.completed`, which surfaces the completion
    /// review card with reward — but the grace check below limits this to a reasonable
    /// gap (10 minutes after the session would have ended). Anything longer than that is
    /// almost certainly an "I forgot to quit cleanly" situation, so we discard.
    private static func recoverIfStale(_ snapshot: FocusTimerSnapshot, now: Date) -> FocusTimerSnapshot {
        guard snapshot.state == .running, let startDate = snapshot.startDate else { return snapshot }
        let expectedEnd = startDate.addingTimeInterval(snapshot.duration + snapshot.accumulatedPause)
        let elapsedPastEnd = now.timeIntervalSince(expectedEnd)
        if elapsedPastEnd > 10 * 60 {
            // App was AFK long past the session boundary — discard rather than auto-credit.
            return FocusTimerSnapshot(duration: snapshot.duration)
        }
        return snapshot
    }

    var isRunning: Bool {
        snapshot.state == .running
    }

    var isPaused: Bool {
        snapshot.state == .paused
    }

    var isActive: Bool {
        snapshot.state == .running || snapshot.state == .paused
    }

    var needsCompletionReview: Bool {
        snapshot.state == .completed
    }

    var canStartNewSession: Bool {
        !isActive && !needsCompletionReview
    }

    func start(taskTitle: String, taskID: UUID? = nil, duration: TimeInterval, at date: Date = Date()) {
        guard canStartNewSession else { return }
        let cleanTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        activeTaskTitle = cleanTitle.isEmpty ? "Quick focus" : cleanTitle
        activeTaskID = taskID
        snapshot = TimerEngine.start(at: date, duration: duration)
        currentDate = date
        pawsCrossedThisSession = 0   // Fresh session, no boundaries crossed yet.
        updateTicker()
        updateProcessActivity()
        save()
    }

    func startRememberedQuickFocus(defaults: UserDefaults = .standard, at date: Date = Date()) {
        start(
            taskTitle: "Quick focus",
            duration: TimeInterval(FocusDefaults.rememberedFocusMinutes(in: defaults) * 60),
            at: date
        )
    }

    func pause(at date: Date = Date()) {
        snapshot = TimerEngine.pause(snapshot, at: date)
        currentDate = date
        updateTicker()
        updateProcessActivity()
        save()
    }

    func resume(at date: Date = Date()) {
        snapshot = TimerEngine.resume(snapshot, at: date)
        currentDate = date
        updateTicker()
        updateProcessActivity()
        save()
    }

    func cancel(at date: Date = Date()) {
        snapshot = TimerEngine.cancel(snapshot, at: date)
        currentDate = date
        pawsCrossedThisSession = 0
        updateTicker()
        updateProcessActivity()
        save()
    }

    func complete(at date: Date = Date()) {
        snapshot = TimerEngine.complete(snapshot, at: date)
        currentDate = date
        updateTicker()
        updateProcessActivity()
        save()
    }

    func reset(duration: TimeInterval = 25 * 60) {
        snapshot = FocusTimerSnapshot(duration: duration)
        currentDate = Date()
        activeTaskID = nil
        activeTaskTitle = "Quick focus"
        pawsCrossedThisSession = 0
        updateTicker()
        updateProcessActivity()
        save()
    }

    func remaining(at date: Date = Date()) -> TimeInterval {
        TimerEngine.remainingTime(for: snapshot, at: date)
    }

    func progress(at date: Date = Date()) -> Double {
        TimerEngine.progress(for: snapshot, at: date)
    }

    func phase(at date: Date = Date()) -> FocusPhase {
        TimerEngine.focusPhase(for: snapshot, at: date)
    }

    func menuBarTitle(at date: Date = Date()) -> String {
        guard isActive || needsCompletionReview else { return "CozyTime" }
        return CozyFormatters.timerString(remaining(at: date))
    }

    func refreshCompletion(at date: Date = Date()) {
        let next = TimerEngine.completeIfNeeded(snapshot, at: date)
        guard next != snapshot else { return }
        snapshot = next
        currentDate = date
        updateTicker()
        updateProcessActivity()
        save()
    }

    private func updateTicker() {
        guard snapshot.state == .running else {
            ticker?.cancel()
            ticker = nil
            return
        }
        guard ticker == nil else { return }
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                Task { @MainActor in
                    self?.currentDate = date
                    self?.refreshCompletion(at: date)
                    self?.evaluatePawBoundary(at: date)
                }
            }
    }

    /// Per-second hook — checks whether the credited duration has crossed a
    /// new 5-minute boundary since the last tick. When it does, increments
    /// `pawsCrossedThisSession` and publishes the new count on
    /// `pawBoundaryDidCross` so the focus screen can animate a "+1" drifter
    /// and pulse the ring. Idempotent — only fires once per crossing.
    private func evaluatePawBoundary(at date: Date) {
        guard snapshot.state == .running else { return }
        let credited = TimerEngine.creditedDuration(for: snapshot, at: date)
        let boundary = Int((credited / Self.pawBoundarySeconds).rounded(.down))
        if boundary > pawsCrossedThisSession {
            pawsCrossedThisSession = boundary
            pawBoundaryDidCross.send(boundary)
        }
    }

    private func updateProcessActivity() {
        let shouldKeepAlive = isActive || needsCompletionReview
        guard shouldKeepAlive != keepsProcessAlive else { return }
        keepsProcessAlive = shouldKeepAlive
        if shouldKeepAlive {
            ProcessInfo.processInfo.disableAutomaticTermination(processActivityReason)
            ProcessInfo.processInfo.disableSuddenTermination()
        } else {
            ProcessInfo.processInfo.enableAutomaticTermination(processActivityReason)
            ProcessInfo.processInfo.enableSuddenTermination()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: snapshotKey)
        }
        defaults.set(activeTaskTitle, forKey: titleKey)
        if let activeTaskID {
            defaults.set(activeTaskID.uuidString, forKey: taskIDKey)
        } else {
            defaults.removeObject(forKey: taskIDKey)
        }
    }
}
