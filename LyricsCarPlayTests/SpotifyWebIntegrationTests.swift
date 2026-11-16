import Foundation
import XCTest
@testable import LyricsCarPlay

final class SpotifyWebIntegrationTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_000)
    private func configuration() throws -> SpotifyWebConfiguration {
        try SpotifyWebConfiguration(clientID: "public-test-client", redirectURL: URL(string: "https://auth.example.com/spotify/callback")!)
    }
    private func tokens(expired: Bool = false) -> SpotifyTokens {
        SpotifyTokens(accessToken: "old-access", refreshToken: "old-refresh",
            expiresAt: date.addingTimeInterval(expired ? -1 : 3_600), scope: SpotifyWebConfiguration.scopes)
    }

    final class Store: SpotifyTokenStore, @unchecked Sendable {
        private let lock = NSLock()
        private var tokens: SpotifyTokens?
        init(_ tokens: SpotifyTokens? = nil) { self.tokens = tokens }
        func load() -> SpotifyTokens? { lock.lock(); defer { lock.unlock() }; return tokens }
        func save(_ tokens: SpotifyTokens) { lock.lock(); defer { lock.unlock() }; self.tokens = tokens }
        func delete() { lock.lock(); defer { lock.unlock() }; tokens = nil }
    }

    struct Response: Sendable {
        let status: Int
        let body: String
        var headers: [String: String] = ["Content-Type": "application/json"]
    }
    actor HTTP: HTTPClient {
        private var responses: [Response]
        private(set) var requests: [URLRequest] = []
        init(_ responses: [Response]) { self.responses = responses }
        func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            requests.append(request)
            guard !responses.isEmpty else { throw URLError(.notConnectedToInternet) }
            let response = responses.removeFirst()
            return (Data(response.body.utf8), HTTPURLResponse(url: request.url!, statusCode: response.status,
                httpVersion: nil, headerFields: response.headers)!)
        }
    }
    actor GateHTTP: HTTPClient {
        let started: @Sendable () -> Void
        private var continuations: [CheckedContinuation<(Data, HTTPURLResponse), Never>] = []
        private var url: URL?
        private(set) var count = 0
        init(started: @escaping @Sendable () -> Void) { self.started = started }
        func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            count += 1; url = request.url
            return await withCheckedContinuation { continuation in
                self.continuations.append(continuation); started()
            }
        }
        func finish() {
            let body = #"{"access_token":"new-access","token_type":"Bearer","expires_in":3600,"refresh_token":"rotated"}"#
            guard let url else { return }
            for continuation in continuations {
                continuation.resume(returning: (Data(body.utf8), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"])!))
            }
            continuations = []
        }
    }

    private func callback(_ request: SpotifyAuthorizationRequest, stateOverride: String? = nil) -> URL {
        let state = URLComponents(url: request.url, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "state" }!.value!
        var components = URLComponents(url: request.redirectURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "state", value: stateOverride ?? state), URLQueryItem(name: "code", value: "code+with&characters")]
        return components.url!
    }

    func testPKCEReferenceVectorAndHTTPSConfiguration() throws {
        XCTAssertEqual(SpotifyPKCE.challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"), "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        XCTAssertEqual(try SpotifyPKCE.random().count, 43)
        for url in ["lyrics-carplay-spotify://callback", "http://auth.example.com/callback", "https://user@auth.example.com/callback", "https://auth.example.com/callback?extra=1"] {
            XCTAssertThrowsError(try SpotifyWebConfiguration(clientID: "public", redirectURL: URL(string: url)!))
        }
    }

    func testAuthorizationUsesVerifierAndPersistsRotatableCredentials() async throws {
        let http = HTTP([Response(status: 200, body: #"{"access_token":"access","token_type":"Bearer","expires_in":3600,"refresh_token":"refresh"}"#)])
        let store = Store(), now = date
        let oauth = SpotifyOAuthClient(configuration: try configuration(), client: http, store: store, now: { now })
        let request = try await oauth.beginAuthorization()
        let items = URLComponents(url: request.url, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(items.first { $0.name == "code_challenge_method" }?.value, "S256")
        XCTAssertNil(items.first { $0.name == "code_verifier" })
        try await oauth.completeAuthorization(callback(request))
        let requests = await http.requests
        let body = String(data: requests[0].httpBody!, encoding: .utf8)!
        XCTAssertTrue(body.contains("code=code%2Bwith%26characters"))
        XCTAssertTrue(body.contains("code_verifier="))
        XCTAssertFalse(body.contains("client_secret"))
        XCTAssertEqual(store.load()?.refreshToken, "refresh")
        do { try await oauth.completeAuthorization(callback(request)); XCTFail("Callback must be single-use") }
        catch { XCTAssertEqual(error as? SpotifyWebError, .invalidCallback) }
    }

    func testInvalidStateAndDeniedAuthorizationDoNotCallTokenEndpoint() async throws {
        let http = HTTP([]), now = date
        let oauth = SpotifyOAuthClient(configuration: try configuration(), client: http, store: Store(), now: { now })
        let request = try await oauth.beginAuthorization()
        do { try await oauth.completeAuthorization(callback(request, stateOverride: "wrong")); XCTFail("State mismatch") }
        catch { XCTAssertEqual(error as? SpotifyWebError, .invalidCallback) }
        let second = try await oauth.beginAuthorization()
        var denied = URLComponents(url: callback(second), resolvingAgainstBaseURL: false)!
        denied.queryItems?.append(URLQueryItem(name: "error", value: "access_denied"))
        do { try await oauth.completeAuthorization(denied.url!); XCTFail("Denial must be explicit") }
        catch { XCTAssertEqual(error as? SpotifyWebError, .authorizationDenied) }
        let count = await http.requests.count
        XCTAssertEqual(count, 0)
    }

    func testExpiredTokenRefreshRotatesAndInvalidGrantDeletesCredentials() async throws {
        let now = date
        let http = HTTP([Response(status: 200, body: #"{"access_token":"new","token_type":"Bearer","expires_in":3600,"refresh_token":"rotated"}"#)])
        let store = Store(tokens(expired: true))
        let oauth = SpotifyOAuthClient(configuration: try configuration(), client: http, store: store, now: { now })
        let access = try await oauth.accessToken()
        XCTAssertEqual(access, "new")
        XCTAssertEqual(store.load()?.refreshToken, "rotated")
        let deniedStore = Store(tokens(expired: true))
        let denied = SpotifyOAuthClient(configuration: try configuration(), client: HTTP([Response(status: 400, body: #"{"error":"invalid_grant"}"#)]), store: deniedStore, now: { now })
        do { _ = try await denied.accessToken(); XCTFail("Expired refresh token") }
        catch { XCTAssertEqual(error as? SpotifyWebError, .authorizationRequired) }
        XCTAssertNil(deniedStore.load())
    }

    func testRefreshWithoutRotationKeepsExistingRefreshToken() async throws {
        let now = date, store = Store(tokens(expired: true))
        let http = HTTP([Response(status: 200, body: #"{"access_token":"new","token_type":"Bearer","expires_in":3600}"#)])
        let oauth = SpotifyOAuthClient(configuration: try configuration(), client: http, store: store, now: { now })
        _ = try await oauth.accessToken()
        XCTAssertEqual(store.load()?.refreshToken, "old-refresh")
    }

    func testConcurrentRefreshIsSingleFlight() async throws {
        let started = expectation(description: "refresh started"), now = date
        let http = GateHTTP { started.fulfill() }
        let oauth = SpotifyOAuthClient(configuration: try configuration(), client: http, store: Store(tokens(expired: true)), now: { now })
        async let first = oauth.accessToken()
        async let second = oauth.accessToken()
        await fulfillment(of: [started], timeout: 2)
        await http.finish()
        let results = try await [first, second]
        XCTAssertEqual(results, ["new-access", "new-access"])
        let count = await http.count
        XCTAssertEqual(count, 1)
    }

    func testLogoutDuringRefreshCannotResurrectCredentials() async throws {
        let started = expectation(description: "refresh started"), now = date
        let http = GateHTTP { started.fulfill() }, store = Store(tokens(expired: true))
        let oauth = SpotifyOAuthClient(configuration: try configuration(), client: http, store: store, now: { now })
        let pending = Task { try await oauth.accessToken() }
        await fulfillment(of: [started], timeout: 2)
        try await oauth.signOut()
        await http.finish()
        do { _ = try await pending.value; XCTFail("Cancelled refresh must not persist") } catch { }
        XCTAssertNil(store.load())
    }

    private var playbackBody: String {
        #"{"is_playing":true,"progress_ms":12000,"item":{"type":"track","id":"0123456789012345678901","name":"Original fixture","duration_ms":30000,"artists":[{"name":"Original artist"}],"album":{"name":"Original album","images":[{"url":"https://example.com/art.jpg"}]}}}"#
    }

    func testPlaybackMetadataAndSingleUnauthorizedRetry() async throws {
        let now = date, store = Store(tokens())
        let tokenHTTP = HTTP([Response(status: 200, body: #"{"access_token":"fresh","token_type":"Bearer","expires_in":3600}"#)])
        let oauth = SpotifyOAuthClient(configuration: try configuration(), client: tokenHTTP, store: store, now: { now })
        let http = HTTP([Response(status: 401, body: ""), Response(status: 200, body: playbackBody)])
        let client = SpotifyWebPlaybackClient(oauth: oauth, client: http, now: { now })
        let value = try await client.playback()
        XCTAssertEqual(value.track?.title, "Original fixture")
        XCTAssertEqual(value.track?.artist, "Original artist")
        XCTAssertEqual(value.track?.album, "Original album")
        XCTAssertEqual(value.track?.duration, 30)
        XCTAssertEqual(value.position, 12)
        XCTAssertEqual(value.state, .playing)
        XCTAssertNotNil(value.track?.artworkURL)
        let requests = await http.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer fresh")
    }

    func testNoActivePlaybackNullablePositionAndNetworkFailures() async throws {
        let now = date
        let oauth = SpotifyOAuthClient(configuration: try configuration(), client: HTTP([]), store: Store(tokens()), now: { now })
        let http = HTTP([Response(status: 204, body: ""),
            Response(status: 200, body: playbackBody.replacingOccurrences(of: "12000", with: "null")),
            Response(status: 200, body: playbackBody.replacingOccurrences(of: "true", with: "false"))])
        let client = SpotifyWebPlaybackClient(oauth: oauth, client: http, now: { now })
        let empty = try await client.playback()
        XCTAssertNil(empty.track)
        let missingPosition = try await client.playback()
        XCTAssertNotNil(missingPosition.track)
        XCTAssertNil(missingPosition.position)
        let paused = try await client.playback()
        XCTAssertEqual(paused.state, .paused)
        XCTAssertEqual(paused.position(at: now.addingTimeInterval(5)), paused.position)
        do { _ = try await client.playback(); XCTFail("Offline transport must fail explicitly") }
        catch { XCTAssertEqual(error as? SpotifyWebError, .network) }
    }

    func testRateLimitAndForbiddenAccessDoNotSpin() async throws {
        let now = date
        let oauth = SpotifyOAuthClient(configuration: try configuration(), client: HTTP([]), store: Store(tokens()), now: { now })
        let http = HTTP([Response(status: 429, body: "", headers: ["Retry-After": "120"])])
        let client = SpotifyWebPlaybackClient(oauth: oauth, client: http, now: { now })
        for _ in 0..<2 {
            do { _ = try await client.playback(); XCTFail("Rate limit must be enforced") }
            catch { XCTAssertEqual(error as? SpotifyWebError, .rateLimited(120)) }
        }
        let requests = await http.requests
        XCTAssertEqual(requests.count, 1)
        let forbidden = SpotifyWebPlaybackClient(oauth: oauth, client: HTTP([Response(status: 403, body: "")]), now: { now })
        do { _ = try await forbidden.playback(); XCTFail("Forbidden capability") }
        catch { XCTAssertEqual(error as? SpotifyWebError, .forbidden) }
    }

    func testTokenEndpointRateLimitAndMissingScopeAreExplicit() async throws {
        let now = date, store = Store(tokens(expired: true))
        let http = HTTP([Response(status: 429, body: "", headers: ["Retry-After": "120"])])
        let oauth = SpotifyOAuthClient(configuration: try configuration(), client: http, store: store, now: { now })
        for _ in 0..<2 {
            do { _ = try await oauth.accessToken(); XCTFail("Token refresh backoff") }
            catch { XCTAssertEqual(error as? SpotifyWebError, .rateLimited(120)) }
        }
        let count = await http.requests.count
        XCTAssertEqual(count, 1)
        let reduced = HTTP([Response(status: 200, body: #"{"access_token":"new","token_type":"Bearer","expires_in":3600,"scope":"user-read-private"}"#)])
        let denied = SpotifyOAuthClient(configuration: try configuration(), client: reduced, store: Store(tokens(expired: true)), now: { now })
        do { _ = try await denied.accessToken(); XCTFail("Required scope missing") }
        catch { XCTAssertEqual(error as? SpotifyWebError, .authorizationDenied) }
    }

    func testLateUnauthorizedResponseCannotDeleteNewerCredentials() async throws {
        let now = date, store = Store(tokens())
        let oauth = SpotifyOAuthClient(configuration: try configuration(), client: HTTP([]), store: store, now: { now })
        store.save(SpotifyTokens(accessToken: "newer-access", refreshToken: "newer-refresh",
            expiresAt: now.addingTimeInterval(3600), scope: SpotifyWebConfiguration.scopes))
        try await oauth.invalidateAccessToken("old-access")
        XCTAssertEqual(store.load()?.accessToken, "newer-access")
    }

    func testPositionEstimatesExpireFreezeWhenPausedAndResetOnNewTrack() {
        let sample = PlaybackSnapshot(track: .demo, state: .playing, position: 5, lastUpdatedAt: date)
        XCTAssertEqual(SpotifyPlaybackProjection.snapshot(from: sample, at: date.addingTimeInterval(1)).position, 6)
        XCTAssertNil(SpotifyPlaybackProjection.snapshot(from: sample, at: date.addingTimeInterval(8)).track)
        XCTAssertNil(SpotifyPlaybackProjection.snapshot(from: sample, at: date.addingTimeInterval(-1)).position)
        let paused = PlaybackSnapshot(track: .demo, state: .paused, position: 5, lastUpdatedAt: date)
        XCTAssertEqual(SpotifyPlaybackProjection.snapshot(from: paused, at: date.addingTimeInterval(10)).position, 5)
        let changed = Track(id: "spotify:next", title: "Next original", artist: "Fixture", album: nil, duration: 30, artworkURL: nil, source: "Spotify")
        let next = PlaybackSnapshot(track: changed, state: .playing, position: 0, lastUpdatedAt: date.addingTimeInterval(5))
        let value = SpotifyPlaybackProjection.snapshot(from: next, at: date.addingTimeInterval(6))
        XCTAssertEqual(value.track, changed)
        XCTAssertEqual(value.position, 1)
    }
}
