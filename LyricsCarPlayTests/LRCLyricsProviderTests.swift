import XCTest
@testable import LyricsCarPlay

final class LRCLyricsProviderTests: XCTestCase {
    private func track(_ id: String = "demo:lrc") -> Track {
        Track(id: id, title: "Original", artist: "Test", album: nil, duration: 30, artworkURL: nil, source: "Demo")
    }

    func testMetadataFractionsMultipleTagsOffsetsAndStableIDs() throws {
        let input = "\u{feff}[ar:Original fixture]\r\n[offset:500]\r\n[00:10.250]Later\r\n[00:01.0][00:05.00]Repeat\r\n[00:15]"
        let first = try LRCParser().parse(input, track: track())
        let second = try LRCParser().parse(input, track: track())
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.lines.map(\.startTime), [0.5, 4.5, 9.75, 14.5])
        XCTAssertEqual(first.lines.map(\.text), ["Repeat", "Repeat", "Later", ""])
        XCTAssertEqual(Set(first.lines.map(\.id)).count, 4)
        XCTAssertNil(first.cacheUntil)
        let other = try LRCParser().parse(input, track: track("demo:other"))
        XCTAssertNotEqual(first.lines[0].id, other.lines[0].id)
    }

    func testNegativeOffsetAndDuplicateTimestamps() throws {
        let doc = try LRCParser().parse("[offset:-1000]\n[00:01]A\n[00:01]B", track: track())
        XCTAssertEqual(doc.lines.map(\.startTime), [2, 2])
        XCTAssertEqual(LyricsTimeline(lines: doc.lines).state(position: 2).currentLine?.text, "B")
    }

    func testMalformedMissingAndOversizedInput() {
        for text in ["plain words", "[ar:metadata]", "[00:61]Bad", "[-01:00]Bad", "[00:00.1234]Bad", "[offset:nan]\n[00:00]Bad", "[00:00]A\n[00:01"] {
            XCTAssertThrowsError(try LRCParser().parse(text, track: track()), text)
        }
        XCTAssertThrowsError(try LRCParser().parse(String(repeating: "a", count: 1_000_001), track: track()))
        let expanded = String(repeating: "[00:00]", count: 2_000) + String(repeating: "a", count: 1_000)
        XCTAssertThrowsError(try LRCParser().parse(expanded, track: track()))
        let tooMany = String(repeating: "[00:00]", count: 50_001)
        XCTAssertThrowsError(try LRCParser().parse(tooMany, track: track()))
    }

    func testImportedProviderIsTrackScopedAndRemovable() async throws {
        let provider = ImportedLRCLyricsProvider()
        let doc = try await provider.importText("[00:00]Original fixture", for: track())
        let loaded = try await provider.lyrics(for: track())
        XCTAssertEqual(loaded, doc)
        let missing = try await provider.lyrics(for: track("demo:other"))
        XCTAssertNil(missing)
        await provider.remove(for: track())
        let removed = try await provider.lyrics(for: track())
        XCTAssertNil(removed)
    }
}
