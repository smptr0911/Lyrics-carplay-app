import Combine
import XCTest
@testable import LyricsCarPlay

@MainActor
final class MusicProviderEventTests: XCTestCase {
    func testChangesAndPositionDriftAreDetectedWithoutPublishingNormalProgress() async {
        let events = MusicProviderEvents()
        var iterator = events.stream().makeAsyncIterator()
        let date = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(events.publish(PlaybackSnapshot(track: .demo, state: .playing, position: 0, lastUpdatedAt: date)))
        let first = await iterator.next()
        XCTAssertTrue(first?.changes.contains(.track) == true)
        XCTAssertFalse(events.publish(PlaybackSnapshot(track: .demo, state: .playing, position: 1, lastUpdatedAt: date.addingTimeInterval(1))))
        XCTAssertTrue(events.publish(PlaybackSnapshot(track: .demo, state: .playing, position: 10, lastUpdatedAt: date.addingTimeInterval(2))))
        let seek = await iterator.next()
        XCTAssertEqual(seek?.changes, Set([MusicProviderChange.position]))
        XCTAssertTrue(events.publish(PlaybackSnapshot(track: .demo, state: .paused, position: 10, lastUpdatedAt: date.addingTimeInterval(2))))
        let pause = await iterator.next()
        XCTAssertTrue(pause?.changes.contains(.playback) == true)
        XCTAssertTrue(events.publish(PlaybackSnapshot(track: nil, state: .stopped, position: nil, lastUpdatedAt: date.addingTimeInterval(3))))
        let stopped = await iterator.next()
        XCTAssertTrue(stopped?.changes.contains(.track) == true)
    }

    final class Source: MusicProvider {
        let kind: MusicApp = .appleMusic
        var authorization: MusicAuthorization = .denied
        var track: Track?
        var statusMessage: String { track == nil ? "Permission denied; use Demo." : "Original fixture" }
        var canControlPlayback: Bool { track != nil }
        func requestAuthorization() async -> MusicAuthorization { authorization }
        func snapshot() -> PlaybackSnapshot { PlaybackSnapshot(track: track, state: .paused, position: track == nil ? nil : 0) }
        func togglePlayback() { }
        func seek(to position: TimeInterval) { }
    }
    struct Provider: LyricsProvider {
        func lyrics(for track: Track) async throws -> LyricsDocument? {
            LyricsDocument(lines: [LyricLine(startTime: 0, text: track.title)], attribution: "Original fixture", cacheUntil: nil)
        }
    }

    func testDeniedAuthorizationIsHonestAndSameIDMetadataChangesReloadLyrics() async {
        let source = Source()
        let model = NowPlayingViewModel(source: source, provider: Provider())
        await model.connect()
        XCTAssertNil(model.snapshot.track)
        XCTAssertFalse(model.isConnecting)
        XCTAssertTrue(model.sourceStatus.contains("Permission denied"))
        let first = expectation(description: "first lyrics"), second = expectation(description: "corrected version")
        let subscription = model.$lyricsState.sink { state in
            guard case .available(let document) = state else { return }
            if document.lines.first?.text == "Original" { first.fulfill() }
            if document.lines.first?.text == "Original (Live)" { second.fulfill() }
        }
        defer { subscription.cancel() }
        source.authorization = .authorized
        source.track = Track(id: "test:same", title: "Original", artist: "Fixture", album: "Studio", duration: 30, artworkURL: nil, source: "Test")
        model.selectSource(source)
        await fulfillment(of: [first], timeout: 2)
        source.track = Track(id: "test:same", title: "Original (Live)", artist: "Fixture", album: "Concert", duration: 30, artworkURL: nil, source: "Test")
        model.seek(to: 0)
        await fulfillment(of: [second], timeout: 2)
        XCTAssertEqual(model.synchronizedLyrics.currentLine?.text, "Original (Live)")
    }
}
