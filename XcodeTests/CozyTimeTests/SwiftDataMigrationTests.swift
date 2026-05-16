import CozyCore
import SwiftData
import XCTest
@testable import CozyTime

@MainActor
final class SwiftDataMigrationTests: XCTestCase {
    func testMigratesLegacyJSONIntoSwiftDataWhenStoreIsEmpty() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CozyTimeMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let legacyURL = tempDirectory.appendingPathComponent("CozyTimeData.json")
        let taskID = UUID()
        let countdownID = UUID()
        let habitID = UUID()
        let rewardID = UUID()
        let sessionID = UUID()
        let now = Date(timeIntervalSinceReferenceDate: 800_000)
        let database = CozyDatabase(
            tasks: [
                TaskItem(id: taskID, title: "Migrated task", notes: "Keep the note", createdAt: now, dueDate: now, priority: 2, listName: "Inbox", tagText: "migration", estimatedMinutes: 25)
            ],
            countdowns: [
                CountdownEvent(id: countdownID, title: "Migrated countdown", targetDate: now.addingTimeInterval(86_400), createdAt: now, themeName: "Jade Desk", stickerName: "sparkles")
            ],
            focusSessions: [
                FocusSession(id: sessionID, taskTitle: "Migrated task", startDate: now, duration: 1_500, completedAt: now.addingTimeInterval(1_500), rewardPoints: 5)
            ],
            habits: [
                Habit(id: habitID, title: "Migrated habit", createdAt: now, targetPerWeek: 4, completionKeys: "2026-05-13", stickerName: "timer", graceDays: 1)
            ],
            rewards: [
                RewardItem(id: rewardID, name: "Migrated sticker", category: "Sticker", symbolName: "star.fill", colorHex: "#F28C38", unlockedAt: now)
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(database).write(to: legacyURL, options: [.atomic])

        let container = try CozySwiftDataSchema.makeContainer(inMemory: true)
        let store = AppDataStore(container: container, legacyJSONURL: legacyURL)

        XCTAssertEqual(store.tasks.map(\.id), [taskID])
        XCTAssertEqual(store.countdowns.map(\.id), [countdownID])
        XCTAssertEqual(store.focusSessions.map(\.id), [sessionID])
        XCTAssertEqual(store.habits.map(\.id), [habitID])
        XCTAssertEqual(store.rewards.map(\.id), [rewardID])
        XCTAssertEqual(store.tasks.first?.notes, "Keep the note")
        XCTAssertEqual(store.tasks.first?.tagText, "migration")
    }

    func testMigratesLegacyJSONThatDoesNotHaveBonusPaws() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CozyTimeLegacyBonusPawsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let legacyURL = tempDirectory.appendingPathComponent("CozyTimeData.json")
        let json = """
        {
          "countdowns": [],
          "focusSessions": [],
          "habits": [],
          "rewards": [],
          "tasks": [
            {
              "completedAt": null,
              "createdAt": "2026-05-17T00:00:00Z",
              "dueDate": null,
              "estimatedMinutes": 25,
              "id": "00000000-0000-0000-0000-000000000202",
              "listName": "Inbox",
              "notes": "Old app data",
              "priority": 1,
              "repeatRule": "",
              "tagText": "legacy",
              "title": "Legacy task survives"
            }
          ]
        }
        """
        try Data(json.utf8).write(to: legacyURL, options: [.atomic])

        let container = try CozySwiftDataSchema.makeContainer(inMemory: true)
        let store = AppDataStore(container: container, legacyJSONURL: legacyURL)

        XCTAssertEqual(store.tasks.map(\.title), ["Legacy task survives"])
        XCTAssertEqual(store.database.bonusPaws, UserDefaults.standard.integer(forKey: "cozy.bonusPaws"))
    }

    func testSeedsOnlyWhenStoreAndLegacyJSONAreEmpty() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CozyTimeSeedTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let missingLegacyURL = tempDirectory.appendingPathComponent("MissingData.json")
        let container = try CozySwiftDataSchema.makeContainer(inMemory: true)
        let store = AppDataStore(container: container, legacyJSONURL: missingLegacyURL)

