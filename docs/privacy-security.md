# Privacy and security

The Demo source does not require a music account, contact a server or collect analytics. Fresh installations default to Demo; saved source choices are preserved. Explicitly permitted demo snapshots may now be persisted for system surfaces, as described below. Spotify connects only after an explicit user action. Apple Music usage text is included for the future opt-in adapter; it is not invoked on launch. No provider credentials are bundled.

Before release, audit actual networking and data retention, add required privacy disclosures/manifests for the final APIs and SDKs, use appropriate credential storage, and avoid logging tokens or lyrics payloads. Do not enable background audio solely to keep lyric polling alive.

The optional Video tab connects to the HTTPS URL supplied by the user and may follow server redirects through AVPlayer. Stream hosts receive normal connection information. URLs are held in memory only; no browsing history or downloads are saved by the app. OS media buffering and AirPlay routing are system-managed.

Music app selection and theme are stored in UserDefaults. Spotify App Remote authentication and playback communicate with Spotify after the user connects; the SDK may require network access. Legacy App Remote access tokens remain in memory. The primary Web API adapter stores access/refresh tokens in private WhenUnlockedThisDeviceOnly Keychain items, isolated from widgets; Disconnect removes stored credentials and reports failures. No vendor secret is bundled; the configured Spotify Client ID is public.

The app now bundles a privacy manifest declaring its local UserDefaults preference use (CA92.1). The app itself has no analytics/tracking. The Spotify SDK has its own manifest, and final Archive/App Store data disclosures must still be audited against actual service behavior. The in-app privacy screen explains source/theme/onboarding preferences, ephemeral tokens, cache deletion and external connections.

## System surfaces

The app writes one expiring metadata/lyric snapshot to a shared App Group file, excluded from backup and protected until first unlock. Only lyrics with explicit system-surface permission are included; imports and unconfigured API permissions default to exclusion. ActivityKit may retain payloads after expiry even though the UI hides stale text. Cleanup is eventual and contracts must permit that retention. There are no credentials in shared data. See [surface storage and lifecycle details](WIDGETS_AND_LIVE_ACTIVITIES.md).

Spotify Web API browser authorization uses PKCE and an associated HTTPS domain. Only a read-only currently-playing scope is requested. The app does not log callbacks or tokens, store client secrets, or poll the Web API in the background. Keychain records may persist across reinstall; revoke the grant in Spotify or use Disconnect to remove credentials. See [authorization details](MUSIC_PROVIDERS.md).
