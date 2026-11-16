import Combine
import UIKit

@MainActor
protocol ExternalURLOpening {
    func open(_ url: URL, universalLinksOnly: Bool) async -> Bool
}

@MainActor
struct SystemExternalURLOpener: ExternalURLOpening {
    func open(_ url: URL, universalLinksOnly: Bool) async -> Bool {
        await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: universalLinksOnly ? [.universalLinksOnly: true] : [:]) {
                continuation.resume(returning: $0)
            }
        }
    }
}

@MainActor
final class AirPlayHelpViewModel: ObservableObject {
    @Published private(set) var isOpening = false
    @Published private(set) var errorMessage: String?
    let compatibility: AirPlayCompatibilityInfo = .unknown
    static let youtubeURL = URL(string: "https://www.youtube.com/")!
    private let opener: any ExternalURLOpening

    init(opener: any ExternalURLOpening = SystemExternalURLOpener()) {
        self.opener = opener
    }

    func openYouTube() async {
        guard !isOpening else { return }
        isOpening = true
        errorMessage = nil
        defer { isOpening = false }
        // A failed universal link is not proof that YouTube is uninstalled.
        // The same public homepage can fall back to the system's web handler.
        if await opener.open(Self.youtubeURL, universalLinksOnly: true) { return }
        if await !opener.open(Self.youtubeURL, universalLinksOnly: false) {
            errorMessage = "YouTube could not be opened. Try visiting youtube.com in Safari."
        }
    }
}
