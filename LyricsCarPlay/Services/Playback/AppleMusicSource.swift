import Combine
import Foundation
import MediaPlayer
import MusicKit
import UIKit

@MainActor
final class AppleMusicSource: MusicProvider {
    let kind: MusicApp = .appleMusic
    let capabilities = MusicProviderCapabilities.appleMusic
    private var selected = false
    private let player = MPMusicPlayerController.systemMusicPlayer
    private let changes = MusicProviderEvents()
    private var subscriptions = Set<AnyCancellable>()
    private var track: Track?
    private var artwork: Data?

    var authorization: MusicAuthorization {
        switch MusicKit.MusicAuthorization.currentStatus {
        case .authorized:
            switch MPMediaLibrary.authorizationStatus() {
            case .authorized: return .authorized
            case .notDetermined: return .notDetermined
            default: return .denied
            }
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }
    var statusMessage: String {
        switch authorization {
        case .notDetermined: return "Authorize Apple Music and media-library access to read supported system-player items."
        case .denied: return "Apple Music/media-library permission is denied. Change access in iOS Settings or use Demo."
        case .authorized:
            return track == nil ? "No readable Music item is exposed. Play a supported item in Music, then return here, or use Demo. Some Music content, including Home Sharing, has no public metadata." : "Apple system music player. Position is sampled while this app is active; lyrics require a separate permitted source."
        }
    }
    var canControlPlayback: Bool { selected && authorization == .authorized && track != nil }
    var canSeek: Bool { canControlPlayback && track?.duration != nil }

    func requestAuthorization() async -> MusicAuthorization {
        _ = await MusicKit.MusicAuthorization.request()
        if MusicKit.MusicAuthorization.currentStatus == .authorized && MPMediaLibrary.authorizationStatus() == .notDetermined {
            _ = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                MPMediaLibrary.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
            }
        }
        if selected { refreshMetadata() }
        return authorization
    }

    func events() -> AsyncStream<MusicProviderEvent> { changes.stream() }
    func snapshot() -> PlaybackSnapshot {
        guard selected, authorization == .authorized else { return PlaybackSnapshot(track: nil, state: .stopped, position: nil) }
        let state: PlaybackState
        let transport = player.playbackState
        switch transport {
        case .playing: state = .playing
        case .paused, .interrupted, .seekingBackward, .seekingForward: state = .paused
        default: state = .stopped
        }
        let raw = player.currentPlaybackTime
        let seeking = transport == .seekingBackward || transport == .seekingForward
        let position: TimeInterval? = !seeking && track != nil && raw.isFinite && raw >= 0 ? raw : nil
        let rate = Double(player.currentPlaybackRate)
        return PlaybackSnapshot(track: track, state: state, position: position, artworkData: artwork,
            playbackRate: rate.isFinite && rate >= 0 ? rate : 1)
    }

    func activate() {
        guard !selected else { return }
        selected = true
        for name in [Notification.Name.MPMusicPlayerControllerNowPlayingItemDidChange, .MPMusicPlayerControllerPlaybackStateDidChange] {
            NotificationCenter.default.publisher(for: name, object: player)
                .sink { [weak self] _ in Task { @MainActor in self?.refreshMetadata() } }
                .store(in: &subscriptions)
        }
        player.beginGeneratingPlaybackNotifications()
        refreshMetadata()
    }

    func deactivate() {
        guard selected else { return }
        selected = false
        subscriptions.removeAll()
        player.endGeneratingPlaybackNotifications()
        track = nil; artwork = nil
    }

    private func refreshMetadata() {
        guard selected else { return }
        guard authorization == .authorized, let item = player.nowPlayingItem else {
            track = nil; artwork = nil; changes.publish(snapshot()); return
        }
        let title = item.title ?? "Unknown title", artist = item.artist ?? "Unknown artist"
        let identifier: String
        if !item.playbackStoreID.isEmpty && item.playbackStoreID != "0" { identifier = "appleMusic:catalog:\(item.playbackStoreID)" }
        else if item.persistentID != 0 { identifier = "appleMusic:library:\(item.persistentID)" }
        else {
            identifier = "appleMusic:item:" + LyricLine.stableID(namespace: "media-player", value: "\(title)|\(artist)|\(item.albumTitle ?? "")|\(item.playbackDuration)").uuidString
        }
        let next = Track(id: identifier, title: title, artist: artist, album: item.albumTitle,
            duration: item.playbackDuration.isFinite && item.playbackDuration > 0 ? item.playbackDuration : nil,
            artworkURL: nil, source: "Apple Music", providerIdentifier: "appleMusic")
        if track != next || artwork == nil {
            artwork = item.artwork?.image(at: CGSize(width: 400, height: 400))?.jpegData(compressionQuality: 0.8)
            if (artwork?.count ?? 0) > 1_000_000 { artwork = nil }
        }
        track = next
        changes.publish(snapshot())
    }

    func togglePlayback() {
        guard canControlPlayback else { return }
        if player.playbackState == .playing { player.pause() } else { player.play() }
    }
    func seek(to position: TimeInterval) {
        guard canSeek, position.isFinite, let duration = track?.duration else { return }
        player.currentPlaybackTime = min(duration, max(0, position))
        changes.publish(snapshot())
    }
}
