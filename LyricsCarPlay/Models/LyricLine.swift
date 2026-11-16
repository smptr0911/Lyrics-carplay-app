import Foundation

struct LyricLine: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let startTime: TimeInterval?
    let endTime: TimeInterval?
    let text: String

    init(id: UUID? = nil, startTime: TimeInterval? = nil, endTime: TimeInterval? = nil, text: String) {
        self.id = id ?? Self.stableID(namespace: "line", value: "\(startTime.map { String(describing: $0) } ?? "nil")|\(endTime.map { String(describing: $0) } ?? "nil")|\(text)")
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }

    /// Deterministic non-cryptographic UUID. Providers include track and source ordinal
    /// in the namespace to distinguish repeated text/timestamps across reloads.
    static func stableID(namespace: String, value: String) -> UUID {
        let bytes = Array((namespace + "\u{0}" + value).utf8)
        func hash(seed: UInt64) -> UInt64 {
            bytes.reduce(seed) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
        }
        let a = hash(seed: 14_695_981_039_346_656_037)
        let b = hash(seed: 7_809_847_782_465_536_322)
        var output = (0..<8).map { UInt8(truncatingIfNeeded: a >> ((7 - $0) * 8)) }
        output += (0..<8).map { UInt8(truncatingIfNeeded: b >> ((7 - $0) * 8)) }
        output[6] = (output[6] & 0x0f) | 0x80
        output[8] = (output[8] & 0x3f) | 0x80
        return UUID(uuid: (output[0], output[1], output[2], output[3], output[4], output[5], output[6], output[7],
                           output[8], output[9], output[10], output[11], output[12], output[13], output[14], output[15]))
    }
}

/// A point-in-time projection for small surfaces, not a playback clock.
/// Persistence requires separate provider permission and an expiry policy.
struct LyricContext: Equatable, Codable, Sendable {
    let previous: LyricLine?
    let current: LyricLine
    let next: LyricLine?
}

struct LyricsDocument: Equatable, Codable, Sendable {
    let lines: [LyricLine]
    let attribution: String
    // nil means caching is prohibited, including in the app cache.
    let cacheUntil: Date?
    // nil prohibits sending lyric text to persisted widgets or Live Activities.
    let surfaceSharingUntil: Date?

    init(lines: [LyricLine], attribution: String, cacheUntil: Date?, surfaceSharingUntil: Date? = nil) {
        self.lines = lines
        self.attribution = attribution
        self.cacheUntil = cacheUntil
        self.surfaceSharingUntil = surfaceSharingUntil
    }
}

enum LyricsState: Equatable, Sendable {
    case idle, loading
    case available(LyricsDocument)
    case unavailable(reason: String)
    case failed(message: String)
}


enum SynchronizationStatus: String, Equatable, Codable, Sendable {
    case unavailable, untimed, positionUnavailable, waiting, gap, synchronized, paused, ended
}

struct SynchronizedLyricsState: Equatable, Codable, Sendable {
    let currentLine: LyricLine?
    let previousLine: LyricLine?
    let nextLine: LyricLine?
    let synchronizationStatus: SynchronizationStatus

    static let unavailable = SynchronizedLyricsState(currentLine: nil, previousLine: nil,
        nextLine: nil, synchronizationStatus: .unavailable)
}
