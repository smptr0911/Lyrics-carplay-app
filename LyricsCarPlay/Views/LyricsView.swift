import SwiftUI

struct LyricsView: View {
    let state: LyricsState
    let activeLineID: UUID?
    let retry: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var followPlayback = true

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
                            Text(document.attribution).font(.caption).foregroundStyle(.secondary)
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
}
