import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct NowPlayingView: View {
    @State private var isImporting = false
    @ObservedObject var model: NowPlayingViewModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(model.selectedMusicApp.title).font(.headline)
                    Text(model.sourceStatus).font(.caption).foregroundStyle(.secondary)
                    if model.selectedMusicApp != .demo {
                        Button(model.selectedMusicApp == .spotify ? "Connect Spotify" : "Authorize Apple Music") {
                            Task { await model.connect() }
                        }
                        .disabled(model.isConnecting || !model.canRequestAuthorization)
                        if model.selectedMusicApp == .spotify && !model.canRequestAuthorization {
                            Text("Configure Spotify Web API authorization using the repository setup guide. Demo works without credentials.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(model.snapshot.state.rawValue.capitalized)
                        .font(.subheadline).foregroundStyle(.secondary)
                        .accessibilityIdentifier("playbackStatus")
                    if let track = model.snapshot.track {
                        if let data = model.snapshot.artworkData, let image = UIImage(data: data) {
                            Image(uiImage: image).resizable().scaledToFit().frame(height: 100).accessibilityHidden(true)
                        } else if let url = track.artworkURL {
                            AsyncImage(url: url) { image in image.resizable().scaledToFit() }
                                placeholder: { Image(systemName: "music.note").font(.largeTitle) }
                                .frame(height: 100).accessibilityHidden(true)
                        }
                        VStack {
                            Text(track.title).font(.title.bold())
                            Text(track.artist).font(.headline)
                            if let album = track.album { Text(album).foregroundStyle(.secondary) }
                            Text(track.source).font(.caption)
                        }.accessibilityElement(children: .combine)
                        if let duration = track.duration, duration.isFinite, duration > 0, let position = model.snapshot.position, position.isFinite {
                            Slider(value: Binding(get: { min(duration, max(0, position)) }, set: { model.seek(to: $0) }), in: 0...duration)
                                .accessibilityLabel("Playback position")
                                .disabled(!model.canSeek)
                        }
                        Button(action: model.togglePlayback) {
                            Label(model.snapshot.state == .playing ? "Pause" : "Play",
                                  systemImage: model.snapshot.state == .playing ? "pause.fill" : "play.fill")
                        }.buttonStyle(.borderedProminent).disabled(!model.canControlPlayback)
                        if let url = track.spotifyURL { Link("Open in Spotify", destination: url) }
                        LyricsView(state: model.lyricsState, activeLineID: model.activeLineID,
                                   synchronized: model.synchronizedLyrics, retry: model.retry)
                            .id(track.identity)
                            .frame(minHeight: 220)
                        if let match = model.lyricsMatch {
                            Text("Match: \(Int((match.confidence * 100).rounded()))% - \(match.source)")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        if model.selectedMusicApp != .spotify {
                            timingControls
                        }
                    } else {
                        ContentUnavailableView("No readable track", systemImage: "music.note", description: Text("The selected provider is not exposing song metadata. Check its status above or choose Demo in Settings."))
                    }
                }.padding().navigationTitle("Now Playing")
                    .fileImporter(isPresented: $isImporting, allowedContentTypes: [.data]) { result in
                        switch result {
                        case .success(let url): Task { await model.importLyrics(from: url) }
                        case .failure(let error): model.reportImportError(error.localizedDescription)
                        }
                    }
            }
        }
    }

    private var timingControls: some View {
        DisclosureGroup("Timing and LRC import") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Offset: \(model.synchronizationOffset, specifier: "%.1f") s")
                    .monospacedDigit()
                Slider(value: Binding(get: { model.synchronizationOffset },
                    set: model.setSynchronizationOffset), in: -10...10, step: 0.1)
                    .accessibilityLabel("Synchronization offset")
                Text("Positive offsets show lyrics earlier. Negative offsets delay them.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Reset offset") { model.setSynchronizationOffset(0) }
                if model.selectedMusicApp == .demo {
                    Picker("Demo speed", selection: Binding(get: { model.snapshot.playbackRate },
                        set: model.setDemoPlaybackRate)) {
                        Text("0.5x").tag(0.5)
                        Text("1x").tag(1.0)
                        Text("1.5x").tag(1.5)
                        Text("2x").tag(2.0)
                    }.pickerStyle(.segmented)
                }
                Button("Import LRC for this track") { isImporting = true }
                    .disabled(model.isImporting)
                Button("Remove imported lyrics") { Task { await model.removeImportedLyrics() } }
                    .disabled(model.isImporting)
                Text("Imports stay in memory for this session. Use lyrics you have permission to display.")
                    .font(.caption).foregroundStyle(.secondary)
                if model.isImporting { ProgressView("Importing...") }
                if let error = model.importError { Text(error).foregroundStyle(.red) }
            }.padding(.top, 8)
        }
    }
}
