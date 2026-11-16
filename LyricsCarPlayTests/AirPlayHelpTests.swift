import XCTest
@testable import LyricsCarPlay

@MainActor
final class AirPlayHelpTests: XCTestCase {
    func testGuideDoesNotLaunchAnythingOrAssertVehicleEligibility() {
        let opener = Opener(results: [])
        let model = AirPlayHelpViewModel(opener: opener)
        XCTAssertEqual(model.compatibility, .unknown)
        XCTAssertTrue(opener.calls.isEmpty)
        XCTAssertFalse(model.isOpening)
        XCTAssertNil(model.errorMessage)
    }

    func testInstalledUniversalLinkHandlerOpensWithoutFallback() async {
        let opener = Opener(results: [true])
        let model = AirPlayHelpViewModel(opener: opener)
        await model.openYouTube()
        XCTAssertEqual(opener.calls.map(\.universalLinksOnly), [true])
        XCTAssertEqual(opener.calls.first?.url.absoluteString, "https://www.youtube.com/")
        XCTAssertNil(model.errorMessage)
    }

    func testMissingYouTubeOrUnassociatedLinkFallsBackToWebsite() async {
        let opener = Opener(results: [false, true])
        let model = AirPlayHelpViewModel(opener: opener)
        await model.openYouTube()
        XCTAssertEqual(opener.calls.map(\.universalLinksOnly), [true, false])
        XCTAssertTrue(opener.calls.allSatisfy { $0.url == AirPlayHelpViewModel.youtubeURL })
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isOpening)
    }

    func testFailedLaunchShowsRecoverableErrorAndRetryClearsIt() async {
        let opener = Opener(results: [false, false, true])
        let model = AirPlayHelpViewModel(opener: opener)
        await model.openYouTube()
        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(model.isOpening)
        await model.openYouTube()
        XCTAssertNil(model.errorMessage)
    }

    func testUnsupportedVehicleHelpDoesNotPromiseToEnableVideo() {
        XCTAssertTrue(AirPlayCompatibilityInfo.unsupportedVehicle.explanation.contains("cannot enable"))
        XCTAssertTrue(AirPlayCompatibilityInfo.unknown.explanation.contains("cannot check"))
    }

    func testUnavailableAirPlayHelpExplainsSeparatePlaybackSession() {
        XCTAssertTrue(AirPlayCompatibilityInfo.airPlayUnavailable.explanation.contains("inside YouTube"))
        XCTAssertTrue(AirPlayCompatibilityInfo.airPlayUnavailable.explanation.contains("cannot create an output"))
        XCTAssertEqual(AirPlayCompatibilityInfo.steps.count, 6)
    }

    private final class Opener: ExternalURLOpening {
        var results: [Bool]
        var calls: [(url: URL, universalLinksOnly: Bool)] = []
        init(results: [Bool]) { self.results = results }
        func open(_ url: URL, universalLinksOnly: Bool) async -> Bool {
            calls.append((url, universalLinksOnly))
            return results.isEmpty ? false : results.removeFirst()
        }
    }
}
