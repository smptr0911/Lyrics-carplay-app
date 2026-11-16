import XCTest
@testable import LyricsCarPlay

final class LyricsSyncEngineTests: XCTestCase {
    @MainActor
    func testMockRateChangesPreservePositionAndPause() {
        var time: TimeInterval = 0
        let source = MockMusicSource(now: { time })
        source.togglePlayback()
        time = 2
        source.setPlaybackRate(2)
        XCTAssertEqual(source.snapshot().position, 2)
        time = 4
        XCTAssertEqual(source.snapshot().position, 6)
        source.togglePlayback()
        time = 100
        source.setPlaybackRate(0.5)
        XCTAssertEqual(source.snapshot().position, 6)
        source.togglePlayback()
        time = 102
        XCTAssertEqual(source.snapshot().position, 7)
        source.setPlaybackRate(.nan)
        XCTAssertEqual(source.snapshot().playbackRate, 0.5)
    }
    @MainActor
    func testMockPlaybackDrivesOriginalLyricsWithoutSleeping() async throws {
        var time: TimeInterval = 100
        let source = MockMusicSource(now: { time })
        let track = try XCTUnwrap(source.snapshot().track)
        let result = try await MockLyricsProvider().lyrics(for: track)
        let document = try XCTUnwrap(result)
        let engine = LyricsSyncEngine()
        source.togglePlayback()
        time += 10
        XCTAssertEqual(engine.activeLineID(in: document.lines, position: source.snapshot().position), document.lines[2].id)
        source.togglePlayback()
        time += 20
        XCTAssertEqual(source.snapshot().position, 10)
        source.seek(to: 5)
        XCTAssertEqual(engine.activeLineID(in: document.lines, position: source.snapshot().position), document.lines[1].id)
        source.togglePlayback()
        time += 25
        XCTAssertEqual(source.snapshot().state, .stopped)
    }

    func testContextBoundariesOrderingAndSerialization() throws {
        let lines = [LyricLine(startTime: 10, text: "last"),
                     LyricLine(startTime: 0, text: "first"),
                     LyricLine(startTime: 5, text: "middle")]
        let engine = LyricsSyncEngine()
        let first = try XCTUnwrap(engine.context(in: lines, position: 0))
        XCTAssertNil(first.previous)
        XCTAssertEqual(first.next, lines[2])
        let middle = try XCTUnwrap(engine.context(in: lines, position: 5))
        XCTAssertEqual(middle.previous, lines[1])
        XCTAssertEqual(middle.current, lines[2])
        XCTAssertEqual(middle.next, lines[0])
        XCTAssertNil(engine.context(in: lines, position: 10)?.next)
        XCTAssertNil(engine.context(in: lines, position: nil))
        XCTAssertNil(engine.context(in: [LyricLine(text: "untimed")], position: 0))
        let data = try JSONEncoder().encode(middle)
        XCTAssertEqual(try JSONDecoder().decode(LyricContext.self, from: data), middle)
    }

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
