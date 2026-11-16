import Foundation

struct SpotifyPlaybackProjection {
    static func snapshot(from sample: PlaybackSnapshot, at date: Date) -> PlaybackSnapshot {
        let age = date.timeIntervalSince(sample.lastUpdatedAt)
        let maximumAge = sample.state == .playing ? 7.0 : 20.0
        guard (0...maximumAge).contains(age) else { return PlaybackSnapshot(track: nil, state: .stopped, position: nil, lastUpdatedAt: date) }
        return PlaybackSnapshot(track: sample.track, state: sample.state, position: sample.position(at: date),
            artworkData: sample.artworkData, playbackRate: sample.playbackRate, lastUpdatedAt: date)
    }
}

actor SpotifyWebPlaybackClient {
    private let oauth: SpotifyOAuthClient
    private let client: any HTTPClient
    private let now: @Sendable () -> Date
    private var retryAt: Date?
    init(oauth: SpotifyOAuthClient, client: any HTTPClient = URLSessionHTTPClient(), now: @escaping @Sendable () -> Date = { Date() }) {
        self.oauth = oauth; self.client = client; self.now = now
    }

    func playback() async throws -> PlaybackSnapshot {
        if let retryAt, retryAt > now() { throw SpotifyWebError.rateLimited(retryAt.timeIntervalSince(now())) }
        for attempt in 0...1 {
            let token = try await oauth.accessToken(forceRefresh: attempt == 1)
            var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let data: Data, response: HTTPURLResponse
            do { (data, response) = try await client.data(for: request) }
            catch is CancellationError { throw CancellationError() }
            catch { throw SpotifyWebError.network }
            try Task.checkCancellation()
            switch response.statusCode {
            case 204: return empty()
            case 401:
                if attempt == 0 { continue }
                try await oauth.invalidateAccessToken(token)
                throw SpotifyWebError.authorizationRequired
            case 403: throw SpotifyWebError.forbidden
            case 429:
                let delay = SpotifyRetry.delay(response)
                retryAt = now().addingTimeInterval(delay)
                throw SpotifyWebError.rateLimited(delay)
            case 200: break
            default: throw SpotifyWebError.server
            }
            guard data.count <= 1_000_000, response.mimeType == "application/json",
                  let payload = try? JSONDecoder().decode(Payload.self, from: data) else { throw SpotifyWebError.invalidResponse }
            guard let item = payload.item, item.type == "track", item.is_local != true,
                  let id = item.id, id.count == 22, id.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) }),
                  let title = item.name, !title.isEmpty else { return empty() }
            let artwork = item.album?.images?.compactMap { image -> URL? in
                guard let url = URL(string: image.url), url.scheme == "https", url.host != nil, url.user == nil else { return nil }
                return url
            }.first
            let duration = item.duration_ms.flatMap { $0.isFinite && $0 > 0 ? $0 / 1_000 : nil }
            let position = payload.progress_ms.flatMap { $0.isFinite && $0 >= 0 ? $0 / 1_000 : nil }
            let track = Track(id: "spotify:track:\(id)", title: title,
                artist: item.artists?.map(\.name).joined(separator: ", ") ?? "Unknown artist",
                album: item.album?.name, duration: duration, artworkURL: artwork, source: "Spotify", providerIdentifier: "spotify")
            let boundedPosition = position.map { value in duration.map { min(value, $0) } ?? value }
            return PlaybackSnapshot(track: track, state: payload.is_playing ? .playing : .paused,
                position: boundedPosition, lastUpdatedAt: now())
        }
        throw SpotifyWebError.authorizationRequired
    }

    private func empty() -> PlaybackSnapshot { PlaybackSnapshot(track: nil, state: .stopped, position: nil, lastUpdatedAt: now()) }
    private struct Payload: Decodable {
        let is_playing: Bool
        let progress_ms: Double?
        let item: Item?
        struct Item: Decodable {
            let id: String?; let type: String?; let name: String?; let duration_ms: Double?; let is_local: Bool?
            let artists: [Artist]?; let album: Album?
        }
        struct Artist: Decodable { let name: String }
        struct Album: Decodable { let name: String?; let images: [Image]? }
        struct Image: Decodable { let url: String }
    }
}
