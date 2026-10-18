import XCTest

final class HabitPetUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testOnboardingOfflineFoodLoggingNavigationAndRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-reset"]
        app.launch()
        let start = app.buttons["Start My Healthy Journey 🚀"]
        XCTAssertTrue(start.waitForExistence(timeout: 15)); start.tap()
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Please fill out this field."].exists)
        app.textFields["signup-name"].tap()
        app.textFields["signup-name"].typeText("Forki Test")
        app.textFields["signup-email"].tap()
        app.textFields["signup-email"].typeText("forki-test@example.com\n")
        for title in ["How old are you?", "What's your height?", "What's your current weight?"] {
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
            app.buttons["Skip for now"].tap()
        }
        let slim = app.buttons.containing(.staticText, identifier: "Slim").firstMatch
        XCTAssertTrue(slim.waitForExistence(timeout: 5)); slim.tap()
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.buttons["Skip for now"].waitForExistence(timeout: 5))
        app.buttons["Skip for now"].tap()
        XCTAssertTrue(app.buttons["Maybe Later"].waitForExistence(timeout: 5))
        app.buttons["Maybe Later"].tap()
        XCTAssertTrue(app.staticTexts["daily-calories"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["daily-calories"].label, "0 / 1800")
        app.buttons["Log Food"].tap()
        XCTAssertTrue(app.buttons["Browse Popular Foods"].waitForExistence(timeout: 5))
        app.buttons["Browse Popular Foods"].tap()
        app.buttons.containing(.staticText, identifier: "Apple, raw, with skin").firstMatch.tap()
        app.swipeUp()
        app.buttons["Log Food"].tap()
        XCTAssertTrue(app.staticTexts["daily-calories"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["daily-calories"].label, "52 / 1800")
        app.buttons["Stats"].tap()
        XCTAssertTrue(app.navigationBars["Your Progress"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["52 kcal"].exists)
        app.buttons["Profile"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
        app.steppers["profile-calorie-goal"].buttons["Increment"].tap()
        app.buttons["Done"].tap()
        app.buttons["Home"].tap()
        XCTAssertEqual(app.staticTexts["daily-calories"].label, "52 / 1850")
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.staticTexts["daily-calories"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["daily-calories"].label, "52 / 1850")
    }
}
