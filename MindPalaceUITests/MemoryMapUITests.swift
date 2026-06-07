import XCTest

final class MemoryMapUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testMemoryMapShowsSearchLocationAndAddAlbumControls() {
        let app = launchApp()

        XCTAssertTrue(app.buttons["memoryMapSearchBar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["memoryMapCurrentLocationButton"].exists)
        XCTAssertTrue(app.buttons["memoryMapAddAlbumButton"].exists)
    }

    func testMemoryMapSearchBarFocusesUnifiedSearchField() {
        let app = launchApp()
        let searchBar = app.buttons["memoryMapSearchBar"]

        XCTAssertTrue(searchBar.waitForExistence(timeout: 5))
        searchBar.tap()

        let searchField = app.textFields["memoryMapUnifiedSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        XCTAssertFalse(app.textFields["memoryMapAlbumSearchField"].exists)
        XCTAssertFalse(app.textFields["memoryMapThemeSearchField"].exists)
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Done"].exists)

        app.typeText("Gotanda")
        XCTAssertTrue(app.staticTexts["Gotanda Station East Route"].waitForExistence(timeout: 3))
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UITestingSkipTutorial",
            "-UITestingDisableLocation"
        ]
        app.launch()
        return app
    }
}
