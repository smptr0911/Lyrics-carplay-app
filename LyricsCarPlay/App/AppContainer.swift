import Foundation
import Combine

@MainActor
final class AppContainer: ObservableObject {
    let nowPlaying: NowPlayingViewModel
    let preferences: AppPreferences

    init() {
        let preferences = AppPreferences()
        self.preferences = preferences
        let initial = ProcessInfo.processInfo.arguments.contains("--demo-mode") ? MusicApp.demo : preferences.musicApp
        if ProcessInfo.processInfo.arguments.contains("--demo-mode") {
            preferences.hasSeenWelcome = !ProcessInfo.processInfo.arguments.contains("--show-welcome")
        }
        if initial != preferences.musicApp { preferences.musicApp = initial }
        let endpoint = LyricsEndpoint.configured()
        #if DEBUG && targetEnvironment(simulator)
        let useBackendForDemo = endpoint?.scheme == "http" && endpoint?.host == "localhost" && !ProcessInfo.processInfo.arguments.contains("--demo-mode")
        #else
        let useBackendForDemo = false
        #endif
        nowPlaying = NowPlayingViewModel(source: Self.makeSource(initial),
            provider: RoutingLyricsProvider(live: LicensedLyricsProvider(endpoint: endpoint), useBackendForDemo: useBackendForDemo))
    }

    func selectMusicApp(_ app: MusicApp) {
        guard preferences.musicApp != app else { return }
        preferences.musicApp = app
        nowPlaying.selectSource(Self.makeSource(app))
    }

    private static func makeSource(_ app: MusicApp) -> any MusicSource {
        switch app {
        case .spotify: return SpotifyMusicSource()
        case .appleMusic: return AppleMusicSource()
        case .demo: return MockMusicSource()
        }
    }
}
