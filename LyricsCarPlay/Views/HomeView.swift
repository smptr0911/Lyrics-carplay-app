import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "music.note.list").font(.system(size: 64)).foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Your music, line by line").font(.largeTitle.bold())
                Text("Choose Spotify, Apple Music, or Demo in Settings. Demo includes original synchronized lyrics.")
                Text("Start Demo in Now Playing, then press Play. Settings offers a best-effort Live Activity; CarPlay display depends on system and vehicle support.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center).padding().navigationTitle("Lyrics CarPlay")
        }
    }
}
