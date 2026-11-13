import Foundation

struct LyricLine: Identifiable, Equatable, Sendable {
    let id: UUID
    let startTime: TimeInterval?
    let text: String

    init(id: UUID = UUID(), startTime: TimeInterval? = nil, text: String) {
        self.id = id
        self.startTime = startTime
        self.text = text
    }
}

struct LyricsDocument: Sendable {
    let lines: [LyricLine]
    let attribution: String
    // nil means caching is prohibited, including in the app cache.
    let cacheUntil: Date?
}

enum LyricsState {
    case idle, loading
    case available(LyricsDocument)
    case unavailable(reason: String)
    case failed(message: String)
}
