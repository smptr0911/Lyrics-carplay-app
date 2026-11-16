import Foundation

protocol LyricsProvider: Sendable {
    func lyrics(for track: Track) async throws -> LyricsDocument?
}

/// Supply short-lived credentials from a secure store/auth service, never app configuration.
protocol LyricsAPICredentials: Sendable {
    func bearerToken() async throws -> String?
}
