import XCTest
@testable import LyricsCarPlay

final class LyricsSyncEngineTests: XCTestCase {
    func testSeeksAndDuplicateTimestamps() {
        let lines = [LyricLine(startTime: 44, text: "later"), LyricLine(startTime: 39, text: "first"), LyricLine(startTime: 39, text: "second")]
        let engine = LyricsSyncEngine()
        XCTAssertEqual(engine.activeLineID(in: lines, position: 45), lines[0].id)
        XCTAssertEqual(engine.activeLineID(in: lines, position: 42.5), lines[2].id)
        XCTAssertNil(engine.activeLineID(in: lines, position: 0))
        XCTAssertNil(engine.activeLineID(in: lines, position: nil))
        XCTAssertNil(engine.activeLineID(in: lines, position: -1))
        XCTAssertNil(engine.activeLineID(in: lines, position: .nan))
    }
    @MainActor
    func testDemoStopsAtEndAndRestarts() {
        let source = MockMusicSource()
        source.togglePlayback()
        source.seek(to: 30)
        XCTAssertEqual(source.snapshot().state, .stopped)
        source.togglePlayback()
        XCTAssertEqual(source.snapshot().state, .playing)
        source.seek(to: 0)
        source.togglePlayback()
        let pausedPosition = source.snapshot().position
        source.seek(to: .nan)
        XCTAssertEqual(source.snapshot().position, pausedPosition)
    }

    func testInvalidTimestampDisablesTimeline() {
        for time in [Double.nan, Double.infinity, -1] {
            let lines = [LyricLine(startTime: 0, text: "valid"), LyricLine(startTime: time, text: "invalid")]
            XCTAssertNil(LyricsTimeline(lines: lines).activeLineID(position: 10))
        }
    }
    func testStaticAndMixedLyricsDisableHighlighting() {
        XCTAssertNil(LyricsSyncEngine().activeLineID(in: [LyricLine(text: "plain"), LyricLine(startTime: 0, text: "timed")], position: 10))
    }
}
