import XCTest

final class OfflineDemoUITests: XCTestCase {
    func testOfflineJourneyAndPersistence() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        let input = app.textFields["access-code"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["demo-label"].exists)
        input.tap()
        input.typeText("WRONG\n")
        XCTAssertTrue(app.staticTexts["access-error"].waitForExistence(timeout: 3))
        input.tap()
        input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5))
        input.typeText("WINTER-UI-TEST-ONLY\n")
        XCTAssertTrue(app.staticTexts["welcome"].waitForExistence(timeout: 8))
        screenshot("home")
        app.tabBars.buttons["Explore"].tap()
        XCTAssertTrue(app.buttons["save-lights"].waitForExistence(timeout: 3))
        app.buttons["save-lights"].tap()
        app.tabBars.buttons["Wallet"].tap()
        XCTAssertTrue(app.staticTexts["Evening lights"].waitForExistence(timeout: 3))
        app.buttons["sample-pass"].tap()
        XCTAssertTrue(app.staticTexts["FICTIONAL SAMPLE PASS"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["demo-label"].exists)
        screenshot("sample-pass")
        app.buttons["Done"].tap()
        app.tabBars.buttons["Home"].tap()
        app.buttons["Settings"].tap()
        let nickname = app.textFields["nickname"]
        XCTAssertTrue(nickname.waitForExistence(timeout: 3))
        nickname.tap()
        nickname.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,count: 11))
        nickname.typeText("Snow Tester")
        app.buttons["Done"].tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["welcome"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["welcome"].label.contains("Snow Tester"))
        app.tabBars.buttons["Wallet"].tap()
        XCTAssertTrue(app.staticTexts["Evening lights"].waitForExistence(timeout: 3))
        screenshot("persisted-wallet")
    }
    private func screenshot(_ name: String) {
        let item = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        item.name = name; item.lifetime = .keepAlways; add(item)
    }
}
