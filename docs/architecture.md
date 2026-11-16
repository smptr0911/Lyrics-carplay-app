# Architecture

## Repository inspection ? 2026-11-16

The existing Git checkout points to github.com/smptr0911/Lyrics-carplay-app. Git was clean before this change. Preserve LyricsCarPlay.xcodeproj and its explicit source memberships.

- Entry point: LyricsCarPlay/App/LyricsCarPlayApp.swift; composition root: AppContainer.
- Targets: LyricsCarPlay, LyricsCarPlayTests, LyricsCarPlayUITests. Shared schemes: LyricsCarPlay and CarPlay Simulator.
- Deployment: iOS 17.0. Swift language mode: 5.0. Do not enable Swift 6 without compiling the adapters and resolving strict concurrency diagnostics on Xcode.
- Automatic signing with a checked-in development team (2JH4JHH9XY); configure the appropriate local team for device testing.
- Dependency: SpotifyiOS via Spotify ios-sdk SPM, pinned to 5.0.1.
- Existing CarPlay templates and scene delegate are simulator-only. Device plist has no CarPlay scene. The audio entitlement is simulator-only; it is not production approval.
- Inspection originally found no widget, ActivityKit or App Group implementation. These are now implemented in source as described in [the current system surface design](WIDGETS_AND_LIVE_ACTIVITIES.md). No continuous background service exists.

## Reused boundaries

SwiftUI views observe the main-actor NowPlayingViewModel. AppContainer injects MusicSource and LyricsProvider adapters. PlaybackCoordinator normalizes playback; LyricsCoordinator handles retrieval and policy-aware in-memory caching. Track, PlaybackSnapshot, LyricLine, and LyricsDocument remain in Models rather than introducing a parallel Shared hierarchy.

LyricsTimeline prepares a stable sorted timeline once per document, then uses binary search during foreground updates. Missing positions, invalid timestamps, and mixed untimed lines disable highlighting. Duplicate timestamps select the last line in source order. Track changes cancel pending requests. Dragging suspends auto-follow until the user resumes it.

MockMusicSource uses an injectable monotonic clock. MockLyricsProvider supplies original lyrics for the demo track only. Fresh preferences and onboarding default to Demo; persisted choices remain intact. Apple Music is the first production integration to validate. Spotify lyric synchronization remains blocked.

LyricContext provides a Codable, Sendable current/previous/next projection, ordered identically to the timeline. It is a point-in-time value; it grants neither persistence rights nor background execution. The context helper is intended for occasional projections; the foreground hot path retains its prepared timeline.

## Shared-surface boundary (original plan; now implemented in source)

Add a WidgetKit extension to the existing project on a Mac with the intended SDK. Share only the required model and storage files by target membership. Use a protocol-based snapshot store with an injected in-memory fake for tests and an atomic App Group container implementation for production. Select a real provisioned App Group identifier for both targets; do not ship a fabricated identifier or fall back silently to private defaults.

Persist only provider-permitted data, with schema version, track identity, capture time, expiry, attribution, and stale-state handling. Clear on source changes and revocation. Demo documents currently prohibit caching through cacheUntil == nil; do not automatically write them through the production licensed-data path. Any demo widget fixture needs its own explicit storage policy.

WidgetKit timelines and ActivityKit updates need separate scheduling adapters. The app's foreground 100 ms polling loop must never become a widget reload loop. Expiry, pause, seek, track changes, suspension, and missed updates must produce honest stale or unavailable states.

## Video

Keep the existing native direct-stream player. The new YouTube guide opens YouTube externally and explains route selection and compatibility. This app does not access YouTube media or control another app's player. Vehicle and system restrictions remain authoritative.

## Synchronized lyrics engine

The existing transport enum remains PlaybackState for adapter compatibility. PlaybackSnapshot is the richer Codable/Sendable playback model: track, position, rate, playing state, and capture date. Track, LyricLine (including optional endTime), LyricsDocument, LyricContext, and SynchronizedLyricsState are serializable shared values. Provider-qualified track identity scopes documents. Line identifiers are deterministic across reloads; LRC/API adapters include source ordinals so duplicate text/timestamps remain distinct. IDs are non-cryptographic and must not be used for security decisions.

LyricsState retains loading, error, and unavailable cases. SynchronizedLyricsState separately describes current/previous/next and synchronization status. This avoids forcing loading logic into the pure timing engine.

