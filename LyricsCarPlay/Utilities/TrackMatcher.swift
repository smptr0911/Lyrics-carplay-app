import Foundation

struct TrackMatcher {
    func matches(_ lhs: Track, _ rhs: Track) -> Bool {
        guard normalized(lhs.title) == normalized(rhs.title),
              normalized(lhs.artist) == normalized(rhs.artist) else { return false }
        if let a = lhs.duration, let b = rhs.duration { return abs(a - b) <= 2 }
        return true
    }
    private func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
