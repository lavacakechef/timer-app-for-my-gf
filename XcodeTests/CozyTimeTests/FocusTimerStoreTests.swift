import AppKit
import SwiftUI
import XCTest
import CozyCore
@testable import CozyTime

@MainActor
final class FocusTimerStoreTests: XCTestCase {
    func testMenuBarTitleShowsIdleNameWhenNoTimerIsActive() {
        let store = FocusTimerStore(defaults: makeDefaults())

        XCTAssertEqual(store.menuBarTitle(), "CozyTime")
    }

    func testMenuBarTitleShowsRemainingTimerWhileRunning() {
        let defaults = makeDefaults()
        let store = FocusTimerStore(defaults: defaults)
        let start = Date(timeIntervalSinceReferenceDate: 10_000)
        let taskID = UUID()

        store.start(taskTitle: "Read one page", taskID: taskID, duration: 25 * 60, at: start)

        XCTAssertEqual(store.menuBarTitle(at: start.addingTimeInterval(61)), "23:59")
        XCTAssertEqual(store.activeTaskID, taskID)
    }

    func testMenuBarTitleRemainsTimerWhenPaused() {
        let store = FocusTimerStore(defaults: makeDefaults())
        let start = Date(timeIntervalSinceReferenceDate: 20_000)

        store.start(taskTitle: "Sketch plan", duration: 5 * 60, at: start)
        store.pause(at: start.addingTimeInterval(72))

        XCTAssertEqual(store.menuBarTitle(at: start.addingTimeInterval(200)), "03:48")
    }

    func testMenuBarTitleShowsFinishedTimerWaitingForReward() {
        let store = FocusTimerStore(defaults: makeDefaults())
        let start = Date(timeIntervalSinceReferenceDate: 25_000)

        store.start(taskTitle: "Tiny wrap", duration: 5 * 60, at: start)
        store.complete(at: start.addingTimeInterval(5 * 60))

        XCTAssertEqual(store.menuBarTitle(at: start.addingTimeInterval(8 * 60)), "00:00")
        XCTAssertTrue(store.needsCompletionReview)
    }

    func testActiveTaskIDPersistsAndClearsOnReset() {
        let defaults = makeDefaults()
        let taskID = UUID()
        let start = Date(timeIntervalSinceReferenceDate: 30_000)

        var store: FocusTimerStore? = FocusTimerStore(defaults: defaults)
        store?.start(taskTitle: "Duplicate title", taskID: taskID, duration: 15 * 60, at: start)
        store = nil

        let restored = FocusTimerStore(defaults: defaults)
        XCTAssertEqual(restored.activeTaskID, taskID)

        restored.reset()
        XCTAssertNil(restored.activeTaskID)
    }

    func testStartDoesNotOverwriteActiveSession() {
        let store = FocusTimerStore(defaults: makeDefaults())
        let start = Date(timeIntervalSinceReferenceDate: 40_000)
        let originalTaskID = UUID()

        store.start(taskTitle: "Original focus", taskID: originalTaskID, duration: 25 * 60, at: start)
        store.start(taskTitle: "Second focus", taskID: UUID(), duration: 5 * 60, at: start.addingTimeInterval(30))

        XCTAssertEqual(store.activeTaskTitle, "Original focus")
        XCTAssertEqual(store.activeTaskID, originalTaskID)
        XCTAssertEqual(store.snapshot.duration, 25 * 60)
        XCTAssertTrue(store.isRunning)
    }

    func testStartDoesNotOverwriteCompletedSessionWaitingForReward() {
        let store = FocusTimerStore(defaults: makeDefaults())
        let start = Date(timeIntervalSinceReferenceDate: 50_000)

        store.start(taskTitle: "Finished focus", duration: 5 * 60, at: start)
        store.complete(at: start.addingTimeInterval(5 * 60))
        store.start(taskTitle: "Next focus", duration: 25 * 60, at: start.addingTimeInterval(5 * 60 + 5))

        XCTAssertEqual(store.activeTaskTitle, "Finished focus")
        XCTAssertEqual(store.snapshot.state, .completed)
        XCTAssertEqual(store.snapshot.duration, 5 * 60)
        XCTAssertTrue(store.needsCompletionReview)
    }

