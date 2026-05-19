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

    func testRememberedFocusMinutesDefaultsToTwentyFiveBeforeAnySelection() {
        let defaults = makeDefaults()

        XCTAssertEqual(FocusDefaults.rememberedFocusMinutes(in: defaults), 25)
        defaults.set(0, forKey: FocusDefaults.lastFocusMinutesKey)
        XCTAssertEqual(FocusDefaults.rememberedFocusMinutes(in: defaults), 25)
        defaults.set(1, forKey: FocusDefaults.lastFocusMinutesKey)
        XCTAssertEqual(FocusDefaults.rememberedFocusMinutes(in: defaults), 1)
        defaults.set(50, forKey: FocusDefaults.lastFocusMinutesKey)
        XCTAssertEqual(FocusDefaults.rememberedFocusMinutes(in: defaults), 50)
    }

    func testRememberedQuickFocusStartUsesStoredDuration() {
        let defaults = makeDefaults()
        defaults.set(50, forKey: FocusDefaults.lastFocusMinutesKey)
        let store = FocusTimerStore(defaults: makeDefaults())

        store.startRememberedQuickFocus(defaults: defaults, at: Date(timeIntervalSinceReferenceDate: 11_000))

        XCTAssertEqual(store.snapshot.duration, 50 * 60)
        XCTAssertEqual(store.activeTaskTitle, "Quick focus")
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

    func testResetClearsActiveTaskTitleSoMenuBarDoesNotShowStaleSession() {
        let store = FocusTimerStore(defaults: makeDefaults())
        let start = Date(timeIntervalSinceReferenceDate: 70_000)

        store.start(taskTitle: "Sketch plan", duration: 5 * 60, at: start)
        store.complete(at: start.addingTimeInterval(5 * 60))
        XCTAssertEqual(store.activeTaskTitle, "Sketch plan")

        store.reset()

        XCTAssertEqual(store.activeTaskTitle, "Quick focus", "reset() must clear the previous session's title so the menu bar reverts to the idle name")
        XCTAssertNil(store.activeTaskID)
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
        XCTAssertEqual(result.totalPaws, 3)
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
        XCTAssertEqual(CozyMascotStyle.named(CozyMascotStyle.defaultID).title, "Mochi")
        let mascotIDs = ["maltese", "biscuit", "tofu", "bao", "bramble", "pip", "yolk", "soba", "hazel", "acorn", "toonz-buddy", "toonz-chick", "licensed"]
        XCTAssertEqual(CozyMascotStyle.all.map(\.id), mascotIDs)
        XCTAssertEqual(CozyLottieMascot.lottiePrefix(forStyleID: "maltese"), "mochi")
        XCTAssertEqual(CozyLottieMascot.lottiePrefix(forStyleID: "biscuit"), "biscuit")
        for id in ["tofu", "bao", "bramble", "pip", "yolk", "soba", "hazel", "acorn"] {
            XCTAssertEqual(CozyLottieMascot.lottiePrefix(forStyleID: id), id)
        }
        XCTAssertNil(CozyLottieMascot.lottiePrefix(forStyleID: "toonz-buddy"))
        XCTAssertNil(CozyLottieMascot.lottiePrefix(forStyleID: "toonz-chick"))
        XCTAssertNil(CozyLottieMascot.lottiePrefix(forStyleID: "licensed"))
        XCTAssertEqual(MascotView.firstMatchingAsset(styleID: "toonz-buddy", state: .deepFocus), "mascot.toonz-buddy.focus")
        XCTAssertEqual(MascotView.firstMatchingAsset(styleID: "toonz-chick", state: .complete), "mascot.toonz-chick.complete")
        XCTAssertEqual(CozyCatalogSymbol.assetName(for: "asset:opentoonz.bow"), "opentoonz.bow")
        XCTAssertEqual(CozyCatalogSymbol.systemName(for: "asset:opentoonz.bow"), "sparkles")
        for assetName in [
            "opentoonz.arc",
            "opentoonz.ball",
            "opentoonz.bow",
            "opentoonz.brush",
            "opentoonz.bubbles",
            "opentoonz.candy",
            "opentoonz.fish2",
            "opentoonz.flower4",
            "opentoonz.frame",
            "opentoonz.icecream",
            "opentoonz.ladybird",
            "opentoonz.leaf",
            "opentoonz.orange",
            "opentoonz.spring",
            "opentoonz.star",
            "opentoonz.sunflower",
            "opentoonz.umbrella",
            "opentoonz.custom.dog.0001",
            "opentoonz.custom.chick.0001"
        ] {
            XCTAssertNotNil(NSImage(named: assetName), "\(assetName) should be present in Assets.car")
        }
        XCTAssertNil(CozyLottieMascot.lottiePrefix(forStyleID: "mango"))
        XCTAssertNil(MascotView.firstMatchingAsset(styleID: "mango", state: .idle), "Retired style ids should not collapse to legacy generic mascot-idle art")

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
