# Music providers and local lyrics matching

Source implementation is integrated with the existing app, synchronization engine and system-surface pipeline. Unsigned device Release compilation is verified in macOS CI on Xcode 16.4, Swift 6.1.2 compiler in the existing Swift 5 language mode, and the iOS 18.5 SDK. All 71 unit tests and four UI tests pass on iOS 18.5 in the same CI run. Live-account authorization and physical-device behavior still require manual verification. The local Windows workspace has no Apple toolchain.

## Architecture and capabilities

MusicProvider extends the original interface with capability descriptions, asynchronous change events and explicit disconnection. MusicSource remains a typealias, preserving existing injection sites. AppContainer retains provider instances across source switches, keeping authorization under a single lifecycle owner. PlaybackCoordinator still supplies snapshots to NowPlayingViewModel; LyricsSyncEngine is unchanged.

| Provider | Metadata and position | Change detection | Native lyric access | Controls |
| --- | --- | --- | --- | --- |
| Demo | Original local metadata; injected monotonic playback clock | Local state events and foreground snapshots | Original demo and permitted imports | Local simulation |
| Apple Music | Public system-player item/time where exposed and authorized | MediaPlayer notifications; cheap foreground position reads | No MusicKit lyrics endpoint used; separate local/licensed source required | Selected system player only |
| Spotify Web API | Authorized account's current track, not device-wide audio; nullable progress | Foreground polling; no playback event subscription | No lyrics endpoint; synchronization remains disabled by policy | Read-only adapter; no modify-playback scope |

Supported, restricted and unavailable capabilities are represented explicitly in MusicProviderCapabilities. Authorization status and current provider messages express runtime failures separately. No provider can inspect arbitrary third-party iPhone audio. The old SpotifyMusicSource App Remote class remains available for explicit injection; it is no longer the default Spotify path. Its old setup instructions do not configure the new Web API flow.

## Apple Music: actual public boundary

The adapter requests MusicKit authorization and, when needed, MediaPlayer library authorization. It uses MPMusicPlayerController.systemMusicPlayer for nowPlayingItem, playback status/time/rate, metadata, artwork and state notifications. It unregisters notifications while inactive. Metadata/artwork are cached between notifications; foreground UI ticks read playback values rather than fetching a catalog or artwork repeatedly.

MusicKit SystemMusicPlayer shares only documented Music-app state; it does not expose an unrestricted mirror of the standalone app's queue. We therefore do not infer the current standalone song from MusicKit queue.currentEntry. MediaPlayer may expose a current/designated Music item, but can also return nil, including for Home Sharing. Missing permission, item or timing produces an honest unavailable state. A paused/designated Music item is not proof of device-wide playback. See [SystemMusicPlayer](https://developer.apple.com/documentation/musickit/systemmusicplayer) and [MediaPlayer nowPlayingItem](https://developer.apple.com/documentation/mediaplayer/mpmusicplayercontroller/nowplayingitem).

ApplicationMusicPlayer manages an app's own queue independently. An app-managed queue could support a future provider through the same interface; this change does not add catalog selection, streaming setup, a developer-token issuer or subscription purchase. No Apple Music lyric data or redistribution permission is assumed. See [ApplicationMusicPlayer](https://developer.apple.com/documentation/musickit/applicationmusicplayer).

Validate real Music metadata, artwork, interruptions, seeking and permission revocation on a physical device. MusicKit/service eligibility and simulator behavior cannot be inferred from these source changes.

## Spotify setup

The primary adapter uses authorization code with S256 PKCE, a cryptographically random verifier/state, a single-use five-minute pending request, and ASWebAuthenticationSession. It requests only user-read-currently-playing and calls GET https://api.spotify.com/v1/me/player/currently-playing. No client secret or playback-modification scope is used. See [PKCE](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow) and [the playback endpoint](https://developer.spotify.com/documentation/web-api/reference/get-the-users-currently-playing-track).

Spotify now requires HTTPS redirects except for permitted loopback configurations. This app deliberately uses an owned HTTPS domain and Apple's HTTPS callback API, available from iOS 17.4. It does not fall back to an insecure/deprecated Web API custom-scheme flow. Demo and Apple Music keep the iOS 17 baseline. See [Spotify redirects](https://developer.spotify.com/documentation/web-api/concepts/redirect_uri) and [Apple's HTTPS callback requirements](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession/callback/https%28host%3Apath%3A%29).

1. Register a Spotify developer application and the exact HTTPS callback, for example https://auth.example.com/spotify/callback. Check current account/endpoint eligibility. Development mode currently requires a Premium app owner and allows up to five allowlisted users; a successful login alone does not establish API access. See [current quota modes](https://developer.spotify.com/documentation/web-api/concepts/quota-modes).
2. Control the callback domain and serve an apple-app-site-association file at /.well-known/apple-app-site-association over HTTPS, with application/json content type and no redirect. Its webcredentials.apps array must contain your actual TEAMID.bundleIdentifier. For example: `{"webcredentials":{"apps":["TEAMID.com.yourcompany.LyricsCarPlay"]}}`. Do not log authorization-code query strings at the callback route. No Spotify client secret is needed on this domain.
3. Enable Associated Domains for the app's App ID/provisioning profile, with webcredentials:your.callback.host. The opt-in entitlement files supplied below preserve App Groups and keep CarPlay audio simulator-only. The widget extension needs no Spotify domain or credential access.
4. Merge the following into gitignored Config/Local.xcconfig, retaining your existing bundle, team and App Group configuration. The `$()` insertion avoids xcconfig interpreting the URL's double slash as a comment.

