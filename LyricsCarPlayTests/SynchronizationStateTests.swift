import XCTest
@testable import LyricsCarPlay

final class SynchronizationStateTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_000)
    private func track(_ id: String = "demo:first", duration: Double? = 30) -> Track {
        Track(id: id, title: "Test", artist: "Original fixture", album: nil, duration: duration, artworkURL: nil, source: "Demo")
    }
    private func document(_ lines: [LyricLine]) -> LyricsDocument {
        LyricsDocument(lines: lines, attribution: "Original tests", cacheUntil: nil)
    }
    private func playback(_ position: Double?, playing: Bool = true, rate: Double = 1, id: String = "demo:first") -> PlaybackSnapshot {
        PlaybackSnapshot(track: track(id), state: playing ? .playing : .paused, position: position,
                         playbackRate: rate, lastUpdatedAt: date)
    }

    func testBeginningEndAndBidirectionalSeeking() {
        let lines = [LyricLine(startTime: 2, text: "First"), LyricLine(startTime: 10, text: "Second")]
        var engine = LyricsSyncEngine()
        engine.load(document: document(lines), for: track())
        engine.update(playback: playback(0), at: date)
        XCTAssertEqual(engine.state.synchronizationStatus, .waiting)
        XCTAssertEqual(engine.state.nextLine, lines[0])
        engine.update(playback: playback(2), at: date)
        XCTAssertEqual(engine.state.currentLine, lines[0])
        engine.update(playback: playback(29), at: date)
        XCTAssertEqual(engine.state.currentLine, lines[1])
        engine.update(playback: playback(3), at: date)
        XCTAssertEqual(engine.state.currentLine, lines[0])
        engine.update(playback: playback(30), at: date, offset: -10)
        XCTAssertNil(engine.state.currentLine)
        XCTAssertEqual(engine.state.synchronizationStatus, .ended)
    }

    func testPauseResumeRateChangesAndNoRedundantStateUpdates() {
        let lines = [LyricLine(startTime: 0, text: "First"), LyricLine(startTime: 5, text: "Second")]
        var engine = LyricsSyncEngine()
        engine.load(document: document(lines), for: track())
        XCTAssertTrue(engine.update(playback: playback(0), at: date))
        XCTAssertFalse(engine.update(playback: playback(1), at: date))
        engine.update(playback: playback(1, playing: false), at: date.addingTimeInterval(20))
        XCTAssertEqual(engine.state.currentLine, lines[0])
        XCTAssertEqual(engine.state.synchronizationStatus, .paused)
        engine.update(playback: playback(1, rate: 2), at: date.addingTimeInterval(2))
        XCTAssertEqual(engine.state.currentLine, lines[1])
        engine.update(playback: playback(1, rate: 0.5), at: date.addingTimeInterval(2))
        XCTAssertEqual(engine.state.currentLine, lines[0])
    }

    func testOffsetsAndUnavailablePositions() {
        let lines = [LyricLine(startTime: 0, text: "First"), LyricLine(startTime: 5, text: "Second")]
        var engine = LyricsSyncEngine()
        engine.load(document: document(lines), for: track())
        engine.update(playback: playback(4), at: date, offset: 1)
        XCTAssertEqual(engine.state.currentLine, lines[1])
        engine.update(playback: playback(5), at: date, offset: -1)
        XCTAssertEqual(engine.state.currentLine, lines[0])
        engine.update(playback: playback(0), at: date, offset: -1)
        XCTAssertEqual(engine.state.synchronizationStatus, .waiting)
        for position in [nil, Double.nan, Double.infinity, -1] as [Double?] {
            engine.update(playback: playback(position), at: date)
            XCTAssertEqual(engine.state.synchronizationStatus, .positionUnavailable)
        }
        engine.update(playback: playback(1), at: date, offset: .nan)
        XCTAssertEqual(engine.state.synchronizationStatus, .positionUnavailable)
        XCTAssertEqual(playback(3, rate: 0).position(at: date.addingTimeInterval(5)), 3)
        XCTAssertNil(playback(0, rate: -1).position(at: date))
    }

    func testOverlapsExplicitEndsAndMissingEnds() {
        let lines = [LyricLine(startTime: 0, endTime: 20, text: "Long"),
                     LyricLine(startTime: 5, endTime: 7, text: "New"),
                     LyricLine(startTime: 10, text: "Final")]
        let timeline = LyricsTimeline(lines: lines)
        XCTAssertEqual(timeline.state(position: 5).currentLine, lines[1])
        let gap = timeline.state(position: 7)
        XCTAssertNil(gap.currentLine)
        XCTAssertEqual(gap.previousLine, lines[1])
        XCTAssertEqual(gap.nextLine, lines[2])
        XCTAssertEqual(gap.synchronizationStatus, .gap)
        XCTAssertEqual(timeline.state(position: 10).currentLine, lines[2])
        XCTAssertEqual(timeline.state(position: 29, duration: 30).currentLine, lines[2])
        XCTAssertEqual(timeline.state(position: 30, duration: 30).synchronizationStatus, .ended)
        let beyondDuration = LyricsTimeline(lines: [lines[0], LyricLine(startTime: 40, text: "Beyond track")])
        XCTAssertEqual(beyondDuration.state(position: 30, duration: 30).previousLine, lines[0])
        XCTAssertNil(beyondDuration.state(position: 0, duration: 0).previousLine)
    }

    func testMissingAndInvalidTimestampsDisableHighlighting() {
        for lines in [[LyricLine(text: "Untimed")],
                      [LyricLine(startTime: 0, text: "Timed"), LyricLine(text: "Untimed")],
                      [LyricLine(startTime: 2, endTime: 1, text: "Invalid")]] {
            let state = LyricsTimeline(lines: lines).state(position: 10)
            XCTAssertEqual(state.synchronizationStatus, .untimed)
            XCTAssertNil(state.currentLine)
        }
        XCTAssertEqual(LyricsTimeline(lines: []).state(position: 0), .unavailable)
    }

    func testTrackSwitchRejectsOldLyricsAndClearsState() {
        let line = LyricLine(startTime: 0, text: "First track")
        var engine = LyricsSyncEngine()
        engine.load(document: document([line]), for: track())
        engine.update(playback: playback(0), at: date)
        engine.update(playback: playback(0, id: "demo:second"), at: date)
        XCTAssertEqual(engine.state, .unavailable)
        engine.update(playback: playback(0), at: date)
        XCTAssertEqual(engine.state, .unavailable)
        engine.load(document: nil, for: track("demo:second"))
        engine.update(playback: playback(0, id: "demo:second"), at: date)
        XCTAssertEqual(engine.state, .unavailable)
        let second = LyricLine(startTime: 0, text: "Second track")
        engine.load(document: document([second]), for: track("demo:second"))
        engine.update(playback: playback(0, id: "demo:second"), at: date)
        XCTAssertEqual(engine.state.currentLine, second)
    }

    func testLargeTimelineAndStableDuplicateOrdering() {
        let lines = (0..<50_000).map { LyricLine(startTime: Double($0), text: "Original line \($0)") }
        let timeline = LyricsTimeline(lines: Array(lines.reversed()))
        for index in [0, 1, 25_000, 49_999, 2] {
            XCTAssertEqual(timeline.activeLineID(position: Double(index) + 0.5), lines[index].id)
        }
        let duplicates = [LyricLine(startTime: 1, text: "A"), LyricLine(startTime: 1, text: "B")]
        XCTAssertEqual(LyricsTimeline(lines: duplicates).activeLineID(position: 1), duplicates[1].id)
    }

    func testSharedModelsRoundTripAndStableIdentifiers() throws {
        let line = LyricLine(startTime: 0, endTime: 3, text: "Original")
        XCTAssertEqual(line.id, LyricLine(startTime: 0, endTime: 3, text: "Original").id)
        let value = playback(1, rate: 1.5)
        XCTAssertEqual(try JSONDecoder().decode(PlaybackSnapshot.self, from: JSONEncoder().encode(value)), value)
        let doc = document([line])
        XCTAssertEqual(try JSONDecoder().decode(LyricsDocument.self, from: JSONEncoder().encode(doc)), doc)
        let state = LyricsTimeline(lines: [line]).state(position: 1)
        XCTAssertEqual(try JSONDecoder().decode(SynchronizedLyricsState.self, from: JSONEncoder().encode(state)), state)
    }
}
