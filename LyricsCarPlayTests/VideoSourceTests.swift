import XCTest
@testable import LyricsCarPlay

final class VideoSourceTests: XCTestCase {
    func testAcceptsTrimmedHTTPSAndSignedStreams() {
        let source = VideoSource(text: "  https://example.com/video.m3u8?token=abc  ")
        XCTAssertEqual(source?.url.absoluteString, "https://example.com/video.m3u8?token=abc")
    }
    func testRejectsInvalidAndCredentialURLs() {
        for text in ["", "not a URL", "http://example.com/movie.mp4", "file:///movie.mp4", "https:///", "https://user:secret@example.com/movie.mp4"] {
            XCTAssertNil(VideoSource(text: text), text)
        }
    }

    func testRecognizesYouTubePagesAsExternalWebPages() {
        XCTAssertTrue(VideoSource(text: "https://youtu.be/example")?.isWebPage == true)
        XCTAssertTrue(VideoSource(text: "https://www.youtube.com/watch?v=example")?.isWebPage == true)
        XCTAssertFalse(VideoSource(text: "https://cdn.example.com/video.mp4")?.isWebPage == true)
    }
}
