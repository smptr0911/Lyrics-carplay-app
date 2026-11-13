import Foundation

enum PlaybackState: Sendable, Equatable { case stopped, playing, paused }
enum MusicAuthorization: Sendable, Equatable { case notDetermined, authorized, denied }

struct PlaybackSnapshot: Sendable {
    let track: Track?
    let state: PlaybackState
    // nil explicitly disables synchronized highlighting.
    let position: TimeInterval?
    let artworkData: Data?

    init(track: Track?, state: PlaybackState, position: TimeInterval?, artworkData: Data? = nil) {
        self.track = track
        self.state = state
        self.position = position
        self.artworkData = artworkData
    }
}
