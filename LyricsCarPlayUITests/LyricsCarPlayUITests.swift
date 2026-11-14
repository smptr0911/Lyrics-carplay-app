import XCTest

final class LyricsCarPlayUITests: XCTestCase {
    func testFirstLaunchExplainsAvailableFeatures() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-mode", "--show-welcome"]
        app.launch()
        XCTAssertTrue(app.buttons["continueWelcome"].waitForExistence(timeout: 3))
        app.buttons["continueWelcome"].tap()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 3))
    }

    func testUserCanSelectMusicApp() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-mode"]
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        let spotify = app.buttons["Spotify"]
        XCTAssertTrue(spotify.waitForExistence(timeout: 3))
        spotify.tap()
        XCTAssertTrue(app.buttons["Open Spotify / Resume"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Now Playing"].tap()
        XCTAssertTrue(app.buttons["Open Spotify / Resume"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Open Road"].exists)
    }

    func testVideoRejectsInvalidURL() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-mode"]
        app.launch()
        app.tabBars.buttons["Video"].tap()
        XCTAssertTrue(app.textFields["videoURL"].exists)
        app.buttons["loadVideo"].tap()
        XCTAssertTrue(app.staticTexts["videoError"].waitForExistence(timeout: 2))
    }

    func testDemoJourney() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-mode"]
        app.launch()
        app.tabBars.buttons["Now Playing"].tap()
        XCTAssertTrue(app.staticTexts["Open Road"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Morning light across the sky"].waitForExistence(timeout: 5))
        app.buttons["Play"].tap()
        XCTAssertTrue(app.buttons["Pause"].exists)
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Current source"].exists)
    }
}
