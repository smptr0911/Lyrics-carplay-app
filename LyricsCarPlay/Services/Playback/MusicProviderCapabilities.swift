import Foundation

enum MusicCapability: Equatable, Sendable {
    case supported
    case restricted(String)
    case unavailable(String)
}

struct MusicProviderCapabilities: Equatable, Sendable {
    let authorization: MusicCapability
    let metadata: MusicCapability
    let position: MusicCapability
    let changeDetection: MusicCapability
    let controls: MusicCapability
    let lyrics: MusicCapability

    static let localDemo = Self(authorization: .supported, metadata: .supported, position: .supported,
        changeDetection: .supported, controls: .supported, lyrics: .supported)
    static let appleMusic = Self(authorization: .supported,
        metadata: .restricted("Only items exposed by Apple's system music player; some Music content has no readable item."),
        position: .restricted("Foreground system-player samples when publicly available."),
        changeDetection: .restricted("System music player notifications while the app is active."),
        controls: .restricted("Only the selected, authorized system music player."),
        lyrics: .unavailable("MusicKit does not supply synchronized lyrics to this app. Use permitted local or licensed data."))
    static let spotifyWeb = Self(authorization: .restricted("PKCE requires configured HTTPS callback, associated domain and eligible account/app."),
        metadata: .restricted("Authorized account playback, not arbitrary iPhone audio."),
        position: .restricted("Nullable Web API samples; polling and network latency limit accuracy."),
        changeDetection: .restricted("Foreground polling with rate-limit backoff; no Web API playback event stream."),
        controls: .unavailable("This Web API adapter requests read-only access."),
        lyrics: .unavailable("No Spotify lyrics endpoint is used; synchronization remains disabled by policy."))
    static let spotifyAppRemote = Self(authorization: .restricted("Legacy App Remote setup and installed Spotify app required."),
        metadata: .restricted("Spotify SDK connection only."), position: .restricted("SDK position samples, not universal device playback."),
        changeDetection: .restricted("SDK player-state callbacks while connected."), controls: .restricted("SDK restrictions apply."),
        lyrics: .unavailable("Spotify synchronization remains disabled by policy."))
}

enum MusicProviderChange: Hashable, Sendable { case track, playback, position }
struct MusicProviderEvent: Sendable {
    let snapshot: PlaybackSnapshot
    let changes: Set<MusicProviderChange>
}

@MainActor
final class MusicProviderEvents {
    private var subscribers: [UUID: AsyncStream<MusicProviderEvent>.Continuation] = [:]
    private var previous: PlaybackSnapshot?

    func stream() -> AsyncStream<MusicProviderEvent> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            subscribers[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.subscribers.removeValue(forKey: id) }
            }
        }
    }

    @discardableResult
    func publish(_ snapshot: PlaybackSnapshot) -> Bool {
        var changes: Set<MusicProviderChange> = []
        if previous?.track != snapshot.track { changes.insert(.track) }
        if previous?.state != snapshot.state || previous?.playbackRate != snapshot.playbackRate { changes.insert(.playback) }
        if let old = previous?.position(at: snapshot.lastUpdatedAt), let position = snapshot.position {
            if abs(old - position) > 0.75 { changes.insert(.position) }
        } else if previous?.position != snapshot.position { changes.insert(.position) }
        previous = snapshot
        guard !changes.isEmpty else { return false }
        let event = MusicProviderEvent(snapshot: snapshot, changes: changes)
        for continuation in subscribers.values { continuation.yield(event) }
        return true
    }
}
