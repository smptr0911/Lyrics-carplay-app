import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var preferences: AppPreferences
    @ObservedObject var model: NowPlayingViewModel
    @ObservedObject var surfaces: LyricsSurfaceController
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
                    ForEach(MusicApp.allCases) { app in
                        Button {
                            selectMusicApp(app)
                        } label: {
                            HStack {
                                Text(app.title)
                                Spacer()
                                if preferences.musicApp == app {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .accessibilityIdentifier(app.title)
                    }
                    LabeledContent("Current source", value: model.selectedMusicApp.title)
                    Text(model.sourceStatus).font(.footnote).foregroundStyle(.secondary)
                    if model.selectedMusicApp != .demo {
                        Button(model.selectedMusicApp == .spotify ? "Connect Spotify" : "Authorize Apple Music") {
                            Task { await model.connect() }
                        }.disabled(model.isConnecting || !model.canRequestAuthorization)
                    }
                    if model.selectedMusicApp != .demo {
                        Button("Disconnect") { Task { await model.disconnect() } }
                        Link("Open app settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                    }
                    if model.selectedMusicApp == .spotify {
                        Text("Connecting requests read-only Spotify account playback access. It does not start playback. Spotify lyrics synchronization remains unavailable.")
                            .font(.footnote)
                    }
                }
                Section("Privacy") { NavigationLink("Privacy and data") { PrivacyView() } }
                Section("Storage") {
                    Button("Clear lyrics cache") { model.clearLyricsCache() }
                    Text("The lyrics cache stays in memory. Permitted snapshots may be saved for widgets and Live Activities. Spotify Web API credentials use protected Keychain storage; video URLs are not saved.").font(.footnote)
                }
                Section("About this prototype") {
                    Text("Demo playback uses original sample lyrics. No music account or network access is needed.")
                    Text("Spotify Web API needs account and HTTPS callback setup. Apple Music exposes only supported system-player items. Licensed lyrics require a separate provider.")
                }
                Section("Video") {
                    Text("Load a direct HTTPS video in the Video tab. AirPlay output requires a compatible display. URLs are not saved; video pauses in the background.")
                }
                Section("CarPlay") {
                    Button("Start Live Activity") { surfaces.startActivity() }
                        .disabled(surfaces.activityRequested)
                    Button("End Live Activity") { surfaces.endActivity() }
                    Text(surfaces.message).font(.footnote).foregroundStyle(.secondary)
                    Text("Add the Lyrics widget in your vehicle's CarPlay widget settings where supported. The system controls its placement and refresh timing.")
                    Text("Lyrics are best-effort snapshots and expire when stale. Accurate synchronization remains in the foreground iPhone app.")
                    Text("Only explicitly permitted lyrics can be shared. The original Demo is enabled; imports remain iPhone-only.")
                }
            }.navigationTitle("Settings")
        }
    }
}
