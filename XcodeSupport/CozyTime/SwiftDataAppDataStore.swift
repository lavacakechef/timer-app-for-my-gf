import CozyCore
import Foundation
import SwiftData
import SwiftUI

@Model
final class StoredTaskItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String
    var createdAt: Date
    var dueDate: Date?
    var completedAt: Date?
    var priority: Int
    var listName: String
    var tagText: String
    var estimatedMinutes: Int
    var repeatRule: String

    init(from task: TaskItem) {
        id = task.id
        title = task.title
        notes = task.notes
        createdAt = task.createdAt
        dueDate = task.dueDate
        completedAt = task.completedAt
        priority = task.priority
        listName = task.listName
        tagText = task.tagText
        estimatedMinutes = task.estimatedMinutes
        repeatRule = task.repeatRule
    }

    var value: TaskItem {
        TaskItem(
            id: id,
            title: title,
            notes: notes,
            createdAt: createdAt,
            dueDate: dueDate,
            completedAt: completedAt,
            priority: priority,
            listName: listName,
            tagText: tagText,
            estimatedMinutes: estimatedMinutes,
            repeatRule: repeatRule
        )
    }
}

@Model
final class StoredCountdownEvent {
    @Attribute(.unique) var id: UUID
    var title: String
    var targetDate: Date
    var createdAt: Date
    var themeName: String
    var stickerName: String
    var notes: String
    var remindersEnabled: Bool = false

    init(from event: CountdownEvent) {
        id = event.id
        title = event.title
        targetDate = event.targetDate
        createdAt = event.createdAt
        themeName = event.themeName
        stickerName = event.stickerName
        notes = event.notes
        remindersEnabled = event.remindersEnabled
    }

    var value: CountdownEvent {
        CountdownEvent(
            id: id,
            title: title,
            targetDate: targetDate,
            createdAt: createdAt,
            themeName: themeName,
            stickerName: stickerName,
            notes: notes,
            remindersEnabled: remindersEnabled
        )
    }
}

@Model
final class StoredFocusSession {
    @Attribute(.unique) var id: UUID
    var taskTitle: String
    var startDate: Date
    var duration: TimeInterval
    var accumulatedPause: TimeInterval
    var completedAt: Date?
    var cancelledAt: Date?
    var moodNote: String
    var rewardPoints: Int

    init(from session: FocusSession) {
        id = session.id
        taskTitle = session.taskTitle
        startDate = session.startDate
        duration = session.duration
        accumulatedPause = session.accumulatedPause
        completedAt = session.completedAt
        cancelledAt = session.cancelledAt
        moodNote = session.moodNote
        rewardPoints = session.rewardPoints
    }

    var value: FocusSession {
        FocusSession(
            id: id,
            taskTitle: taskTitle,
            startDate: startDate,
            duration: duration,
            accumulatedPause: accumulatedPause,
            completedAt: completedAt,
            cancelledAt: cancelledAt,
            moodNote: moodNote,
            rewardPoints: rewardPoints
        )
    }
}

@Model
final class StoredHabit {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var targetPerWeek: Int
    var completionKeys: String
    var stickerName: String
    var graceDays: Int

    init(from habit: Habit) {
        id = habit.id
        title = habit.title
        createdAt = habit.createdAt
        targetPerWeek = habit.targetPerWeek
        completionKeys = habit.completionKeys
        stickerName = habit.stickerName
        graceDays = habit.graceDays
    }

    var value: Habit {
        Habit(
            id: id,
            title: title,
            createdAt: createdAt,
            targetPerWeek: targetPerWeek,
            completionKeys: completionKeys,
            stickerName: stickerName,
            graceDays: graceDays
        )
    }
}

