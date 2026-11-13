# Build and test

Requires macOS, Xcode 16 or newer with an iOS simulator, and iOS 17 or newer. Open LyricsCarPlay.xcodeproj, select LyricsCarPlay, and run on a simulator. For device builds set a unique bundle identifier and development team in Signing & Capabilities. No signing team or CarPlay entitlement is checked in.

Run `xcodebuild -list -project LyricsCarPlay.xcodeproj` and `xcodebuild -showdestinations -scheme LyricsCarPlay`, then:

```sh
xcodebuild test -project LyricsCarPlay.xcodeproj -scheme LyricsCarPlay -destination 'platform=iOS Simulator,id=<SIMULATOR_ID>' CODE_SIGNING_ALLOWED=NO
```

Unit tests cover sync boundaries, duplicate timestamps, backward seeks, absent position, matching, cache policy/expiry, and unconfigured provider errors. The UI smoke test checks the demo and navigation. Manually verify Dynamic Type, VoiceOver, Reduce Motion, manual-scroll override, pause/seek, and app lifecycle on device. Future integration tests must cover slow responses, cancellation, track changes, authorization revocation, and network loss.

The Windows scaffold environment cannot compile SwiftUI or execute Xcode tests. CI provides the macOS validation path; a successful local generation is not an iOS build result.

For the separate CarPlay template prototype, follow the [CarPlay simulator setup](carplay-simulator.md). Simulator-only template tests exercise list selection completion and disabled unavailable features. They do not establish that the system launched the CarPlay scene; perform the documented manual launch/reconnect checks on macOS.

The initial selected music app is now Spotify. For manual local lyrics testing, choose Settings > Music app > Demo. UI tests pass --demo-mode at launch to isolate account-free flows. Spotify SDK setup and real-device checks are in [the Spotify guide](spotify-integration.md).
