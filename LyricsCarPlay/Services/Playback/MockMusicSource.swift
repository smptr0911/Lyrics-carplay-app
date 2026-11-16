import Foundation

@MainActor
final class MockMusicSource: MusicSource {
    private(set) var authorization: MusicAuthorization = .authorized
    private var playing = false
    private(set) var playbackRate: Double = 1
    private var offset: TimeInterval = 0
    private var startedAt: TimeInterval?
    private let now: () -> TimeInterval
    private let changes = MusicProviderEvents()
    func events() -> AsyncStream<MusicProviderEvent> { changes.stream() }

    /// A monotonic clock keeps the demo stable across wall-clock changes.
    init(now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.now = now
    }
    private let track = Track.demo

    func requestAuthorization() async -> MusicAuthorization { authorization }

    func snapshot() -> PlaybackSnapshot {
        let position = min(30, max(0, offset + (startedAt.map { (now() - $0) * playbackRate } ?? 0)))
        if position >= 30 { playing = false; offset = 30; startedAt = nil }
        let result = PlaybackSnapshot(track: track, state: position >= 30 ? .stopped : (playing ? .playing : .paused), position: position, playbackRate: playbackRate)
        changes.publish(result)
        return result
    }

    func togglePlayback() {
        offset = snapshot().position ?? 0
        if playing { startedAt = nil } else {
            if offset >= 30 { offset = 0 }
            startedAt = now()
        }
        playing.toggle()
        _ = snapshot()
    }

    func setPlaybackRate(_ rate: Double) {
        guard rate.isFinite, (0.25...3).contains(rate) else { return }
        offset = snapshot().position ?? 0
        playbackRate = rate
        startedAt = playing ? now() : nil
        _ = snapshot()
    }

    func seek(to position: TimeInterval) {
        guard position.isFinite else { return }
        offset = min(30, max(0, position))
        startedAt = playing ? now() : nil
        _ = snapshot()
    }
}
