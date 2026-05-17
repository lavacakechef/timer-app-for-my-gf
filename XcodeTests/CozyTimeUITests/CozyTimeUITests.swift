import CoreGraphics
import XCTest

final class CozyTimeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFirstLaunchCoreWorkflow() throws {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 8))

        let taskTitle = "UI test tiny task"
        let firstSessionTitle = app.textFields["firstSession.title"]
        XCTAssertTrue(firstSessionTitle.waitForExistence(timeout: 5))
        clickElement(firstSessionTitle)
        firstSessionTitle.typeKey("a", modifierFlags: [.command])
        firstSessionTitle.typeText(taskTitle)
        XCTAssertTrue(app.buttons["firstSession.start"].waitForExistence(timeout: 5))
        app.buttons["firstSession.start"].click()

        openSection("focus", in: app)

        let startButton = app.buttons["focus.start"]
        let pauseButton = app.buttons["focus.pause"]
        let resumeButton = app.buttons["focus.resume"]
        if !pauseButton.waitForExistence(timeout: 2) {
            if resumeButton.waitForExistence(timeout: 1) {
                resumeButton.click()
            } else {
                XCTAssertTrue(startButton.waitForExistence(timeout: 5))
                startButton.click()
            }
            XCTAssertTrue(pauseButton.waitForExistence(timeout: 5))
        }

        pauseButton.click()
        XCTAssertTrue(app.buttons["focus.resume"].waitForExistence(timeout: 5))
        app.buttons["focus.stop"].click()
    }

    @MainActor
    func testFocusCompletionAddsRewardAndStats() throws {
        let app = launchApp(extraArguments: ["-ui-testing-reward-ready"])

        openSection("focus", in: app)
        XCTAssertTrue(app.buttons["focus.claimReward"].waitForExistence(timeout: 5))
        app.buttons["focus.claimReward"].click()

        // Special/dream adventure rolls now present a CozyUnlockSheet modal,
        // which is a two-stage reveal: tap the wrap first, then the dismiss
        // ("Add to room") button becomes enabled. Tap both if the sheet appears.
        let unlockWrap = app.descendants(matching: .any)["focus.unlockSheet.wrap"].firstMatch
        if unlockWrap.waitForExistence(timeout: 1.5) {
            unlockWrap.click()
            let backToReview = app.descendants(matching: .any)["focus.unlockSheet.back"].firstMatch
            if backToReview.waitForExistence(timeout: 2) {
                backToReview.click()
            }
        }

        let reflectionNote = "Proof saved"
        let reflectionField = app.descendants(matching: .any)["focus.reflection"].firstMatch
        XCTAssertTrue(reflectionField.waitForExistence(timeout: 5))
        clickElement(reflectionField)
        reflectionField.typeText(reflectionNote)
        XCTAssertTrue(app.buttons["focus.rewardsRoom"].waitForExistence(timeout: 5))
        app.buttons["focus.rewardsRoom"].click()
        XCTAssertTrue(app.descendants(matching: .any)["screen.rewards"].firstMatch.waitForExistence(timeout: 5))

        XCTAssertTrue(app.staticTexts["Focus Stamp"].waitForExistence(timeout: 5))
        let shopSegment = app.descendants(matching: .any)["Shop"].firstMatch
        XCTAssertTrue(shopSegment.waitForExistence(timeout: 5))
        shopSegment.click()
        XCTAssertTrue(app.staticTexts["Mochi Shop"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Twinkle Bow"].waitForExistence(timeout: 5))

        openSection("stats", in: app)
        XCTAssertTrue(app.staticTexts["5m"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Mochi's level"].waitForExistence(timeout: 5))

        openSection("calendar", in: app)
        let savedDay = app.buttons.matching(identifier: "calendar.day.open")
            .matching(NSPredicate(format: "label CONTAINS[c] %@ AND label CONTAINS[c] %@", "5m", reflectionNote))
            .firstMatch
        XCTAssertTrue(savedDay.waitForExistence(timeout: 5), "Calendar did not expose the saved focus session and reflection note.")
        savedDay.click()
        XCTAssertTrue(app.staticTexts["Focus diary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[reflectionNote].waitForExistence(timeout: 5))
        let focusDiaryRow = app.descendants(matching: .any)["calendar.detail.row.focus"].firstMatch
        XCTAssertTrue(focusDiaryRow.waitForExistence(timeout: 5))
        clickElement(focusDiaryRow)
        XCTAssertTrue(app.descendants(matching: .any)["screen.focus"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testCountdownComposerLayoutAtCompactAndWideSizes() throws {
        for windowSize in ["720x600", "1120x760"] {
            let app = launchApp(extraArguments: ["-ui-testing-window-size", windowSize])
            defer { app.terminate() }

            openSection("calendar", in: app)
            let newCountdown = app.buttons["calendar.newCountdown"]
            XCTAssertTrue(newCountdown.waitForExistence(timeout: 5))
            newCountdown.click()

            let title = app.textFields["countdown.title"]
            let date = app.descendants(matching: .any)["countdown.date"].firstMatch
            let reminders = app.descendants(matching: .any)["countdown.reminders"].firstMatch
            let add = app.buttons["countdown.add"].firstMatch

            XCTAssertTrue(title.waitForExistence(timeout: 5))
            XCTAssertTrue(date.waitForExistence(timeout: 5))
            XCTAssertTrue(reminders.waitForExistence(timeout: 5))
            XCTAssertTrue(add.waitForExistence(timeout: 5))
            assertNoOverlap([date, reminders, add], context: "countdown composer \(windowSize)")

            app.typeKey(.escape, modifierFlags: [])
        }
    }

    @MainActor
    func testCountdownHabitAndSettingsFlows() throws {
        let app = launchApp()
        let suffix = UUID().uuidString.prefix(6)

        // Countdowns now live inside Calendar (sidebar consolidation).
        // The "+ New countdown" button on Calendar opens the composer sheet.
        openSection("calendar", in: app)
        let newCountdown = app.buttons["calendar.newCountdown"]
        XCTAssertTrue(newCountdown.waitForExistence(timeout: 5))
        newCountdown.click()
        let countdownTitle = "UI countdown \(suffix)"
        let countdownField = app.textFields["countdown.title"]
        XCTAssertTrue(countdownField.waitForExistence(timeout: 5))
        clickElement(countdownField)
        countdownField.typeText(countdownTitle)
        app.buttons["countdown.add"].click()
        XCTAssertTrue(app.staticTexts[countdownTitle].waitForExistence(timeout: 5))
        // Close the composer sheet so subsequent navigation can proceed.
        if app.sheets.firstMatch.exists {
            app.typeKey(.escape, modifierFlags: [])
        }

        openSection("habits", in: app)
        let habitTitle = "UI habit \(suffix)"
        let habitField = app.textFields["habit.title"]
        XCTAssertTrue(habitField.waitForExistence(timeout: 5))
        clickElement(habitField)
        habitField.typeText(habitTitle)
        let addHabitButton = app.buttons["habit.add"]
        XCTAssertTrue(addHabitButton.waitForExistence(timeout: 5))
        clickElement(addHabitButton)
        XCTAssertTrue(app.staticTexts[habitTitle].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(identifier: "habit.toggle").firstMatch.waitForExistence(timeout: 5))
        app.buttons.matching(identifier: "habit.toggle").firstMatch.click()

        openSection("settings", in: app)
        let mascotName = app.textFields["settings.mascotName"]
        XCTAssertTrue(mascotName.waitForExistence(timeout: 5))
        clickElement(mascotName)
        mascotName.typeKey("a", modifierFlags: [.command])
        mascotName.typeText("Mochi")
        XCTAssertEqual(mascotName.value as? String, "Mochi")
    }

    @MainActor
    func testAccessibilityAuditForPrimaryScreens() throws {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 8))

        if #available(macOS 14.0, *) {
            let options = XCTExpectedFailure.Options()
            options.issueMatcher = { issue in
                issue.compactDescription.contains("Parent/Child mismatch")
                    || issue.compactDescription.contains("Element has no description")
            }
            try XCTExpectFailure("Xcode's macOS SwiftUI accessibility audit reports known false positives for the generated NavigationSplitView root group.", options: options) {
                try app.performAccessibilityAudit()
            }
        }
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        launchApp(extraArguments: [])
    }

    @MainActor
    private func launchApp(extraArguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["COZYTIME_UI_TESTING"] = "1"
        app.launchArguments = [
            "-ui-testing",
            "-ApplePersistenceIgnoreState",
            "YES"
        ] + extraArguments
        app.launch()
        app.activate()
        return app
    }

    @MainActor
    private func openSection(_ section: String, in app: XCUIApplication) {
        let identifier = "sidebar.\(section)"
        let deadline = Date().addingTimeInterval(8)

        while Date() < deadline {
            let screen = app.descendants(matching: .any)["screen.\(section)"].firstMatch
            if screen.exists {
                return
            }

            let button = app.buttons[identifier].firstMatch
            let item = button.exists ? button : app.descendants(matching: .any)[identifier].firstMatch
            if item.waitForExistence(timeout: 0.5) {
                if item.isHittable {
                    item.click()
                } else {
                    item.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
                }

                if screen.waitForExistence(timeout: 1.5) {
                    return
                }
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }

        XCTFail("Did not open section \(section)")
    }

    @MainActor
    private func clickElement(_ element: XCUIElement) {
        if element.isHittable {
            element.click()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        }
    }

    @MainActor
    private func assertNoOverlap(
        _ elements: [XCUIElement],
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let frames = elements.map { $0.frame }
        for leftIndex in frames.indices {
            for rightIndex in frames.indices where rightIndex > leftIndex {
                XCTAssertFalse(
                    frames[leftIndex].intersects(frames[rightIndex]),
                    "\(context): element \(leftIndex) overlaps element \(rightIndex). \(frames[leftIndex]) vs \(frames[rightIndex])",
                    file: file,
                    line: line
                )
            }
        }
    }
}
