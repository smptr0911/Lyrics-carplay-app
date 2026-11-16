import ActivityKit
import SwiftUI
import WidgetKit

struct LyricsLiveActivity: Widget {
    var body: some WidgetConfiguration { configuration }

    var configuration: ActivityConfiguration<LyricsActivityAttributes> {
        ActivityConfiguration(for: LyricsActivityAttributes.self) { context in
            if #available(iOS 18.0, *) {
                AdaptiveLyricsActivityView(context: context)
            } else {
                LyricsSurfaceView(snapshot: freshSnapshot(context), compact: false).padding()
            }
        } dynamicIsland: { context in
            let snapshot = freshSnapshot(context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(snapshot.title).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: snapshot.playbackState == .playing ? "play.fill" : "pause.fill")
                        .accessibilityLabel(snapshot.playbackState.rawValue)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LyricsSurfaceView(snapshot: snapshot, compact: false)
                }
            } compactLeading: {
                Image(systemName: "music.note").accessibilityLabel(snapshot.title)
            } compactTrailing: {
                Text(snapshot.status == .ready ? (snapshot.lyricLine ?? snapshot.message) : snapshot.message)
                    .font(.caption2).lineLimit(1).truncationMode(.tail)
            } minimal: {
                Image(systemName: snapshot.status == .ready ? "music.note" : "clock")
            }
        }
    }
}

@available(iOS 18.0, *)
struct SmallFamilyLyricsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        LyricsLiveActivity().configuration.supplementalActivityFamilies([.small])
    }
}

@available(iOS 18.0, *)
private struct AdaptiveLyricsActivityView: View {
    let context: ActivityViewContext<LyricsActivityAttributes>
    @Environment(\.activityFamily) private var family
    var body: some View {
        LyricsSurfaceView(snapshot: freshSnapshot(context), compact: family == .small)
            .padding(family == .small ? 10 : 16)
    }
}

private func freshSnapshot(_ context: ActivityViewContext<LyricsActivityAttributes>) -> SharedLyricsSnapshot {
    if context.isStale {
        return context.state.snapshot.redacted(status: .stale, message: "Open iPhone to refresh", at: .now)
    }
    return context.state.snapshot.presentation(at: .now)
}

#Preview("Lock Screen", as: .content, using: LyricsActivityAttributes(sessionID: UUID())) {
    LyricsLiveActivity()
} contentStates: {
    LyricsActivityAttributes.ContentState(snapshot: .demo(at: .now))
    LyricsActivityAttributes.ContentState(snapshot: .unavailable(at: .now))
    LyricsActivityAttributes.ContentState(snapshot: SharedLyricsSnapshot.demo(at: .now)
        .redacted(status: .suspended, message: "Open iPhone to refresh", at: .now))
}
