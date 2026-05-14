import Foundation

public struct TaskItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var notes: String
    public var createdAt: Date
    public var dueDate: Date?
    public var completedAt: Date?
    public var priority: Int
    public var listName: String
    public var tagText: String
    public var estimatedMinutes: Int
    public var repeatRule: String

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        createdAt: Date = Date(),
        dueDate: Date? = nil,
        completedAt: Date? = nil,
        priority: Int = 0,
        listName: String = "Inbox",
        tagText: String = "",
        estimatedMinutes: Int = 25,
        repeatRule: String = ""
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.completedAt = completedAt
        self.priority = priority
        self.listName = listName
        self.tagText = tagText
        self.estimatedMinutes = estimatedMinutes
        self.repeatRule = repeatRule
    }

    public var isCompleted: Bool {
        completedAt != nil
    }

    public var filterRecord: TaskFilterRecord {
        TaskFilterRecord(title: title, dueDate: dueDate, completedAt: completedAt, priority: priority)
    }
}

public struct CountdownEvent: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var targetDate: Date
    public var createdAt: Date
    public var themeName: String
    public var stickerName: String
    public var notes: String
    public var remindersEnabled: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        targetDate: Date,
        createdAt: Date = Date(),
        themeName: String = "Blush Mochi",
        stickerName: String = "sparkles",
        notes: String = "",
        remindersEnabled: Bool = false
    ) {
        self.id = id
        self.title = title
        self.targetDate = targetDate
        self.createdAt = createdAt
        self.themeName = themeName
        self.stickerName = stickerName
        self.notes = notes
        self.remindersEnabled = remindersEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case targetDate
        case createdAt
        case themeName
        case stickerName
        case notes
        case remindersEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        targetDate = try container.decode(Date.self, forKey: .targetDate)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        themeName = try container.decode(String.self, forKey: .themeName)
        stickerName = try container.decode(String.self, forKey: .stickerName)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        remindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? false
    }

    public func daysRemaining(now: Date = Date(), calendar: Calendar = CozyCalendar.shared) -> Int {
        let from = calendar.startOfDay(for: now)
        let to = calendar.startOfDay(for: targetDate)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    public func phase(now: Date = Date(), calendar: Calendar = CozyCalendar.shared) -> CountdownPhase {
        let days = daysRemaining(now: now, calendar: calendar)
        switch days {
        case ..<0:
            return .overdue(abs(days))
        case 0:
            return .today
        case 1:
            return .tomorrow
        case 2...7:
            return .finalWeek(days)
        case 8...30:
            return .warmingUp(days)
        default:
            return .longRange(days)
        }
    }

    public func progress(now: Date = Date()) -> Double {
        if targetDate <= createdAt {
            return now >= targetDate ? 1 : 0
        }
        let total = targetDate.timeIntervalSince(createdAt)
        let elapsed = now.timeIntervalSince(createdAt)
        return min(1, max(0, elapsed / total))
    }
}

public enum CountdownPhase: Equatable, Sendable {
    case longRange(Int)
    case warmingUp(Int)
    case finalWeek(Int)
    case tomorrow
    case today
    case overdue(Int)

    public var label: String {
        switch self {
        case .longRange: "Dream board"
        case .warmingUp: "Prep season"
        case .finalWeek: "Final week"
        case .tomorrow: "Tomorrow"
        case .today: "Today"
        case .overdue: "Soft reset"
        }
    }

    public var mascotState: String {
        switch self {
        case .today: "complete"
        case .overdue: "overdue"
        default: "countdown"
        }
    }

    public var isOverdue: Bool {
        if case .overdue = self { return true }
        return false
    }
}

public struct FocusSession: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var taskTitle: String
    public var startDate: Date
    public var duration: TimeInterval
    public var accumulatedPause: TimeInterval
    public var completedAt: Date?
    public var cancelledAt: Date?
    public var moodNote: String
    public var rewardPoints: Int

    public init(
        id: UUID = UUID(),
        taskTitle: String,
        startDate: Date = Date(),
        duration: TimeInterval = 25 * 60,
        accumulatedPause: TimeInterval = 0,
        completedAt: Date? = nil,
        cancelledAt: Date? = nil,
        moodNote: String = "",
        rewardPoints: Int = 0
    ) {
        self.id = id
        self.taskTitle = taskTitle
        self.startDate = startDate
        self.duration = duration
        self.accumulatedPause = accumulatedPause
        self.completedAt = completedAt
        self.cancelledAt = cancelledAt
        self.moodNote = moodNote
        self.rewardPoints = rewardPoints
    }

    public var completedMinutes: Int {
        Int((duration / 60).rounded())
    }

    public var reportingDate: Date {
        completedAt ?? cancelledAt ?? startDate
    }

    public var isRewardEligible: Bool {
        rewardPoints > 0 || duration >= 5 * 60
    }
}

public struct Habit: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var targetPerWeek: Int
    public var completionKeys: String
    public var stickerName: String
    public var graceDays: Int

    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        targetPerWeek: Int = 4,
        completionKeys: String = "",
        stickerName: String = "leaf",
        graceDays: Int = 1
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.targetPerWeek = targetPerWeek
        self.completionKeys = completionKeys
        self.stickerName = stickerName
        self.graceDays = graceDays
    }
}

public struct RewardItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var category: String
    public var symbolName: String
    public var colorHex: String
    public var unlockedAt: Date
    public var isEquipped: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        category: String,
        symbolName: String,
        colorHex: String,
        unlockedAt: Date = Date(),
        isEquipped: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.unlockedAt = unlockedAt
        self.isEquipped = isEquipped
    }
}

public struct CozyDatabase: Codable, Equatable, Sendable {
    public var tasks: [TaskItem]
    public var countdowns: [CountdownEvent]
    public var focusSessions: [FocusSession]
    public var habits: [Habit]
    public var rewards: [RewardItem]

    public init(
        tasks: [TaskItem] = [],
        countdowns: [CountdownEvent] = [],
        focusSessions: [FocusSession] = [],
        habits: [Habit] = [],
        rewards: [RewardItem] = []
    ) {
        self.tasks = tasks
        self.countdowns = countdowns
        self.focusSessions = focusSessions
        self.habits = habits
        self.rewards = rewards
    }
}
