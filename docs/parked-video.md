# Parked video via AirPlay

Added 2026-11-12. The Parked Video tab accepts a user-supplied direct HTTPS MP4/HLS URL, prepares an AVPlayer, and displays Apple's native playback controls and an AirPlay route picker. Loading does not automatically start playback. Unsupported streams and item failures show an error; users can close and reload. URLs are not stored or logged. Playback stops when leaving the tab and pauses when the app enters the background. Background/locked-phone playback is not implemented.

## Vehicle behavior and scope

Apple describes [AirPlay video in supported parked vehicles](https://developer.apple.com/videos/play/wwdc2026/212/). Select a compatible car display from the iPhone player. The car/system determines when external video is permitted and can switch to audio-only. The app does not infer parking from GPS or expose a switch that claims to override vehicle restrictions. The iPhone player itself is not a vehicle parking detector.

This implementation enables AirPlay external playback; it cannot make an unsupported vehicle accept video. Standard CarPlay compatibility alone does not establish video support. Real vehicle compatibility remains unverified.

Apple's session separately describes iOS 27 CarPlay video browsing, vehicle capability checks, and video/audio entitlements. That native head-unit browsing experience is not part of this iOS 17 / Xcode 16 app. Implement it only with the matching SDK, granted entitlement, current category rules, and device tests. No entitlement or CarPlay scene is added here.

## Validation on macOS and hardware

1. Run unit and UI tests from docs/testing.md. URL validation tests require no network.
2. Load a permitted direct HTTPS MP4 and HLS stream. Confirm loading, manual Play, pause, seeking, retry after failure, and close/reload behavior.
3. Verify invalid URLs, unsupported content, unreachable servers, and failures during playback. No third-party sample video is bundled.
4. Confirm changing tabs stops video, backgrounding pauses it, and route-picker presentation does not stop it.
5. On a supported parked vehicle, choose its display through AirPlay and verify video output. In a controlled hardware test, verify the vehicle's video restriction transition and audio-only behavior. Do not test while operating the vehicle.
6. Verify unsupported vehicles provide no video route, and confirm VoiceOver and Dynamic Type usability.

The Windows authoring environment cannot run AVKit/Xcode locally. Compilation and simulator tests run on the repository's macOS GitHub Actions workflow. Physical vehicle behavior is not yet validated.

## API references

- [AVPlayer allowsExternalPlayback](https://developer.apple.com/documentation/avfoundation/avplayer/allowsexternalplayback)
- [AVPlayerViewController](https://developer.apple.com/documentation/avkit/avplayerviewcontroller)
- [AVRoutePickerView](https://developer.apple.com/documentation/avkit/avroutepickerview)

The player now fails a stalled initial load after 30 seconds, pauses on audio interruptions and removed output devices, and cancels loading work on close/replacement. No automatic resume is performed. These lifecycle paths still require device validation.

## YouTube guide (2026-11-16)

Open **Video → YouTube and AirPlay guide** on iPhone. `AirPlayGuideView` explains the six manual steps: park safely, connect to a video-compatible CarPlay vehicle, open YouTube, choose and start a video there, select the vehicle only if YouTube offers the appropriate AirPlay output, and respect vehicle/iOS restrictions. Check the manufacturer's requirements for the exact vehicle, infotainment software, iPhone and iOS version. Neither CarPlay audio nor updating the phone establishes video support. YouTube and individual content may offer no suitable output. No vehicle models or YouTube compatibility are certified by this application.

**Open YouTube** uses `UIApplication.open` with the public HTTPS homepage, initially with `universalLinksOnly`. If no associated app accepts it, it retries the same HTTPS URL with normal system routing, allowing the website to open. A failed universal-link attempt does not establish whether YouTube is installed. No private URL scheme, app-install probe, video URL, autoplay parameter, routing action, download or embedded YouTube player is involved. If both attempts fail, the screen suggests Safari and permits retry. Launching the homepage does not guarantee which app or browser the user's system will choose.

`AirPlayHelpViewModel` injects `ExternalURLOpening` for deterministic launch tests. `AirPlayCompatibilityInfo` holds informational unknown/unsupported/unavailable scenarios. They are help content, not live vehicle detection; the guide always reports actual compatibility as unknown. Opening the guide neither changes the music provider nor stops music. Explicit use of the separate direct-stream player retains its existing music-pause behavior.

## Public API boundaries and current documentation

- [Apple's iPhone guide](https://support.apple.com/guide/iphone/play-videos-with-carplay-xykemxkw6he5/ios) describes supported vehicles, selecting the display from the playing app and switching to audio-only when the vehicle disallows video.
- [CarPlay developer overview](https://developer.apple.com/carplay/) distinguishes AirPlay video support implemented by vehicle manufacturers from native CarPlay video apps. Ordinary CarPlay support is not a video guarantee.
- [WWDC26: Rev up your CarPlay app](https://developer.apple.com/videos/play/wwdc2026/212/) describes iOS 27 video browsing in compatible vehicles, requiring AirPlay support and the approved category. This project's tested Xcode 16.4 / iOS 18.5 SDK does not provide those newer browsing APIs. The guide uses only APIs available to the existing iOS 17 app.
- [CarPlay Video App entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.carplay-video) is a separate video category capability. Apple's current documentation also restricts combining it with other CarPlay entitlements. This informational feature adds no entitlement, category, scene or vehicle capability API. Newer category-specific APIs must not be described as a universal eligibility detector available to this app.
- [AVRoutePickerView](https://developer.apple.com/documentation/avkit/avroutepickerview) presents receivers for media routing. The existing picker is scoped to this application's AVPlayer. It is deliberately absent from the YouTube guide: public AVKit controls do not let this app take over YouTube's separate playback session, select a vehicle route on its behalf, or obtain its video stream. A visible receiver would not establish that YouTube can send that video or that driving restrictions permit it.
- [universalLinksOnly](https://developer.apple.com/documentation/uikit/uiapplication/openexternalurloptionskey/universallinksonly) documents the public installed-handler attempt and its failure semantics.

No public API used by this ordinary app can force a vehicle to accept video, enable a missing route, override motion restrictions, certify parked eligibility, or start AirPlay for another app. There is no GPS/accelerometer-based inference, user-selected parked switch, mirroring implementation or moving-vehicle override. These boundaries do not deny the existence of approved CarPlay video-category APIs in newer SDKs; those are outside this guide's scope.

## Guide verification

`AirPlayHelpTests` exercises no automatic launch on creation, successful universal-link routing, missing/unassociated app fallback, total failure and retry, unknown/unsupported vehicle help and unavailable AirPlay help. `testAirPlayGuideOpensFromVideoTab` navigates to the guide and checks the launch action without opening an external app during automated testing. Existing lyrics, video URL validation and other app tests remain in the full suite.

Manual device checks still required: YouTube installed/uninstalled and universal-link preferences; browser restrictions and retry; VoiceOver/Dynamic Type and light/dark appearance; manufacturer-supported parked vehicle output; unsupported vehicle and absent route behavior; vehicle-enforced video-to-audio transition. Simulator navigation and mocked routing tests do not validate physical vehicle or YouTube output compatibility.
