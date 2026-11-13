# CarPlay simulator prototype

The simulator-only scene delegate and list templates let a developer browse the demo track and its metadata in CarPlay. See [Mac setup](../../docs/carplay-simulator.md).

The simulator SDK selects a dedicated scene manifest and audio entitlement file. Physical-device builds and archives keep the original iPhone manifest and do not acquire CarPlay entitlements. This prototype neither claims Apple approval nor implements head-unit lyrics, audio playback, or native parked-video browsing. The production eligibility gate remains in [the feasibility review](../../docs/carplay-feasibility.md).
