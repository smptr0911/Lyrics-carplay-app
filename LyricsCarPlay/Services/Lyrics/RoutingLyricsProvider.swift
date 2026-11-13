import Foundation

struct RoutingLyricsProvider: LyricsProvider {
    let live: LicensedLyricsProvider
    let useBackendForDemo: Bool
    init(live: LicensedLyricsProvider, useBackendForDemo: Bool = false) {
        self.live = live
        self.useBackendForDemo = useBackendForDemo
    }
    func lyrics(for track: Track) async throws -> LyricsDocument? {
        if track.id.hasPrefix("demo:"), !useBackendForDemo {
            return try await MockLyricsProvider().lyrics(for: track)
        }
        return try await live.lyrics(for: track)
    }
}
