import SwiftUI
import WidgetKit

struct LyricsEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedLyricsSnapshot
}

struct LyricsTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> LyricsEntry {
        LyricsEntry(date: Date(), snapshot: .demo(at: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (LyricsEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)); return }
        Task { completion(await currentEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LyricsEntry>) -> Void) {
        Task {
            let entry = await currentEntry()
            var entries = [entry]
            if entry.snapshot.expiresAt > entry.date {
                let expiry = entry.snapshot.expiresAt
                entries.append(LyricsEntry(date: expiry, snapshot: entry.snapshot.presentation(at: expiry)))
            }
            // The second entry expires content; it does not schedule future lyric lines.
            completion(Timeline(entries: entries, policy: .after(entry.date.addingTimeInterval(900))))
        }
    }

    private func currentEntry() async -> LyricsEntry {
        let now = Date()
        let snapshot: SharedLyricsSnapshot
        do {
            let repository = try AppGroupLyricsRepository.configured()
            snapshot = try await repository.load() ?? .unavailable(at: now)
        } catch { snapshot = .unavailable(at: now, message: "Shared storage unavailable") }
        return LyricsEntry(date: now, snapshot: snapshot.presentation(at: now))
    }
}

struct LyricsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedLyricsSnapshot.widgetKind, provider: LyricsTimelineProvider()) { entry in
            ViewThatFits(in: .vertical) {
                LyricsSurfaceView(snapshot: entry.snapshot, compact: false)
                LyricsSurfaceView(snapshot: entry.snapshot, compact: true)
            }
            .containerBackground(for: .widget) { Color(uiColor: .secondarySystemBackground) }
        }
        .configurationDisplayName("Lyrics snapshot")
        .description("Best-effort lyrics from the iPhone app. System refresh timing varies.")
        .supportedFamilies([.systemSmall])
        .containerBackgroundRemovable(true)
        // Keep WidgetKit's contextual content margins. No deep link or app-launch assumption.
    }
}

struct LyricsSurfaceView: View {
    let snapshot: SharedLyricsSnapshot
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            Text(snapshot.title).font(.headline).lineLimit(1).truncationMode(.tail)
            if !compact && !snapshot.artist.isEmpty {
                Text(snapshot.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Text(snapshot.status == .ready ? (snapshot.lyricLine ?? snapshot.message) : snapshot.message)
                .font(.body.weight(.semibold)).lineLimit(compact ? 2 : 3).truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading).layoutPriority(1)
            HStack(spacing: 4) {
                Image(systemName: snapshot.playbackState == .playing ? "play.fill" : "pause.fill")
                    .accessibilityHidden(true)
                Text(statusLabel).lineLimit(1)
                if !compact {
                    Text(snapshot.updatedAt, style: .time).lineLimit(1)
                        .accessibilityLabel(Text("Updated at \(snapshot.updatedAt.formatted(date: .omitted, time: .shortened))"))
                }
            }.font(.caption2).foregroundStyle(.secondary)
            if !compact, let attribution = snapshot.attribution, snapshot.status == .ready {
                Text(attribution).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusLabel: String {
        switch snapshot.status {
        case .ready: return snapshot.playbackState == .paused ? "Paused" : "Snapshot"
        case .loading: return "Loading"
        case .suspended: return "Updates paused"
        case .stale: return "Snapshot expired"
        case .unavailable: return "Unavailable"
        }
    }
}

#Preview("Timeline and expiry", as: .systemSmall) {
    LyricsWidget()
} timeline: {
    LyricsEntry(date: .now, snapshot: .demo(at: .now))
    LyricsEntry(date: .now.addingTimeInterval(5), snapshot: SharedLyricsSnapshot(
        status: .loading, message: "Loading lyrics", updatedAt: .now, expiresAt: .now.addingTimeInterval(30)))
    LyricsEntry(date: .now.addingTimeInterval(10), snapshot: SharedLyricsSnapshot(
        title: "A deliberately long original track title", artist: "An original demonstration artist",
        lyricLine: "This original demonstration line is deliberately long to check truncation in small system presentations.",
        playbackState: .paused, status: .ready, message: "Paused", updatedAt: .now, expiresAt: .now.addingTimeInterval(30)))
}

struct LyricsLayoutPreviews: PreviewProvider {
    static var previews: some View {
        ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
            LyricsSurfaceView(snapshot: .demo(at: .now), compact: false)
                .containerBackground(for: .widget) { Color(uiColor: .secondarySystemBackground) }
                .environment(\.colorScheme, scheme)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName(scheme == .dark ? "Dark" : "Light")
        }
    }
}
