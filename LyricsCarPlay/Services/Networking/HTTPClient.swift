import Foundation

protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

private final class SameOriginRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        guard let original = task.originalRequest?.url, let next = request.url,
              original.scheme == next.scheme, original.host == next.host, original.port == next.port,
              LyricsEndpoint.isAllowed(next) else { completionHandler(nil); return }
        completionHandler(request)
    }
}

struct URLSessionHTTPClient: HTTPClient {
    enum TransportError: Error { case invalidResponse, responseTooLarge }
    private let session: URLSession
    static let maximumResponseBytes = 1_000_000

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.httpShouldSetCookies = false
        session = URLSession(configuration: configuration, delegate: SameOriginRedirectDelegate(), delegateQueue: nil)
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw TransportError.invalidResponse }
        guard response.expectedContentLength <= Int64(Self.maximumResponseBytes) else { throw TransportError.responseTooLarge }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < Self.maximumResponseBytes else { throw TransportError.responseTooLarge }
            data.append(byte)
        }
        return (data, response)
    }
}
