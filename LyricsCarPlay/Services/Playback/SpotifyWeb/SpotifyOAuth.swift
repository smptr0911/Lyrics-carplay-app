import CryptoKit
import Foundation
import Security

enum SpotifyWebError: LocalizedError, Equatable {
    case configuration, authorizationRequired, authorizationDenied, invalidCallback, invalidResponse
    case network, forbidden, rateLimited(TimeInterval), server, cancelled, secureStorage
    var errorDescription: String? {
        switch self {
        case .configuration: return "Spotify Web API requires a Client ID, an owned HTTPS callback domain, and matching associated-domain signing. Browser authorization requires iOS 17.4 or later."
        case .authorizationRequired: return "Connect Spotify again to authorize playback access."
        case .authorizationDenied: return "Spotify authorization was denied or the required playback scope was not granted."
        case .invalidCallback: return "The Spotify authorization response could not be verified. Try connecting again."
        case .invalidResponse: return "Spotify returned an unsupported or invalid response."
        case .network: return "Spotify is unreachable. Playback timing is unavailable until the next successful request."
        case .forbidden: return "Spotify playback access is restricted. Check account eligibility, app mode, allowlisted users and granted scopes."
        case .rateLimited: return "Spotify requested a retry delay. Playback polling is temporarily paused."
        case .server: return "Spotify is temporarily unavailable."
        case .cancelled: return "Spotify connection cancelled."
        case .secureStorage: return "Spotify credentials could not be read or updated securely."
        }
    }
}

struct SpotifyWebConfiguration: Sendable {
    let clientID: String
    let redirectURL: URL
    static let scopes = "user-read-currently-playing"

    init(clientID: String, redirectURL: URL) throws {
        let clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty, clientID.utf8.count <= 256, !clientID.contains(where: \.isWhitespace),
              !clientID.contains("$("), !clientID.contains("YOUR_"),
              redirectURL.scheme == "https", let host = redirectURL.host, !host.isEmpty,
              host != "localhost", host.contains("."), redirectURL.port == nil,
              redirectURL.user == nil, redirectURL.password == nil, redirectURL.query == nil,
              redirectURL.fragment == nil, !redirectURL.path.isEmpty else { throw SpotifyWebError.configuration }
        self.clientID = clientID
        self.redirectURL = redirectURL
    }

    static func configured(bundle: Bundle = .main) -> Self? {
        guard let client = bundle.object(forInfoDictionaryKey: "SpotifyClientID") as? String,
              let value = bundle.object(forInfoDictionaryKey: "SpotifyRedirectURI") as? String,
              let url = URL(string: value),
              let configuredHost = bundle.object(forInfoDictionaryKey: "SpotifyAuthHost") as? String,
              configuredHost == url.host else { return nil }
        return try? Self(clientID: client, redirectURL: url)
    }

    func accepts(_ url: URL) -> Bool {
        url.scheme == redirectURL.scheme && url.host == redirectURL.host && url.path == redirectURL.path &&
        url.port == nil && url.user == nil && url.password == nil && url.fragment == nil
    }
}

struct SpotifyTokens: Codable, Sendable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let scope: String
}

struct SpotifyAuthorizationRequest: Sendable {
    let url: URL
    let redirectURL: URL
}

enum SpotifyPKCE {
    static func random() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw SpotifyWebError.secureStorage }
        return base64URL(Data(bytes))
    }
    static func challenge(_ verifier: String) -> String { base64URL(Data(SHA256.hash(data: Data(verifier.utf8)))) }
    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    static func form(_ fields: [String: String]) -> Data {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return Data(fields.sorted { $0.key < $1.key }.map {
            "\($0.key.addingPercentEncoding(withAllowedCharacters: allowed)!)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed)!)"
        }.joined(separator: "&").utf8)
    }
}

