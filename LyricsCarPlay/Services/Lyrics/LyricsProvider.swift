import Foundation

protocol LyricsProvider: Sendable {
    func lyrics(for track: Track) async throws -> LyricsDocument?
}
