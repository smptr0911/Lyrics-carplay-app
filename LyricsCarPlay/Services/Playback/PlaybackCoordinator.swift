import Foundation

@MainActor
final class PlaybackCoordinator {
    private(set) var source: any MusicSource
    init(source: any MusicSource) { self.source = source }
    func replaceSource(_ source: any MusicSource) {
        self.source.deactivate()
        if let spotify = self.source as? SpotifyMusicSource { spotify.cancelAuthorization() }
        self.source = source
    }
    func snapshot() -> PlaybackSnapshot { source.snapshot() }
}
