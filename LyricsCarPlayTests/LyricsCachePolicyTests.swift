import XCTest
@testable import LyricsCarPlay

@MainActor
final class LyricsCachePolicyTests: XCTestCase {
    func testRevokedRetentionRemovesEarlierPermittedDocument() {
        let cache = LyricsCache()
        let now = Date()
        cache.insert(LyricsDocument(lines: [], attribution: "test", cacheUntil: now.addingTimeInterval(60)), for: "track", now: now)
        cache.insert(LyricsDocument(lines: [], attribution: "test", cacheUntil: nil), for: "track", now: now)
        XCTAssertNil(cache.document(for: "track", now: now))
    }
    func testCapacityEvictionAndClear() {
        let cache = LyricsCache(capacity: 1)
        let now = Date()
        let document = LyricsDocument(lines: [], attribution: "test", cacheUntil: now.addingTimeInterval(60))
        cache.insert(document, for: "old", now: now)
        cache.insert(document, for: "new", now: now)
        XCTAssertNil(cache.document(for: "old", now: now))
        XCTAssertNotNil(cache.document(for: "new", now: now))
        cache.clear()
        XCTAssertNil(cache.document(for: "new", now: now))
    }
}
