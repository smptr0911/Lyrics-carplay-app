# Changelog

## Unreleased

- SwiftUI app with persisted source selection, appearance, onboarding and privacy controls.
- Spotify App Remote metadata, playback controls and authorization/lifecycle integration; lyrics gated by source policy.
- Apple Music SystemMusicPlayer adapter with permission-aware metadata, playback and seek.
- Original demo lyrics, prepared timed-line search, stale-request cancellation and bounded policy-aware cache.
- Injectable lyrics HTTP client with response limits, same-origin redirects and debug-simulator localhost support.
- Local demo-only backend with provider interface, input validation, no-store responses and HTTP integration tests.
- Native video playback, AirPlay picker, loading timeout, interruption/route handling and explicit lifecycle cleanup.
- Simulator-only CarPlay library/detail template prototype.
- macOS simulator/device compilation workflow, source handoff package and release checklist.

Build/device caveat: Windows structural and backend checks are separate from the still-required Xcode, iPhone and vehicle verification. No production provider agreement, CarPlay approval, backend deployment or App Store release is included.
