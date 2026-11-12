import Foundation

struct VideoSource: Equatable {
    let url: URL

    init?(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              let url = components.url else { return nil }
        self.url = url
    }
}
