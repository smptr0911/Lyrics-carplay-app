# CarPlay simulator and device validation

Reviewed 2026-11-16. Earlier claims in this file about a locally inspected Xcode 27.2 installation and a particular connected iPhone have been removed: they are not verified evidence for this session. Local authoring is Windows. The macOS CI toolchain and menu-probe result belong in [the integration record](INTEGRATION_TESTING.md).

## Standard iOS Simulator external display

[Apple's official instructions](https://developer.apple.com/documentation/carplay/using-the-carplay-simulator) describe running an iPhone simulator from Xcode, then choosing **I/O > External Displays > CarPlay** in the Simulator application's menu bar. The article describes an 800 x 480, @2x window, entitlement requirements for CarPlay-category apps, and limitations around real locked-device, Siri and audio testing.

The project preserves a **CarPlay Simulator** scheme with a simulator-only template-navigation prototype. Choose that scheme and an installed iPhone simulator, run it, then look for the documented menu. It explores original demo library/detail templates; it does not implement full-screen lyrics, native vehicle video or production playback controls. Physical builds do not enable that scene or its simulator-only audio entitlement.

The primary **LyricsCarPlay** scheme builds the app and widget extension. Use that scheme for normal development. A template-preview build does not verify widget selection or Live Activities in CarPlay. In particular, an iOS 18.5 simulator cannot validate iOS 26 CarPlay widget/activity behavior.

Verify the actual menu, rather than assuming the documentation applies to every installed version:

```sh
python3 scripts/inspect_development_environment.py --probe-simulator-menu
```

The script records selected Xcode, SDKs, available runtimes, schemes and resolved signing settings. It opens the verified installed Simulator bundle and attempts the documented menu hierarchy through public macOS accessibility automation. If automation, localization, the menu or a usable UI session is unavailable, it records **UNVERIFIED**. That is not proof the feature is missing. Do not add private defaults flags, invented tool paths or entitlements to manufacture a missing menu. Manually inspect the selected Simulator version and keep a screenshot/result in your test record. The optional probe may need macOS Accessibility/Automation permission; it does not request or grant that permission itself.

## Standalone CarPlay Simulator / Additional Tools

Apple's [CarPlay Developer Guide](https://developer.apple.com/download/files/CarPlay-Developer-Guide.pdf) documents the separate Mac app in the **Hardware** folder of **Additional Tools for Xcode**. Unlike the standard iOS Simulator display, it connects to a real USB iPhone.

1. Sign in to [Apple Developer More Downloads](https://developer.apple.com/download/all/?q=Additional%20Tools%20for%20Xcode), locate Additional Tools for the intended Xcode generation and read its release notes/system requirements. Apple's public CarPlay material documents the package, but the authenticated listing and a package installation were unavailable to this session.
2. For the new iOS 26 CarPlay widget/activity experience, use an iOS 26+ iPhone and a compatible modern Additional Tools package; the iOS 18.5 CI runtime cannot establish this compatibility. Additional Tools for Xcode 26 is a documented generation associated with that experience. Do not assume that package runs on every Mac or is compatible with Xcode 16.4. **No exact Additional Tools build/package compatibility was verified here.**
3. Download and mount the selected disk image. Locate **CarPlay Simulator** in **Hardware** and launch that app from the actual downloaded location (or a location you copy it to). No fixed `/Applications` installation path is required or asserted.
4. Connect and unlock the iPhone over USB, trust the Mac and follow the tool's connection UI. Install the signed app from Xcode first; Developer Mode is required for development builds. Verify the actual tool/iOS pairing before collecting results.
5. Inspect supported display configurations and CarPlay widgets/activities, then repeat on physical vehicle/head-unit hardware. Account permissions, provisioning and vehicle support remain independent checks.

For Xcode 27, Apple's guide also documents **Device Hub**: select the USB iPhone, then choose CarPlay Simulator from Device. This path was not exercised here and is not claimed to exist in Xcode 16.4. Apple's WWDC26 session directs video developers to the standalone Additional Tools simulator. These version-specific paths must not be conflated.

## Real iPhone and vehicle

Configure your own signing team, app/extension IDs and App Group before installing. Use the normal **LyricsCarPlay** scheme. No production CarPlay app-category entitlement is added for widgets, Live Activities or the AirPlay guide. Native category/template integration would require separate eligibility and Apple approval.

Use a compatible vehicle or powered aftermarket head unit. Apple recommends wireless CarPlay where possible so an iPhone can stay connected to Xcode for debugging. Test locked/unlocked behavior, audio interruptions, permissions, physical presentation and actual timing; a simulator is not the sole acceptance environment. Video additionally requires manufacturer-supported parked video and enforcement by iOS/vehicle. The app never infers parked eligibility or provides an override.

## Evidence status

- Standard external-display menu: public accessibility automation verified **I/O > External Displays > CarPlay** on the CI runner's selected Xcode 16.4 Simulator. Automated menu existence does not mean a CarPlay session/presentation was tested. See the exact environment evidence in the integration record.
- Standalone Additional Tools simulator and Xcode 27 Device Hub: not installed or exercised here; exact package compatibility unverified.
- Signed iPhone, CarPlay widget selection/rendering, Dashboard Live Activity, vehicle AirPlay output: not exercised here.
- App/extension builds, unit/UI tests and source/repository checks: see [integration verification](INTEGRATION_TESTING.md).

[CarPlay developer overview](https://developer.apple.com/carplay/) and [WWDC26 simulator discussion](https://developer.apple.com/videos/play/wwdc2026/212/) provide the official version-specific context.
