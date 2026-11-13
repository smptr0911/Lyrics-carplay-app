import Foundation

enum MusicApp: String, CaseIterable, Identifiable, Sendable {
    case spotify, appleMusic, demo
    var id: String { rawValue }
    var title: String {
        switch self {
        case .spotify: return "Spotify"
        case .appleMusic: return "Apple Music"
        case .demo: return "Demo"
        }
    }
}
