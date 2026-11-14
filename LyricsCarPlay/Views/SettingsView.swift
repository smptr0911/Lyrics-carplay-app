import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var preferences: AppPreferences
    @ObservedObject var model: NowPlayingViewModel
    let selectMusicApp: (MusicApp) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $preferences.appearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }
                }
                Section("Music source") {
                    Menu {
                        ForEach(MusicApp.allCases) { app in
                            Button(app.title) { selectMusicApp(app) }
                        }
                    } label: {
                        LabeledContent("Music app", value: preferences.musicApp.title)
                    }
                    .accessibilityIdentifier("musicAppPicker")
                    LabeledContent("Current source", value: model.selectedMusicApp.title)
                    Text(model.sourceStatus).font(.footnote).foregroundStyle(.secondary)
                    if model.selectedMusicApp != .demo {
                        Button(model.selectedMusicApp == .spotify ? "Open Spotify / Resume" : "Authorize Apple Music") {
                            Task { await model.connect() }
                        }.disabled(model.isConnecting)
                    }
                    if model.selectedMusicApp != .demo {
                        Button("Disconnect") { model.disconnect() }
                        Link("Open app settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                    }
                    if model.selectedMusicApp == .spotify {
                        Text("Connecting opens Spotify and may resume playback. Lyrics synchronization is unavailable for this source.")
                            .font(.footnote)
                    }
                }
                Section("Privacy") { NavigationLink("Privacy and data") { PrivacyView() } }
                Section("Storage") {
                    Button("Clear lyrics cache") { model.clearLyricsCache() }
                    Text("Only provider-permitted lyrics are cached in memory. Video URLs and login tokens are not saved.").font(.footnote)
                }
                Section("About this prototype") {
                    Text("Demo playback uses original sample lyrics. No music account or network access is needed.")
                    Text("Spotify connects on a configured iPhone. Apple Music reads the system music player. A licensed lyrics service must be configured separately.")
                }
                Section("Video") {
                    Text("Load a direct HTTPS video in the Video tab. AirPlay output requires a compatible display. URLs are not saved; video pauses in the background.")
                }
                Section("CarPlay") {
                    Text("A simulator-only CarPlay navigation preview is available for development. Device video output uses AirPlay on supported vehicles.")
                }
            }.navigationTitle("Settings")
        }
    }
}
