import XCTest

final class StorefrontUITests: XCTestCase {
    @MainActor
    func testColdWarmAndBackgroundLaunch() throws {
        guard #available(iOS 16.4, *) else { throw XCTSkip("URL UI testing requires iOS 16.4+") }
        let app = XCUIApplication(bundleIdentifier: "dev.accesshub.sidestoretest")
        let url = URL(string: "storefrontdemo://open")!
        let receipt = app.staticTexts["storefront-launch-receipt"]

        func open(_ expected: Int) -> String {
            app.open(url)
            let prompt = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons["Open"]
            if prompt.waitForExistence(timeout: 2) { prompt.tap() }
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
            let received = NSPredicate(format: "value BEGINSWITH %@", "\(expected):")
            let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: received, object: receipt)], timeout: 20)
            XCTAssertEqual(result, .completed, "Expected URL callback \(expected)")
            return (receipt.value as? String ?? "missing").components(separatedBy: ":").last!
        }

        app.terminate()
        let coldPID = open(1)
        XCTAssertEqual(open(2), coldPID, "Already-running URL must reuse the process")
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        XCTAssertEqual(open(3), coldPID, "Background URL must reuse the process")
        app.terminate()
        XCTAssertNotEqual(open(4), coldPID, "Cold relaunch must start a new process")
        app.open(URL(string: "storefrontdemo://wrong-host")!)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue((receipt.value as? String ?? "").hasPrefix("4:"), "Unsupported host must be ignored")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
