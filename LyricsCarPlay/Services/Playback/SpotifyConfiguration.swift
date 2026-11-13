import Foundation

struct SpotifyConfiguration {
    static let redirectURL = URL(string: "lyrics-carplay-spotify://callback")!
    let clientID: String

    init?(bundle: Bundle = .main) {
        guard let value = bundle.object(forInfoDictionaryKey: "SpotifyClientID") as? String else { return nil }
        self.init(clientID: value)
    }

    init?(clientID: String) {
        let value = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("$("), value != "YOUR_SPOTIFY_CLIENT_ID" else { return nil }
        self.clientID = value
    }

    static func acceptsCallback(_ url: URL) -> Bool {
        url.scheme == redirectURL.scheme && url.host == redirectURL.host &&
        url.path == redirectURL.path && url.user == nil && url.password == nil && url.port == nil
    }
}
