import XCTest
@testable import LyricsCarPlay

final class ProviderAdapterTests: XCTestCase {
    func testUnconfiguredProviderFailsExplicitly() async {
        let track = Track(id: "test:1", title: "Test", artist: "Test", album: nil, duration: nil, artworkURL: nil, source: "test")
        do {
            _ = try await LicensedLyricsProvider().lyrics(for: track)
            XCTFail("Unconfigured provider must not silently return lyrics")
        } catch { XCTAssertTrue(error is LicensedLyricsProvider.ConfigurationError) }
    }
    @MainActor
    func testCacheRequiresPermissionAndExpires() {
        let cache = LyricsCache()
        let now = Date()
        cache.insert(LyricsDocument(lines: [], attribution: "test", cacheUntil: nil), for: "blocked", now: now)
        XCTAssertNil(cache.document(for: "blocked", now: now))
        cache.insert(LyricsDocument(lines: [], attribution: "test", cacheUntil: now.addingTimeInterval(10)), for: "allowed", now: now)
        XCTAssertNotNil(cache.document(for: "allowed", now: now))
        XCTAssertNil(cache.document(for: "allowed", now: now.addingTimeInterval(11)))
    }
}
