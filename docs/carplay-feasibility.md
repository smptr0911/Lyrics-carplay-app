# CarPlay feasibility review

Reviewed: 2026-11-12. Scope: Phase 0's first task, reviewing current categories and entitlement requirements. This is a documentation review, not entitlement approval or a completed Phase 0 milestone.

## Current categories and integration paths

Apple's [CarPlay overview](https://developer.apple.com/carplay/) currently describes audio, video when parked in supported cars, messaging/VoIP, navigation, EV charging, fueling, parking, public safety, quick food ordering, voice-based conversation, and driving-task apps. It also describes widgets and Live Activities as separate integration paths. These options have different requirements; they are not interchangeable ways to obtain an arbitrary head-unit interface.

| Path | Relevance to Lyrics CarPlay |
| --- | --- |
| Audio | Candidate only if the product becomes an eligible audio app. A lyrics companion is not automatically eligible because it relates to music. |
| Communication, navigation, and driving-related services | The current lyrics product does not establish a fit. Do not request an unrelated category merely to display text. |
| Parked video | A distinct supported-car experience; it does not establish permission for a lyrics interface during driving. |
| Widgets / Live Activities | A separate future investigation for suitable glanceable content. Their availability does not validate scrolling lyrics. |

The fit assessments above are project conclusions, not Apple eligibility decisions. OS/device availability and category-specific rules still need checking before selecting any path.

## Entitlement requirements

Apple's [Requesting CarPlay Entitlements](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements) requires a category-specific request and agreement to the CarPlay Entitlement Addendum. Apple evaluates the application and grants qualifying capabilities to the developer account.

After approval, enable the capability for the App ID, generate a matching provisioning profile, and configure the target's entitlements and signing. The entitlement file must match granted capabilities. Adding a Boolean in a plist alone does not grant access. Apple also identifies additional CarPlay review requirements.

The documented audio entitlement is `com.apple.developer.carplay-audio`. The article also lists communication, charging, navigation, parking, and quick-ordering keys. Its table is narrower than the current overview's category list; do not treat it as an exhaustive list of current categories or guess missing keys. Consult the selected category's current documentation when implementing it.

No request has been submitted, account capability verified, or approval received as part of this work.

## Interface constraints relevant to lyrics

Apple's [CarPlay design guidelines](https://developer.apple.com/design/human-interface-guidelines/carplay) describe category-appropriate system templates, rendered by iOS, and brief interactions suitable for driving. They also require usable interactions while the phone is locked and errors handled on the car display rather than directing someone to pick up the phone.

The [CPNowPlayingTemplate API](https://developer.apple.com/documentation/carplay/cpnowplayingtemplate) documents a shared playback interface using Now Playing metadata, controls, album/artist information, and Up Next. Its documented surface does not establish a scrolling-lyrics interface. The page identifies the audio entitlement as a requirement.

Project inference: the reviewed APIs do not establish an approved implementation for this product's proposed continuous lyric reading. A list template's ability to show text is insufficient evidence that repurposing it for lyrics is permitted. Do not encode lyrics as track titles, artwork, or video to work around the intended interface.

## Decision and remaining gates

Proceed with the independent iPhone demo. Hold CarPlay lyrics implementation pending a supported interaction design and eligibility confirmation from Apple. This is an engineering hold, not a claim that Apple has rejected the app or that every future parked/passenger experience is impossible.

Before implementing CarPlay:

- Define whether the product is an audio player or solely a lyrics companion.
- Map each proposed interaction to a documented category and supported template; investigate parked experiences separately if desired.
- Review category-specific guidance and the full current developer guide, including distribution requirements. The linked guide PDF could not be retrieved by the research tool during this review, so no claim of a full guide review is made.
- Obtain an Apple eligibility decision through the [CarPlay request process](https://developer.apple.com/contact/carplay), then record the response and granted capability.
- Confirm lyrics licensing covers the exact platform and use, and validate on supported hardware.

The next roadmap task is the detailed feature-to-template assessment. Music-source validation, provider selection, and the final M0 go/no-go decision remain open. This review does not authorize production CarPlay capability. The later simulator-only template prototype is described below.

## Added parked-video path

The [parked video implementation](parked-video.md) adds iPhone playback and AirPlay output for compatible vehicles. This does not change the hold on continuous CarPlay lyrics or add native head-unit video browsing. Vehicle output and restriction behavior still require hardware validation.

## Simulator template exploration

A [simulator-only scene and template prototype](carplay-simulator.md) is now configured for developer testing. It lists the original demo track and static metadata. Its audio entitlement and manifest are selected only for the simulator SDK, and the delegate is compiled only for simulator. Production eligibility remains pending; device builds do not include the CarPlay scene or entitlement. No head-unit lyrics, real playback, or video browsing was added by this prototype.
