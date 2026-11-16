# Implementation plan

Current scope, 2026-11-16. This plan supersedes older Spotify-first priorities and historical bootstrap checklists. The project already exists and must be extended in place.

## 1. Foundation ? implemented, Apple build verification pending

Reuse existing models, protocols, mock providers, MVVM composition, SwiftUI screen, XCTest targets, and original timed demo. Default fresh installs to Demo and preserve saved preferences. Inject a monotonic mock playback clock. Add deterministic synchronization and adjacent-line projection tests. Add an external YouTube AirPlay guide. Run available structural/backend checks; record Xcode testing separately.

## 1a. Synchronized lyrics engine - implemented, Swift verification pending

Codable playback/timing models, stable line IDs, explicit end ranges, a prepared binary-search engine, adjacent-line statuses, offset/rate support, duplicate update suppression, session-only LRC import, foreground focus UI, and automated edge-case tests are now implemented. The configurable future API accepts end times and an injected secure-credential interface. Run the new and existing Swift suites on a Mac before declaring this milestone verified.

## 2. Apple Music and licensed lyrics

Validate the existing SystemMusicPlayer adapter on a signed physical device, including permissions, queue changes, playback time, pause, seek, and foreground resumption. Obtain a lyrics provider contract that permits the intended surfaces, caching, and attribution. Apple Music access does not provide lyric redistribution rights. Review lifecycle cancellation and adapter concurrency before enabling Swift 6 language mode. Keep demo independent of credentials and networking.

## 3. WidgetKit, ActivityKit, and App Groups - source implemented, Apple validation pending

Use installed Xcode SDK interfaces and official Apple guidance to add one widget extension in the existing project, with small-widget and appropriate Live Activity presentations. Provision a common App Group, implement a protocol-based atomic snapshot store, and test it with mocks. Include stale/expired states and rights-aware persistence. Add Activity authorization, lifecycle management, and conservative update scheduling. Validate the system's small CarPlay presentation and choose an appropriate low-density design. No per-second refresh guarantee or production CarPlay audio entitlement is required for this work.

## 4. Authorized Spotify metadata

Preserve the existing App Remote adapter while evaluating Spotify Web API metadata access using authorization code with PKCE, Keychain token storage, token refresh, rate limits, and mocked transport tests. Do not embed a client secret. Web API support is not currently implemented. Review Spotify policy before changing the current lyrics block; metadata authorization alone is insufficient.

## 5. Device and release validation

Run simulator unit/UI tests, unsigned Release builds, signed App Group checks, and physical music/CarPlay/AirPlay tests. Evaluate supported iOS versions, locked-phone behavior, data retention, accessibility, and power use. Keep YouTube playback external and use the guide when no supported route exists. Never infer parking or override vehicle restrictions.

## Unresolved gates

No local Xcode SDK is available. Swift 6 compatibility, extension APIs, provisioning, refresh behavior, vehicle support, YouTube route availability, production lyrics rights, Spotify Web API authorization, and real-device MusicKit behavior remain unverified. These are explicit next steps, not implemented features.

## System surface status

The embedded extension, small widget, standard/small Live Activity, shared repository, lifecycle controller and mocked tests are implemented. Xcode compilation, previews, signed App Group access and CarPlay Simulator/device validation remain required. See [current implementation and test matrix](WIDGETS_AND_LIVE_ACTIVITIES.md).

## Music integration implementation

Reusable capability/event interfaces, public Apple Music system metadata, primary Spotify Web API PKCE/refresh/Keychain support, conservative local lyric matching, metadata-sensitive rematching and mocked tests are implemented in source. Spotify remains read-only and lyric synchronization remains blocked by policy. Owned-domain/provisioning setup and signed live-account tests are still required. See [current provider implementation](MUSIC_PROVIDERS.md).