LyricsSyncEngine prepares a LyricsTimeline when a document loads. Lookup is O(log n), context access is O(1), and updates return whether visible state changed. A changed track discards the previous timeline until a matching document loads. The engine has no SwiftUI, provider, timer, or actor dependency.

PlaybackSnapshot.position(at:) optionally interpolates from an explicit capture date at the supplied rate, freezes when paused, and clamps at track duration. Callers must supply a fresh snapshot when rate, seek, or track changes. Backwards clock differences clamp elapsed time to zero; elapsed wall-clock interpolation is for foreground presentation, not a background timing guarantee. The live view model uses fresh provider positions directly, avoiding extrapolation of stale SDK measurements. Demo uses a monotonic injected clock and preserves position when its rate changes.

Selection rules:

- Start-inclusive, explicit end-exclusive intervals. Latest start wins an overlap; last source entry wins duplicate starts.
- Missing end times extend to the next start or known track duration. An unknown final duration leaves the last line active until a new snapshot/document supersedes it.
- Explicitly ended lines leave a gap; an older overlapping line does not resume.
- At known track duration, current highlighting ends regardless of offset.
- Mixed/missing/invalid timestamps disable the entire document's highlighting while preserving static text.
- A positive synchronization offset advances lyric display. A negative offset delays it. The UI bounds this to +/-10 seconds; the pure engine accepts finite offsets and rejects invalid arithmetic.
- Missing positions, missing documents, untimed documents, waiting, gaps, paused, synchronized, and ended states are explicit.

The foreground view model polls at 100 ms only while its root scene task is active. It publishes line context and active IDs only when changed and ignores capture-date-only snapshot changes. Seeking and offset controls update synchronously without waiting for the next tick. Existing source capabilities and Spotify policy restrictions remain enforced.

## Imported and future providers

ImportedLRCLyricsProvider is an actor implementing LyricsProvider. The coordinator checks track-scoped imports before its existing permitted cache and configurable API provider. UTF-8 LRC supports mm:ss, 1-3 decimal digits, repeated timestamp tags, metadata, and global millisecond offsets. Positive LRC offset advances display and combines with the UI offset. Negative adjusted starts clamp to zero. Enhanced word-level LRC and hour-form timestamps are not supported. Invalid time tokens fail explicitly. Input and expanded lyric text are each bounded to 1 MB and at most 50,000 entries, including repeated tags. Parsing and file reads occur outside the main actor. Imports remain in memory until removed or the process exits, without uploads. Explicit bindings win; cross-provider matching requires complete agreeing metadata as described below.

The system file importer reads only a user-selected file and balances security-scoped access. See [Apple fileImporter documentation](https://developer.apple.com/documentation/swiftui/view/fileimporter%28ispresented%3Aallowedcontenttypes%3Aoncompletion%3A%29). The user is responsible for permission to display imported text.

LicensedLyricsProvider remains the future API adapter and now accepts optional endTime values and an injected LyricsAPICredentials interface. An auth service/Keychain implementation can supply a short-lived bearer token. No token is embedded, logged, placed in UserDefaults, or added to the URL by this implementation. Provider secrets should remain on the backend. There is no new credential UI or Keychain token acquisition flow. Unconfigured providers still fail explicitly; no Apple Music/Spotify lyrics endpoint is assumed.

## System surface milestone

LyricsWidgets is the fourth target, embedded and signed separately. Shared snapshot, repository and ActivityAttributes files have membership in the app and extension. Services/Surfaces contains the rights-aware projection, pure scheduling policy, injectable activity client and serialized controller. AppContainer injects a callback into NowPlayingViewModel; scene changes control suspension. Settings owns explicit start/end actions. The timing engine remains independent. See [design, signing and refresh limits](WIDGETS_AND_LIVE_ACTIVITIES.md).

## Music provider integration

MusicProvider now defines capabilities, snapshots, authorization and change streams; MusicSource is a compatibility alias. AppContainer retains one provider per source to keep credentials under one lifecycle owner. Apple Music uses MusicKit authorization and MediaPlayer system-player metadata/notifications, rather than assuming a shared MusicKit queue. The primary Spotify provider uses HTTPS PKCE authorization, private Keychain storage and foreground Web API polling; the original App Remote adapter remains explicit legacy code. LyricsMatchingService performs conservative local matching and exposes confidence/source. Metadata-sensitive keys invalidate stale lyric work/cache entries while leaving LyricsSyncEngine unchanged. See [provider boundaries, setup and tests](MUSIC_PROVIDERS.md).
