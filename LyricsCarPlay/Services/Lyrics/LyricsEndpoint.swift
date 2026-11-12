import Foundation

struct LyricsEndpoint {
    static func isAllowed(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host, !host.isEmpty, components.user == nil,
              components.password == nil, components.fragment == nil else { return false }
        if components.scheme?.lowercased() == "https" { return true }
        #if DEBUG && targetEnvironment(simulator)
        // The local development server is never accepted in device or release builds.
        return components.scheme == "http" && host == "localhost"
        #else
        return false
        #endif
    }

    static func configured(in bundle: Bundle = .main) -> URL? {
        guard let raw = bundle.object(forInfoDictionaryKey: "LyricsAPIURL") as? String,
              !raw.isEmpty, !raw.contains("$("), let url = URL(string: raw), isAllowed(url) else { return nil }
        return url
    }
}
