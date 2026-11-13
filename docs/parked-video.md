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

The Windows authoring environment cannot compile or run AVKit/Xcode. Physical vehicle behavior is not yet validated.

## API references

- [AVPlayer allowsExternalPlayback](https://developer.apple.com/documentation/avfoundation/avplayer/allowsexternalplayback)
- [AVPlayerViewController](https://developer.apple.com/documentation/avkit/avplayerviewcontroller)
- [AVRoutePickerView](https://developer.apple.com/documentation/avkit/avroutepickerview)

The player now fails a stalled initial load after 30 seconds, pauses on audio interruptions and removed output devices, and cancels loading work on close/replacement. No automatic resume is performed. These lifecycle paths still require device validation.
