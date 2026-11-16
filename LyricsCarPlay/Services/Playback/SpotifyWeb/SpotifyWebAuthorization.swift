import AuthenticationServices
import Foundation
import UIKit

@MainActor
protocol SpotifyWebAuthorizing: AnyObject {
    func authorize(_ request: SpotifyAuthorizationRequest) async throws -> URL
    func cancel()
}

@available(iOS 17.4, *)
@MainActor
final class SystemSpotifyWebAuthorization: NSObject, SpotifyWebAuthorizing, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    private var continuation: CheckedContinuation<URL, Error>?
    private var anchor: ASPresentationAnchor?
    private var requestID = UUID()

    func authorize(_ request: SpotifyAuthorizationRequest) async throws -> URL {
        guard session == nil, let host = request.redirectURL.host,
              let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .filter({ $0.activationState == .foregroundActive }).flatMap(\.windows).first(where: \.isKeyWindow) else {
            throw SpotifyWebError.configuration
        }
        anchor = window
        let identifier = UUID(); requestID = identifier
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let session = ASWebAuthenticationSession(url: request.url,
                    callback: .https(host: host, path: request.redirectURL.path)) { [weak self] url, error in
                    Task { @MainActor in
                        guard let self, self.requestID == identifier else { return }
                        self.finish(url, error: error)
                    }
                }
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = true
                self.session = session
                if Task.isCancelled { cancel() }
                else if !session.start() { finish(nil, error: SpotifyWebError.configuration) }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard let self, self.requestID == identifier else { return }
                self.cancel()
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { anchor ?? ASPresentationAnchor() }
    func cancel() { session?.cancel(); finish(nil) }
    private func finish(_ url: URL?, error: Error? = nil) {
        let continuation = continuation
        requestID = UUID()
        self.continuation = nil; session = nil; anchor = nil
        if let url { continuation?.resume(returning: url) }
        else {
            let cancelled = error == nil || (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
            continuation?.resume(throwing: cancelled ? SpotifyWebError.cancelled : .configuration)
        }
    }
}
