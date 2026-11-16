# Widgets and Live Activities

## Implementation status

The original project had three targets and reusable shared models, but no widget extension, Live Activities, or App Groups. The new embedded LyricsWidgets target preserves those targets. Source and project wiring are implemented; compilation, previews, signing, and CarPlay rendering remain unverified because this Windows workspace has no Xcode, Apple SDK, or Swift compiler.

The baseline remains iOS 17 and Swift 5 language mode. The documented supplemental small family uses iOS 18 APIs, guarded for availability, and requires Xcode 16 or newer. iOS 17 retains standard Lock Screen/Dynamic Island presentations. CarPlay widget/Live Activity testing needs iOS 26 or newer and compatible tools/hardware. No new CarPlay entitlement or full-screen interface was added. The old audio entitlement remains simulator-only.

## Configure signing

Config/App.xcconfig defines `LYRICS_APP_GROUP = group.$(APP_BUNDLE_IDENTIFIER)`. This is an identifier template, not a registered App Group. In gitignored Config/Local.xcconfig set a unique APP_BUNDLE_IDENTIFIER and a real LYRICS_APP_GROUP registered to your developer team. Configure your development team in Xcode. Enable the same group on the app and extension App IDs and regenerate their provisioning profiles. The extension bundle ID appends .LyricsWidgets to the app ID.

Both target entitlements contain the group; both Info plists expose LyricsAppGroup. The app's simulator entitlement merges it with the existing simulator-only audio entitlement. Both app Info variants enable NSSupportsLiveActivities. There is no APNs or frequent-push configuration.

Missing shared storage produces an explicit message; there is no fallback to private defaults or fake live demo data. Live Activity updates use ActivityKit independently of the shared file. Cross-process access still requires validation on a signed device.

## Shared data and permission

SharedLyricsSnapshot carries bounded track/text/attribution, playback position/rate/state, offset, capture time, expiry, status and schema version. The app is the single writer. AppGroupLyricsRepository performs atomic JSON replacement, backup exclusion and bounded reads. File protection allows reads while locked after the first unlock following restart; verify that privacy tradeoff on device.

LyricsDocument.surfaceSharingUntil explicitly authorizes system surfaces separately from cacheUntil. Original demo lyrics grant this permission. Imports and API responses without it share metadata but no lyric text. Production providers must review the small surface's attribution/truncation and retention behavior before granting permission. Spotify remains excluded by the existing policy gate.

Expiry is the earliest of thirty seconds, permission expiry, the adjusted lyric boundary, and remaining track duration. Paused content also has a short freshness window. Expired presentation redacts the lyric. Physical removal of file bytes or system-retained ActivityKit payloads is eventual, not guaranteed at expiry, especially after process termination. Contracts must permit that retention; the code does not promise exact deletion timing.

## Scheduling and lifecycle

The foreground iPhone engine remains authoritative. A serialized controller coalesces content changes, seeks, rate/offset changes, and ten-second freshness heartbeats. It does not write at each UI tick. Line-only widget reload requests are coalesced to one per minute; track/status/transport transitions request a reload immediately. Those intervals are app policy, not delivery guarantees.

The widget timeline contains the snapshot and an expiry entry, with a requested refresh after fifteen minutes. It never queues predicted lyric lines. Both reload requests and timeline rendering remain system-controlled.

Settings offers explicit Start/End Live Activity actions. Start checks authorization and foreground state. Tracks update dynamic content in the same session; pause updates state; stopped/missing playback ends activities. Existing sessions can be recovered. Dismissal does not automatically restart an activity. Leaving the active scene sends a suspended, redacted snapshot; foreground return refreshes an existing activity. Suspension may interrupt the final update, so expiry and staleDate are fallbacks. There is no background timer, artificial audio session, background execution mode, or push server.

## Platform investigation

WidgetKit uses dynamic budgets; Apple describes typical frequently viewed budgets of 40-70 reloads daily and foreground/Now Playing exemptions. This companion cannot claim to be the music player merely to obtain an exemption. Even exemptions provide no delivery SLA. See [WidgetKit refresh guidance](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date).

ActivityKit accepts app updates when execution time is available or authorized pushes. It does not grant continuous background runtime. No guaranteed per-line interval exists for the remote CarPlay presentation. Forwarding/rendering may be reduced or coalesced. Content includes staleDate and stays bounded below the combined 4 KB static/dynamic limit. See [ActivityKit lifecycle](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities) and [Apple's team Q&A](https://developer.apple.com/news/?id=qpqf1gru).

Therefore reliable karaoke timing every few seconds on CarPlay is not a supported promise. This is an engineering conclusion from execution and scheduling restrictions, not an Apple endorsement of a lyric-heavy design.

The widget uses systemSmall, semantic colors, default contextual margins, removable background, bounded line counts and tail truncation. The activity supports the supplemental small family used by CarPlay/Watch, plus standard Lock Screen/Dynamic Island views. No widget deep link or interactive Live Activity control assumes that tapping launches a CarPlay app. See [widget guidance](https://developer.apple.com/documentation/widgetkit/adding-standby-and-carplay-support-to-your-widget), [CarPlay presentations](https://developer.apple.com/videos/play/wwdc2025/216/), and [small-family example](https://developer.apple.com/videos/play/wwdc2024/10068/).

## Verification still required

1. On Mac, record Xcode/SDK versions and run `bash scripts/verify_on_mac.sh`. Inspect installed interfaces for supplementalActivityFamilies and activityFamily. Unsigned compilation does not validate provisioning.
2. Open LyricsWidget previews: systemSmall, light/dark, loading, long text and expiry. Verify background removal and margins in real system contexts, plus accessibility sizes.
3. Preview Lock Screen/Dynamic Island and the iOS 18+ small activity family. Use Demo, press Play, then Settings > CarPlay > Start Live Activity. Verify permission denial, pause, seek, rate/offset, track changes, missing text, End, and user dismissal.
4. On a signed device verify shared-file access after first unlock. Background/lock the app and check suspended/stale presentation. Reopen and check refreshed state.
5. Use Apple's CarPlay Simulator from Additional Tools for Xcode with a compatible iPhone, then a physical vehicle. This is distinct from the repository's CPTemplate simulator prototype. Inspect Dashboard activities, widgets, small-family layout, truncation, contrast and background removal. Measure actual update delays without treating observations as guarantees.

LyricsSurfaceTests cover mocked lifecycle, tracks, pause, suspension/resumption, denial/dismissal, coalescing, refresh policy, permissions, expiry, payload bounds, atomic storage and corrupt data. Added Swift tests remain unrun here. Structural validation, OpenStep parsing, and Swift grammar parsing pass; these do not compile Apple APIs. The ten backend tests pass independently.