@Model
final class StoredRewardItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String
    var symbolName: String
    var colorHex: String
    var unlockedAt: Date
    var isEquipped: Bool

    init(from reward: RewardItem) {
        id = reward.id
        name = reward.name
        category = reward.category
        symbolName = reward.symbolName
        colorHex = reward.colorHex
        unlockedAt = reward.unlockedAt
        isEquipped = reward.isEquipped
    }

    var value: RewardItem {
        RewardItem(
            id: id,
            name: name,
            category: category,
            symbolName: symbolName,
            colorHex: colorHex,
            unlockedAt: unlockedAt,
            isEquipped: isEquipped
        )
    }
}

enum CozySwiftDataSchema {
    static let models: [any PersistentModel.Type] = [
        StoredTaskItem.self,
        StoredCountdownEvent.self,
        StoredFocusSession.self,
        StoredHabit.self,
        StoredRewardItem.self
    ]

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

@MainActor
final class AppDataStore: ObservableObject {
    @Published private(set) var database = CozyDatabase()

    private let container: ModelContainer
    private let legacyJSONURL: URL

    init(
        container: ModelContainer? = nil,
        legacyJSONURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        do {
            if let container {
                self.container = container
            } else {
                self.container = try CozySwiftDataSchema.makeContainer(inMemory: isUITesting)
            }
        } catch {
            fatalError("Could not create SwiftData container: \(error)")
        }

        self.legacyJSONURL = legacyJSONURL ?? Self.defaultLegacyJSONURL(fileManager: fileManager, isUITesting: isUITesting)

        do {
            try CozyJSONToSwiftDataMigrator.migrateIfNeeded(
                legacyJSONURL: self.legacyJSONURL,
                context: self.container.mainContext
            )
            try seedIfNeeded()
            try reload()
        } catch {
            database = CozyDatabase()
        }
    }

    var tasks: [TaskItem] { database.tasks }
    var countdowns: [CountdownEvent] { database.countdowns }
    var focusSessions: [FocusSession] { database.focusSessions }
    var habits: [Habit] { database.habits }
    var rewards: [RewardItem] { database.rewards }
    var progression: ProgressionSummary { CozyProgression.summary(for: database) }

    func addTask(_ task: TaskItem) {
        container.mainContext.insert(StoredTaskItem(from: task))
        saveAndReload()
    }

    func updateTask(_ task: TaskItem) {
        guard let stored = fetchTask(id: task.id) else { return }
        stored.title = task.title
        stored.notes = task.notes
        stored.dueDate = task.dueDate
        stored.completedAt = task.completedAt
        stored.priority = task.priority
        stored.listName = task.listName
        stored.tagText = task.tagText
        stored.estimatedMinutes = task.estimatedMinutes
        stored.repeatRule = task.repeatRule
        saveAndReload()
    }

    func deleteTask(id: UUID) {
        guard let task = fetchTask(id: id) else { return }
        container.mainContext.delete(task)
        saveAndReload()
    }

    func toggleTaskCompletion(id: UUID, at date: Date = Date()) {
        guard let task = fetchTask(id: id) else { return }
        task.completedAt = task.completedAt == nil ? date : nil
        if task.completedAt != nil {
            insertRewardIfNeeded(RewardItem(name: "Tiny Win", category: "Sticker", symbolName: "checkmark.seal.fill", colorHex: "#A8512D"))
        }
        saveAndReload()
    }

