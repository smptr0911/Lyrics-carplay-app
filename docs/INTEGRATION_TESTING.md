# Integration verification record

Date: 2026-11-16. This is a development handoff, not release certification. The existing project, synchronization engine, targets and source-provider architecture remain intact. Current code and documentation are snapshotted to the isolated `codex/music-providers-ci-20261116` branch for macOS checks; the authoring workspace stays on its existing branch.

## Environment and evidence

Local authoring: Windows 11; Xcode, Apple SDKs, simulator runtimes, USB iPhone and a CarPlay vehicle are unavailable locally. `scripts/inspect_development_environment.py` reports absence explicitly and records installed tools, runtimes, schemes and allowlisted resolved settings on Mac. It never dumps complete build settings, credentials or physical-device identifiers.

The completed pre-audit [CI baseline](https://github.com/smptr0911/Lyrics-carplay-app/actions/runs/43946086918) used Xcode 16.4, compiler Swift 6.1.2 and iOS 18.5. App and extension compile in Swift 5 language mode; deployment is iOS 17, and supplemental small activity APIs are guarded for iOS 18. Current audit CI evidence is recorded below after completion. Selected CI tools do not establish the developer's local Xcode version.

Actual runner inspection also found Xcode 16.0–16.4 and 26.0.1–26.3 installations, with iOS simulator runtimes 18.5, 18.6, 26.0.1, 26.1 and 26.2. The selected default remains Xcode 16.4 / iOS 18.5 SDK. Resolved app and extension settings agree on iOS 17, Swift 5, automatic signing, team `2JH4JHH9XY` and placeholder group `group.org.example.LyricsCarPlay`; these do not prove provisioning. Public accessibility automation verified the selected Simulator's **I/O > External Displays > CarPlay** menu. Neither that probe nor the existence of newer tools establishes actual CarPlay rendering.

Shared schemes: `LyricsCarPlay` (app, embedded extension, unit and UI tests), `CarPlay Simulator` (legacy simulator-only template preview). Four targets remain: app, unit tests, UI tests, LyricsWidgets. Automatic signing uses `APP_DEVELOPMENT_TEAM` consistently across all targets. The inherited default team and `org.example` bundle identifier are not transferable provisioning. The registered group must match app and extension; `NSSupportsLiveActivities` is enabled in both app Info variants. No frequent ActivityKit push entitlement, APNs server or background audio execution mode is added. Device builds contain no CarPlay template scene or category entitlement. Simulator audio-category entitlements are isolated to the existing prototype.

## Verification matrix

Final audit result: [CI run 43951717742](https://github.com/smptr0911/Lyrics-carplay-app/actions/runs/43951717742) passed all four jobs. Xcode 16.4 selected iPhone 16 Pro / iOS 18.5; Xcode 26.3 selected iPhone 17 Pro / iOS 26.2. Each toolchain passed 79 unit tests and 5 UI tests. Unsigned device Release builds and static analysis passed; the modern job also explicitly built LyricsWidgets for Simulator. Local structural checks and all 10 backend tests passed. Result bundles and logs are retained as workflow artifacts. These results do not verify physical CarPlay, real account authorization, signed App Groups or vehicle video output.

| Area | Automated evidence | Still requires manual testing |
|---|---|---|
| Demo/iPhone lyrics | Unit engine, matching/import tests and app UI journey | VoiceOver, large text, Reduce Motion, extended battery use |
| Synchronization | Seek, pause/resume, rates, offset, boundaries, malformed/large LRC, gaps/overlaps, track/source changes and stale responses | Real provider timing and interruption behavior |
| Apple Music | Public adapter compiles; injected provider failures/events are covered | Actual MusicKit/media permission prompts, denial/revocation, metadata/artwork/position for eligible standalone Music items, subscription/content variations |
| Spotify | Mock HTTP/browser/store tests cover PKCE/state/callback checks, expiration/refresh, 401/403/429/offline, empty playback and drift expiry | Real developer account access, HTTPS AASA callback/provisioning, cancellation, Keychain persistence, account metadata and rate limits |
| Widget | Extension source/previews compile; shared projection, repository round trip/corruption, permissions, expiry, bounds and reload-policy tests | Gallery appearance, Home Screen/Today View placement, cross-process signed App Group access, iOS 26+ CarPlay selection and rendered layout |
| Live Activity | Content models/layouts compile; mocked lifecycle covers start/update/end, denial/dismissal, track/pause and suspension/resumption | Actual ActivityKit lifecycle authorization, Lock Screen, supported Dynamic Island and CarPlay rendering |
| AirPlay guide | Guide navigation UI test and mocked HTTPS launch/fallback/retry | Installed/uninstalled YouTube behavior on iPhone, real compatible vehicle output and restriction transitions |
| Stability/security | Foreground cancellation/release regression; failed shared storage does not block ActivityKit; compiler and analyzer checks | Instruments Leaks/Allocations, Time Profiler/Energy, long-running background/lock cycles, final Archive privacy/signing review |

No account-backed integration or physical vehicle presentation is treated as tested merely because its adapter compiles or a mock passes. Demo is simulated metadata/time, not an audio recording. The engine remains independent of SwiftUI. Spotify lyric synchronization remains disabled; neither vendor supplies a lyric endpoint in this implementation.

## Fixes and diagnostics from this audit

- Replaced hardcoded target team settings with a shared configurable value; updated the ignored-local-config template with App Group and optional HTTPS Spotify setup. Previously the template's team override was shadowed by target settings.
- Made the legacy Spotify Objective-C delegate boundary explicitly `@preconcurrency`, retaining actor runtime checks. [Spotify documents main-thread callbacks](https://github.com/spotify/ios-sdk#frequently-asked-questions). This migration annotation does not claim complete strict Swift 6 adoption.
- Preserved a legacy playback sample's capture timestamp/rate when asynchronous artwork arrives, and published that metadata change. Artwork is not a new playback measurement.
- Added foreground task cancellation/deactivation/release coverage and shared-storage failure coverage. These are bounded ownership checks, not an Instruments leak certification.
- Added Debug-only `LyricsCarPlay` / `SurfaceTiming` logs containing event labels and snapshot age only. No lyrics, titles, provider URLs, credentials or group paths are logged. Events distinguish saves, widget reload requests, widget timeline reads and ActivityKit calls returning. Release emits none of these timing logs.
- Extended Mac verification to inventory actual tools/resolved settings and run `xcodebuild analyze`. Clang analysis does not prove Swift memory/race safety. A cold CoreSimulator inventory timeout is explicitly unverified; the real test command still requires an available runtime.
- Simulator test runs retain a unique `.xcresult` bundle under `.build/logs`, uploaded with CI logs. Repeated local checks do not collide with an existing result bundle.
- Fixed runtime selection: tests now choose an installed iPhone runtime at or below the selected simulator SDK version, rather than blindly choosing a newer runtime installed for another Xcode. The previous selector chose iOS 26.2 while using the iOS 18.5 SDK and incurred lengthy startup; all 79 unit tests passed in that superseded run before cancellation. CI additionally verifies the discovered Xcode 26.3 installation in its own job. The independent environment/menu job avoids affecting XCTest's Simulator process and supports an environment-only workflow dispatch.

## Measure system update behavior

No actual widget/CarPlay render-latency measurement is available in this session. Existing unit tests verify app policy, not WidgetKit delivery. Use this repeatable physical test:

1. Record code commit, Xcode/iOS, iPhone, vehicle/head-unit and infotainment versions, connection type, surface and lyric-sharing permission. Use original Demo content.
2. In a Debug build, filter Console for subsystem `LyricsCarPlay`, category `SurfaceTiming`. Start Demo and a Live Activity, then add the widget. Save request timestamps separately from timeline-read timestamps. A timeline read and an ActivityKit call returning do **not** prove display time.
3. Record the displayed surface with an external camera/time reference. Observe line/track/pause/seek changes, foreground/background/lock and reconnection. Compare actual display changes against requested changes. For line timing use Now Playing as the foreground reference; do not use these logs to infer a parked state.
4. Log request-to-timeline-read delay, observed request-to-render delay, missed/coalesced lines and expiry/redaction. Repeat for light/dark appearance, missing lyrics, long text and system background removal. Mark unavailable cases rather than assigning zero latency.
5. Keep observations bounded to the tested setup. WidgetKit budgets and ActivityKit/background scheduling offer no reliable per-line CarPlay refresh guarantee. Do not use artificial background timers, fake audio or push traffic to imply one.

App policy currently coalesces lyric-only widget reload requests to one per minute, allows meaningful track/transport/status transitions immediately, and saves freshness heartbeats at ten seconds. Those are measured/tested policy constants, not measured OS refresh rates. See [system-surface limitations](WIDGETS_AND_LIVE_ACTIVITIES.md).

## Developer/device completion checklist

1. Configure your team, unique app/extension IDs and identical registered App Group; regenerate profiles and install on a Developer Mode iPhone. Verify first-unlock/locked file protection and explicit sharing permissions.
2. Follow [CarPlay simulator instructions](carplay-simulator.md); record the exact available menu/tool/package. Do not substitute the simulator-only template preview for widget/activity validation.
3. Run Demo and local LRC on iPhone. Exercise source changes, seek/rate/offset, pause/resume, unavailable lyrics, background/return, disconnect and cache clearing.
4. With appropriate accounts, separately run the Apple Music and Spotify rows above. Keep secrets out of logs/issue reports. Configure HTTPS callback/AASA only for Spotify-enabled builds.
5. Check widget gallery/background/margins and ActivityKit start/update/end, lock, dismissal and re-entry. Measure rendering as described above on supported CarPlay hardware.
6. Exercise the guide with YouTube installed/absent. Vehicle/video compatibility is manufacturer/content-dependent; respect OS/vehicle enforcement. Do not test while operating a vehicle.
7. Profile memory, energy and network polling with Instruments; review final signed Archive privacy manifests and rights. Complete these gates before TestFlight or production claims.

## Files changed by this audit

- Signing: `Config/App.xcconfig`, `Config/Local.xcconfig.example`, `LyricsCarPlay.xcodeproj/project.pbxproj`.
- Runtime: `LyricsCarPlay/Services/Playback/SpotifyMusicSource.swift`, `LyricsCarPlay/Services/Surfaces/LyricsSurfaceController.swift`, `LyricsCarPlay/Shared/SharedLyricsRepository.swift`, `LyricsWidgets/LyricsWidget.swift`.
- Regression tests: `LyricsCarPlayTests/NowPlayingLifecycleTests.swift`, `LyricsCarPlayTests/LyricsSurfaceTests.swift`.
- Tooling: `.github/workflows/ios-ci.yml`, `scripts/inspect_development_environment.py`, `scripts/validate_project.py`, `scripts/verify_on_mac.sh`.
- Handoff: `README.md`, `docs/INTEGRATION_TESTING.md`, `docs/carplay-simulator.md`, `docs/testing.md`, `docs/MUSIC_PROVIDERS.md`, `docs/release-checklist.md`.
