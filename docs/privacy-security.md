# Privacy and security

The Demo source does not request permissions, contact a server, collect analytics, or persist lyrics. The default selected source is Spotify, which connects only after an explicit user action. Apple Music usage text is included for the future opt-in adapter; it is not invoked on launch. No provider credentials are bundled.

Before release, audit actual networking and data retention, add required privacy disclosures/manifests for the final APIs and SDKs, use appropriate credential storage, and avoid logging tokens or lyrics payloads. Do not enable background audio solely to keep lyric polling alive.

The optional Video tab connects to the HTTPS URL supplied by the user and may follow server redirects through AVPlayer. Stream hosts receive normal connection information. URLs are held in memory only; no browsing history or downloads are saved by the app. OS media buffering and AirPlay routing are system-managed.

Music app selection and theme are stored in UserDefaults. Spotify App Remote authentication and playback communicate with Spotify after the user connects; the SDK may require network access. Access tokens remain in memory and are discarded on source replacement/process exit. No vendor secret is bundled; the configured Spotify Client ID is public.

The app now bundles a privacy manifest declaring its local UserDefaults preference use (CA92.1). The app itself has no analytics/tracking. The Spotify SDK has its own manifest, and final Archive/App Store data disclosures must still be audited against actual service behavior. The in-app privacy screen explains source/theme/onboarding preferences, ephemeral tokens, cache deletion and external connections.