```xcconfig
SPOTIFY_CLIENT_ID = your_public_client_id
SPOTIFY_AUTH_HOST = auth.example.com
SPOTIFY_REDIRECT_URI = https:/$()/auth.example.com/spotify/callback
APP_ENTITLEMENTS = LyricsCarPlay/Resources/LyricsCarPlay-Spotify.entitlements
APP_SIMULATOR_ENTITLEMENTS = LyricsCarPlay/CarPlay/CarPlay-Spotify-Simulator.entitlements
```

Default entitlements do not request an unconfigured associated domain. HTTPS callback matching is handled by the active authentication session, not a generic app-open callback. This does not configure universal links outside authorization. AASA/CDN caching, provisioning and real-domain verification require device testing. No domain, developer account or live credentials were configured by this change.

## Credential and network lifecycle

Access/refresh tokens live in the private Keychain with WhenUnlockedThisDeviceOnly protection and no shared access group or synchronization. Tokens never enter preferences, widgets, Live Activities, request URLs or logs. Browser verifier/state stay in memory. Refresh begins thirty seconds before expiry, preserves a previous refresh token if no rotation is returned, and persists rotations. An invalid_grant removes unusable credentials and requires authorization again. See [Spotify refresh behavior](https://developer.spotify.com/documentation/web-api/tutorials/refreshing-tokens).

Refresh acquisition is single-flight. Logout cancels requests and advances a generation so a late response cannot resurrect credentials. A late rejected access token cannot delete a newer authorization. Disconnect reports Keychain failures and does not claim success when deletion fails. Source changes/backgrounding stop polling but retain authorized credentials; Disconnect removes them. Account-wide Spotify grants are managed separately in Spotify. Keychain records may outlive app uninstall; use Disconnect or revoke the grant in Spotify when appropriate.

The API retries one 401 after refresh, distinguishes 403 eligibility/scope restrictions, handles 204/null/unsupported playback, and honors 429 Retry-After deadlines in both API and token clients. Network errors clear current metadata rather than present stale playback as live. The app polls every five seconds while playing, ten while paused and fifteen while idle; network/server failures retry after fifteen seconds and forbidden access after sixty. Polling stops with the active scene. There is no background monitoring guarantee.

Foreground position estimates reuse the existing PlaybackSnapshot helper and expire after seven seconds while playing or twenty while paused. Pause freezes position; seeks/new samples reset it. Network latency is not measurable sample accuracy, and Spotify's timestamp must not be treated as an exact local capture clock. Stale samples hide metadata/timing until a new response. These positions are not used for Spotify lyric synchronization.

## Matching and automatic updates

LyricsMatchingService compares title, artist, album and duration. It preserves all live/acoustic/remix/instrumental/remaster descriptors, rejects conflicting albums or durations over two seconds apart, and declines ambiguous local records. Cross-provider matching requires complete agreeing metadata; missing fields do not justify guessing. Explicitly track-bound imports take priority. Confidence is a conservative heuristic or exact binding, not audio verification: 1.0 for an import means the user bound it to that track; for an ID-based configured provider it means provider-asserted identity. Source/attribution and confidence appear in the iPhone UI.

Imports remain session-only and sharing permission defaults to absent. Removing a cross-provider match removes its original import binding. Original bundled demo data can match its own complete metadata without credentials. LyricsCatalog is a protocol for future local/licensed candidates; the existing LyricsProvider remains the authorized ID-based adapter. No scraped search or vendor lyrics endpoint is invented.

Track identity or relevant metadata changes cancel old lyric work, rematch, prepare the existing engine, and update iPhone/shared-widget/activity state through the existing callback. Matching/cache keys include metadata so a corrected version under the same provider ID cannot reuse an earlier document. Artwork-only changes do not refetch lyrics. Spotify is blocked at both the view model and coordinator: [Spotify's endpoint policy](https://developer.spotify.com/documentation/web-api/reference/get-the-users-currently-playing-track) does not authorize this app to synchronize recordings with lyrics or provide a public lyrics endpoint.

## Verification

New SpotifyWebIntegrationTests, LyricsMatchingServiceTests and MusicProviderEventTests use fake HTTP, token stores and providers. They cover PKCE, bad state/denial, expired and rotating tokens, single-flight refresh, logout races, no playback, nullable progress, pause, one 401 retry, forbidden access, API/token rate limits, offline transport, position expiry/drift, incorrect/ambiguous versions, source info, import removal and metadata-sensitive cache/rematching. Existing synchronization, surface and Demo tests remain in place.

Run `bash scripts/verify_on_mac.sh` on a Mac with a matching SDK. Then test real authorization, Keychain persistence across relaunch, cancellation/source switches, device lock, refresh/revocation, Spotify playback on another account device, Apple Music missing-item cases, and the widget/activity handoff. Signed/live-account checks remain manual. The [passing macOS CI run](https://github.com/smptr0911/Lyrics-carplay-app/actions/runs/43941873382) verifies unsigned device Release compilation, 71 unit tests and four UI tests on iOS 18.5; it does not verify account/domain provisioning or real vehicle behavior.

The installed SDK inspection is reproducible with scripts/inspect_apple_sdk.py. The preserved App Remote SDK currently emits actor-isolation migration warnings in Swift 5 mode; full Swift 6 language migration remains a separate task. The primary Web API path does not use that legacy delegate.
