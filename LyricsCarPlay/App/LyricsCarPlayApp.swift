import SwiftUI

@main
struct LyricsCarPlayApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var container = AppContainer()
    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView().tabItem { Label("Home", systemImage: "house") }
                NowPlayingView(model: container.nowPlaying).tabItem { Label("Now Playing", systemImage: "music.note") }
                ParkedVideoView(prepareForVideo: container.nowPlaying.pausePlayback)
                    .tabItem { Label("Video", systemImage: "play.rectangle") }
                SettingsView(preferences: container.preferences, model: container.nowPlaying, selectMusicApp: container.selectMusicApp).tabItem { Label("Settings", systemImage: "gear") }
            }
            .modifier(WelcomeModifier(preferences: container.preferences, selectMusicApp: container.selectMusicApp))
            .modifier(AppAppearanceModifier(preferences: container.preferences))
            .onOpenURL { container.nowPlaying.handleCallback($0) }
            .task(id: scenePhase) {
                if scenePhase == .active { await container.nowPlaying.run() }
            }
        }
    }
}

private struct AppAppearanceModifier: ViewModifier {
    @ObservedObject var preferences: AppPreferences
    func body(content: Content) -> some View {
        content.preferredColorScheme(preferences.appearance.colorScheme)
    }
}
