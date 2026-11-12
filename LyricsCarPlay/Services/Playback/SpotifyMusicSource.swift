import Foundation
import UIKit
import SpotifyiOS

@MainActor
final class SpotifyMusicSource: NSObject, MusicSource {
    let kind: MusicApp = .spotify
    private(set) var authorization: MusicAuthorization = .notDetermined
    private(set) var statusMessage = "Connect Spotify to see the current track."
    private var current = PlaybackSnapshot(track: nil, state: .stopped, position: nil)
    private var seekAllowed = false
    private var selected = false
    private var awaitingCallback = false
    private var authorizationStartedAt: Date?
    private var remote: SPTAppRemote?

    var canControlPlayback: Bool { selected && remote?.isConnected == true && current.track != nil }
    var canSeek: Bool { canControlPlayback && seekAllowed }

    override init() {
        super.init()
        guard let configuration = SpotifyConfiguration() else {
            statusMessage = "Spotify connection is not configured in this build."
            return
        }
        let settings = SPTConfiguration(clientID: configuration.clientID, redirectURL: SpotifyConfiguration.redirectURL)
        let remote = SPTAppRemote(configuration: settings, logLevel: .none)
        remote.delegate = self
        self.remote = remote
    }

    func requestAuthorization() async -> MusicAuthorization {
        guard selected, let remote else { return authorization }
        #if targetEnvironment(simulator)
        statusMessage = "Spotify requires an iPhone with the Spotify app installed. Choose Demo in the simulator."
        return authorization
        #else
        guard UIApplication.shared.canOpenURL(URL(string: "spotify:")!) else {
            statusMessage = "Install Spotify and sign in, then try connecting again."
            return authorization
        }
        awaitingCallback = true
        authorizationStartedAt = Date()
        statusMessage = "Opening Spotify. This may resume your last track."
        remote.authorizeAndPlayURI("") { [weak self] available in
            guard let self, self.awaitingCallback else { return }
            if !available {
                self.awaitingCallback = false
                self.statusMessage = "Unable to open Spotify. Please try again."
            }
        }
        return authorization
        #endif
    }

    func handleCallback(_ url: URL) {
        guard awaitingCallback, SpotifyConfiguration.acceptsCallback(url),
              let started = authorizationStartedAt, Date().timeIntervalSince(started) < 300,
              let remote else { return }
        awaitingCallback = false
        authorizationStartedAt = nil
        let parameters = remote.authorizationParameters(from: url)
        guard let token = parameters?[SPTAppRemoteAccessTokenKey], !token.isEmpty else {
            authorization = .denied
            statusMessage = "Spotify authorization was not completed. Try connecting again."
            return
        }
        // Memory only: never log or store callback URLs or access tokens in preferences.
        remote.connectionParameters.accessToken = token
        authorization = .authorized
        statusMessage = "Connecting to Spotify..."
        if selected { remote.connect() }
    }

    func activate() {
        selected = true
        if let remote, remote.connectionParameters.accessToken != nil, !remote.isConnected {
            statusMessage = "Reconnecting to Spotify..."
            remote.connect()
        }
    }

    func deactivate() {
        selected = false
        remote?.disconnect()
        current = PlaybackSnapshot(track: nil, state: .stopped, position: nil)
        seekAllowed = false
        // Preserve an in-flight authorization through the expected Spotify app switch.
    }

    func cancelAuthorization() {
        awaitingCallback = false
        authorizationStartedAt = nil
        remote?.connectionParameters.accessToken = nil
        authorization = .notDetermined
        statusMessage = "Spotify disconnected. Select Open Spotify / Resume to connect."
    }

    func snapshot() -> PlaybackSnapshot { current }

    func togglePlayback() {
        guard canControlPlayback, let player = remote?.playerAPI else { return }
        if current.state == .playing { player.pause(commandCallback) }
        else { player.resume(commandCallback) }
    }

    func seek(to position: TimeInterval) {
        guard canSeek, position.isFinite, position >= 0, let duration = current.track?.duration else { return }
        remote?.playerAPI?.seek(toPosition: Int(min(position, duration) * 1000), callback: commandCallback)
    }

    private var commandCallback: SPTAppRemoteCallback {
        { [weak self] _, error in
            guard let self, self.selected else { return }
            if error != nil { self.statusMessage = "Spotify could not complete that playback action." }
        }
    }
}

extension SpotifyMusicSource: SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        guard selected else { appRemote.disconnect(); return }
        authorization = .authorized
        statusMessage = "Spotify connected. Lyrics synchronization is unavailable for this source."
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(commandCallback)
        appRemote.playerAPI?.getPlayerState { [weak self] result, error in
            guard let self, self.selected, appRemote.isConnected else { return }
            if let state = result as? SPTAppRemotePlayerState { self.playerStateDidChange(state) }
            else if error != nil { self.statusMessage = "Unable to read Spotify playback. Reconnect to try again." }
        }
    }

    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        current = PlaybackSnapshot(track: nil, state: .stopped, position: nil)
        statusMessage = "Spotify connection failed. Select Open Spotify / Resume to reconnect."
    }

    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        current = PlaybackSnapshot(track: nil, state: .stopped, position: nil)
        seekAllowed = false
        statusMessage = "Spotify disconnected. Select Open Spotify / Resume to reconnect."
    }

    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        guard selected, remote?.isConnected == true else { return }
        let item = playerState.track
        let track = Track(id: item.uri, title: item.name, artist: item.artist.name,
                          album: item.album.name, duration: Double(item.duration) / 1000,
                          artworkURL: nil, source: "Spotify")
        seekAllowed = playerState.playbackRestrictions.canSeek
        let trackChanged = current.track?.id != track.id
        current = PlaybackSnapshot(track: track, state: playerState.isPaused ? .paused : .playing,
                                   position: Double(playerState.playbackPosition) / 1000,
                                   artworkData: trackChanged ? nil : current.artworkData)
        if trackChanged {
            remote?.imageAPI?.fetchImage(forItem: item, with: CGSize(width: 400, height: 400)) { [weak self] result, _ in
                guard let self, self.selected, self.remote?.isConnected == true,
                      self.current.track?.id == track.id, let image = result as? UIImage,
                      let data = image.jpegData(compressionQuality: 0.8), data.count <= 1_000_000 else { return }
                self.current = PlaybackSnapshot(track: self.current.track, state: self.current.state,
                                                position: self.current.position, artworkData: data)
            }
        }
        // Do not extrapolate a synthetic timestamp or use these positions for lyric sync.
    }
}