actor SpotifyOAuthClient {
    private struct Pending {
        let verifier: String
        let state: String
        let createdAt: Date
        let generation: Int
    }
    private let configuration: SpotifyWebConfiguration
    private let client: any HTTPClient
    private let store: any SpotifyTokenStore
    private let now: @Sendable () -> Date
    private var pending: Pending?
    private var generation = 0
    private var tokenTask: Task<String, Error>?
    private var retryAt: Date?

    init(configuration: SpotifyWebConfiguration, client: any HTTPClient = URLSessionHTTPClient(),
         store: any SpotifyTokenStore, now: @escaping @Sendable () -> Date = { Date() }) {
        self.configuration = configuration; self.client = client; self.store = store; self.now = now
    }

    func hasCredentials() throws -> Bool { try store.load() != nil }

    func beginAuthorization() throws -> SpotifyAuthorizationRequest {
        cancelAuthorization()
        let value = Pending(verifier: try SpotifyPKCE.random(), state: try SpotifyPKCE.random(), createdAt: now(), generation: generation)
        pending = value
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "response_type", value: "code"), URLQueryItem(name: "redirect_uri", value: configuration.redirectURL.absoluteString),
            URLQueryItem(name: "scope", value: SpotifyWebConfiguration.scopes), URLQueryItem(name: "state", value: value.state),
            URLQueryItem(name: "code_challenge_method", value: "S256"), URLQueryItem(name: "code_challenge", value: SpotifyPKCE.challenge(value.verifier))]
        return SpotifyAuthorizationRequest(url: components.url!, redirectURL: configuration.redirectURL)
    }

    func completeAuthorization(_ url: URL) async throws {
        let value = pending
        pending = nil // Every attempt consumes the single-use request, including invalid callbacks.
        guard let value, value.generation == generation, configuration.accepts(url),
              (0..<300).contains(now().timeIntervalSince(value.createdAt)),
              let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { throw SpotifyWebError.invalidCallback }
        func unique(_ name: String) -> String? {
            let values = query.filter { $0.name == name }
            return values.count == 1 ? values.first?.value : nil
        }
        guard unique("state") == value.state else { throw SpotifyWebError.invalidCallback }
        if query.contains(where: { $0.name == "error" }) { throw SpotifyWebError.authorizationDenied }
        guard let code = unique("code"), !code.isEmpty else { throw SpotifyWebError.invalidCallback }
        let tokens = try await tokenRequest(["grant_type": "authorization_code", "code": code,
            "redirect_uri": configuration.redirectURL.absoluteString, "code_verifier": value.verifier], previous: nil)
        try Task.checkCancellation()
        guard value.generation == generation else { throw SpotifyWebError.cancelled }
        try store.save(tokens)
    }

    func cancelAuthorization() {
        generation += 1; pending = nil
        tokenTask?.cancel(); tokenTask = nil
    }

    func signOut() throws {
        generation += 1
        pending = nil
        tokenTask?.cancel(); tokenTask = nil
        retryAt = nil
        try store.delete()
    }

    func invalidateAccessToken(_ rejected: String) throws {
        // A late 401 must not log out a newer browser authorization or a replaced token.
        guard pending == nil, try store.load()?.accessToken == rejected else { return }
        try signOut()
    }

    /// Single-flight acquisition includes Keychain access and persistence, not just the HTTP call.
    func accessToken(forceRefresh: Bool = false) async throws -> String {
        if let tokenTask {
            return try await withTaskCancellationHandler { try await tokenTask.value } onCancel: { tokenTask.cancel() }
        }
        let revision = generation
        let task = Task { try await self.acquire(forceRefresh: forceRefresh, generation: revision) }
        tokenTask = task
        defer { if generation == revision { tokenTask = nil } }
        return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
    }

    private func acquire(forceRefresh: Bool, generation revision: Int) async throws -> String {
        guard let tokens = try store.load() else { throw SpotifyWebError.authorizationRequired }
        if !forceRefresh && tokens.expiresAt.timeIntervalSince(now()) > 30 { return tokens.accessToken }
        let refreshed: SpotifyTokens
        do { refreshed = try await tokenRequest(["grant_type": "refresh_token", "refresh_token": tokens.refreshToken], previous: tokens) }
        catch SpotifyWebError.authorizationRequired {
            if revision == generation { try store.delete() }
            throw SpotifyWebError.authorizationRequired
        }
        try Task.checkCancellation()
        guard revision == generation else { throw SpotifyWebError.cancelled }
        try store.save(refreshed) // Synchronous store witness: logout cannot interleave with this write.
        return refreshed.accessToken
    }

    private func tokenRequest(_ fields: [String: String], previous: SpotifyTokens?) async throws -> SpotifyTokens {
        if let retryAt, retryAt > now() { throw SpotifyWebError.rateLimited(retryAt.timeIntervalSince(now())) }
        var fields = fields; fields["client_id"] = configuration.clientID
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"; request.httpBody = SpotifyPKCE.form(fields)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let data: Data, response: HTTPURLResponse
        do { (data, response) = try await client.data(for: request) }
        catch is CancellationError { throw CancellationError() }
        catch { throw SpotifyWebError.network }
        if response.statusCode == 429 {
            let delay = SpotifyRetry.delay(response)
            retryAt = now().addingTimeInterval(delay)
            throw SpotifyWebError.rateLimited(delay)
        }
        if response.statusCode == 400 || response.statusCode == 401 {
            struct Failure: Decodable { let error: String }
            if (try? JSONDecoder().decode(Failure.self, from: data).error) == "invalid_grant" { throw SpotifyWebError.authorizationRequired }
            throw SpotifyWebError.authorizationDenied
        }
        guard response.statusCode == 200 else { throw SpotifyWebError.server }
        struct Payload: Decodable {
            let access_token: String; let token_type: String; let expires_in: Double
            let refresh_token: String?; let scope: String?
        }
        guard data.count <= 64_000, response.mimeType == "application/json",
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.token_type.lowercased() == "bearer", !payload.access_token.isEmpty,
              payload.access_token.utf8.allSatisfy({ (33...126).contains($0) }),
              payload.expires_in.isFinite, (1...86_400).contains(payload.expires_in),
              let refresh = payload.refresh_token ?? previous?.refreshToken, !refresh.isEmpty else { throw SpotifyWebError.invalidResponse }
        let scope = payload.scope ?? previous?.scope ?? SpotifyWebConfiguration.scopes
        guard scope.split(separator: " ").contains(Substring(SpotifyWebConfiguration.scopes)) else { throw SpotifyWebError.authorizationDenied }
        retryAt = nil
        return SpotifyTokens(accessToken: payload.access_token, refreshToken: refresh,
            expiresAt: now().addingTimeInterval(payload.expires_in), scope: scope)
    }
}

enum SpotifyRetry {
    static func delay(_ response: HTTPURLResponse) -> TimeInterval {
        guard let text = response.value(forHTTPHeaderField: "Retry-After"),
              let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)), value.isFinite, value >= 0 else { return 60 }
        return max(1, value) // Never shorten Spotify's requested delay.
    }
}
