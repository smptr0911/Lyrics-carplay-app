import XCTest
@testable import LyricsCarPlay

final class LyricsMatchingServiceTests: XCTestCase {
    private func track(_ id: String, title: String = "Original", album: String? = "Studio", duration: Double? = 30) -> Track {
        Track(id: id, title: title, artist: "Original artist", album: album, duration: duration, artworkURL: nil, source: "Test")
    }
    private func candidate(_ track: Track) -> LyricsCandidate {
        LyricsCandidate(track: track, document: LyricsDocument(lines: [LyricLine(startTime: 0, text: track.title)],
            attribution: "Original fixture", cacheUntil: nil), source: "Original local fixture")
    }

    func testConfidentCrossProviderMatchIncludesSource() {
        let result = LyricsMatchingService().match(track("appleMusic:1"), candidates: [candidate(track("local:1"))])
        guard case .matched(let match) = result else { return XCTFail("Matching metadata") }
        XCTAssertEqual(match.confidence, 1, accuracy: 0.001)
        XCTAssertEqual(match.source, "Original local fixture")
        XCTAssertEqual(match.document.lines.first?.text, "Original")
    }

    func testVersionAlbumDurationAndIncompleteMetadataAreNotGuessed() {
        let original = candidate(track("local:1"))
        for version in ["Original (Live)", "Original (Acoustic)", "Original - Remix", "Original (Instrumental)"] {
            guard case .unavailable = LyricsMatchingService().match(track("music:1", title: version), candidates: [original]) else {
                return XCTFail("Unrelated versions must not match")
            }
        }
        for target in [track("music:1", album: "Live album"), track("music:1", duration: 40),
                       track("music:1", album: nil), track("music:1", duration: nil)] {
            guard case .unavailable = LyricsMatchingService().match(target, candidates: [original]) else { return XCTFail("Insufficient metadata") }
        }
    }

    func testExplicitBindingWinsAndAmbiguousVersionsAreUnavailable() {
        let current = track("local:chosen")
        let result = LyricsMatchingService().match(current, candidates: [candidate(track("other:1")), candidate(current)])
        guard case .matched(let match) = result else { return XCTFail("Explicit binding should win") }
        XCTAssertEqual(match.sourceTrackIdentity, current.identity)
        let ambiguous = LyricsMatchingService().match(track("music:1"), candidates: [candidate(track("local:1")), candidate(track("local:2"))])
        guard case .unavailable = ambiguous else { return XCTFail("Ambiguous local records must not be selected") }
    }

    actor Provider: LyricsProvider {
        private(set) var requests = 0
        let missing: Bool
        init(missing: Bool = false) { self.missing = missing }
        func lyrics(for track: Track) async throws -> LyricsDocument? {
            requests += 1
            return missing ? nil : LyricsDocument(lines: [LyricLine(startTime: 0, text: track.title)],
                attribution: "Original test provider", cacheUntil: Date().addingTimeInterval(60))
        }
    }

    @MainActor
    func testMissingLyricsAndMetadataSensitiveCache() async throws {
        let provider = Provider()
        let coordinator = LyricsCoordinator(provider: provider)
        let first = track("test:same")
        let cached = try await coordinator.lyrics(for: first)
        XCTAssertEqual(cached?.lines.first?.text, "Original")
        _ = try await coordinator.lyrics(for: first)
        let changed = try await coordinator.lyrics(for: track("test:same", title: "Original (Live)"))
        XCTAssertEqual(changed?.lines.first?.text, "Original (Live)")
        let count = await provider.requests
        XCTAssertEqual(count, 2)
        let unavailable = try await LyricsCoordinator(provider: Provider(missing: true)).match(for: first)
        XCTAssertNil(unavailable)
    }

    @MainActor
    func testImportedCatalogCanMatchAndRemoveOriginalBinding() async throws {
        let coordinator = LyricsCoordinator(provider: Provider(missing: true))
        let local = track("local:1"), other = track("appleMusic:1")
        _ = try await coordinator.imports.importText("[00:00]Original fixture", for: local)
        let match = try await coordinator.match(for: other)
        XCTAssertEqual(match?.sourceTrackIdentity, local.identity)
        XCTAssertEqual(match?.document.lines.first?.text, "Original fixture")
        await coordinator.imports.remove(identity: local.identity)
        let missing = try await coordinator.match(for: other)
        XCTAssertNil(missing)
    }

    @MainActor
    func testSpotifyCannotBypassLyricsPolicyThroughMatching() async throws {
        let provider = Provider()
        let coordinator = LyricsCoordinator(provider: provider)
        let spotify = Track(id: "spotify:track:0123456789012345678901", title: Track.demo.title,
            artist: Track.demo.artist, album: Track.demo.album, duration: Track.demo.duration, artworkURL: nil, source: "Spotify")
        let match = try await coordinator.match(for: spotify)
        XCTAssertNil(match)
        let requests = await provider.requests
        XCTAssertEqual(requests, 0)
    }
}
