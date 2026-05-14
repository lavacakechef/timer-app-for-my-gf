import CozyCore
import Combine
import Foundation

@MainActor
final class FocusTimerStore: ObservableObject {
    @Published private(set) var snapshot: FocusTimerSnapshot
    @Published private(set) var currentDate = Date()
    @Published var activeTaskTitle: String
    @Published var activeTaskID: UUID?

    private let defaults: UserDefaults
    private let snapshotKey = "focus.snapshot.v1"
    private let titleKey = "focus.activeTaskTitle.v1"
    private let taskIDKey = "focus.activeTaskID.v1"
    private let processActivityReason = "CozyTime has an active focus timer."
    private var ticker: AnyCancellable?
    private var keepsProcessAlive = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: snapshotKey),
           let decoded = try? JSONDecoder().decode(FocusTimerSnapshot.self, from: data) {
            snapshot = decoded
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
        updateTicker()
        updateProcessActivity()
        save()
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
                }
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
