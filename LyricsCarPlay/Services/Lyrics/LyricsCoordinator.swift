import Foundation

@MainActor
final class LyricsCoordinator {
    private let provider: any LyricsProvider
    private let catalogs: [any LyricsCatalog]
    let imports = ImportedLRCLyricsProvider()
    private let cache = LyricsCache()
    init(provider: any LyricsProvider, catalogs: [any LyricsCatalog] = []) { self.provider = provider; self.catalogs = catalogs }

    func clearCache() { cache.clear() }

    func lyrics(for track: Track) async throws -> LyricsDocument? {
        try await match(for: track)?.document
    }

    func match(for track: Track) async throws -> LyricsMatch? {
        guard track.providerIdentifier.lowercased() != "spotify", !track.id.hasPrefix("spotify:") else { return nil }
        var candidates = await imports.candidates(for: track)
        for catalog in catalogs { candidates += try await catalog.candidates(for: track) }
        if case .matched(let match) = LyricsMatchingService().match(track, candidates: candidates) { return match }
        if track.identity != Track.demo.identity,
           let demo = try await MockLyricsProvider().lyrics(for: .demo),
           case .matched(let match) = LyricsMatchingService().match(track, candidates: [LyricsCandidate(track: .demo, document: demo, source: "Original bundled demo")]) {
            return match
        }
        let key = LyricsTrackKey(track).cacheKey
        if let cached = cache.document(for: key) {
            return LyricsMatch(document: cached, confidence: 1, source: cached.attribution)
        }
        let document = try await provider.lyrics(for: track)
        try Task.checkCancellation()
        if let document { cache.insert(document, for: key) }
        return document.map { LyricsMatch(document: $0, confidence: 1, source: $0.attribution) }
    }
}
