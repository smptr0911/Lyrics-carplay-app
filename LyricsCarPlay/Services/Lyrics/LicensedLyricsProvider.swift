import Foundation

struct LicensedLyricsProvider: LyricsProvider {
    enum ConfigurationError: LocalizedError {
        case providerNotConfigured, invalidEndpoint
        var errorDescription: String? {
            switch self {
            case .providerNotConfigured: return "A licensed lyrics provider has not been configured."
            case .invalidEndpoint: return "The lyrics service must use a valid HTTPS endpoint."
            }
        }
    }

    private let endpoint: URL?
    private let client: any HTTPClient
    private let credentials: (any LyricsAPICredentials)?

    init(endpoint: URL? = nil, client: any HTTPClient = URLSessionHTTPClient(), credentials: (any LyricsAPICredentials)? = nil) {
        self.endpoint = endpoint
        self.client = client
        self.credentials = credentials
    }

    func lyrics(for track: Track) async throws -> LyricsDocument? {
        guard let endpoint else { throw ConfigurationError.providerNotConfigured }
        guard LyricsEndpoint.isAllowed(endpoint),
              var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw ConfigurationError.invalidEndpoint
        }
        var query = components.queryItems ?? []
        query.removeAll { $0.name == "trackID" }
        query.append(URLQueryItem(name: "trackID", value: track.id))
        components.queryItems = query
        guard let url = components.url else { throw ConfigurationError.invalidEndpoint }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let credentials {
            let token: String?
            do { token = try await credentials.bearerToken() }
            catch is CancellationError { throw CancellationError() }
            catch { throw LyricsProviderError.authorizationRequired }
            // CRLF is one Swift Character; inspect bytes to reject every control/whitespace byte.
            guard let token, !token.isEmpty, token.utf8.allSatisfy({ (33...126).contains($0) }) else {
                throw LyricsProviderError.authorizationRequired
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let data: Data
        let response: HTTPURLResponse
        do { (data, response) = try await client.data(for: request) }
        catch is CancellationError { throw CancellationError() }
        catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw LyricsProviderError.networkUnavailable
        }
        catch { throw LyricsProviderError.serverFailure }
        try Task.checkCancellation()
        switch response.statusCode {
        case 204, 404: return nil
        case 401, 403: throw LyricsProviderError.authorizationRequired
        case 429: throw LyricsProviderError.rateLimited
        case 200: break
        default: throw LyricsProviderError.serverFailure
        }
        guard response.mimeType == "application/json", data.count <= 1_000_000 else {
            throw LyricsProviderError.invalidResponse
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload: LyricsAPIResponse
        do { payload = try decoder.decode(LyricsAPIResponse.self, from: data) }
        catch { throw LyricsProviderError.invalidResponse }
        return try payload.document(for: track)
    }
}
