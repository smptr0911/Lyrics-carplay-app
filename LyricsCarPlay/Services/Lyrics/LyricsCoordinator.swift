import Foundation

@MainActor
final class LyricsCoordinator {
    private let provider: any LyricsProvider
    private let cache = LyricsCache()
    init(provider: any LyricsProvider) { self.provider = provider }

    func clearCache() { cache.clear() }

    func lyrics(for track: Track) async throws -> LyricsDocument? {
        if let cached = cache.document(for: track.id) { return cached }
        let document = try await provider.lyrics(for: track)
        try Task.checkCancellation()
        if let document { cache.insert(document, for: track.id) }
        return document
    }
}
