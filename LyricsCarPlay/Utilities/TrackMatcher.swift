import Foundation

struct TrackMatchAssessment: Equatable, Sendable {
    let confidence: Double
    let reason: String
}

struct TrackMatcher {
    func matches(_ lhs: Track, _ rhs: Track) -> Bool { assessment(lhs, rhs).confidence > 0 }

    func assessment(_ lhs: Track, _ rhs: Track) -> TrackMatchAssessment {
        let title = normalized(lhs.title), artist = normalized(lhs.artist)
        guard !title.isEmpty, !artist.isEmpty, title != "unknown title", artist != "unknown artist",
              title == normalized(rhs.title), artist == normalized(rhs.artist) else {
            return TrackMatchAssessment(confidence: 0, reason: "Title, artist or version differs.")
        }
        // Preserve every version descriptor: live/acoustic/remix/instrumental are never stripped.
        var score = 0.8
        if let a = lhs.duration, let b = rhs.duration {
            guard a.isFinite, b.isFinite, a > 0, b > 0, abs(a - b) <= 2 else {
                return TrackMatchAssessment(confidence: 0, reason: "Duration differs or is invalid.")
            }
            score += 0.1
        }
        if let a = lhs.album, let b = rhs.album, !normalized(a).isEmpty, !normalized(b).isEmpty {
            guard normalized(a) == normalized(b) else { return TrackMatchAssessment(confidence: 0, reason: "Album/version differs.") }
            score += 0.1
        }
        return TrackMatchAssessment(confidence: min(1, score), reason: "Conservative metadata comparison.")
    }

    private func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
