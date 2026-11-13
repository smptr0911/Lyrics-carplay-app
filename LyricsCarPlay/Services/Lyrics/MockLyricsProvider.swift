import Foundation

struct MockLyricsProvider: LyricsProvider {
    func lyrics(for track: Track) async throws -> LyricsDocument? {
        guard track.id == "demo:open-road" else { return nil }
        return LyricsDocument(lines: [
            LyricLine(startTime: 0, text: "Morning light across the sky"),
            LyricLine(startTime: 5, text: "Clouds like paper drifting by"),
            LyricLine(startTime: 10, text: "Every mile a brand new day"),
            LyricLine(startTime: 15, text: "Hear the rhythm lead the way"),
            LyricLine(startTime: 20, text: "Let the quiet melody flow"),
            LyricLine(startTime: 25, text: "There is room for us to grow")
        ], attribution: "Original demonstration lyrics created for this project.", cacheUntil: nil)
    }
}
