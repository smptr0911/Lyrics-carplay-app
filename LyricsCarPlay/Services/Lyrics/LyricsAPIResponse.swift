import Foundation

/// App-owned backend contract, not a claim about any third-party vendor's schema.
struct LyricsAPIResponse: Decodable {
    struct Line: Decodable {
        let startTime: TimeInterval?
        let text: String
    }
    let trackID: String
    let attribution: String
    let lines: [Line]
    let cacheUntil: Date?

    func document(for track: Track) throws -> LyricsDocument {
        guard trackID == track.id,
              !attribution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              lines.allSatisfy({ line in
                  !line.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                  (line.startTime.map { $0.isFinite && $0 >= 0 } ?? true)
              }) else { throw LyricsProviderError.invalidResponse }
        let ordered: [Line]
        if lines.allSatisfy({ $0.startTime != nil }) {
            ordered = lines.enumerated().sorted {
                let a = $0.element.startTime!, b = $1.element.startTime!
                return a == b ? $0.offset < $1.offset : a < b
            }.map(\.element)
        } else {
            ordered = lines
        }
        return LyricsDocument(lines: ordered.map { LyricLine(startTime: $0.startTime, text: $0.text) },
                              attribution: attribution, cacheUntil: cacheUntil)
    }
}

enum LyricsProviderError: LocalizedError, Equatable {
    case invalidResponse, authorizationRequired, rateLimited, serverFailure, networkUnavailable
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "The lyrics service returned an invalid response."
        case .authorizationRequired: return "The lyrics service requires authorization."
        case .rateLimited: return "Too many requests. Please try again later."
        case .networkUnavailable: return "The lyrics service could not be reached. Check your connection and try again."
        case .serverFailure: return "The lyrics service is unavailable. Please try again later."
        }
    }
}
