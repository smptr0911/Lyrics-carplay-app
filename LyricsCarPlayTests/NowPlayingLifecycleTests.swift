import XCTest
import Combine
@testable import LyricsCarPlay

@MainActor
final class NowPlayingLifecycleTests: XCTestCase {
    final class Source: MusicSource {
        let identifier: String
        var position: TimeInterval = 0
        var authorization: MusicAuthorization { .authorized }
        init(_ identifier: String) { self.identifier = identifier }
        func requestAuthorization() async -> MusicAuthorization { .authorized }
        func snapshot() -> PlaybackSnapshot {
            PlaybackSnapshot(track: Track(id: identifier, title: identifier, artist: "Test", album: nil,
                duration: 10, artworkURL: nil, source: "Test"), state: .paused, position: position)
        }
        func togglePlayback() { }
        func seek(to position: TimeInterval) { self.position = position }
    }

    struct ImmediateProvider: LyricsProvider {
        func lyrics(for track: Track) async throws -> LyricsDocument? {
            LyricsDocument(lines: [LyricLine(startTime: 0, text: "First"), LyricLine(startTime: 5, text: "Second")],
                           attribution: "Original test", cacheUntil: nil)
        }
    }

    func testSeekingAndOffsetsUpdateImmediatelyWithoutTimerAndSuppressDuplicates() async {
        let loaded = expectation(description: "lyrics loaded")
        let model = NowPlayingViewModel(source: Source("initial"), provider: ImmediateProvider())
        let subscription = model.$lyricsState.sink { state in
            if case .available = state { loaded.fulfill() }
        }
        defer { subscription.cancel() }
        model.selectSource(Source("test"))
        await fulfillment(of: [loaded], timeout: 2)
        XCTAssertEqual(model.synchronizedLyrics.currentLine?.text, "First")
        model.seek(to: 7)
        XCTAssertEqual(model.synchronizedLyrics.currentLine?.text, "Second")
        model.setSynchronizationOffset(-3)
        XCTAssertEqual(model.synchronizedLyrics.currentLine?.text, "First")
        XCTAssertEqual(model.synchronizedLyrics.synchronizationStatus, .paused)
        var emissions = 0
        let changes = model.$synchronizedLyrics.dropFirst().sink { _ in emissions += 1 }
        model.seek(to: 7)
        model.setSynchronizationOffset(-3)
        XCTAssertEqual(emissions, 0)
        changes.cancel()
        model.setSynchronizationOffset(.nan)
        XCTAssertEqual(model.synchronizationOffset, -3)
    }

    actor GateProvider: LyricsProvider {
        let requested: @Sendable (String) -> Void
        private var continuations: [String: CheckedContinuation<LyricsDocument?, Never>] = [:]
        init(requested: @escaping @Sendable (String) -> Void) { self.requested = requested }
        func lyrics(for track: Track) async throws -> LyricsDocument? {
            // Deliberately ignore cancellation to model a slow vendor SDK.
            await withCheckedContinuation { continuation in
                continuations[track.id] = continuation
                requested(track.id)
            }
        }
        func finish(_ identifier: String) {
            continuations.removeValue(forKey: identifier)?.resume(returning:
                LyricsDocument(lines: [LyricLine(startTime: 0, text: identifier)], attribution: "test", cacheUntil: nil))
        }
    }

    func testLateCancelledResponseCannotReplaceNewSource() async {
        let firstRequested = expectation(description: "first requested")
        let secondRequested = expectation(description: "second requested")
        let loaded = expectation(description: "second loaded")
        let provider = GateProvider { id in
            if id == "first" { firstRequested.fulfill() }
            if id == "second" { secondRequested.fulfill() }
        }
        let model = NowPlayingViewModel(source: Source("initial"), provider: provider)
        var displayed: [String] = []
        let subscription = model.$lyricsState.sink { state in
            if case .available(let document) = state, let text = document.lines.first?.text {
                displayed.append(text)
                if text == "second" { loaded.fulfill() }
            }
        }
        defer { subscription.cancel() }
        model.selectSource(Source("first"))
        await fulfillment(of: [firstRequested], timeout: 2)
        model.selectSource(Source("second"))
        await fulfillment(of: [secondRequested], timeout: 2)
        await provider.finish("first")
        await provider.finish("second")
        await fulfillment(of: [loaded], timeout: 2)
        XCTAssertEqual(displayed, ["second"])
        XCTAssertEqual(model.snapshot.track?.id, "second")
    }
}
