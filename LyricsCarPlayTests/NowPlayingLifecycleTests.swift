import XCTest
import Combine
@testable import LyricsCarPlay

@MainActor
final class NowPlayingLifecycleTests: XCTestCase {
    final class Source: MusicSource {
        let identifier: String
        var authorization: MusicAuthorization { .authorized }
        init(_ identifier: String) { self.identifier = identifier }
        func requestAuthorization() async -> MusicAuthorization { .authorized }
        func snapshot() -> PlaybackSnapshot {
            PlaybackSnapshot(track: Track(id: identifier, title: identifier, artist: "Test", album: nil,
                duration: 10, artworkURL: nil, source: "Test"), state: .paused, position: 0)
        }
        func togglePlayback() { }
        func seek(to position: TimeInterval) { }
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
