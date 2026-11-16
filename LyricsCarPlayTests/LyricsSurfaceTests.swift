import ActivityKit
import XCTest
@testable import LyricsCarPlay

@MainActor
final class LyricsSurfaceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000)

    actor Repository: SharedLyricsRepository {
        var values: [SharedLyricsSnapshot] = []
        func load() -> SharedLyricsSnapshot? { values.last }
        func save(_ snapshot: SharedLyricsSnapshot) { values.append(snapshot) }
        func clear() { values = [] }
    }

    final class ActivityClient: LyricsActivityClient {
        var hasActivity = false
        var starts: [SharedLyricsSnapshot] = []
        var updates: [SharedLyricsSnapshot] = []
        var ends = 0
        var denied = false
        func start(_ snapshot: SharedLyricsSnapshot) throws {
            if denied { throw LyricsSharingError.groupUnavailable }
            hasActivity = true; starts.append(snapshot)
        }
        func update(_ snapshot: SharedLyricsSnapshot) async { updates.append(snapshot) }
        func end() async { hasActivity = false; ends += 1 }
    }

    private func snapshot(_ id: String = "first", at date: Date? = nil, state: SurfacePlaybackState = .playing) -> SharedLyricsSnapshot {
        SharedLyricsSnapshot(trackID: id, title: id, lyricLine: "Original fixture", playbackState: state,
            status: .ready, updatedAt: date ?? now, expiresAt: (date ?? now).addingTimeInterval(5))
    }

    func testActivityStartsOnlyByRequestUpdatesTrackAndPauseAndEnds() async {
        let activity = ActivityClient()
        let repository = Repository()
        var reloads = 0
        let controller = LyricsSurfaceController(repository: repository, activity: activity, reloadWidget: { reloads += 1 })
        controller.setForeground(true)
        controller.receive(snapshot())
        await controller.waitForPendingUpdates()
        XCTAssertTrue(activity.starts.isEmpty)
        controller.startActivity()
        await controller.waitForPendingUpdates()
        XCTAssertEqual(activity.starts.count, 1)
        controller.receive(snapshot("second", at: now.addingTimeInterval(1)))
        await controller.waitForPendingUpdates()
        XCTAssertEqual(activity.updates.last?.trackID, "second")
        controller.receive(snapshot("second", at: now.addingTimeInterval(2), state: .paused))
        await controller.waitForPendingUpdates()
        XCTAssertEqual(activity.updates.last?.playbackState, .paused)
        controller.endActivity()
        await controller.waitForPendingUpdates()
        XCTAssertFalse(activity.hasActivity)
        XCTAssertFalse(controller.activityRequested)
        XCTAssertGreaterThanOrEqual(reloads, 3)
    }

    func testBackgroundRedactsLineAndForegroundResumesExistingActivity() async {
        let activity = ActivityClient()
        let repository = Repository()
        let controller = LyricsSurfaceController(repository: repository, activity: activity, reloadWidget: {})
        controller.setForeground(true)
        controller.receive(snapshot())
        controller.startActivity()
        await controller.waitForPendingUpdates()
        controller.setForeground(false, at: now.addingTimeInterval(1))
        await controller.waitForPendingUpdates()
        let background = await repository.load()
        XCTAssertEqual(background?.status, .suspended)
        XCTAssertNil(background?.lyricLine)
        XCTAssertEqual(activity.updates.last?.status, .suspended)
        controller.receive(snapshot("ignored"))
        await controller.waitForPendingUpdates()
        XCTAssertEqual(activity.updates.last?.status, .suspended)
        controller.setForeground(true)
        controller.receive(snapshot("resumed", at: now.addingTimeInterval(2)))
        await controller.waitForPendingUpdates()
        XCTAssertEqual(activity.starts.count, 1)
        XCTAssertEqual(activity.updates.last?.trackID, "resumed")
    }

    func testUserDismissalAndDeniedAuthorizationDoNotAutoRestart() async {
        let activity = ActivityClient()
        let controller = LyricsSurfaceController(repository: Repository(), activity: activity, reloadWidget: {})
        controller.setForeground(true)
        controller.receive(snapshot())
        controller.startActivity()
        await controller.waitForPendingUpdates()
        activity.hasActivity = false // Model system/user dismissal.
        controller.receive(snapshot("next"))
        await controller.waitForPendingUpdates()
        XCTAssertEqual(activity.starts.count, 1)
        XCTAssertFalse(controller.activityRequested)
        activity.denied = true
        controller.startActivity()
        await controller.waitForPendingUpdates()
        XCTAssertEqual(activity.starts.count, 1)
        XCTAssertFalse(controller.activityRequested)
    }

    func testStoppedPlaybackEndsActivity() async {
        let activity = ActivityClient()
        activity.hasActivity = true
        let controller = LyricsSurfaceController(repository: Repository(), activity: activity, reloadWidget: {})
        controller.setForeground(true)
        controller.receive(snapshot(state: .stopped))
        await controller.waitForPendingUpdates()
        XCTAssertFalse(activity.hasActivity)
        XCTAssertEqual(activity.ends, 1)
    }

    func testUpdatesCoalesceToLatestSnapshot() async {
        let repository = Repository()
        let controller = LyricsSurfaceController(repository: repository, activity: ActivityClient(), reloadWidget: {})
        controller.setForeground(true)
        controller.receive(snapshot("old"))
        controller.receive(snapshot("new"))
        await controller.waitForPendingUpdates()
        let stored = await repository.load()
        XCTAssertEqual(stored?.trackID, "new")
    }

    func testExpiryHidesOldLineAndPayloadIsBounded() throws {
        let value = snapshot()
        XCTAssertEqual(value.presentation(at: now.addingTimeInterval(4)).lyricLine, "Original fixture")
        XCTAssertNil(value.presentation(at: now.addingTimeInterval(5)).lyricLine)
        XCTAssertEqual(value.presentation(at: now.addingTimeInterval(5)).status, .stale)
        XCTAssertNil(value.presentation(at: now.addingTimeInterval(-1)).lyricLine)
        let long = String(repeating: "\u{1f3b5}", count: 10_000)
        let bounded = SharedLyricsSnapshot(trackID: long, title: long, artist: long, lyricLine: long, attribution: long,
            message: long, updatedAt: now, expiresAt: now.addingTimeInterval(5))
        let data = try JSONEncoder().encode(LyricsActivityAttributes.ContentState(snapshot: bounded))
        XCTAssertLessThan(data.count, 3_500) // Leave space for static attributes below ActivityKit's 4 KB limit.
        XCTAssertEqual(try JSONDecoder().decode(LyricsActivityAttributes.ContentState.self, from: data).snapshot, bounded)
        let escaped = String(repeating: "\"\\\n", count: 10_000)
        let worstCase = SharedLyricsSnapshot(trackID: escaped, title: escaped, artist: escaped,
            lyricLine: escaped, attribution: escaped, message: escaped, updatedAt: now, expiresAt: now)
        XCTAssertLessThan(try JSONEncoder().encode(LyricsActivityAttributes.ContentState(snapshot: worstCase)).count, 3_500)
    }

    func testReloadPolicyThrottlesLineOnlyChangesButNotTrackAndPause() {
        var policy = LyricsSurfaceUpdatePolicy()
        let first = snapshot()
        policy.lastSaved = first
        policy.lastReloadAt = now
        let line = SharedLyricsSnapshot(trackID: "first", title: "first", lyricLine: "New original line",
            playbackState: .playing, status: .ready, updatedAt: now.addingTimeInterval(5), expiresAt: now.addingTimeInterval(10))
        XCTAssertTrue(policy.shouldSave(line))
        XCTAssertFalse(policy.shouldReloadWidget(line, at: now.addingTimeInterval(5)))
        XCTAssertTrue(policy.shouldReloadWidget(line, at: now.addingTimeInterval(60)))
        XCTAssertTrue(policy.shouldReloadWidget(snapshot("other"), at: now))
        XCTAssertTrue(policy.shouldReloadWidget(snapshot(state: .paused), at: now))
        XCTAssertFalse(policy.shouldSave(first))
        XCTAssertTrue(policy.shouldSave(snapshot(at: now.addingTimeInterval(10))))
        XCTAssertTrue(policy.shouldSave(snapshot(at: now.addingTimeInterval(-1))))
    }

    func testAtomicRepositoryRoundTripAndCorruptData() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = AppGroupLyricsRepository(directory: directory)
        let reader = AppGroupLyricsRepository(directory: directory)
        try await writer.save(snapshot())
        let stored = try await reader.load()
        XCTAssertEqual(stored, snapshot())
        let file = directory.appendingPathComponent("lyrics-snapshot-v1.json")
        XCTAssertEqual(try file.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        try Data("not-json".utf8).write(to: file)
        do { _ = try await reader.load(); XCTFail("Corrupt data must fail explicitly") } catch { }
        try await writer.clear()
        let empty = try await reader.load()
        XCTAssertNil(empty)
    }

    func testProjectionRequiresSeparatePermissionAndExpiresAtLineBoundary() {
        let track = Track(id: "demo:test", title: "Test", artist: "Test", album: nil, duration: 10, artworkURL: nil, source: "Demo")
        let first = LyricLine(startTime: 0, text: "Original first")
        let next = LyricLine(startTime: 5, text: "Original next")
        let sync = SynchronizedLyricsState(currentLine: first, previousLine: nil, nextLine: next, synchronizationStatus: .synchronized)
        let playback = PlaybackSnapshot(track: track, state: .playing, position: 1, lastUpdatedAt: now)
        let projection = LyricsSurfaceProjection()
        let blocked = LyricsDocument(lines: [first, next], attribution: "Test", cacheUntil: now.addingTimeInterval(100))
        XCTAssertNil(projection.snapshot(playback: playback, lyrics: .available(blocked), synchronized: sync, offset: 0, at: now).lyricLine)
        let allowed = LyricsDocument(lines: [first, next], attribution: "Test", cacheUntil: nil, surfaceSharingUntil: now.addingTimeInterval(100))
        let value = projection.snapshot(playback: playback, lyrics: .available(allowed), synchronized: sync, offset: 1, at: now)
        XCTAssertEqual(value.lyricLine, first.text)
        XCTAssertEqual(value.expiresAt, now.addingTimeInterval(3))
        let loading = projection.snapshot(playback: playback, lyrics: .loading, synchronized: .unavailable, offset: 0, at: now)
        XCTAssertEqual(loading.status, .loading)
        XCTAssertNil(loading.lyricLine)
        let expired = LyricsDocument(lines: [first], attribution: "Test", cacheUntil: nil, surfaceSharingUntil: now)
        XCTAssertNil(projection.snapshot(playback: playback, lyrics: .available(expired), synchronized: sync, offset: 0, at: now).lyricLine)
    }

    func testOriginalBundledDemoExplicitlyPermitsSystemSurfaces() async throws {
        let track = Track(id: "demo:open-road", title: "Open Road", artist: "Demo", album: nil,
                          duration: 30, artworkURL: nil, source: "Demo")
        let result = try await MockLyricsProvider().lyrics(for: track)
        let document = try XCTUnwrap(result)
        XCTAssertNil(document.cacheUntil)
        XCTAssertNotNil(document.surfaceSharingUntil)
        let snapshot = LyricsSurfaceProjection().snapshot(
            playback: PlaybackSnapshot(track: track, state: .playing, position: 0),
            lyrics: .available(document), synchronized: LyricsTimeline(lines: document.lines).state(position: 0),
            offset: 0, at: Date())
        XCTAssertEqual(snapshot.status, .ready)
        XCTAssertEqual(snapshot.lyricLine, document.lines.first?.text)
    }
}
