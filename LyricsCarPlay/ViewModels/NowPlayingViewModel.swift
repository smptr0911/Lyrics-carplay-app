import SwiftUI

@MainActor
final class NowPlayingViewModel: ObservableObject {
    @Published private(set) var snapshot = PlaybackSnapshot(track: nil, state: .stopped, position: nil)
    @Published private(set) var lyricsState: LyricsState = .idle
    @Published private(set) var activeLineID: UUID?
    @Published private(set) var selectedMusicApp: MusicApp = .demo
    @Published private(set) var sourceStatus = ""
    @Published private(set) var canControlPlayback = false
    @Published private(set) var canSeek = false
    @Published private(set) var isConnecting = false
    private var isActive = false
    private var connectionEnabled = true
    private var runID: UUID?
    private let playback: PlaybackCoordinator
    private let lyrics: LyricsCoordinator
    private var timeline = LyricsTimeline(lines: [])
    private var loadedTrackID: String?
    private var request: Task<Void, Never>?

    init(source: any MusicSource, provider: any LyricsProvider) {
        playback = PlaybackCoordinator(source: source)
        lyrics = LyricsCoordinator(provider: provider)
        selectedMusicApp = source.kind
        sourceStatus = source.statusMessage
    }

    func run() async {
        let identifier = UUID()
        runID = identifier
        isActive = true
        if connectionEnabled { playback.source.activate() }
        defer {
            if runID == identifier {
                runID = nil
                isActive = false
                playback.source.deactivate()
                request?.cancel(); request = nil; loadedTrackID = nil
            }
        }
        while !Task.isCancelled && runID == identifier {
            refresh()
            do { try await Task.sleep(for: .milliseconds(200)) } catch { break }
        }
    }

    private func refresh() {
        snapshot = playback.snapshot()
        sourceStatus = playback.source.statusMessage
        canControlPlayback = playback.source.canControlPlayback
        canSeek = playback.source.canSeek
        if snapshot.track?.id != loadedTrackID {
            request?.cancel()
            loadedTrackID = snapshot.track?.id
            activeLineID = nil
            timeline = LyricsTimeline(lines: [])
            guard let track = snapshot.track else { lyricsState = .idle; return }
            guard playback.source.allowsLyrics else {
                lyricsState = .unavailable(reason: "Lyrics are unavailable for Spotify in this app because synchronization is restricted by Spotify policy.")
                return
            }
            lyricsState = .loading
            request = Task { [weak self] in
                guard let self else { return }
                do {
                    let document = try await lyrics.lyrics(for: track)
                    guard !Task.isCancelled, loadedTrackID == track.id else { return }
                    if let document, !document.lines.isEmpty {
                        timeline = LyricsTimeline(lines: document.lines)
                        lyricsState = .available(document)
                        activeLineID = timeline.activeLineID(position: snapshot.position)
                    }
                    else { lyricsState = .unavailable(reason: "No lyrics found for this track.") }
                } catch {
                    guard !Task.isCancelled, loadedTrackID == track.id else { return }
                    lyricsState = .failed(message: error.localizedDescription)
                }
            }
        }
        if case .available = lyricsState {
            activeLineID = timeline.activeLineID(position: snapshot.position)
        } else { activeLineID = nil }
    }

    func selectSource(_ source: any MusicSource) {
        request?.cancel()
        request = nil
        loadedTrackID = nil
        activeLineID = nil
        lyricsState = .idle
        playback.replaceSource(source)
        selectedMusicApp = source.kind
        connectionEnabled = true
        if isActive { source.activate() }
        refresh()
    }

    func connect() async {
        guard !isConnecting else { return }
        isConnecting = true
        connectionEnabled = true
        let source = playback.source
        if isActive { source.activate() }
        _ = await source.requestAuthorization()
        isConnecting = false
        refresh()
    }

    func handleCallback(_ url: URL) {
        playback.source.handleCallback(url)
        refresh()
    }

    func clearLyricsCache() {
        lyrics.clearCache()
        request?.cancel()
        request = nil
        lyricsState = .unavailable(reason: "Lyrics cache cleared. Reload to fetch lyrics again.")
        activeLineID = nil
        timeline = LyricsTimeline(lines: [])
        loadedTrackID = snapshot.track?.id
    }

    func disconnect() {
        connectionEnabled = false
        playback.source.deactivate()
        if let spotify = playback.source as? SpotifyMusicSource { spotify.cancelAuthorization() }
        request?.cancel()
        lyrics.clearCache()
        lyricsState = .idle
        activeLineID = nil
        loadedTrackID = nil
        refresh()
    }

    func pausePlayback() {
        if playback.source.canControlPlayback && playback.snapshot().state == .playing { playback.source.togglePlayback() }
        refresh()
    }

    func togglePlayback() { guard canControlPlayback else { return }; playback.source.togglePlayback(); refresh() }
    func seek(to position: TimeInterval) { guard canSeek else { return }; playback.source.seek(to: position); refresh() }
    func retry() { loadedTrackID = nil; refresh() }
}
