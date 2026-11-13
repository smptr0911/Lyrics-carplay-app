#if targetEnvironment(simulator)
import XCTest
import CarPlay
@testable import LyricsCarPlay

@MainActor
final class CarPlayTemplatesTests: XCTestCase {
    func testDemoSelectionCompletesAndUnavailableFeaturesAreDisabled() {
        var selected = 0
        var completed = 0
        let root = CarPlayTemplates.root { selected += 1 }
        XCTAssertEqual(root.sections.count, 2)
        let item = root.sections[0].items[0] as! CPListItem
        item.handler?(item, { completed += 1 })
        XCTAssertEqual(selected, 1)
        XCTAssertEqual(completed, 1)
        for item in root.sections[1].items {
            XCTAssertFalse((item as! CPListItem).isEnabled)
        }
    }

    func testDetailsDoNotExposeFakePlaybackActions() {
        let details = CarPlayTemplates.demoTrack()
        XCTAssertEqual(details.title, "Open Road")
        XCTAssertEqual(details.sections[0].items.count, 3)
        for item in details.sections[0].items {
            let row = item as! CPListItem
            XCTAssertFalse(row.isEnabled)
            XCTAssertNil(row.handler)
        }
    }
}
#endif
