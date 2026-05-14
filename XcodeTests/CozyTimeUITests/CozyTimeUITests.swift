import XCTest

final class CozyTimeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFirstLaunchCoreWorkflow() throws {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 8))

        let quickAdd = app.textFields["quickAdd.title"]
        let taskTitle = "UI test tiny task"
        XCTAssertTrue(quickAdd.waitForExistence(timeout: 5))
        quickAdd.click()
        quickAdd.typeText(taskTitle)
        app.buttons["quickAdd.add"].click()
        XCTAssertTrue(waitForTextField(quickAdd, toClear: taskTitle), "Quick add did not clear after adding the task.")

        let focusSidebarItem = app.descendants(matching: .any)["sidebar.focus"].firstMatch
        XCTAssertTrue(focusSidebarItem.waitForExistence(timeout: 5))
        focusSidebarItem.click()

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

        let reflectionNote = "Proof saved"
        let reflectionField = app.descendants(matching: .any)["focus.reflection"].firstMatch
        XCTAssertTrue(reflectionField.waitForExistence(timeout: 5))
        reflectionField.click()
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
        XCTAssertTrue(app.staticTexts["Mochi level"].waitForExistence(timeout: 5))

        openSection("calendar", in: app)
        let savedDay = app.buttons.matching(identifier: "calendar.day.open")
            .matching(NSPredicate(format: "label CONTAINS[c] %@ AND label CONTAINS[c] %@", "5m", reflectionNote))
            .firstMatch
        XCTAssertTrue(savedDay.waitForExistence(timeout: 5), "Calendar did not expose the saved focus session and reflection note.")
        savedDay.click()
        XCTAssertTrue(app.staticTexts["Focus diary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[reflectionNote].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCountdownHabitAndSettingsFlows() throws {
        let app = launchApp()
        let suffix = UUID().uuidString.prefix(6)

        openSection("countdowns", in: app)
        let countdownTitle = "UI countdown \(suffix)"
        let countdownField = app.textFields["countdown.title"]
        XCTAssertTrue(countdownField.waitForExistence(timeout: 5))
        countdownField.click()
        countdownField.typeText(countdownTitle)
        app.buttons["countdown.add"].click()
        XCTAssertTrue(app.staticTexts[countdownTitle].waitForExistence(timeout: 5))

        openSection("habits", in: app)
        let habitTitle = "UI habit \(suffix)"
        let habitField = app.textFields["habit.title"]
        XCTAssertTrue(habitField.waitForExistence(timeout: 5))
        habitField.click()
        habitField.typeText(habitTitle)
        app.buttons["habit.add"].click()
        XCTAssertTrue(app.staticTexts[habitTitle].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(identifier: "habit.toggle").firstMatch.waitForExistence(timeout: 5))
        app.buttons.matching(identifier: "habit.toggle").firstMatch.click()

        openSection("settings", in: app)
        let mascotName = app.textFields["settings.mascotName"]
        XCTAssertTrue(mascotName.waitForExistence(timeout: 5))
        mascotName.click()
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
        app.launchArguments = ["-ui-testing"] + extraArguments
        app.launch()
        return app
    }

    @MainActor
    private func openSection(_ section: String, in app: XCUIApplication) {
        let item = app.descendants(matching: .any)["sidebar.\(section)"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Missing sidebar item \(section)")
        item.click()
        let screen = app.descendants(matching: .any)["screen.\(section)"].firstMatch
        if !screen.waitForExistence(timeout: 3) {
            item.click()
        }
        XCTAssertTrue(screen.waitForExistence(timeout: 5), "Did not open section \(section)")
    }

    @MainActor
    private func waitForTextField(_ field: XCUIElement, toClear text: String, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let value = field.value as? String ?? ""
            if !value.contains(text) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }
}
