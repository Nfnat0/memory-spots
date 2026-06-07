import XCTest

final class ScreenshotAutomationTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureAppStoreScreenshots() throws {
        let editorApp = launchApp()
        openAlbum(named: "Gotanda Station East Route", in: editorApp)
        openPhoto(named: "Street Wires", in: editorApp)
        XCTAssertTrue(
            editorApp.descendants(matching: .any)["Sticky Note: VPC"].waitForExistence(timeout: 10),
            "The cloud architecture note should exist in the photo editor."
        )
        XCTAssertTrue(
            editorApp.descendants(matching: .any)["Sticky Note: security group"].waitForExistence(timeout: 10),
            "The third cloud architecture note should exist in the photo editor."
        )
        captureScreenshot(named: "01-photo-notes.png")
        editorApp.terminate()

        let mapApp = launchApp()
        openMapFilter(named: "Gotanda Station East Route", in: mapApp)
        captureScreenshot(named: "02-memory-map.png")
        mapApp.terminate()

        let reviewApp = launchApp()
        openAlbum(named: "Daruma Room Route", in: reviewApp)
        XCTAssertTrue(reviewApp.buttons["Open photo"].firstMatch.waitForExistence(timeout: 10))
        captureScreenshot(named: "03-route-detail.png")

        let reviewPhoto = reviewApp.buttons["Open photo"].firstMatch
        XCTAssertTrue(reviewPhoto.waitForExistence(timeout: 10), "Review photo tile should exist")
        reviewPhoto.tap()

        let reviewNote = reviewApp.descendants(matching: .any)["Sticky Note: ser vs estar"].firstMatch
        XCTAssertTrue(reviewNote.waitForExistence(timeout: 10), "The first review note should exist.")
        reviewNote.tap()
        XCTAssertTrue(
            reviewApp.staticTexts["Ser is permanent identity; estar is temporary state or location."].waitForExistence(timeout: 5),
            "The revealed answer should be visible."
        )
        captureScreenshot(named: "04-review.png")

        reviewApp.navigationBars.buttons.element(boundBy: 0).tap()
        reviewApp.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(reviewApp.navigationBars["Albums"].waitForExistence(timeout: 10))
        XCTAssertTrue(reviewApp.staticTexts["Gotanda Station East Route"].exists)
        XCTAssertTrue(reviewApp.staticTexts["Elephant Plaza Route"].exists)
        XCTAssertTrue(reviewApp.staticTexts["Indoor Study Route"].exists)
        captureScreenshot(named: "05-albums.png")
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppStoreScreenshotData",
            "-UITestingSkipTutorial",
            "-UITestingDisableLocation"
        ]
        app.launch()
        return app
    }

    private func openAlbum(named albumName: String, in app: XCUIApplication) {
        let albumsTab = app.tabBars.buttons["Albums"]
        XCTAssertTrue(albumsTab.waitForExistence(timeout: 10), "Albums tab button should exist")
        albumsTab.tap()

        let albumButton = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", albumName)).firstMatch
        if !albumButton.waitForExistence(timeout: 15) {
            print("--- DEBUG APP HIERARCHY ---")
            print(app.debugDescription)
            XCTFail("\(albumName) album button did not appear")
        }
        albumButton.tap()
    }

    private func openPhoto(named photoName: String, in app: XCUIApplication) {
        let photoTile = app.buttons["Open photo"].firstMatch
        XCTAssertTrue(photoTile.waitForExistence(timeout: 10), "\(photoName) tile should exist")
        photoTile.tap()
    }

    private func openMapFilter(named filterName: String, in app: XCUIApplication) {
        let mapTab = app.tabBars.buttons["Memory Map"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 10), "Memory Map tab button should exist")
        mapTab.tap()

        let searchBar = app.buttons["memoryMapSearchBar"]
        XCTAssertTrue(searchBar.waitForExistence(timeout: 10), "Map search bar should exist")
        searchBar.tap()

        let searchField = app.textFields["memoryMapUnifiedSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Map search field should exist")
        searchField.typeText(filterName)

        let filterButton = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", filterName)).firstMatch
        XCTAssertTrue(filterButton.waitForExistence(timeout: 10), "\(filterName) filter should exist")
        filterButton.tap()
    }

    private func captureScreenshot(named name: String) {
        Thread.sleep(forTimeInterval: 1.5)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
