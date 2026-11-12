import XCTest
@testable import LyricsCarPlay

@MainActor
final class MusicSourceSelectionTests: XCTestCase {
    final class Source: MusicSource {
        let kind: MusicApp
        var authorization: MusicAuthorization = .authorized
        var deactivated = false
        init(_ kind: MusicApp) { self.kind = kind }
        func requestAuthorization() async -> MusicAuthorization { authorization }
        func snapshot() -> PlaybackSnapshot {
            PlaybackSnapshot(track: Track(id: "test:\(kind.rawValue)", title: kind.title, artist: "Test", album: nil,
                                           duration: 30, artworkURL: nil, source: kind.title), state: .paused, position: 0)
        }
        func togglePlayback() { }
        func seek(to position: TimeInterval) { }
        func deactivate() { deactivated = true }
    }

    actor CountingProvider: LyricsProvider {
        private(set) var count = 0
        func lyrics(for track: Track) async throws -> LyricsDocument? { count += 1; return nil }
    }

    func testSwitchClearsTrackAndDoesNotRequestSpotifyLyrics() async {
        let oldSource = Source(.demo)
        let provider = CountingProvider()
        let model = NowPlayingViewModel(source: oldSource, provider: provider)
        model.selectSource(Source(.spotify))
        XCTAssertTrue(oldSource.deactivated)
        XCTAssertEqual(model.selectedMusicApp, .spotify)
        XCTAssertEqual(model.snapshot.track?.source, "Spotify")
        XCTAssertNil(model.activeLineID)
        guard case .unavailable = model.lyricsState else { return XCTFail("Spotify lyrics must remain blocked") }
        let requests = await provider.count
        XCTAssertEqual(requests, 0)
    }

    func testPreferencePersistsAndUnknownValueDefaultsToSpotify() {
        let name = "MusicSourceSelectionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertEqual(AppPreferences(defaults: defaults).musicApp, .spotify)
        let preferences = AppPreferences(defaults: defaults)
        preferences.musicApp = .demo
        XCTAssertEqual(AppPreferences(defaults: defaults).musicApp, .demo)
        defaults.set("removed-app", forKey: "musicApp")
        XCTAssertEqual(AppPreferences(defaults: defaults).musicApp, .spotify)
    }

    func testSpotifyConfigurationRejectsUnsetIDAndUnrelatedCallbacks() {
        XCTAssertNil(SpotifyConfiguration(clientID: ""))
        XCTAssertNil(SpotifyConfiguration(clientID: "$(SPOTIFY_CLIENT_ID)"))
        XCTAssertNotNil(SpotifyConfiguration(clientID: "public-client-id"))
        XCTAssertTrue(SpotifyConfiguration.acceptsCallback(URL(string: "lyrics-carplay-spotify://callback#access_token=test")!))
        for text in ["other://callback", "lyrics-carplay-spotify://other", "lyrics-carplay-spotify://callback/extra", "lyrics-carplay-spotify://user@callback"] {
            XCTAssertFalse(SpotifyConfiguration.acceptsCallback(URL(string: text)!))
        }
    }
}
