# Integration status

- MockMusicSource and MockLyricsProvider provide a local, original 30-second demo.
- AppleMusicSource now reads SystemMusicPlayer song metadata, artwork URL, state and finite playback position; it implements authorization, play/pause and seeking. Configure the App ID MusicKit App Service and verify supported queue/account behavior on device. It does not observe arbitrary third-party apps.
- LicensedLyricsProvider implements an injectable HTTPS JSON client for the [app-owned backend contract](backend-contract.md), including status mapping, cancellation, input validation, attribution and cache metadata. Without an injected endpoint it throws a configuration error. No backend, vendor account, authentication, or live API is included.

Before enabling a provider, document authentication, track IDs, attribution, territorial rights, rate limits, cancellation, error mapping, and reliable position capabilities. Put confidential vendor credentials behind a backend, never in the app bundle. Music access alone does not license lyric display.

SpotifyMusicSource now implements the official App Remote integration with a persisted user-selected music app. See [Spotify setup and policy limitations](spotify-integration.md). A configured Client ID and physical iPhone are required. Spotify lyrics requests are blocked. The default source is now Spotify; choose Demo for local previews.
