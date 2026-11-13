import Foundation

@MainActor
final class MockMusicSource: MusicSource {
    private(set) var authorization: MusicAuthorization = .authorized
    private var playing = false
    private var offset: TimeInterval = 0
    private var startedAt: Date?
    private let track = Track(id: "demo:open-road", title: "Open Road", artist: "Lyrics CarPlay Demo",
                              album: "Original demo", duration: 30, artworkURL: nil, source: "Demo")

    func requestAuthorization() async -> MusicAuthorization { authorization }

    func snapshot() -> PlaybackSnapshot {
        let position = min(30, max(0, offset + (startedAt.map { Date().timeIntervalSince($0) } ?? 0)))
        if position >= 30 { playing = false; offset = 30; startedAt = nil }
        return PlaybackSnapshot(track: track, state: position >= 30 ? .stopped : (playing ? .playing : .paused), position: position)
    }

    func togglePlayback() {
        offset = snapshot().position ?? 0
        if playing { startedAt = nil } else {
            if offset >= 30 { offset = 0 }
            startedAt = Date()
        }
        playing.toggle()
    }

    func seek(to position: TimeInterval) {
        guard position.isFinite else { return }
        offset = min(30, max(0, position))
        startedAt = playing ? Date() : nil
    }
}
