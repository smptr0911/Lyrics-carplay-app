import Foundation

@MainActor
protocol MusicProvider: AnyObject {
    var kind: MusicApp { get }
    var authorization: MusicAuthorization { get }
    var statusMessage: String { get }
    var canControlPlayback: Bool { get }
    var canSeek: Bool { get }
    var canRequestAuthorization: Bool { get }
    var allowsLyrics: Bool { get }
    var capabilities: MusicProviderCapabilities { get }
    func events() -> AsyncStream<MusicProviderEvent>
    func requestAuthorization() async -> MusicAuthorization
    func snapshot() -> PlaybackSnapshot
    func togglePlayback()
    func seek(to position: TimeInterval)
    func activate()
    func deactivate()
    func handleCallback(_ url: URL)
    func disconnect() async
    func cancelAuthorization()
}

/// Keep existing adapters, injection points and tests source-compatible.
typealias MusicSource = MusicProvider

extension MusicProvider {
    var capabilities: MusicProviderCapabilities { .localDemo }
    func events() -> AsyncStream<MusicProviderEvent> { AsyncStream { $0.finish() } }
    func disconnect() async { deactivate() }
    func cancelAuthorization() { }
    var kind: MusicApp { .demo }
    var statusMessage: String { "Local demo ready." }
    var canControlPlayback: Bool { true }
    var canSeek: Bool { canControlPlayback }
    var canRequestAuthorization: Bool { true }
    // Spotify explicitly prohibits syncing its recordings with lyrics/video.
    var allowsLyrics: Bool { kind != .spotify }
    func activate() { }
    func deactivate() { }
    func handleCallback(_ url: URL) { }
}
