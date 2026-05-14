import CozyCore
import Foundation

@MainActor
final class AppDataStore: ObservableObject {
    @Published private(set) var database: CozyDatabase

    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folderURL = baseURL.appendingPathComponent("CozyTime", isDirectory: true)
        try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        fileURL = folderURL.appendingPathComponent("CozyTimeData.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder.cozy.decode(CozyDatabase.self, from: data) {
            database = decoded
        } else {
            database = CozyDatabase.seeded()
            save()
        }
    }

    var tasks: [TaskItem] { database.tasks }
    var countdowns: [CountdownEvent] { database.countdowns }
    var focusSessions: [FocusSession] { database.focusSessions }
    var habits: [Habit] { database.habits }
    var rewards: [RewardItem] { database.rewards }
    var progression: ProgressionSummary { CozyProgression.summary(for: database) }

    func addTask(_ task: TaskItem) {
        database.tasks.append(task)
        save()
    }

    func updateTask(_ task: TaskItem) {
        guard let index = database.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        database.tasks[index] = task
        save()
    }

    func deleteTask(id: UUID) {
        database.tasks.removeAll { $0.id == id }
        save()
    }

    func toggleTaskCompletion(id: UUID, at date: Date = Date()) {
        guard let index = database.tasks.firstIndex(where: { $0.id == id }) else { return }
        database.tasks[index].completedAt = database.tasks[index].completedAt == nil ? date : nil
        if database.tasks[index].completedAt != nil {
        unlockReward(RewardItem(name: "Tiny Win", category: "Sticker", symbolName: "checkmark.seal.fill", colorHex: "#A8512D"), saveAfter: false)
        }
        save()
    }

    func completeTask(title: String, at date: Date = Date()) {
        guard let index = database.tasks.firstIndex(where: { $0.title == title && !$0.isCompleted }) else { return }
        database.tasks[index].completedAt = date
        save()
    }

    func completeTask(id: UUID, at date: Date = Date()) {
        guard let index = database.tasks.firstIndex(where: { $0.id == id && !$0.isCompleted }) else { return }
        database.tasks[index].completedAt = date
        save()
    }

    func addCountdown(_ event: CountdownEvent) {
        database.countdowns.append(event)
        unlockReward(RewardItem(name: "Plan Sparkle", category: "Countdown sticker", symbolName: "sparkles", colorHex: "#8CB8D0"), saveAfter: false)
        save()
    }

    func updateCountdown(_ event: CountdownEvent) {
        guard let index = database.countdowns.firstIndex(where: { $0.id == event.id }) else { return }
        database.countdowns[index] = event
        save()
    }

    func updateCountdown(withID id: UUID, remindersEnabled: Bool) {
        guard let index = database.countdowns.firstIndex(where: { $0.id == id }) else { return }
        database.countdowns[index].remindersEnabled = remindersEnabled
        save()
    }

    func deleteCountdown(id: UUID) {
        database.countdowns.removeAll { $0.id == id }
        save()
    }

    func rescheduleCountdown(id: UUID, to targetDate: Date) {
        guard let index = database.countdowns.firstIndex(where: { $0.id == id }) else { return }
        database.countdowns[index].targetDate = targetDate
        save()
    }

    func addHabit(_ habit: Habit) {
        database.habits.append(habit)
        save()
    }

    func deleteHabit(id: UUID) {
        database.habits.removeAll { $0.id == id }
        save()
    }

    func toggleHabit(id: UUID, at date: Date = Date()) {
        guard let index = database.habits.firstIndex(where: { $0.id == id }) else { return }
        database.habits[index].completionKeys = HabitMath.toggleCompletion(keys: database.habits[index].completionKeys, on: date)
        save()
    }

    func addFocusSession(_ session: FocusSession) {
        database.focusSessions.append(session)
        if session.isRewardEligible {
            unlockReward(RewardItem(name: "Focus Stamp", category: "Sticker", symbolName: "star.circle.fill", colorHex: "#A8512D"), saveAfter: false)
        }
        save()
    }

    func updateFocusMood(sessionID: UUID, moodNote: String) {
        guard let index = database.focusSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        database.focusSessions[index].moodNote = moodNote
        save()
    }

    func unlockReward(_ reward: RewardItem, saveAfter: Bool = true) {
        guard !database.rewards.contains(where: { $0.name == reward.name && $0.category == reward.category }) else { return }
        database.rewards.append(reward)
        if saveAfter { save() }
    }

    func equipReward(id: UUID) {
        guard let index = database.rewards.firstIndex(where: { $0.id == id }) else { return }
        let category = database.rewards[index].category
        for rewardIndex in database.rewards.indices where shouldEquipOnlyOne(in: category) && database.rewards[rewardIndex].category == category {
            database.rewards[rewardIndex].isEquipped = false
        }
        database.rewards[index].isEquipped = true
        save()
    }

    func purchase(_ item: ShopCatalogItem) {
        if let existing = database.rewards.first(where: { $0.name == item.name && $0.category == item.category }) {
            equipReward(id: existing.id)
            return
        }
        guard CozyProgression.canPurchase(item, database: database) else { return }
        var reward = item.rewardItem
        reward.isEquipped = true
        if shouldEquipOnlyOne(in: reward.category) {
            for rewardIndex in database.rewards.indices where database.rewards[rewardIndex].category == reward.category {
                database.rewards[rewardIndex].isEquipped = false
            }
        }
        unlockReward(reward)
    }

    func exportData() -> URL? {
        save()
        return fileURL
    }

    private func save() {
        do {
            let data = try JSONEncoder.cozy.encode(database)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Keep UI non-blocking for private v1; release builds should surface this.
        }
    }

    private func shouldEquipOnlyOne(in category: String) -> Bool {
        category.localizedCaseInsensitiveContains("outfit")
            || category.localizedCaseInsensitiveContains("accessory")
            || category.localizedCaseInsensitiveContains("skin")
            || category.localizedCaseInsensitiveContains("timer frame")
            || category.localizedCaseInsensitiveContains("room decor")
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
