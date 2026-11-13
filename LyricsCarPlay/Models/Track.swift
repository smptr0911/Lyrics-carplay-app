import Foundation

struct Track: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval?
    let artworkURL: URL?
    let source: String
}

extension Track {
    var spotifyURL: URL? {
        let parts = id.split(separator: ":")
        guard parts.count == 3, parts[0] == "spotify", (parts[1] == "track" || parts[1] == "episode"),
              parts[2].count == 22, parts[2].utf8.allSatisfy({ byte in
                  (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte)
              }) else { return nil }
        return URL(string: "https://open.spotify.com/\(parts[1])/\(parts[2])")
    }
}
