# Build and test

Requires macOS, Xcode 16 or newer with an iOS simulator, and iOS 17 or newer. Open LyricsCarPlay.xcodeproj, select LyricsCarPlay, and run on a simulator. For device builds set a unique bundle identifier and development team in Signing & Capabilities. A development team is checked in; the CarPlay audio entitlement is restricted to simulator builds. Neither establishes production approval.

Run `xcodebuild -list -project LyricsCarPlay.xcodeproj` and `xcodebuild -showdestinations -scheme LyricsCarPlay`, then:

```sh
xcodebuild test -project LyricsCarPlay.xcodeproj -scheme LyricsCarPlay -destination 'platform=iOS Simulator,id=<SIMULATOR_ID>' CODE_SIGNING_ALLOWED=NO
```

Unit tests cover sync boundaries, duplicate timestamps, backward seeks, absent position, matching, cache policy/expiry, and unconfigured provider errors. The UI smoke test checks the demo and navigation. Manually verify Dynamic Type, VoiceOver, Reduce Motion, manual-scroll override, pause/seek, and app lifecycle on device. Future integration tests must cover slow responses, cancellation, track changes, authorization revocation, and network loss.

The Windows scaffold environment cannot compile SwiftUI or execute Xcode tests. CI provides the macOS validation path; a successful local generation is not an iOS build result.

For the separate CarPlay template prototype, follow the [CarPlay simulator setup](carplay-simulator.md). Simulator-only template tests exercise list selection completion and disabled unavailable features. They do not establish that the system launched the CarPlay scene; perform the documented manual launch/reconnect checks on macOS.

Fresh installations default to Demo; existing source preferences are preserved. For manual local lyrics testing, choose Settings > Music app > Demo. UI tests pass --demo-mode at launch to isolate account-free flows. Spotify SDK setup and real-device checks are in [the Spotify guide](spotify-integration.md).

## Foundation verification ? 2026-11-16

Added deterministic mocked playback-to-lyrics coverage for exact timestamps, elapsed playback, pause, backward seek, and completion without real sleeps. Context tests cover unordered input, adjacent lines, first/last boundaries, missing timing, and Codable round trips. Preference tests cover fresh defaults, saved Apple Music selection, and invalid stored values.

Run `python scripts/validate_project.py` and `python -m unittest discover -s backend/tests -v` on Windows. These validate structure and the Python backend only; they do not run XCTest or compile Swift.

On macOS run `bash scripts/verify_on_mac.sh` for simulator tests and unsigned Release compilation. Record Xcode/SDK versions with `xcodebuild -version` and `xcodebuild -showsdks`. Inspect installed WidgetKit/ActivityKit interfaces before adding SDK-dependent APIs. No Xcode, Swift compiler, or Apple SDK is available in the current Windows workspace.

Manual foundation check: launch with fresh defaults, continue with Demo, open Now Playing, press Play, observe Open Road and the highlighted original lyrics, pause, seek backwards, and resume. Open Video → YouTube and AirPlay guide. Verify unknown compatibility, the six manual steps, troubleshooting and the Open YouTube button. Test installed/uninstalled YouTube and universal-link preferences on a physical iPhone; a successful URL handoff does not establish AirPlay success. Test small screens, light/dark appearance and accessibility text sizes. Follow [parked-video hardware checks](parked-video.md) separately; simulator tests cannot certify a vehicle.

`AirPlayHelpTests` uses an injected URL opener for successful app handoff, website fallback, launch failure/retry and initial no-side-effect behavior. Help-state coverage includes unknown compatibility, unsupported vehicles and unavailable AirPlay. `testAirPlayGuideOpensFromVideoTab` covers navigation and button availability without leaving the app. No automated test simulates a vehicle being parked or claims to validate real YouTube output.

Before any widget milestone, verify App Group access on a signed device, stale-data rendering, system refresh budgets, locked-phone behavior, and supported CarPlay hardware. YouTube route availability and vehicle motion enforcement require physical testing and cannot be established by unit tests.

## Synchronization milestone

