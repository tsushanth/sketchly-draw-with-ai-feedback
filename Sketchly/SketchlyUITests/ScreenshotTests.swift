import XCTest

@MainActor
class ScreenshotTests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        setupSnapshot(app)
        app.launch()
    }

    func testScreenshots() {
        sleep(3)
        snapshot("01_Discover")

        app.tabBars.buttons["Learn"].tap()
        sleep(1)
        snapshot("02_Learn")

        app.tabBars.buttons["Practice"].tap()
        sleep(1)
        snapshot("03_Practice")

        app.tabBars.buttons["Settings"].tap()
        sleep(1)
        snapshot("04_Settings")

        app.tabBars.buttons["Discover"].tap()
        sleep(1)
        snapshot("05_DiscoverMain")
    }
}
