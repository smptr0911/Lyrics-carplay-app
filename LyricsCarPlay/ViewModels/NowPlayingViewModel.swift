import SwiftUI

@MainActor
final class NowPlayingViewModel: ObservableObject {
    @Published private(set) var snapshot = PlaybackSnapshot(track: nil, state: .stopped, position: nil)
    @Published private(set) var lyricsState: LyricsState = .idle
    @Published private(set) var lyricsMatch: LyricsMatch?
    @Published private(set) var activeLineID: UUID?
    @Published private(set) var selectedMusicApp: MusicApp = .demo
    @Published private(set) var sourceStatus = ""
    @Published private(set) var canControlPlayback = false
    @Published private(set) var canSeek = false
    @Published private(set) var canRequestAuthorization = true
    @Published private(set) var isConnecting = false
    private var isActive = false
    private var connectionEnabled = true
    private var runID: UUID?
    private let onSurfaceUpdate: ((PlaybackSnapshot, LyricsState, SynchronizedLyricsState, TimeInterval) -> Void)?
    private let playback: PlaybackCoordinator
    private let lyrics: LyricsCoordinator
    @Published private(set) var synchronizedLyrics: SynchronizedLyricsState = .unavailable
    @Published private(set) var synchronizationOffset: TimeInterval = 0
    @Published private(set) var importError: String?
    @Published private(set) var isImporting = false
    private var engine = LyricsSyncEngine()
    private var importID: UUID?
    private var loadedTrackKey: LyricsTrackKey?
    private var request: Task<Void, Never>?
    private var observation: Task<Void, Never>?

    init(source: any MusicSource, provider: any LyricsProvider,
         onSurfaceUpdate: ((PlaybackSnapshot, LyricsState, SynchronizedLyricsState, TimeInterval) -> Void)? = nil) {
        self.onSurfaceUpdate = onSurfaceUpdate
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
        observeSource()
        defer {
            if runID == identifier {
                runID = nil
                isActive = false
                playback.source.deactivate()
                observation?.cancel(); observation = nil
                request?.cancel(); request = nil; loadedTrackKey = nil
            }
        }
        while !Task.isCancelled && runID == identifier {
            refresh()
            do { try await Task.sleep(for: .milliseconds(100)) } catch { break }
        }
    }

    private func observeSource() {
        observation?.cancel()
        let source = playback.source
        let events = source.events()
        observation = Task { [weak self] in
            for await _ in events {
                guard !Task.isCancelled, let self, self.playback.source === source else { return }
                self.refresh()
            }
        }
    }

    private func refresh() {
        defer { updateSynchronization() }
        let latest = playback.snapshot()
        // In particular, a new capture date alone must not redraw paused lyrics.
        if snapshot.track != latest.track || snapshot.state != latest.state || snapshot.position != latest.position ||
            snapshot.playbackRate != latest.playbackRate || snapshot.artworkData != latest.artworkData {
            snapshot = latest
        }
        let source = playback.source
        if sourceStatus != source.statusMessage { sourceStatus = source.statusMessage }
        if canControlPlayback != source.canControlPlayback { canControlPlayback = source.canControlPlayback }
        if canSeek != source.canSeek { canSeek = source.canSeek }
        if canRequestAuthorization != source.canRequestAuthorization { canRequestAuthorization = source.canRequestAuthorization }
        if snapshot.track.map(LyricsTrackKey.init) != loadedTrackKey {
            request?.cancel()
            importID = nil; isImporting = false; importError = nil
            loadedTrackKey = snapshot.track.map(LyricsTrackKey.init)
            activeLineID = nil
            lyricsMatch = nil
            engine.load(document: nil, for: snapshot.track)
            synchronizedLyrics = .unavailable
            guard let track = snapshot.track else { lyricsState = .idle; return }
            guard playback.source.allowsLyrics else {
                lyricsState = .unavailable(reason: "Lyrics are unavailable for Spotify in this app because synchronization is restricted by Spotify policy.")
                return
            }
            lyricsState = .loading
            request = Task { [weak self] in
                guard let self else { return }
                do {
                    let match = try await lyrics.match(for: track)
                    let document = match?.document
                    guard !Task.isCancelled, loadedTrackKey == LyricsTrackKey(track) else { return }
                    if let document, !document.lines.isEmpty {
                        engine.load(document: document, for: track)
                        lyricsMatch = match
                        lyricsState = .available(document)
                        updateSynchronization()
                    }
                    else { lyricsState = .unavailable(reason: "No lyrics found for this track.") }
                } catch {
                    guard !Task.isCancelled, loadedTrackKey == LyricsTrackKey(track) else { return }
                    lyricsState = .failed(message: error.localizedDescription)
                }
            }
        }
    }

