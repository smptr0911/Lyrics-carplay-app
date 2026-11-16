import Foundation

enum SurfacePlaybackState: String, Codable, Hashable, Sendable { case playing, paused, stopped }
enum LyricsSurfaceStatus: String, Codable, Hashable, Sendable { case ready, loading, unavailable, suspended, stale }

/// A bounded, expiring snapshot, never a promise of live playback or background execution.
struct SharedLyricsSnapshot: Codable, Hashable, Sendable {
    static let widgetKind = "LyricsWidget"
    let schemaVersion: Int
    let trackID: String?
    let title: String
    let artist: String
    let lyricLine: String?
    let attribution: String?
    let playbackState: SurfacePlaybackState
    let playbackPosition: TimeInterval?
    let playbackRate: Double
    let synchronizationOffset: TimeInterval
    let status: LyricsSurfaceStatus
    let message: String
    let updatedAt: Date
    let expiresAt: Date

    init(trackID: String? = nil, title: String = "Lyrics", artist: String = "", lyricLine: String? = nil,
         attribution: String? = nil, playbackState: SurfacePlaybackState = .stopped,
         playbackPosition: TimeInterval? = nil, playbackRate: Double = 1, synchronizationOffset: TimeInterval = 0,
         status: LyricsSurfaceStatus = .unavailable,
         message: String = "Open the iPhone app", updatedAt: Date, expiresAt: Date) {
        schemaVersion = 1
        self.trackID = trackID.map { Self.bounded($0, bytes: 160) }
        self.title = Self.bounded(title, bytes: 240)
        self.artist = Self.bounded(artist, bytes: 160)
        self.lyricLine = lyricLine.map { Self.bounded($0, bytes: 600) }
        self.attribution = attribution.map { Self.bounded($0, bytes: 160) }
        self.playbackState = playbackState
        self.playbackPosition = playbackPosition.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        self.playbackRate = playbackRate.isFinite && playbackRate >= 0 ? playbackRate : 0
        self.synchronizationOffset = synchronizationOffset.isFinite ? synchronizationOffset : 0
        self.status = status
        self.message = Self.bounded(message, bytes: 160)
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
    }

    private static func bounded(_ text: String, bytes: Int) -> String {
        var result = ""
        var count = 0
        for scalar in text.unicodeScalars {
            let part = CharacterSet.controlCharacters.contains(scalar) ? " " : String(scalar)
            let size = part.utf8.count
            guard count + size <= bytes else { break }
            result.append(contentsOf: part)
            count += size
        }
        return result
    }

    func redacted(status: LyricsSurfaceStatus, message: String, at date: Date) -> Self {
        Self(trackID: trackID, title: title, artist: artist, playbackState: playbackState,
             playbackPosition: playbackPosition, playbackRate: playbackRate, synchronizationOffset: synchronizationOffset,
             status: status, message: message,
             updatedAt: updatedAt, expiresAt: date)
    }

    func presentation(at date: Date) -> Self {
        guard status != .suspended, status != .stale else { return self }
        guard date >= updatedAt, date < expiresAt else {
            return redacted(status: .stale, message: "Open iPhone to refresh", at: date)
        }
        return self
    }

    /// Capture dates, position and freshness alone do not constitute a content change.
    func hasSameContent(as other: Self) -> Bool {
        trackID == other.trackID && title == other.title && artist == other.artist &&
        lyricLine == other.lyricLine && attribution == other.attribution &&
        playbackState == other.playbackState && playbackRate == other.playbackRate &&
        synchronizationOffset == other.synchronizationOffset && status == other.status && message == other.message
    }

    static func unavailable(at date: Date, message: String = "Open the iPhone app") -> Self {
        Self(message: message, updatedAt: date, expiresAt: date.addingTimeInterval(30))
    }

    static func demo(at date: Date) -> Self {
        Self(trackID: "demo:open-road", title: "Open Road", artist: "Lyrics CarPlay Demo",
             lyricLine: "Morning light across the sky", attribution: "Original demo lyrics",
             playbackState: .playing, status: .ready, message: "Best effort",
             updatedAt: date, expiresAt: date.addingTimeInterval(5))
    }
}
