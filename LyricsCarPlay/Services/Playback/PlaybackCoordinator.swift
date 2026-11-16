import Foundation

@MainActor
final class PlaybackCoordinator {
    private(set) var source: any MusicSource
    init(source: any MusicSource) { self.source = source }
    func replaceSource(_ source: any MusicSource) {
        self.source.deactivate()
        self.source.cancelAuthorization()
        self.source = source
    }
    func snapshot() -> PlaybackSnapshot { source.snapshot() }
}
