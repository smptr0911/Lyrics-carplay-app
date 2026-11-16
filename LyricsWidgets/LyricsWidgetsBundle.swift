import SwiftUI
import WidgetKit

@main
struct LyricsWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LyricsWidget()
        if #available(iOS 18.0, *) {
            SmallFamilyLyricsLiveActivity()
        } else {
            LyricsLiveActivity()
        }
    }
}