    func testFocusRewardResolverUsesDeterministicSeedAndStoresOnlyBonusPaws() {
        let start = Date(timeIntervalSinceReferenceDate: 60_000)
        let snapshot = TimerEngine.start(at: start, duration: 25 * 60)
        let result = FocusRewardResolver.resolve(
            snapshot: snapshot,
            taskTitle: "Study",
            boost: .default,
            existingRewards: [],
            now: start.addingTimeInterval(5 * 60),
            seed: 0
        )

        XCTAssertEqual(result.minutes, 5)
        XCTAssertEqual(result.xp, 10)
        XCTAssertEqual(result.rewardPaws, 2)
        XCTAssertEqual(result.totalPaws, 4)
        XCTAssertEqual(result.session.taskTitle, "Study")
        XCTAssertEqual(result.session.rewardPoints, 2)
        XCTAssertEqual(result.adventureRoll?.rarity, .everyday)
        XCTAssertNotNil(result.adventureRoll?.reward)
    }

    func testFocusRewardResolverDoesNotRewardImmediateCompletion() {
        let start = Date(timeIntervalSinceReferenceDate: 61_000)
        let snapshot = TimerEngine.start(at: start, duration: 25 * 60)
        let result = FocusRewardResolver.resolve(
            snapshot: snapshot,
            taskTitle: "Study",
            boost: .default,
            existingRewards: [],
            now: start.addingTimeInterval(12),
            seed: 0
        )

        XCTAssertFalse(result.isRewardEligible)
        XCTAssertFalse(result.shouldCompleteTask)
        XCTAssertEqual(result.minutes, 0)
        XCTAssertEqual(result.xp, 0)
        XCTAssertEqual(result.rewardPaws, 0)
        XCTAssertEqual(result.totalPaws, 0)
        XCTAssertNil(result.adventureRoll)
        XCTAssertEqual(result.session.rewardPoints, 0)
    }

    func testForegroundPaletteTokensMeetTextContrastOnLightSurfaces() throws {
        let foregrounds: [(String, Color)] = [
            ("focusJade", CozyPalette.focusJade),
            ("persimmon", CozyPalette.persimmon),
            ("berry", CozyPalette.berry),
            ("skyBlue", CozyPalette.skyBlue),
            ("coolBlue", CozyPalette.coolBlue),
            ("wasabiText", CozyPalette.wasabiText),
            ("habitLavender", CozyPalette.habitLavender),
            ("countdownBerry", CozyPalette.countdownBerry),
            ("overdue", CozyPalette.overdue)
        ]
        let backgrounds: [(String, Color)] = [
            ("surface", CozyPalette.surface),
            ("canvas", CozyPalette.canvas)
        ]

        for foreground in foregrounds {
            for background in backgrounds {
                let ratio = try contrastRatio(foreground.1, background.1)
                XCTAssertGreaterThanOrEqual(
                    ratio,
                    4.5,
                    "\(foreground.0) must keep AA text contrast on \(background.0); got \(ratio)"
                )
            }
        }
    }

    func testTimerAndMascotPersonalizationCatalogsHaveStableDefaults() {
        XCTAssertEqual(CozyMascotStyle.named(CozyMascotStyle.defaultID).title, "Maltese")
        XCTAssertGreaterThanOrEqual(CozyMascotStyle.all.count, 3)

        XCTAssertEqual(CozyTimerSkin.named(CozyTimerSkin.defaultID).title, "Rose Ring")
        XCTAssertGreaterThanOrEqual(CozyTimerSkin.all.count, 5)
        XCTAssertEqual(CozyTimerSkin.id(matching: "Rose Ring Timer Skin"), "rose-ring")
        XCTAssertEqual(CozyTimerSkin.id(matching: "Jade Ring Timer Skin"), "jade-ring")

        XCTAssertTrue(CozyTimerShape.allCases.contains(.ring))
        XCTAssertTrue(CozyTimerShape.allCases.contains(.capsule))
        XCTAssertTrue(CozyTimerShape.allCases.contains(.hourglass))
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "dev.local.cozytime.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func contrastRatio(_ foreground: Color, _ background: Color) throws -> CGFloat {
        let foregroundLuminance = try relativeLuminance(foreground)
        let backgroundLuminance = try relativeLuminance(background)
        let lighter = max(foregroundLuminance, backgroundLuminance)
        let darker = min(foregroundLuminance, backgroundLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: Color) throws -> CGFloat {
        let nsColor = try XCTUnwrap(NSColor(color).usingColorSpace(.sRGB))
        func linearize(_ component: CGFloat) -> CGFloat {
            component <= 0.03928
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(nsColor.redComponent)
            + 0.7152 * linearize(nsColor.greenComponent)
            + 0.0722 * linearize(nsColor.blueComponent)
    }
}
