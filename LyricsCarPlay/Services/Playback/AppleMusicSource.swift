import Foundation
import MusicKit

@MainActor
final class AppleMusicSource: MusicSource {
    let kind: MusicApp = .appleMusic
    private var selected = false
    private var playbackError: String?
    private var command: Task<Void, Never>?
    private var player: SystemMusicPlayer { .shared }

    var authorization: MusicAuthorization {
        switch MusicKit.MusicAuthorization.currentStatus {
        case .authorized: return .authorized
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }
    var statusMessage: String {
        if let playbackError { return playbackError }
        switch authorization {
        case .notDetermined: return "Authorize Apple Music to read its playback."
        case .denied: return "Apple Music access is denied. You can change access in app settings."
        case .authorized:
            return snapshot().track == nil ? "Play a song in Apple Music, then return here." : "Apple Music connected."
        }
    }
    var canControlPlayback: Bool { selected && authorization == .authorized && snapshot().track != nil && command == nil }
    var canSeek: Bool { canControlPlayback && snapshot().track?.duration != nil }

    func requestAuthorization() async -> MusicAuthorization {
        _ = await MusicKit.MusicAuthorization.request()
        playbackError = nil
        return authorization
    }

    func snapshot() -> PlaybackSnapshot {
        guard selected, authorization == .authorized,
              let item = player.queue.currentEntry?.item, case .song(let song) = item else {
            return PlaybackSnapshot(track: nil, state: .stopped, position: nil)
        }
        let track = Track(id: "appleMusic:\(song.id.rawValue)", title: song.title, artist: song.artistName,
                          album: song.albumTitle, duration: song.duration,
                          artworkURL: song.artwork?.url(width: 400, height: 400), source: "Apple Music")
        let state: PlaybackState
        switch player.state.playbackStatus {
        case .playing: state = .playing
        case .paused, .interrupted: state = .paused
        default: state = .stopped
        }
        let time = player.playbackTime
        return PlaybackSnapshot(track: track, state: state, position: time.isFinite && time >= 0 ? time : nil)
    }

    func togglePlayback() {
        guard canControlPlayback else { return }
        playbackError = nil
        if player.state.playbackStatus == .playing { player.pause(); return }
        command = Task { [weak self] in
            guard let self else { return }
            defer { command = nil }
            do { try await player.play() }
            catch { if selected && !Task.isCancelled { playbackError = "Apple Music could not start playback. Check your account and connection." } }
        }
    }

    func seek(to position: TimeInterval) {
        guard canSeek, position.isFinite, let duration = snapshot().track?.duration else { return }
        player.playbackTime = min(max(0, position), duration)
    }
    func activate() { selected = true }
    func deactivate() { selected = false; command?.cancel(); command = nil }
}
