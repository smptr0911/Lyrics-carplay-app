import AVKit
import Combine

@MainActor
final class VideoPlayerViewModel: ObservableObject {
    @Published var urlText = ""
    @Published private(set) var player: AVPlayer?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    private var statusObservation: NSKeyValueObservation?
    private var failureObserver: AnyCancellable?
    private var interruptionObserver: AnyCancellable?
    private var routeObserver: AnyCancellable?
    private var loadingTimeout: Task<Void, Never>?

    init() {
        interruptionObserver = NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                guard raw == AVAudioSession.InterruptionType.began.rawValue else { return }
                Task { @MainActor [weak self] in self?.pause() }
            }
        routeObserver = NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] notification in
                let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                guard raw == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
                Task { @MainActor [weak self] in self?.pause() }
            }
    }

    func load() {
        stop()
        guard let source = VideoSource(text: urlText) else {
            errorMessage = "Enter a valid HTTPS video URL without embedded credentials."
            return
        }
        do {
            // Set the category without activating the session or starting playback.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch {
            errorMessage = "Unable to prepare video playback. Please try again."
            return
        }
        errorMessage = nil
        isLoading = true
        let item = AVPlayerItem(url: source.url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.allowsExternalPlayback = true
        player = newPlayer
        loadingTimeout = Task { [weak self, weak item] in
            do { try await Task.sleep(for: .seconds(30)) } catch { return }
            guard let self, let item, self.player?.currentItem === item, self.isLoading else { return }
            self.fail()
        }
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let status = item.status
            Task { @MainActor [weak self, weak item] in
                guard let self, let item, self.player?.currentItem === item else { return }
                switch status {
                case .readyToPlay:
                    self.isLoading = false
                    self.loadingTimeout?.cancel()
                    self.loadingTimeout = nil
                case .failed: self.fail()
                default: break
                }
            }
        }
        failureObserver = NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: item)
            .sink { [weak self, weak item] _ in
                Task { @MainActor in
                    guard let self, let item, self.player?.currentItem === item else { return }
                    self.fail()
                }
            }
    }

    private func fail() {
        stop()
        errorMessage = "This video could not be played. Check the connection and use a direct, supported video stream."
    }

    func pause() { player?.pause() }

    func stop() {
        loadingTimeout?.cancel()
        loadingTimeout = nil
        statusObservation = nil
        failureObserver = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        isLoading = false
        errorMessage = nil
    }
}
