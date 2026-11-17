# Lyrics CarPlay App

An iPhone lyrics companion with a foreground synchronization engine, authorized music metadata adapters, and best-effort WidgetKit / ActivityKit presentations. The existing Xcode project is preserved. This is a development build, not a certified vehicle integration or an App Store release.

## Supported features

- Account-free Demo: simulated playback of **Open Road** with original timestamped lyrics, pause/resume, seeking, playback rate and synchronization offset controls. No audio recording is bundled or played by Demo.
- Binary-search lyric selection, track changes, gaps/overlaps, untimed/unavailable content and session-only UTF-8 LRC import. Imported files are bound to the selected track; matching avoids unrelated versions.
- Apple Music public system-player adapter: authorization, eligible metadata/artwork, transport and position where exposed. Not arbitrary third-party playback monitoring.
- Spotify Web API: read-only metadata/position, native PKCE authorization, protected Keychain credentials, refresh, backoff and foreground polling. **Spotify lyric synchronization is disabled.** Legacy App Remote is preserved but is not the default provider.
- Embedded **LyricsWidgets** extension: `systemSmall` widget, Lock Screen / Dynamic Island Live Activity and availability-guarded supplemental small family. Shared snapshots use App Groups and explicit lyric-sharing permission. These surfaces do not promise karaoke timing.
- **Video > YouTube and AirPlay guide**: manual parked-only setup, unknown/unsupported compatibility help and public HTTPS YouTube launch with website fallback. A separate existing native player accepts permitted direct HTTPS MP4/HLS streams; its route picker controls only that player.

## Requirements and verified scope

