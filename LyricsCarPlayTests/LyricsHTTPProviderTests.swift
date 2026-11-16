import XCTest
@testable import LyricsCarPlay

final class LyricsHTTPProviderTests: XCTestCase {
    private let track = Track(id: "test:1", title: "Test", artist: "Artist", album: nil, duration: nil, artworkURL: nil, source: "test")

    struct StubClient: HTTPClient {
        let status: Int
        let payload: String
        func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "trackID" })?.value, "test:1")
            return (Data(payload.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"])!)
        }
    }

    struct Credentials: LyricsAPICredentials {
        let token: String?
        func bearerToken() async throws -> String? { token }
    }

    struct AuthorizedClient: HTTPClient {
        func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer original-test-token")
            let payload = #"{"trackID":"test:1","attribution":"Original","lines":[{"text":"A","startTime":0,"endTime":2}]}"#
            return (Data(payload.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"])!)
        }
    }

    func testInjectedAuthorizationAndExplicitEndTimes() async throws {
        let provider = LicensedLyricsProvider(endpoint: URL(string: "https://example.com/lyrics"),
            client: AuthorizedClient(), credentials: Credentials(token: "original-test-token"))
        let first = try await provider.lyrics(for: track)
        let second = try await provider.lyrics(for: track)
        XCTAssertEqual(first?.lines.first?.endTime, 2)
        XCTAssertEqual(first?.lines.first?.id, second?.lines.first?.id)
        for token in [nil, "", "invalid\r\nheader"] as [String?] {
            do {
                _ = try await LicensedLyricsProvider(endpoint: URL(string: "https://example.com/lyrics"),
                    client: AuthorizedClient(), credentials: Credentials(token: token)).lyrics(for: track)
                XCTFail("Missing or invalid credential must fail before transport")
            } catch { XCTAssertEqual(error as? LyricsProviderError, .authorizationRequired) }
        }
    }

    func testValidResponseSortsLinesWithoutGrantingCachePermission() async throws {
        let client = StubClient(status: 200, payload: #"{"trackID":"test:1","attribution":"Original test","lines":[{"text":"later","startTime":5},{"text":"earlier","startTime":0}]}"#)
        let document = try await LicensedLyricsProvider(endpoint: URL(string: "https://example.com/lyrics"), client: client).lyrics(for: track)
        XCTAssertEqual(document?.lines.map(\.text), ["earlier", "later"])
        XCTAssertNil(document?.cacheUntil)
    }

    func testNoMatchAndRateLimit() async throws {
        let endpoint = URL(string: "https://example.com/lyrics")!
        let missing = try await LicensedLyricsProvider(endpoint: endpoint, client: StubClient(status: 404, payload: "")).lyrics(for: track)
        XCTAssertNil(missing)
        do {
            _ = try await LicensedLyricsProvider(endpoint: endpoint, client: StubClient(status: 429, payload: "")).lyrics(for: track)
            XCTFail("Rate limit must be visible")
        } catch { XCTAssertEqual(error as? LyricsProviderError, .rateLimited) }
    }

    func testRejectsWrongTrackAndNegativeTiming() async {
        for payload in [
            #"{"trackID":"other:1","attribution":"Test","lines":[]}"#,
            #"{"trackID":"test:1","attribution":"Test","lines":[{"text":"bad","startTime":-1}]}"#,
            #"{"trackID":"test:1","attribution":"Test","lines":[{"text":"bad","startTime":5,"endTime":4}]}"#
        ] {
            do {
                _ = try await LicensedLyricsProvider(endpoint: URL(string: "https://example.com/lyrics"), client: StubClient(status: 200, payload: payload)).lyrics(for: track)
                XCTFail("Invalid metadata must not be displayed")
            } catch { XCTAssertEqual(error as? LyricsProviderError, .invalidResponse) }
        }
    }
}
