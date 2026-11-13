import SwiftUI

struct WelcomeView: View {
    @State private var selection: MusicApp = .spotify
    let continueWith: (MusicApp) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Choose your music app").font(.title2.bold())
                    Text("Connect your music account only when you are ready. Demo works without an account.")
                    Picker("Music app", selection: $selection) {
                        ForEach(MusicApp.allCases) { app in Text(app.title).tag(app) }
                    }
                }
                Section("What is available") {
                    Text("Spotify provides current-track information and playback controls. Spotify lyrics are unavailable in this app.")
                    Text("Timed lyrics work with the original demo and with separately licensed, permitted sources.")
                    Text("Watch video only while parked. AirPlay video output requires a compatible vehicle or display.")
                }
                Section {
                    Button("Continue") { continueWith(selection) }.buttonStyle(.borderedProminent).accessibilityIdentifier("continueWelcome")
                    NavigationLink("Privacy and data") { PrivacyView() }
                }
            }.navigationTitle("Welcome")
        }.interactiveDismissDisabled()
    }
}

struct WelcomeModifier: ViewModifier {
    @ObservedObject var preferences: AppPreferences
    let selectMusicApp: (MusicApp) -> Void
    func body(content: Content) -> some View {
        content.sheet(isPresented: Binding(get: { !preferences.hasSeenWelcome }, set: { _ in })) {
            WelcomeView { app in
                selectMusicApp(app)
                preferences.hasSeenWelcome = true
            }
        }
    }
}