Minimum deployment: **iOS 17**, iPhone. Use **Xcode 16 or newer** to compile the guarded iOS 18 small activity family. The project retains **Swift 5 language mode** with targeted concurrency checks and async/await; it is not declared Swift 6 strict-mode clean. macOS must meet the selected Xcode's requirements; consult [Apple's compatibility table](https://developer.apple.com/xcode/system-requirements/).

The final [macOS CI run](https://github.com/smptr0911/Lyrics-carplay-app/actions/runs/43951717742) passed on **Xcode 16.4 / iOS 18.5** and **Xcode 26.3 / iOS 26.2**: 79 unit tests and 5 UI tests on each toolchain, unsigned device Release builds, widget compilation and static analysis. See the [integration verification record](docs/INTEGRATION_TESTING.md). Local authoring is Windows; no local Xcode or physical iPhone/vehicle is attached to this session.

CarPlay widgets and Live Activities require compatible **iOS 26+** CarPlay environments. Compiling on the iOS 18.5 SDK does not verify those presentations. Neither a standard CarPlay connection nor an iOS upgrade guarantees AirPlay vehicle video support.

## Setup and build

1. Open `LyricsCarPlay.xcodeproj` on a Mac and resolve the pinned Swift package dependency (Spotify iOS SDK 5.0.1). Select the shared **LyricsCarPlay** scheme and an installed iPhone simulator running iOS 17 or later.
2. Run the app. Choose Demo in Settings if an earlier source choice was saved. In Now Playing press Play, seek using the slider and expand Timing and LRC import. Demo needs no provider credentials, backend or paid music account.
3. For a signed iPhone build, copy `Config/Local.xcconfig.example` to ignored `Config/Local.xcconfig`. Replace `APP_BUNDLE_IDENTIFIER`, `APP_DEVELOPMENT_TEAM` and `LYRICS_APP_GROUP` with your registered identifiers. The default team is inherited from the existing project; it is not a provisioned account for other developers.
4. Enable the same registered App Group on the app and extension App IDs and provisioning profiles. The extension identifier is `$(APP_BUNDLE_IDENTIFIER).LyricsWidgets`. Verify Signing & Capabilities on all targets, trust the Mac on iPhone, enable Developer Mode and run **LyricsCarPlay** on the device. App Groups and optional Associated Domains require appropriate Apple Developer account capabilities; a free Personal Team does not establish this configuration.

```sh
# Windows or macOS: repository/backend checks
python scripts/inspect_development_environment.py
python scripts/validate_project.py
python -m unittest discover -s backend/tests -v

# Mac: actual installed tools, SDKs, schemes and resolved signing settings
python3 scripts/inspect_development_environment.py --probe-simulator-menu

# Mac: widget simulator build, app unit/UI tests, unsigned device build and analysis
bash scripts/verify_on_mac.sh
```

Unsigned CI does not validate provisioning. `xcodebuild analyze` runs Clang's analyzer and the build diagnostics; it is not a comprehensive Swift memory-leak or race detector. Use Instruments and device tests for those checks.

## Apple Music setup

The app declares the Apple Music usage explanation and requests MusicKit authorization plus media-library access where needed. In Settings choose Apple Music and tap Authorize Apple Music. Start a supported item in Apple's Music app, then return to this app. The adapter reads only what the public system music player exposes; inaccessible metadata produces an honest unavailable state. Denial, revocation, subscription/content variants and real playback need device validation. No Apple Music lyric endpoint exists in this implementation. See [music providers and matching](docs/MUSIC_PROVIDERS.md).

For MusicKit service use, enable **MusicKit** under the registered App ID's **App Services** in the developer portal, using the same bundle ID and team as the signed app. This is a runtime app service, not a new invented MusicKit entitlement. See [Apple's setup instructions](https://developer.apple.com/documentation/musickit/using-automatic-token-generation-for-apple-music-api). No private signing key or developer token is bundled in this app.

## Spotify setup

Create a Spotify developer application with authorized test accounts and a public client ID. Configure an owned HTTPS redirect URI, matching `SPOTIFY_AUTH_HOST`, an HTTPS AASA `webcredentials` association, and Associated Domains provisioning using the optional Spotify entitlement files. Native HTTPS browser callbacks require **iOS 17.4+**. Select Spotify and Connect Spotify in Settings. No client secret belongs in the app or xcconfig. The Web API provider cannot control playback or synchronize Spotify recordings with lyrics. See [complete setup and capability limits](docs/MUSIC_PROVIDERS.md) and [Spotify setup](docs/spotify-setup.md).

Demo and local LRC need no API. Production lyrics need separate licensing, matching, retention and system-surface permission. Provider secrets belong in an authorized backend or injected secure credential source, not distributed configuration. See [backend development](backend/README.md).

## Widget and Live Activity setup

After signed App Group configuration, run Demo and add **Lyrics snapshot** from the supported iPhone widget gallery (Home Screen / Today View where offered). It supports `systemSmall`; it is not a Lock Screen accessory-family widget. No stored snapshot shows an unavailable state rather than fabricated demo data.

With Demo selected, open Now Playing, then Settings > CarPlay > Start Live Activity. Use End Live Activity to dismiss. Live Activities must be allowed by the device and system settings. Lock Screen and supported Dynamic Island layouts are implemented. Pausing and track changes update content; leaving the active scene redacts/suspends lyrics and freshness expiry is a fallback. Imported/API lyrics without explicit sharing permission remain off these surfaces.

Add/select the widget in a supported CarPlay widget configuration and inspect Dashboard activities using a compatible environment. This selection, physical App Group access, real Lock Screen/Dynamic Island rendering, and CarPlay rendering remain manual checks. Widget reloads are requests, not scheduled per-line delivery. ActivityKit grants no continuous background runtime. See [system-surface design, setup and limits](docs/WIDGETS_AND_LIVE_ACTIVITIES.md).

## CarPlay simulation and real devices

Apple documents **Simulator > I/O > External Displays > CarPlay** for the standard iOS Simulator. The separate shared **CarPlay Simulator** project scheme is a simulator-only template navigation prototype, not a head-unit lyric implementation. Neither the scheme nor compilation proves the menu was available or exercised. The environment inspector attempts public accessibility automation and explicitly records an unverified result when access is unavailable.

Apple also distributes a **standalone CarPlay Simulator** in Additional Tools for Xcode; it connects to a real USB iPhone. Xcode 27 adds a Device Hub path. Package compatibility, exact verified menu status and installation steps are recorded in [CarPlay simulator instructions](docs/carplay-simulator.md). No Additional Tools package, Device Hub session or vehicle was exercised in this session.

Use a signed physical iPhone and supported vehicle/head unit for final validation, preferably wireless CarPlay so Xcode debugging can remain connected. No production CarPlay category entitlement is requested by this app. Widget/Live Activity support is separate from the legacy simulator-only audio-category template scene.

## Parked video and AirPlay limits

Park safely, connect to a manufacturer-supported video-compatible CarPlay vehicle, open YouTube on iPhone and start the chosen video there. Only if YouTube offers an appropriate AirPlay option and the vehicle supports it should you select that display. The OS and vehicle enforce availability; output can stop or become audio-only. This app cannot route YouTube's separate session, detect authoritative parked eligibility, enable unsupported vehicles or override restrictions. It does not embed, scrape, download, intercept or mirror YouTube. No video entitlement is added. See [official API research and manual checks](docs/parked-video.md).

## Testing, known issues and roadmap

[Integration verification](docs/INTEGRATION_TESTING.md) separates automated evidence from mocked services and unverified system/account behavior. [Testing guide](docs/testing.md) covers regression and manual checks. [Architecture](docs/architecture.md), [implementation plan](docs/IMPLEMENTATION_PLAN.md) and [platform limitations](docs/CARPLAY_LIMITATIONS.md) describe the existing design.

Remaining work: signed App Group/device validation; live Apple Music and Spotify account tests; widget and Live Activity rendering/latency measurement on iOS 26+ CarPlay; Instruments battery/leak profiling; accessibility checks; licensed production lyric sources and policy review. Accurate synchronization is foreground iPhone behavior. Per-line CarPlay updates, universal video compatibility, App Store approval and production service availability are not promised.

Next development phase: execute the hardware/account matrix and record observations before expanding integrations or preparing TestFlight. Release gates are tracked in [release checklist](docs/release-checklist.md).
