import Foundation
import Combine

@MainActor
final class AppContainer: ObservableObject {
    let nowPlaying: NowPlayingViewModel
    let preferences: AppPreferences
    let surfaces: LyricsSurfaceController
    private var sources: [MusicApp: any MusicSource] = [:]

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
        let surfaces = LyricsSurfaceController(repository: try? AppGroupLyricsRepository.configured(),
            activity: SystemLyricsActivityClient())
        self.surfaces = surfaces
        let source = Self.makeSource(initial)
        sources = [initial: source]
        nowPlaying = NowPlayingViewModel(source: source,
            provider: RoutingLyricsProvider(live: LicensedLyricsProvider(endpoint: endpoint), useBackendForDemo: useBackendForDemo),
            onSurfaceUpdate: { playback, lyrics, synchronized, offset in
                surfaces.receive(LyricsSurfaceProjection().snapshot(playback: playback, lyrics: lyrics,
                    synchronized: synchronized, offset: offset, at: Date()))
            })
    }

    func selectMusicApp(_ app: MusicApp) {
        guard preferences.musicApp != app else { return }
        preferences.musicApp = app
        let source = sources[app] ?? Self.makeSource(app)
        sources[app] = source
        nowPlaying.selectSource(source)
    }

    private static func makeSource(_ app: MusicApp) -> any MusicSource {
        switch app {
        case .spotify: return SpotifyWebMusicSource()
        case .appleMusic: return AppleMusicSource()
        case .demo: return MockMusicSource()
        }
    }
}
