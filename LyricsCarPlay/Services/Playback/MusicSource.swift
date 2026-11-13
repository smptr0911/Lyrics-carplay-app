import Foundation

@MainActor
protocol MusicSource: AnyObject {
    var kind: MusicApp { get }
    var authorization: MusicAuthorization { get }
    var statusMessage: String { get }
    var canControlPlayback: Bool { get }
    var canSeek: Bool { get }
    var allowsLyrics: Bool { get }
    func requestAuthorization() async -> MusicAuthorization
    func snapshot() -> PlaybackSnapshot
    func togglePlayback()
    func seek(to position: TimeInterval)
    func activate()
    func deactivate()
    func handleCallback(_ url: URL)
}

extension MusicSource {
    var kind: MusicApp { .demo }
    var statusMessage: String { "Local demo ready." }
    var canControlPlayback: Bool { true }
    var canSeek: Bool { canControlPlayback }
    // Spotify explicitly prohibits syncing its recordings with lyrics/video.
    var allowsLyrics: Bool { kind != .spotify }
    func activate() { }
    func deactivate() { }
    func handleCallback(_ url: URL) { }
}
