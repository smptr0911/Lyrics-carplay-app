import XCTest
@testable import LyricsCarPlay

final class TrackMatchingTests: XCTestCase {
    func testNormalizationAndVersionMismatch() {
        func track(_ title: String, _ duration: Double) -> Track {
            Track(id: title, title: title, artist: "Artist", album: nil, duration: duration, artworkURL: nil, source: "test")
        }
        XCTAssertTrue(TrackMatcher().matches(track(" Caf\u{00E9}  ", 100), track("cafe", 101)))
        XCTAssertTrue(TrackMatcher().matches(track("Cafe\u{0301}", 100), track("cafe", 101)))
        XCTAssertFalse(TrackMatcher().matches(track("Caf?", 100), track("cafe", 101)))
        XCTAssertFalse(TrackMatcher().matches(track("Song", 100), track("Song (Live)", 100)))
        XCTAssertFalse(TrackMatcher().matches(track("Song", 100), track("Song", 110)))
    }
}
