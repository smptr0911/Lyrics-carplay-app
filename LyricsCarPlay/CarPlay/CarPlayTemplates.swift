#if targetEnvironment(simulator)
import CarPlay

@MainActor
enum CarPlayTemplates {
    static func root(selectDemo: @escaping () -> Void) -> CPListTemplate {
        let demo = CPListItem(text: "Open Road", detailText: "Lyrics CarPlay Demo")
        demo.accessoryType = .disclosureIndicator
        demo.handler = { _, completion in
            defer { completion() }
            selectDemo()
        }
        let video = CPListItem(text: "Parked video", detailText: "AirPlay on compatible vehicles; browsing not connected")
        video.isEnabled = false
        let lyrics = CPListItem(text: "Lyrics", detailText: "Available in the iPhone app")
        lyrics.isEnabled = false
        return CPListTemplate(title: "Lyrics CarPlay", sections: [
            CPListSection(items: [demo], header: "Demo library", sectionIndexTitle: nil),
            CPListSection(items: [video, lyrics], header: "Feature availability", sectionIndexTitle: nil)
        ])
    }

    static func demoTrack() -> CPListTemplate {
        let artist = CPListItem(text: "Artist", detailText: "Lyrics CarPlay Demo")
        let album = CPListItem(text: "Album", detailText: "Original demo")
        let playback = CPListItem(text: "Preview only", detailText: "No audio or video plays from this screen")
        for item in [artist, album, playback] { item.isEnabled = false }
        return CPListTemplate(title: "Open Road", sections: [CPListSection(items: [artist, album, playback])])
    }
}
#endif
