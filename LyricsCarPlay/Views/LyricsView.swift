import SwiftUI

struct LyricsView: View {
    let state: LyricsState
    let activeLineID: UUID?
    let synchronized: SynchronizedLyricsState
    let retry: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var followPlayback = true

    private var statusText: String {
        switch synchronized.synchronizationStatus {
        case .waiting: return "Lyrics begin soon"
        case .gap: return "Instrumental"
        case .ended: return "Track ended"
        case .positionUnavailable: return "Playback timing unavailable"
        default: return "Lyrics will appear here"
        }
    }

    var body: some View {
        switch state {
        case .idle: Text("Lyrics will appear here.").foregroundStyle(.secondary)
        case .loading: ProgressView("Finding lyrics...")
        case .unavailable(let reason):
            VStack {
                ContentUnavailableView("Lyrics unavailable", systemImage: "text.alignleft", description: Text(reason))
                Button("Reload lyrics", action: retry)
            }
        case .failed(let message):
            VStack { Text(message); Button("Try again", action: retry) }
        case .available(let document):
            VStack {
                if synchronized.synchronizationStatus != .untimed {
                    VStack(alignment: .leading, spacing: 12) {
                        if let previous = synchronized.previousLine {
                            Text(previous.text).font(.title3).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Text(synchronized.currentLine.map { $0.text.isEmpty ? "Instrumental" : $0.text } ?? statusText)
                            .font(.largeTitle.bold()).foregroundStyle(Color.accentColor).lineLimit(4).minimumScaleFactor(0.7)
                            .accessibilityAddTraits(.isSelected)
                            .accessibilityIdentifier("currentLyric")
                            .contentTransition(.opacity)
                        if let next = synchronized.nextLine {
                            Text(next.text).font(.title3).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: synchronized.currentLine?.id)
                }
                if synchronized.synchronizationStatus == .untimed {
                    fullLyrics(document)
                } else {
                    DisclosureGroup("All lyrics") { fullLyrics(document).frame(height: 220) }
                }
                Text(document.attribution).font(.caption).foregroundStyle(.secondary)

            }
        }
    }

    private func fullLyrics(_ document: LyricsDocument) -> some View {
        VStack {
            if !followPlayback { Button("Follow lyrics") { followPlayback = true } }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(document.lines) { line in
                            Text(line.text).font(.title2).fontWeight(line.id == activeLineID ? .bold : .regular)
                                .foregroundStyle(line.id == activeLineID ? Color.accentColor : Color.primary)
                                .accessibilityAddTraits(line.id == activeLineID ? .isSelected : [])
                                .id(line.id)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical)
                }
                .simultaneousGesture(DragGesture().onChanged { _ in followPlayback = false })
                .onChange(of: activeLineID, initial: true) { _, id in
                    guard followPlayback, let id else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut) { proxy.scrollTo(id, anchor: .center) }
                }
                .onChange(of: followPlayback) { _, follow in
                    if follow, let activeLineID { proxy.scrollTo(activeLineID, anchor: .center) }
                }
            }
        }
    }
}
