import Foundation

// Preserve the adapter-facing transport enum; richer timing lives in PlaybackSnapshot.
enum PlaybackState: String, Codable, Sendable, Equatable { case stopped, playing, paused }
enum MusicAuthorization: String, Codable, Sendable, Equatable { case notDetermined, authorized, denied }

struct PlaybackSnapshot: Equatable, Codable, Sendable {
    let track: Track?
    let state: PlaybackState
    let position: TimeInterval?
    let artworkData: Data?
    let playbackRate: Double
    let lastUpdatedAt: Date
    var isPlaying: Bool { state == .playing }
    var playbackPosition: TimeInterval? { position }

    init(track: Track?, state: PlaybackState, position: TimeInterval?, artworkData: Data? = nil,
         playbackRate: Double = 1, lastUpdatedAt: Date = Date()) {
        self.track = track
        self.state = state
        self.position = position
        self.artworkData = artworkData
        self.playbackRate = playbackRate
        self.lastUpdatedAt = lastUpdatedAt
    }

    /// Optional foreground interpolation. Callers supply `now`; no background timer is implied.
    func position(at now: Date) -> TimeInterval? {
        guard let position, position.isFinite, position >= 0,
              playbackRate.isFinite, playbackRate >= 0 else { return nil }
        let elapsed = now.timeIntervalSince(lastUpdatedAt)
        guard elapsed.isFinite else { return nil }
        var value = position + (isPlaying ? max(0, elapsed) * playbackRate : 0)
        guard value.isFinite else { return nil }
        if let duration = track?.duration, duration.isFinite, duration >= 0 { value = min(value, duration) }
        return value
    }
}