New XCTest coverage is in SynchronizationStateTests and LRCLyricsProviderTests, with additional view-model, mock-rate, and HTTP-provider tests in the existing suites. Cases cover start/end boundaries, forward/backward seeking, pause/resume, fractional rates, invalid/missing positions, overlapping intervals, explicit gaps, implicit ends, unavailable/untimed documents, track switches including return to a previous track, positive/negative offsets, duplicate suppression, stable IDs, Codable round trips, LRC repeated tags/metadata/offsets, malformed/oversized input, track-scoped imports, injected authorization, and a 50,000-line prepared timeline.

The view-model test asserts seek/offset results immediately and counts synchronization publications to catch redundant updates. Existing late-cancelled-response tests remain in place. These tests use original fixture text; no copyrighted lyrics or live account is required.

Current environment results: structural validation passes (146 Xcode objects) and all 10 Python backend tests pass. Added Swift tests and SwiftUI changes have not been compiled or executed here because neither Xcode nor a Swift toolchain is installed. Docker is installed but its engine is unavailable. Do not treat the Python result as synchronization test success.

On a Mac run `bash scripts/verify_on_mac.sh`. Then manually open Now Playing in Demo, seek in both directions, change demo speed, pause/resume, and expand Timing and LRC import. Adjust the offset and verify immediate line changes. Import a UTF-8 LRC file using Files, verify it follows the current track, and remove it to restore the provider. Check Dark Mode, accessibility text sizes, Reduce Motion, and the collapsed/expanded controls on a small device. Background execution is intentionally not guaranteed.

## WidgetKit and ActivityKit milestone

See [the preview, signing, lifecycle and CarPlay test matrix](WIDGETS_AND_LIVE_ACTIVITIES.md). LyricsSurfaceTests use repository/activity fakes and awaitable batch completion for deterministic lifecycle, track, pause, background, dismissal, expiry, permission and storage checks. Structural checks and independent OpenStep parsing validate four targets and the embed graph. New Swift files pass a grammar parser, which does not check Apple APIs or types. All ten backend tests pass. Swift tests, extension/app builds, previews, signed groups and CarPlay Simulator remain unrun without Xcode. The Mac verification script now explicitly builds LyricsWidgets.

## Music providers and matching

SpotifyWebIntegrationTests mock HTTP and token storage for PKCE, callback validation, denied authorization, expired/rotated credentials, refresh coalescing and logout races, one 401 retry, no active playback, nullable progress, pause, API/token 429 backoff, forbidden access, offline errors and bounded position estimates. LyricsMatchingServiceTests cover version/album/duration mismatches, ambiguity, explicit bindings, source/confidence, import removal, metadata-sensitive caching and the Spotify policy gate. MusicProviderEventTests cover drift/change detection, authorization denial and rematching corrected metadata under the same ID.

Local structural and grammar checks pass. The local Xcode command reports that macOS/Xcode is required; it is not a Swift test result. A signed-device checklist and developer setup are in [the provider guide](MUSIC_PROVIDERS.md). Remote macOS CI is being used for the implementation snapshot; its result must be recorded separately before claiming compilation or XCTest success.

## Verified macOS result - 2026-11-16

[CI verification](https://github.com/smptr0911/Lyrics-carplay-app/actions/runs/43941873382) passes for code commit c75c44c on the isolated codex/music-providers-ci-20261116 branch: Xcode 16.4, Swift compiler 6.1.2 in Swift 5 language mode, iOS 18.5 SDK/simulator. The app and embedded widget/Live Activity extension compile for unsigned device Release. All 71 unit tests and four UI tests pass. The 13 Spotify Web tests, six matching tests and two provider-event tests are included in that count. All ten Python backend tests also pass locally.

Compiler verification caught and corrected WidgetBundleBuilder availability branching and a CRLF bearer-validation bug; invalid CRLF, NUL, tabs and spaces now fail before transport. The source timing engine was preserved. Live credentials, domain association/provisioning, physical Music behavior, real Keychain lock/relaunch and CarPlay delivery still require device checks. Legacy App Remote delegate actor-isolation warnings remain migration work before enabling Swift 6 language mode.
