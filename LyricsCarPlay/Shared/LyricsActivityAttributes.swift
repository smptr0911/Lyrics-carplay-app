import ActivityKit
import Foundation

struct LyricsActivityAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        let snapshot: SharedLyricsSnapshot
    }
    let sessionID: UUID
}
