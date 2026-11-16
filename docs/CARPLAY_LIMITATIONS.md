# CarPlay limitations

Reviewed against official Apple documentation on 2026-11-16. No installed Xcode SDK is available in this Windows environment; documentation review is not an SDK compile check.

## Supported direction

Apple describes small widgets and Live Activities in CarPlay from iOS 26. Apps can offer these without implementing an entitled CarPlay template app. Live Activities use the small activity presentation, with compact Dynamic Island fallback; system settings and context control visibility. This does not permit arbitrary full-screen SwiftUI or guarantee that a lyric-heavy design is suitable. Keep text glanceable and review current design guidance.

- [Apple CarPlay overview](https://developer.apple.com/carplay/)
- [Turbocharge your app for CarPlay](https://developer.apple.com/videos/play/wwdc2025/216/)
- [Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)

## Timing and execution

WidgetKit manages timeline refreshes and budgets. The foreground app's polling interval cannot be reused as a refresh contract. ActivityKit also does not provide unrestricted background runtime or guaranteed per-line updates. Show a snapshot honestly, include expiry/staleness, and evaluate accuracy on real hardware. Do not promise continuous karaoke timing after app suspension.

- [Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)

## Music and lyrics

MusicKit playback time is public, but is not universal access to arbitrary apps' playback. Validate the existing SystemMusicPlayer adapter on device. No Apple Music or Spotify lyrics API is assumed. Production text must come from a separately authorized lyrics source with permissions for the intended surfaces. Current Spotify lyrics remain disabled pending policy review.

- [MusicPlayer playbackTime](https://developer.apple.com/documentation/musickit/musicplayer/playbacktime)

## YouTube and parked video

Apple describes AirPlay video in supported cars while not driving. Compatibility is vehicle-dependent. Our app cannot enable another app's AirPlay output, force a route, detect an authoritative parked state, or bypass system motion restrictions. Open YouTube on iPhone, use its supported AirPlay controls if available, and follow the vehicle's setup instructions. If the route or video is unavailable, this app provides guidance only. No downloading, scraping, interception, or rehosting is implemented.

Apple also documents newer CarPlay video-app capabilities; those are separate from this external YouTube guide and must not be inferred to authorize controlling YouTube.

- [CarPlay capabilities and AirPlay video](https://developer.apple.com/carplay/)
- [Rev up your CarPlay app](https://developer.apple.com/videos/play/wwdc2026/212/)

## Repository status

The existing simulator template prototype remains isolated from device builds. No new CarPlay entitlement was added. WidgetKit and ActivityKit source implementations and App Group configuration are now present. Build, signing and CarPlay rendering remain unverified. See [system surfaces and update investigation](WIDGETS_AND_LIVE_ACTIVITIES.md). The iPhone supports iOS 17; future CarPlay-specific APIs require availability checks against the chosen SDK and OS. Preserve a functional iPhone-only fallback.
