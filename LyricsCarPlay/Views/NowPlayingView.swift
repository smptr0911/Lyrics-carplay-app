import SwiftUI
import UIKit

struct NowPlayingView: View {
    @ObservedObject var model: NowPlayingViewModel
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(model.selectedMusicApp.title).font(.headline)
                Text(model.sourceStatus).font(.caption).foregroundStyle(.secondary)
                if model.selectedMusicApp != .demo {
                    Button(model.selectedMusicApp == .spotify ? "Open Spotify / Resume" : "Authorize Apple Music") {
                        Task { await model.connect() }
                    }.disabled(model.isConnecting)
                }
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
                    LyricsView(state: model.lyricsState, activeLineID: model.activeLineID, retry: model.retry)
                        .id(track.id)
                } else {
                    ContentUnavailableView("Nothing playing", systemImage: "music.note", description: Text("Select your music app in Settings, then connect it here. Demo works without an account."))
                }
            }.padding().navigationTitle("Now Playing")
        }
    }
}
