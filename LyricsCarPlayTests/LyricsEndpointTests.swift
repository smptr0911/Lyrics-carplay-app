import XCTest
@testable import LyricsCarPlay

final class LyricsEndpointTests: XCTestCase {
    func testProductionEndpointsRequireHTTPSAndNoEmbeddedCredentials() {
        XCTAssertTrue(LyricsEndpoint.isAllowed(URL(string: "https://example.com/v1/lyrics")!))
        for text in ["http://example.com/lyrics", "https://user:secret@example.com/lyrics", "file:///lyrics", "https://example.com/lyrics#token"] {
            XCTAssertFalse(LyricsEndpoint.isAllowed(URL(string: text)!))
        }
    }
    func testLocalServerIsOnlyAllowedInDebugSimulatorBuilds() {
        let url = URL(string: "http://localhost:8787/v1/lyrics")!
        #if DEBUG && targetEnvironment(simulator)
        XCTAssertTrue(LyricsEndpoint.isAllowed(url))
        #else
        XCTAssertFalse(LyricsEndpoint.isAllowed(url))
        #endif
    }
}
