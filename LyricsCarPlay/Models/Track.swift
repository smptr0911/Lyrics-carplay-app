import Foundation

struct Track: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval?
    let artworkURL: URL?
    let source: String
    let providerIdentifier: String

    init(id: String, title: String, artist: String, album: String?, duration: TimeInterval?,
         artworkURL: URL?, source: String, providerIdentifier: String? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkURL = artworkURL
        self.source = source
        self.providerIdentifier = providerIdentifier ?? (id.contains(":") ? String(id.prefix(while: { $0 != ":" })) : source)
    }

    /// Provider-qualified IDs are the cache and synchronization identity.
    var identity: String { "\(providerIdentifier):\(id)" }
}

extension Track {
    static let demo = Track(id: "demo:open-road", title: "Open Road", artist: "Lyrics CarPlay Demo",
        album: "Original demo", duration: 30, artworkURL: nil, source: "Demo")
    var spotifyURL: URL? {
        let parts = id.split(separator: ":")
        guard parts.count == 3, parts[0] == "spotify", (parts[1] == "track" || parts[1] == "episode"),
              parts[2].count == 22, parts[2].utf8.allSatisfy({ byte in
                  (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte)
              }) else { return nil }
        return URL(string: "https://open.spotify.com/\(parts[1])/\(parts[2])")
    }
}
