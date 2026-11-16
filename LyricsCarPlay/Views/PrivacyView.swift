import SwiftUI

struct PrivacyView: View {
    var body: some View {
        List {
            Section("On this device") {
                Text("Your music-app choice, theme, and welcome-screen preference are saved on this device.")
                Text("Provider-permitted lyrics are cached in memory. Imports stay in memory until removed or the app exits. You can clear the lyrics cache in Settings.")
                Text("For widgets and Live Activities, the latest song metadata and explicitly permitted lyric snapshot can be saved on this device and sent to system displays. Expired text is hidden; stored payload cleanup may happen later. Original demo lyrics permit this sharing.")
                Text("Spotify Web API access and refresh tokens are stored in this device's protected Keychain. They are not shared with widgets. Entered video URLs are not saved.")
            }
            Section("External connections") {
                Text("Connecting Spotify or Apple Music uses those services and their account permissions. Video playback contacts the video host you choose. A configured lyrics service receives track identifiers for permitted sources.")
                Text("This app does not include advertising or analytics. External services and system media buffering have their own data handling.")
            }
            Section("Your controls") {
                Text("Disconnect in Settings removes this app's stored Spotify Web API credentials; storage errors are reported. It does not revoke account-wide authorization. Manage that with Spotify itself.")
                Text("Apple Music permission can be changed in iOS app settings. Deleting this app removes its local preferences.")
            }
        }.navigationTitle("Privacy and data")
    }
}