    private func updateSynchronization() {
        defer { onSurfaceUpdate?(snapshot, lyricsState, synchronizedLyrics, synchronizationOffset) }
        if case .available = lyricsState {
            // Providers already return a fresh position. Do not extrapolate stale adapter state.
            engine.update(playback: snapshot, at: snapshot.lastUpdatedAt, offset: synchronizationOffset)
            if synchronizedLyrics != engine.state { synchronizedLyrics = engine.state }
            let id = engine.state.currentLine?.id
            if activeLineID != id { activeLineID = id }
        } else {
            if activeLineID != nil { activeLineID = nil }
            if synchronizedLyrics != .unavailable { synchronizedLyrics = .unavailable }
        }
    }

    func selectSource(_ source: any MusicSource) {
        request?.cancel()
        importID = nil; isImporting = false; importError = nil
        request = nil
        loadedTrackKey = nil
        activeLineID = nil
        lyricsState = .idle
        lyricsMatch = nil
        engine.load(document: nil, for: nil)
        synchronizedLyrics = .unavailable
        playback.replaceSource(source)
        selectedMusicApp = source.kind
        connectionEnabled = true
        if isActive { source.activate(); observeSource() }
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
        importID = nil; isImporting = false; importError = nil
        request = nil
        lyricsMatch = nil
        lyricsState = .unavailable(reason: "Lyrics cache cleared. Reload to fetch lyrics again.")
        activeLineID = nil
        engine.load(document: nil, for: snapshot.track)
        synchronizedLyrics = .unavailable
        loadedTrackKey = snapshot.track.map(LyricsTrackKey.init)
        updateSynchronization()
    }

    func disconnect() async {
        connectionEnabled = false
        let source = playback.source
        source.deactivate()
        source.cancelAuthorization()
        observation?.cancel(); observation = nil
        request?.cancel()
        lyrics.clearCache()
        lyricsState = .idle
        lyricsMatch = nil
        activeLineID = nil
        loadedTrackKey = nil
        refresh()
        await source.disconnect()
        if playback.source === source { refresh() }
    }

    func pausePlayback() {
        if playback.source.canControlPlayback && playback.snapshot().state == .playing { playback.source.togglePlayback() }
        refresh()
    }

    func togglePlayback() { guard canControlPlayback else { return }; playback.source.togglePlayback(); refresh() }
    func seek(to position: TimeInterval) { guard canSeek else { return }; playback.source.seek(to: position); refresh() }
    func retry() { importID = nil; isImporting = false; loadedTrackKey = nil; refresh() }

    func setSynchronizationOffset(_ value: TimeInterval) {
        guard value.isFinite else { return }
        let bounded = min(10, max(-10, value))
        guard bounded != synchronizationOffset else { return }
        synchronizationOffset = bounded
        updateSynchronization()
    }

    func setDemoPlaybackRate(_ value: Double) {
        guard let demo = playback.source as? MockMusicSource else { return }
        demo.setPlaybackRate(value)
        refresh()
    }

    func importLyrics(from url: URL) async {
        guard let track = snapshot.track, playback.source.allowsLyrics else { return }
        let token = UUID()
        importID = token
        isImporting = true
        importError = nil
        request?.cancel()
        defer { if importID == token { isImporting = false } }
        do {
            let document = try await lyrics.imports.importFile(url, for: track)
            guard importID == token, snapshot.track?.identity == track.identity, !Task.isCancelled else { return }
            engine.load(document: document, for: track)
            lyricsMatch = LyricsMatch(document: document, confidence: 1, source: "User-imported LRC (bound to this track)")
            lyricsState = .available(document)
            updateSynchronization()
        } catch {
            guard importID == token, snapshot.track?.identity == track.identity else { return }
            if case .loading = lyricsState { retry() }
            importError = error.localizedDescription
        }
    }

    func reportImportError(_ message: String) { importError = message }

    func removeImportedLyrics() async {
        guard let track = snapshot.track else { return }
        importID = nil; isImporting = false
        let identity = lyricsMatch?.sourceTrackIdentity ?? track.identity
        await lyrics.imports.remove(identity: identity)
        guard snapshot.track?.identity == track.identity else { return }
        lyrics.clearCache()
        retry()
    }
}
