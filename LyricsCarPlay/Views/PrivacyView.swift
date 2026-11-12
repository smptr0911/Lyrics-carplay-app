import SwiftUI

struct PrivacyView: View {
    var body: some View {
        List {
            Section("On this device") {
                Text("Your music-app choice, theme, and welcome-screen preference are saved on this device.")
                Text("Lyrics are kept in memory only when the provider permits caching. You can clear this cache in Settings.")
                Text("Spotify connection tokens and entered video URLs are not saved by this app. Reconnect Spotify after restarting the app.")
            }
            Section("External connections") {
                Text("Connecting Spotify or Apple Music uses those services and their account permissions. Video playback contacts the video host you choose. A configured lyrics service receives track identifiers for permitted sources.")
                Text("This app does not include advertising or analytics. External services and system media buffering have their own data handling.")
            }
            Section("Your controls") {
                Text("Disconnect in Settings to clear the current app connection. This does not revoke the music service's account-wide authorization; manage that with the service itself.")
                Text("Apple Music permission can be changed in iOS app settings. Deleting this app removes its local preferences.")
            }
        }.navigationTitle("Privacy and data")
    }
}
