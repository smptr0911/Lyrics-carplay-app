# Development workflow

The upstream repository uses two development branches based on `main`:

- `development/mac-xcode`: SwiftUI, Xcode, iOS Simulator, unsigned device builds, and CarPlay Simulator work.
- `development/windows-validation`: Python validation, backend tests, documentation, and platform-independent maintenance.

Keep changes on the matching branch. Do not copy source files between computers; push the branch and pull it on the other machine when a change is intentionally shared. Merge completed work into `main` through a pull request so CI remains the integration gate.

Backend, structural, and whitespace checks run on both branches. The Mac-only iOS workflow runs on `main`, `development/mac-xcode`, and pull requests; direct pushes to `development/windows-validation` do not consume a macOS runner.

## Mac/Xcode workflow

1. Install Xcode, select it with `xcode-select`, and install an iOS 17 or newer simulator runtime.
2. Clone the repository and check out `development/mac-xcode`.
3. Configure `Config/Local.xcconfig` from the example when Spotify, signing, or a local lyrics endpoint is needed. Never commit secrets.
4. Run `python3 scripts/validate_project.py --xcode`.
5. Run `bash scripts/verify_on_mac.sh`; fix the first Swift or test failure before continuing.
6. Open `LyricsCarPlay.xcodeproj`, run the `LyricsCarPlay` scheme on an iPhone simulator, and manually verify Demo, lyrics sync, settings, video validation, and accessibility.
7. Use the `CarPlay Simulator` scheme for the documented simulator-only navigation preview.
8. Configure a real bundle identifier and development team, then test on an iPhone. Spotify and Apple Music require their documented account and entitlement setup.
9. Commit focused changes, push `development/mac-xcode`, and open a pull request to `main`.

## Windows validation workflow

1. Check out `development/windows-validation`.
2. Run `python scripts/validate_project.py`.
3. Run `python -m unittest discover -s backend/tests -v`.
4. Review documentation links, backend contract changes, and repository configuration.
5. Do not claim an iOS build or device test from Windows; leave that validation to the Mac branch/CI.
6. Commit focused changes, push `development/windows-validation`, and open a pull request to `main`.

## Ordered product steps from here

1. Complete the Mac simulator run and fix any Xcode or UI regressions.
2. Verify Demo behavior on a physical iPhone, including permissions, lifecycle, scrolling, Dynamic Type, VoiceOver, and reduced motion.
3. Create and configure the Spotify developer app, then test connection, callback, playback controls, reconnection, and authorization removal.
4. Configure Apple Music capabilities and validate the system-player path with an eligible account and subscription.
5. Confirm lyrics licensing, provider retention, matching, cancellation, offline behavior, and production backend requirements.
6. Finish CarPlay eligibility and template review with Apple; keep the simulator prototype conditional until approved.
7. Validate parked-video rights, supported formats, AirPlay routing, and vehicle restrictions.
8. Complete privacy, signing, security, performance, and release checks.
9. Run device/vehicle tests, TestFlight, policy review, and final App Store submission checks.
