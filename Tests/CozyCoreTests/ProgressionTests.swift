import XCTest
@testable import CozyCore

final class ProgressionTests: XCTestCase {
    func testLegacyDatabaseJSONMissingBonusPawsStillDecodes() throws {
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
              "id": "00000000-0000-0000-0000-000000000101",
              "listName": "Inbox",
              "notes": "Legacy JSON did not have bonusPaws.",
              "priority": 1,
              "repeatRule": "",
              "tagText": "legacy",
              "title": "Keep legacy task"
            }
          ]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let database = try decoder.decode(CozyDatabase.self, from: Data(json.utf8))

        XCTAssertEqual(database.bonusPaws, 0)
        XCTAssertEqual(database.tasks.map(\.title), ["Keep legacy task"])
    }

    func testProgressionRewardsFocusTasksAndHabitsWithoutPunishment() {
        let now = Date(timeIntervalSinceReferenceDate: 10_000)
        let database = CozyDatabase(
            tasks: [
                TaskItem(title: "Done", completedAt: now),
                TaskItem(title: "Open")
            ],
            countdowns: [
                CountdownEvent(title: "Trip", targetDate: now)
            ],
            focusSessions: [
                FocusSession(taskTitle: "Study", duration: 25 * 60, completedAt: now)
            ],
            habits: [
                Habit(title: "Read", completionKeys: "2026-05-12,2026-05-13")
            ]
        )

        let summary = CozyProgression.summary(for: database)

        XCTAssertEqual(summary.xp, 82)
        XCTAssertEqual(summary.level, 2)
        XCTAssertEqual(summary.coinsEarned, 20)
        XCTAssertEqual(summary.coinsAvailable, 20)
        XCTAssertEqual(summary.petStage, .puppy)
        XCTAssertGreaterThan(summary.progressToNextLevel, 0)
    }

    func testPurchasedShopItemsSpendCoinsAndCannotBeBoughtTwice() {
        let item = CozyProgression.shopCatalog[0]
        let database = CozyDatabase(
            focusSessions: [
                FocusSession(taskTitle: "Study", duration: 120 * 60, completedAt: Date())
            ],
            rewards: [item.rewardItem]
        )

        let summary = CozyProgression.summary(for: database)

        XCTAssertFalse(CozyProgression.canPurchase(item, database: database))
        // coinsEarned = xp/4 + focusPaws = (240/4) + 0 = 60; spent = Twinkle Bow (6 paws after rebalance)
        XCTAssertEqual(summary.coinsAvailable, 54)
    }

    func testStarterTimerSkinDoesNotCreateHiddenShopDebt() {
        let starterSkin = RewardItem(
            name: "Rose Ring Timer Skin",
            category: "Timer skin",
            symbolName: "heart.circle.fill",
            colorHex: "#B84E73",
            isEquipped: true
        )
        let database = CozyDatabase(
            focusSessions: [
                FocusSession(taskTitle: "Study", duration: 25 * 60, completedAt: Date())
            ],
            rewards: [starterSkin]
        )

        XCTAssertEqual(CozyProgression.summary(for: database).coinsAvailable, 12)
    }

    func testNearestUnlockChoosesClosestUnpurchasedReward() {
        let firstItem = CozyProgression.shopCatalog[0]
        let database = CozyDatabase(
            tasks: [TaskItem(title: "Done", completedAt: Date())],
            focusSessions: [
                FocusSession(taskTitle: "Study", duration: 10 * 60, completedAt: Date())
            ],
            rewards: [firstItem.rewardItem]
        )

        XCTAssertEqual(CozyProgression.nearestUnlock(in: database)?.id, CozyProgression.shopCatalog[1].id)
    }

    func testFocusRewardPointsBecomeSpendablePaws() {
        let database = CozyDatabase(
            focusSessions: [
                FocusSession(taskTitle: "Study", duration: 25 * 60, completedAt: Date(), rewardPoints: 3)
            ]
        )

        XCTAssertEqual(CozyProgression.summary(for: database).coinsAvailable, 15)
    }

    func testPartialFocusDoesNotEarnProgressionRewards() {
        let database = CozyDatabase(
            focusSessions: [
                FocusSession(taskTitle: "Tiny pause", duration: 4 * 60, completedAt: Date(), rewardPoints: 0)
            ]
        )

        let summary = CozyProgression.summary(for: database)

        XCTAssertEqual(summary.xp, 0)
        XCTAssertEqual(summary.coinsAvailable, 0)
    }

    func testAdventureRollUsesTransparentWeightedRarityBands() {
        XCTAssertEqual(CozyProgression.adventureRarity(for: 0), .everyday)
        XCTAssertEqual(CozyProgression.adventureRarity(for: 70), .cozy)
        XCTAssertEqual(CozyProgression.adventureRarity(for: 92), .special)
        XCTAssertEqual(CozyProgression.adventureRarity(for: 99), .dream)
        XCTAssertEqual(CozyProgression.adventureOddsText, "Everyday 70% / Cozy 22% / Special 7% / Dream 1%")
    }

    func testAdventureDuplicateConvertsIntoPawsInsteadOfASecondCurrency() throws {
        let firstRoll = CozyProgression.adventureRoll(seed: 70, completedMinutes: 25, existingRewards: [])
        let reward = try XCTUnwrap(firstRoll.reward)

        let duplicateRoll = CozyProgression.adventureRoll(seed: 70, completedMinutes: 25, existingRewards: [reward])

        XCTAssertNil(duplicateRoll.reward)
        XCTAssertEqual(duplicateRoll.rarity, .cozy)
        XCTAssertEqual(duplicateRoll.duplicatePaws, 1)
    }

    func testShopCatalogIncludesTimerCosmeticsAsCosmeticCoinSinks() {
        let timerSkins = CozyProgression.shopCatalog.filter { $0.category == "Timer skin" }
        let timerFrames = CozyProgression.shopCatalog.filter { $0.category == "Timer frame" }

        XCTAssertGreaterThanOrEqual(timerSkins.count, 3)
        XCTAssertGreaterThanOrEqual(timerFrames.count, 2)
        XCTAssertTrue(timerSkins.allSatisfy { $0.coinCost > 0 && $0.requiredLevel >= 1 })
        XCTAssertTrue(timerFrames.allSatisfy { $0.coinCost > 0 && $0.requiredLevel >= 1 })
        XCTAssertTrue(timerSkins.contains { $0.name == "Rose Ring Timer Skin" })
        XCTAssertTrue(timerFrames.contains { $0.name == "Pill Timer Frame" })
    }
}
