import Foundation

struct LyricsCandidate: Sendable {
    let track: Track
    let document: LyricsDocument
    let source: String
}

struct LyricsMatch: Sendable {
    let document: LyricsDocument
    let confidence: Double
    let source: String
    let sourceTrackIdentity: String?
    init(document: LyricsDocument, confidence: Double, source: String, sourceTrackIdentity: String? = nil) {
        self.document = document; self.confidence = confidence; self.source = source; self.sourceTrackIdentity = sourceTrackIdentity
    }
}

struct LyricsTrackKey: Equatable, Sendable {
    let identity: String
    let title: String
    let artist: String
    let album: String?
    let duration: Double?
    init(_ track: Track) {
        identity = track.identity; title = track.title; artist = track.artist; album = track.album
        duration = track.duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
    }
    var cacheKey: String {
        LyricLine.stableID(namespace: "lyrics-match", value: "\(identity.utf8.count):\(identity)|\(title.utf8.count):\(title)|\(artist.utf8.count):\(artist)|\(album ?? "")|\(duration.map { String($0) } ?? "nil")").uuidString
    }
}

enum LyricsMatchResult: Sendable {
    case matched(LyricsMatch)
    case unavailable(reason: String)
}

protocol LyricsCatalog: Sendable {
    func candidates(for track: Track) async throws -> [LyricsCandidate]
}

/// Metadata-based selection is independent of the sync engine and provider networking.
struct LyricsMatchingService: Sendable {
    func match(_ track: Track, candidates: [LyricsCandidate]) -> LyricsMatchResult {
        let exact = candidates.filter { $0.track.identity == track.identity && TrackMatcher().matches(track, $0.track) }
        if exact.count == 1, let candidate = exact.first {
            return .matched(LyricsMatch(document: candidate.document, confidence: 1, source: candidate.source, sourceTrackIdentity: candidate.track.identity))
        }
        if exact.count > 1 { return .unavailable(reason: "Multiple documents are bound to this track.") }
        let ranked = candidates.compactMap { candidate -> (LyricsCandidate, Double)? in
            let score = TrackMatcher().assessment(track, candidate.track).confidence
            guard score > 0 else { return nil }
            // An explicitly bound import needs no speculative cross-provider matching.
            guard score >= 0.99 else { return nil } // Cross-provider matches need title, artist, album AND duration.
            return (candidate, score)
        }.sorted { $0.1 > $1.1 }
        guard let first = ranked.first else { return .unavailable(reason: "No confident local lyrics match.") }
        if ranked.count > 1 && abs(first.1 - ranked[1].1) < 0.01 {
            return .unavailable(reason: "Multiple lyric versions match. Import the correct LRC for this track.")
        }
        return .matched(LyricsMatch(document: first.0.document, confidence: first.1, source: first.0.source, sourceTrackIdentity: first.0.track.identity))
    }
}
