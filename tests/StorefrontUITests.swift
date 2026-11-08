import XCTest
import UIKit

final class StorefrontUITests: XCTestCase {
    @MainActor
    func testColdWarmAndBackgroundLaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "dev.accesshub.sidestoretest")
        let url = URL(string: "storefrontdemo://open")!
        let receipt = app.staticTexts["storefront-launch-receipt"]

        func send(_ target: URL) {
            // Use the same cross-app API as a native storefront. XCUIApplication.open
            // starts a fresh launch session, so it cannot verify process preservation.
            let delivered = expectation(description: "iOS accepts custom URL")
            UIApplication.shared.open(target, options: [:]) { success in
                XCTAssertTrue(success)
                delivered.fulfill()
            }
            let prompt = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons["Open"]
            if prompt.waitForExistence(timeout: 5) { prompt.tap() }
            // The completion callback waits for the user's approval, too.
            wait(for: [delivered], timeout: 15)
        }
        func open(_ expected: Int) -> String {
            send(url)
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
            let received = NSPredicate(format: "value BEGINSWITH %@", "\(expected):")
            let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: received, object: receipt)], timeout: 20)
            XCTAssertEqual(result, .completed, "Expected URL callback \(expected)")
            return (receipt.value as? String ?? "missing").components(separatedBy: ":").last!
        }

        // XCTest installs the target lazily on its first managed launch. Install it
        // before asking another process to resolve its registered custom scheme.
        app.launch()
        app.terminate()
        let coldPID = open(1)
        XCTAssertEqual(open(2), coldPID, "Already-running URL must reuse the process")
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        XCTAssertEqual(open(3), coldPID, "Background URL must reuse the process")
        app.terminate()
        XCTAssertNotEqual(open(4), coldPID, "Cold relaunch must start a new process")
        send(URL(string: "storefrontdemo://wrong-host")!)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue((receipt.value as? String ?? "").hasPrefix("4:"), "Unsupported host must be ignored")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
