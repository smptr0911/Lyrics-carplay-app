import Foundation

struct LyricsSurfaceProjection {
    func snapshot(playback: PlaybackSnapshot, lyrics: LyricsState, synchronized: SynchronizedLyricsState,
                  offset: TimeInterval, at now: Date) -> SharedLyricsSnapshot {
        guard let track = playback.track else { return .unavailable(at: now) }
        var line: String?
        var attribution: String?
        var status: LyricsSurfaceStatus = .unavailable
        var message = "Lyrics unavailable"
        var expiry = now.addingTimeInterval(30)
        switch lyrics {
        case .loading: status = .loading; message = "Loading lyrics"
        case .available(let document):
            // Permission for disk-backed system surfaces is separate from foreground display/cache rights.
            if let permission = document.surfaceSharingUntil, permission > now {
                expiry = min(expiry, permission)
                if let current = synchronized.currentLine {
                    line = current.text.isEmpty ? "Instrumental" : current.text
                    attribution = document.attribution
                    status = .ready
                    message = playback.isPlaying ? "Best effort" : "Paused"
                    if playback.isPlaying, playback.playbackRate > 0, let position = playback.position {
                        let end = [current.endTime, synchronized.nextLine?.startTime].compactMap { $0 }.min()
                        if let end { expiry = min(expiry, now.addingTimeInterval(max(0, (end - position - offset) / playback.playbackRate))) }
                        if let duration = track.duration, duration.isFinite {
                            expiry = min(expiry, now.addingTimeInterval(max(0, (duration - position) / playback.playbackRate)))
                        }
                    }
                } else {
                    switch synchronized.synchronizationStatus {
                    case .waiting: message = "Lyrics begin soon"
                    case .gap: message = "Instrumental"
                    case .ended: message = "Track ended"
                    case .untimed: message = "Timed lyrics unavailable"
                    default: message = "Playback timing unavailable"
                    }
                }
            } else { message = "Lyrics sharing unavailable" }
        default: break
        }
        return SharedLyricsSnapshot(trackID: LyricLine.stableID(namespace: "surface", value: track.identity).uuidString,
            title: track.title, artist: track.artist, lyricLine: line, attribution: attribution,
            playbackState: SurfacePlaybackState(rawValue: playback.state.rawValue) ?? .stopped,
            playbackPosition: playback.position, playbackRate: playback.playbackRate, synchronizationOffset: offset,
            status: status, message: message, updatedAt: now, expiresAt: expiry)
    }
}

/// App policy, not an Apple refresh entitlement. Caller keeps a coalesced latest value.
struct LyricsSurfaceUpdatePolicy {
    var lastSaved: SharedLyricsSnapshot?
    var lastReloadAt: Date?
    func shouldSave(_ snapshot: SharedLyricsSnapshot) -> Bool {
        guard let lastSaved else { return true }
        if snapshot.updatedAt < lastSaved.updatedAt { return true }
        if let before = lastSaved.playbackPosition, let after = snapshot.playbackPosition {
            let elapsed = max(0, snapshot.updatedAt.timeIntervalSince(lastSaved.updatedAt))
            let expected = before + (lastSaved.playbackState == .playing ? elapsed * lastSaved.playbackRate : 0)
            if abs(after - expected) > 0.25 { return true }
        }
        return !snapshot.hasSameContent(as: lastSaved) || snapshot.updatedAt.timeIntervalSince(lastSaved.updatedAt) >= 10
    }
    func shouldReloadWidget(_ snapshot: SharedLyricsSnapshot, at now: Date) -> Bool {
        guard let lastSaved, let lastReloadAt else { return true }
        if now < lastReloadAt { return true }
        let transition = snapshot.trackID != lastSaved.trackID || snapshot.playbackState != lastSaved.playbackState || snapshot.status != lastSaved.status
        return transition || now.timeIntervalSince(lastReloadAt) >= 60
    }
}