    func completeTask(title: String, at date: Date = Date()) {
        let descriptor = FetchDescriptor<StoredTaskItem>(
            predicate: #Predicate { $0.title == title && $0.completedAt == nil },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        guard let task = try? container.mainContext.fetch(descriptor).first else { return }
        task.completedAt = date
        saveAndReload()
    }

    func completeTask(id: UUID, at date: Date = Date()) {
        guard let task = fetchTask(id: id), task.completedAt == nil else { return }
        task.completedAt = date
        saveAndReload()
    }

    func addCountdown(_ event: CountdownEvent) {
        container.mainContext.insert(StoredCountdownEvent(from: event))
        insertRewardIfNeeded(RewardItem(name: "Plan Sparkle", category: "Countdown sticker", symbolName: "sparkles", colorHex: "#8CB8D0"))
        saveAndReload()
    }

    func updateCountdown(_ event: CountdownEvent) {
        let descriptor = FetchDescriptor<StoredCountdownEvent>(predicate: #Predicate { $0.id == event.id })
        guard let stored = try? container.mainContext.fetch(descriptor).first else { return }
        stored.title = event.title
        stored.targetDate = event.targetDate
        stored.createdAt = event.createdAt
        stored.themeName = event.themeName
        stored.stickerName = event.stickerName
        stored.notes = event.notes
        stored.remindersEnabled = event.remindersEnabled
        saveAndReload()
    }

    func updateCountdown(withID id: UUID, remindersEnabled: Bool) {
        let descriptor = FetchDescriptor<StoredCountdownEvent>(predicate: #Predicate { $0.id == id })
        guard let stored = try? container.mainContext.fetch(descriptor).first else { return }
        stored.remindersEnabled = remindersEnabled
        saveAndReload()
    }

    func deleteCountdown(id: UUID) {
        let descriptor = FetchDescriptor<StoredCountdownEvent>(predicate: #Predicate { $0.id == id })
        guard let event = try? container.mainContext.fetch(descriptor).first else { return }
        container.mainContext.delete(event)
        saveAndReload()
    }

    func rescheduleCountdown(id: UUID, to targetDate: Date) {
        let descriptor = FetchDescriptor<StoredCountdownEvent>(predicate: #Predicate { $0.id == id })
        guard let event = try? container.mainContext.fetch(descriptor).first else { return }
        event.targetDate = targetDate
        saveAndReload()
    }

    func addHabit(_ habit: Habit) {
        container.mainContext.insert(StoredHabit(from: habit))
        saveAndReload()
    }

    func deleteHabit(id: UUID) {
        let descriptor = FetchDescriptor<StoredHabit>(predicate: #Predicate { $0.id == id })
        guard let habit = try? container.mainContext.fetch(descriptor).first else { return }
        container.mainContext.delete(habit)
        saveAndReload()
    }

    func toggleHabit(id: UUID, at date: Date = Date()) {
        let descriptor = FetchDescriptor<StoredHabit>(predicate: #Predicate { $0.id == id })
        guard let habit = try? container.mainContext.fetch(descriptor).first else { return }
        habit.completionKeys = HabitMath.toggleCompletion(keys: habit.completionKeys, on: date)
        saveAndReload()
    }

    func addFocusSession(_ session: FocusSession) {
        container.mainContext.insert(StoredFocusSession(from: session))
        if session.isRewardEligible {
            insertRewardIfNeeded(RewardItem(name: "Focus Stamp", category: "Sticker", symbolName: "star.circle.fill", colorHex: "#A8512D"))
        }
        saveAndReload()
    }

    func updateFocusMood(sessionID: UUID, moodNote: String) {
        let descriptor = FetchDescriptor<StoredFocusSession>(predicate: #Predicate { $0.id == sessionID })
        guard let session = try? container.mainContext.fetch(descriptor).first else { return }
        session.moodNote = moodNote
        saveAndReload()
    }

    func unlockReward(_ reward: RewardItem, saveAfter: Bool = true) {
        guard insertRewardIfNeeded(reward) else { return }
        if saveAfter { saveAndReload() }
    }

    func equipReward(id: UUID) {
        let descriptor = FetchDescriptor<StoredRewardItem>(predicate: #Predicate { $0.id == id })
        guard let reward = try? container.mainContext.fetch(descriptor).first else { return }
        if shouldEquipOnlyOne(in: reward.category) {
            let category = reward.category
            let categoryDescriptor = FetchDescriptor<StoredRewardItem>(predicate: #Predicate { $0.category == category })
            if let rewards = try? container.mainContext.fetch(categoryDescriptor) {
                rewards.forEach { $0.isEquipped = false }
            }
        }
        reward.isEquipped = true
        saveAndReload()
    }

    func purchase(_ item: ShopCatalogItem) {
        let itemName = item.name
        let itemCategory = item.category
        let descriptor = FetchDescriptor<StoredRewardItem>(
            predicate: #Predicate { $0.name == itemName && $0.category == itemCategory }
        )
        if let existing = try? container.mainContext.fetch(descriptor).first {
            equipReward(id: existing.id)
            return
        }

        guard CozyProgression.canPurchase(item, database: database) else { return }
        if shouldEquipOnlyOne(in: item.category) {
            let category = item.category
            let categoryDescriptor = FetchDescriptor<StoredRewardItem>(predicate: #Predicate { $0.category == category })
            if let rewards = try? container.mainContext.fetch(categoryDescriptor) {
                rewards.forEach { $0.isEquipped = false }
            }
        }
        var reward = item.rewardItem
        reward.isEquipped = true
        container.mainContext.insert(StoredRewardItem(from: reward))
        saveAndReload()
    }

    func exportData() -> URL? {
        do {
            let data = try JSONEncoder.cozy.encode(database)
            let url = legacyJSONURL.deletingLastPathComponent().appendingPathComponent("CozyTimeExport.json")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            return nil
        }
    }

    private func saveAndReload() {
        do {
            try container.mainContext.save()
            try reload()
        } catch {
            try? reload()
        }
    }

    private func shouldEquipOnlyOne(in category: String) -> Bool {
        category.localizedCaseInsensitiveContains("outfit")
            || category.localizedCaseInsensitiveContains("accessory")
            || category.localizedCaseInsensitiveContains("skin")
            || category.localizedCaseInsensitiveContains("timer frame")
            || category.localizedCaseInsensitiveContains("room decor")
    }

    private func reload() throws {
        let tasks = try container.mainContext.fetch(FetchDescriptor<StoredTaskItem>(sortBy: [SortDescriptor(\.createdAt)])).map(\.value)
        let countdowns = try container.mainContext.fetch(FetchDescriptor<StoredCountdownEvent>(sortBy: [SortDescriptor(\.targetDate)])).map(\.value)
        let sessions = try container.mainContext.fetch(FetchDescriptor<StoredFocusSession>(sortBy: [SortDescriptor(\.startDate)])).map(\.value)
        let habits = try container.mainContext.fetch(FetchDescriptor<StoredHabit>(sortBy: [SortDescriptor(\.createdAt)])).map(\.value)
        let rewards = try container.mainContext.fetch(FetchDescriptor<StoredRewardItem>(sortBy: [SortDescriptor(\.unlockedAt)])).map(\.value)
        database = CozyDatabase(tasks: tasks, countdowns: countdowns, focusSessions: sessions, habits: habits, rewards: rewards)
    }

    private func seedIfNeeded() throws {
        guard try !CozySwiftDataStoreState.hasAnyData(in: container.mainContext) else { return }

        let seed = CozyDatabase.seeded()
        seed.tasks.forEach { container.mainContext.insert(StoredTaskItem(from: $0)) }
        seed.countdowns.forEach { container.mainContext.insert(StoredCountdownEvent(from: $0)) }
        seed.focusSessions.forEach { container.mainContext.insert(StoredFocusSession(from: $0)) }
        seed.habits.forEach { container.mainContext.insert(StoredHabit(from: $0)) }
        seed.rewards.forEach { container.mainContext.insert(StoredRewardItem(from: $0)) }
        try container.mainContext.save()
    }

    private func fetchTask(id: UUID) -> StoredTaskItem? {
        let descriptor = FetchDescriptor<StoredTaskItem>(predicate: #Predicate { $0.id == id })
        return try? container.mainContext.fetch(descriptor).first
    }

    @discardableResult
    private func insertRewardIfNeeded(_ reward: RewardItem) -> Bool {
        let rewardName = reward.name
        let rewardCategory = reward.category
        let descriptor = FetchDescriptor<StoredRewardItem>(
            predicate: #Predicate { $0.name == rewardName && $0.category == rewardCategory }
        )
        guard (try? container.mainContext.fetch(descriptor).isEmpty) ?? false else { return false }
        container.mainContext.insert(StoredRewardItem(from: reward))
        return true
    }

    private static func defaultLegacyJSONURL(fileManager: FileManager, isUITesting: Bool = false) -> URL {
        if isUITesting {
            return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("CozyTimeUITests-\(UUID().uuidString)", isDirectory: true)
                .appendingPathComponent("CozyTimeData.json")
        }

        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return baseURL
            .appendingPathComponent("CozyTime", isDirectory: true)
            .appendingPathComponent("CozyTimeData.json")
    }
}

enum CozySwiftDataStoreState {
    static func hasAnyData(in context: ModelContext) throws -> Bool {
        try hasAny(StoredTaskItem.self, in: context)
            || hasAny(StoredCountdownEvent.self, in: context)
            || hasAny(StoredFocusSession.self, in: context)
            || hasAny(StoredHabit.self, in: context)
            || hasAny(StoredRewardItem.self, in: context)
    }

    private static func hasAny<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<T>()
        descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
    }
}

enum CozyJSONToSwiftDataMigrator {
    static func migrateIfNeeded(legacyJSONURL: URL, context: ModelContext) throws {
        guard try !CozySwiftDataStoreState.hasAnyData(in: context),
              FileManager.default.fileExists(atPath: legacyJSONURL.path) else { return }

        let data = try Data(contentsOf: legacyJSONURL)
        let database = try JSONDecoder.cozy.decode(CozyDatabase.self, from: data)

        database.tasks.forEach { context.insert(StoredTaskItem(from: $0)) }
        database.countdowns.forEach { context.insert(StoredCountdownEvent(from: $0)) }
        database.focusSessions.forEach { context.insert(StoredFocusSession(from: $0)) }
        database.habits.forEach { context.insert(StoredHabit(from: $0)) }
        database.rewards.forEach { context.insert(StoredRewardItem(from: $0)) }
        try context.save()
    }
}

private extension JSONEncoder {
    static var cozy: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var cozy: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension CozyDatabase {
    static func seeded(now: Date = Date()) -> CozyDatabase {
        let calendar = Calendar.autoupdatingCurrent
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: now)

        return CozyDatabase(
            tasks: [
                TaskItem(title: "Start one cozy focus block", notes: "Pick one tiny thing and let Mochi keep time.", dueDate: now, priority: 2, tagText: "focus", estimatedMinutes: 25),
                TaskItem(title: "Spend first paws in the shop", notes: "Tiny sessions unlock accessories and room decor.", dueDate: tomorrow, priority: 1, tagText: "rewards", estimatedMinutes: 15),
                TaskItem(title: "Plan tomorrow’s soft reset", dueDate: nextWeek, priority: 1, tagText: "review", estimatedMinutes: 20)
            ],
            countdowns: [
                CountdownEvent(title: "First cozy release", targetDate: nextWeek ?? now, themeName: CozyTheme.defaultName, stickerName: "sparkles", notes: "Private build for daily use.")
            ],
            habits: [
                Habit(title: "One focused block", targetPerWeek: 4, stickerName: "timer"),
                Habit(title: "Gentle shutdown", targetPerWeek: 3, stickerName: "moon.stars.fill")
            ],
            rewards: [
                RewardItem(name: "Rose Ring Timer Skin", category: "Timer skin", symbolName: "heart.circle.fill", colorHex: "#B84E73", isEquipped: true),
                RewardItem(name: "Tiny Win Sticker", category: "Sticker", symbolName: "star.fill", colorHex: "#A8512D", isEquipped: true),
                RewardItem(name: "Starter Desk Mat", category: "Room decor", symbolName: "rectangle.roundedtop.fill", colorHex: "#DDEDE7", isEquipped: true)
            ]
        )
    }
}
