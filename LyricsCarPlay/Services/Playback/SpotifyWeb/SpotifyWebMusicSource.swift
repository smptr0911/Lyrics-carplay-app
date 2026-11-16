import Foundation

@MainActor
final class SpotifyWebMusicSource: MusicProvider {
    let kind: MusicApp = .spotify
    let capabilities = MusicProviderCapabilities.spotifyWeb
    let canControlPlayback = false
    let canSeek = false
    let allowsLyrics = false
    private(set) var authorization: MusicAuthorization = .notDetermined
    private(set) var statusMessage = "Connect Spotify for read-only account playback metadata. Lyrics are unavailable for this source."
    var canRequestAuthorization: Bool { oauth != nil && browser != nil }
    private let oauth: SpotifyOAuthClient?
    private let client: SpotifyWebPlaybackClient?
    private let browser: (any SpotifyWebAuthorizing)?
    private let changes = MusicProviderEvents()
    private var selected = false
    private var connecting = false
    private var revision = UUID()
    private var authRevision = UUID()
    private var cleanup: Task<Void, Never>?
    private var poll: Task<Void, Never>?
    private var current = PlaybackSnapshot(track: nil, state: .stopped, position: nil)

    convenience init() {
        guard let configuration = SpotifyWebConfiguration.configured() else {
            self.init(oauth: nil, client: nil, browser: nil); return
        }
        let store = KeychainSpotifyTokenStore(service: (Bundle.main.bundleIdentifier ?? "LyricsCarPlay") + ".spotify.web", clientID: configuration.clientID)
        let oauth = SpotifyOAuthClient(configuration: configuration, store: store)
        if #available(iOS 17.4, *) {
            self.init(oauth: oauth, client: SpotifyWebPlaybackClient(oauth: oauth), browser: SystemSpotifyWebAuthorization())
        } else { self.init(oauth: oauth, client: nil, browser: nil) }
    }

    init(oauth: SpotifyOAuthClient?, client: SpotifyWebPlaybackClient?, browser: (any SpotifyWebAuthorizing)?) {
        self.oauth = oauth; self.client = client; self.browser = browser
        if oauth == nil || browser == nil { statusMessage = SpotifyWebError.configuration.localizedDescription }
    }

    func events() -> AsyncStream<MusicProviderEvent> { changes.stream() }
    func snapshot() -> PlaybackSnapshot {
        guard selected else { return PlaybackSnapshot(track: nil, state: .stopped, position: nil) }
        let now = Date()
        // A short, explicitly estimated foreground interval; stale API samples never run indefinitely.
        let result = SpotifyPlaybackProjection.snapshot(from: current, at: now)
        if current.track != nil && result.track == nil {
            statusMessage = "Spotify playback sample expired; waiting for a fresh account response."
            return PlaybackSnapshot(track: nil, state: .stopped, position: nil, lastUpdatedAt: now)
        }
        return result
    }

    func requestAuthorization() async -> MusicAuthorization {
        guard selected, !connecting, let oauth, let browser else { return authorization }
        connecting = true
        let token = UUID(); authRevision = token
        defer { if authRevision == token { connecting = false } }
        await cleanup?.value
        guard authRevision == token else { return authorization }
        poll?.cancel(); poll = nil; revision = UUID()
        current = PlaybackSnapshot(track: nil, state: .stopped, position: nil)
        do {
            let request = try await oauth.beginAuthorization()
            guard authRevision == token, !Task.isCancelled else { throw SpotifyWebError.cancelled }
            let callback = try await browser.authorize(request)
            guard authRevision == token else { throw SpotifyWebError.cancelled }
            try await oauth.completeAuthorization(callback)
            guard authRevision == token else { return authorization }
            authorization = .authorized
            statusMessage = "Spotify authorized. Reading account playback..."
        } catch {
            guard authRevision == token else { return authorization }
            await oauth.cancelAuthorization()
            authorization = .denied
            statusMessage = (error as? SpotifyWebError)?.localizedDescription ?? "Spotify connection could not be completed."
        }
        if selected { startPolling() }
        return authorization
    }

    func activate() { selected = true; if !connecting { startPolling() } }
    func deactivate() { selected = false; poll?.cancel(); poll = nil; revision = UUID() }
    func cancelAuthorization() {
        authRevision = UUID(); connecting = false; browser?.cancel()
        let oauth = oauth
        cleanup = Task { await oauth?.cancelAuthorization() }
    }
    func disconnect() async {
        deactivate(); cancelAuthorization(); await cleanup?.value
        do { try await oauth?.signOut(); authorization = .notDetermined; statusMessage = "Spotify disconnected; stored Web API credentials removed." }
        catch { statusMessage = SpotifyWebError.secureStorage.localizedDescription }
        current = PlaybackSnapshot(track: nil, state: .stopped, position: nil)
        changes.publish(current)
    }
    func togglePlayback() { }
    func seek(to position: TimeInterval) { }

    private func startPolling() {
        guard poll == nil, let oauth, let client else { return }
        let token = UUID(); revision = token
        poll = Task { [weak self] in
            guard let self else { return }
            defer { if revision == token { poll = nil } }
            await cleanup?.value
            guard selected, revision == token, !Task.isCancelled else { return }
            do {
                guard try await oauth.hasCredentials() else { return }
            } catch { statusMessage = SpotifyWebError.secureStorage.localizedDescription; return }
            while selected && revision == token && !Task.isCancelled {
                var delay: TimeInterval = 5
                do {
                    let result = try await client.playback()
                    guard selected, revision == token, !Task.isCancelled else { return }
                    current = result; authorization = .authorized
                    statusMessage = result.track == nil ? "No supported Spotify track is exposed by the account. Ads, episodes and local files are not shown." : "Spotify Web API sample; position is estimated briefly between requests. Lyrics synchronization is disabled."
                    changes.publish(result)
                    delay = result.track == nil ? 15 : (result.state == .paused ? 10 : 5)
                } catch {
                    guard selected, revision == token, !Task.isCancelled else { return }
                    current = PlaybackSnapshot(track: nil, state: .stopped, position: nil)
                    changes.publish(current)
                    let failure = error as? SpotifyWebError ?? .network
                    statusMessage = failure.localizedDescription
                    switch failure {
                    case .authorizationRequired, .authorizationDenied: authorization = .denied; return
                    case .rateLimited(let seconds): delay = seconds
                    case .forbidden: delay = 60
                    default: delay = 15
                    }
                }
                do { try await Task.sleep(for: .seconds(min(delay, 86_400))) } catch { return }
                // Longer Retry-After values remain enforced by the API client's deadline.
            }
        }
    }
}