        XCTAssertFalse(store.tasks.isEmpty)
        XCTAssertFalse(store.countdowns.isEmpty)
        XCTAssertFalse(store.habits.isEmpty)
        XCTAssertFalse(store.rewards.isEmpty)
    }

    func testPartialStoreDoesNotGetPollutedBySeedsOrLegacyMigration() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CozyTimePartialStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let legacyURL = tempDirectory.appendingPathComponent("CozyTimeData.json")
        let legacyDatabase = CozyDatabase(tasks: [TaskItem(title: "Should not migrate")])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(legacyDatabase).write(to: legacyURL, options: [.atomic])

        let container = try CozySwiftDataSchema.makeContainer(inMemory: true)
        let existingReward = RewardItem(name: "Existing only", category: "Sticker", symbolName: "star.fill", colorHex: "#F28C38")
        container.mainContext.insert(StoredRewardItem(from: existingReward))
        try container.mainContext.save()

        let store = AppDataStore(container: container, legacyJSONURL: legacyURL)

        XCTAssertTrue(store.tasks.isEmpty)
        XCTAssertEqual(store.rewards.map(\.name), ["Existing only"])
    }

    func testCompletingTaskByIDDoesNotCompleteDuplicateTitle() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CozyTimeDuplicateTaskTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let container = try CozySwiftDataSchema.makeContainer(inMemory: true)
        container.mainContext.insert(StoredRewardItem(from: RewardItem(name: "Existing", category: "Sticker", symbolName: "star", colorHex: "#F28C38")))
        try container.mainContext.save()
        let store = AppDataStore(
            container: container,
            legacyJSONURL: tempDirectory.appendingPathComponent("MissingData.json")
        )
        let first = TaskItem(title: "Same title", createdAt: Date(timeIntervalSinceReferenceDate: 1))
        let second = TaskItem(title: "Same title", createdAt: Date(timeIntervalSinceReferenceDate: 2))

        store.addTask(first)
        store.addTask(second)
        store.completeTask(id: second.id, at: Date(timeIntervalSinceReferenceDate: 3))

        let matching = store.tasks.filter { $0.title == "Same title" }
        XCTAssertEqual(matching.first { $0.id == first.id }?.isCompleted, false)
        XCTAssertEqual(matching.first { $0.id == second.id }?.isCompleted, true)
    }

    func testDeletingTaskByIDOnlyRemovesThatTask() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CozyTimeDeleteTaskTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let container = try CozySwiftDataSchema.makeContainer(inMemory: true)
        container.mainContext.insert(StoredRewardItem(from: RewardItem(name: "Existing", category: "Sticker", symbolName: "star", colorHex: "#F28C38")))
        try container.mainContext.save()
        let store = AppDataStore(
            container: container,
            legacyJSONURL: tempDirectory.appendingPathComponent("MissingData.json")
        )
        let first = TaskItem(title: "Keep this", createdAt: Date(timeIntervalSinceReferenceDate: 1))
        let second = TaskItem(title: "Undo-created prep task", createdAt: Date(timeIntervalSinceReferenceDate: 2))

        store.addTask(first)
        store.addTask(second)
        store.deleteTask(id: second.id)

        XCTAssertTrue(store.tasks.contains { $0.id == first.id })
        XCTAssertFalse(store.tasks.contains { $0.id == second.id })
    }

    func testUpdatingHabitPreservesIdentityAndCompletionHistory() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CozyTimeUpdateHabitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let container = try CozySwiftDataSchema.makeContainer(inMemory: true)
        container.mainContext.insert(StoredRewardItem(from: RewardItem(name: "Existing", category: "Sticker", symbolName: "star", colorHex: "#F28C38")))
        try container.mainContext.save()
        let store = AppDataStore(
            container: container,
            legacyJSONURL: tempDirectory.appendingPathComponent("MissingData.json")
        )
        let habitID = UUID()
        let habit = Habit(
            id: habitID,
            title: "Read",
            createdAt: Date(timeIntervalSinceReferenceDate: 10),
            targetPerWeek: 4,
            completionKeys: "2026-05-15,2026-05-16",
            stickerName: "book.fill",
            graceDays: 1
        )

        store.addHabit(habit)
        store.updateHabit(
            Habit(
                id: habitID,
                title: "Read calmly",
                createdAt: habit.createdAt,
                targetPerWeek: habit.targetPerWeek,
                completionKeys: habit.completionKeys,
                stickerName: habit.stickerName,
                graceDays: habit.graceDays
            )
        )

        XCTAssertEqual(store.habits.count, 1)
        XCTAssertEqual(store.habits.first?.id, habitID)
        XCTAssertEqual(store.habits.first?.title, "Read calmly")
        XCTAssertEqual(store.habits.first?.completionKeys, "2026-05-15,2026-05-16")
        XCTAssertFalse(store.undoManager.canUndo, "rename/update should not register a delete undo")
    }

    func testRepeatedFocusSessionsDoNotDuplicateTheFocusStampReward() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CozyTimeRewardDuplicateTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let container = try CozySwiftDataSchema.makeContainer(inMemory: true)
        let store = AppDataStore(
            container: container,
            legacyJSONURL: tempDirectory.appendingPathComponent("MissingData.json")
        )

        store.addFocusSession(FocusSession(taskTitle: "Study", duration: 5 * 60, completedAt: Date()))
        store.addFocusSession(FocusSession(taskTitle: "Study again", duration: 5 * 60, completedAt: Date()))

        XCTAssertEqual(store.rewards.filter { $0.name == "Focus Stamp" && $0.category == "Sticker" }.count, 1)
    }

    func testPartialFocusSessionDoesNotUnlockFocusStamp() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CozyTimePartialFocusRewardTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let container = try CozySwiftDataSchema.makeContainer(inMemory: true)
        let store = AppDataStore(
            container: container,
            legacyJSONURL: tempDirectory.appendingPathComponent("MissingData.json")
        )

        store.addFocusSession(FocusSession(taskTitle: "Immediate stop", duration: 4 * 60, completedAt: Date(), rewardPoints: 0))

        XCTAssertEqual(store.focusSessions.count, 1)
        XCTAssertEqual(store.focusSessions.first?.isRewardEligible, false)
        XCTAssertFalse(store.rewards.contains { $0.name == "Focus Stamp" && $0.category == "Sticker" })
        XCTAssertEqual(store.focusSessions.reduce(0) { $0 + ($1.isRewardEligible ? $1.completedMinutes * 2 : 0) }, 0)
    }

    func testCompleteTaskByTitleIsDeterministicWithIdenticalCreatedAt() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CozyTimeDeterministicCompleteTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let container = try CozySwiftDataSchema.makeContainer(inMemory: true)
        let store = AppDataStore(
            container: container,
            legacyJSONURL: tempDirectory.appendingPathComponent("MissingData.json")
        )
        let sameMoment = Date(timeIntervalSinceReferenceDate: 100)
        let lowerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let higherID = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFE")!

        store.addTask(TaskItem(id: higherID, title: "Same name", createdAt: sameMoment))
        store.addTask(TaskItem(id: lowerID, title: "Same name", createdAt: sameMoment))

        store.completeTask(title: "Same name", at: Date(timeIntervalSinceReferenceDate: 200))

        // With secondary sort by id, the lower-id task is the deterministic first match.
        let completed = store.tasks.filter { $0.title == "Same name" && $0.isCompleted }
        XCTAssertEqual(completed.count, 1)
        XCTAssertEqual(completed.first?.id, lowerID, "deterministic completion must pick the same task every time, regardless of insertion order")
    }

    func testMigrationRenamesLegacyJSONToPreventReRun() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CozyTimeMigrationRenameTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let legacyURL = tempDirectory.appendingPathComponent("CozyTimeData.json")
        let database = CozyDatabase(tasks: [TaskItem(title: "Migrated")])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(database).write(to: legacyURL, options: [.atomic])

        let container = try CozySwiftDataSchema.makeContainer(inMemory: true)
        _ = AppDataStore(container: container, legacyJSONURL: legacyURL)

        let migratedURL = legacyURL.appendingPathExtension("migrated")
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path), "original JSON should be renamed after a successful migration")
        XCTAssertTrue(FileManager.default.fileExists(atPath: migratedURL.path), "migrated marker file should exist for recovery")
    }
}
