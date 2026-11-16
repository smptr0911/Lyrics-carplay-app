import Foundation
import OSLog

/// Timing only: never log tracks, lyric text, provider URLs, credentials or App Group paths.
enum LyricsSurfaceDiagnostics {
    private static let logger = Logger(subsystem: "LyricsCarPlay", category: "SurfaceTiming")
    static func record(_ event: String, snapshot: SharedLyricsSnapshot) {
        #if DEBUG
        let age = max(0, Date().timeIntervalSince(snapshot.updatedAt))
        logger.debug("\(event, privacy: .public) snapshot age seconds=\(age, privacy: .public)")
        #endif
    }
}

protocol SharedLyricsRepository: Sendable {
    func load() async throws -> SharedLyricsSnapshot?
    func save(_ snapshot: SharedLyricsSnapshot) async throws
    func clear() async throws
}

enum LyricsSharingError: LocalizedError {
    case groupUnavailable, invalidSnapshot
    var errorDescription: String? {
        switch self {
        case .groupUnavailable: return "Shared storage unavailable. Check App Group signing for both targets."
        case .invalidSnapshot: return "Shared lyrics data is invalid or incompatible."
        }
    }
}

/// One writer (the app); readers see either the previous complete file or its atomic replacement.
actor AppGroupLyricsRepository: SharedLyricsRepository {
    private let file: URL

    init(directory: URL) {
        file = directory.appendingPathComponent("lyrics-snapshot-v1.json")
    }

    static func configured(bundle: Bundle = .main) throws -> AppGroupLyricsRepository {
        guard let identifier = bundle.object(forInfoDictionaryKey: "LyricsAppGroup") as? String,
              identifier.hasPrefix("group."), !identifier.contains("$("),
              let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            throw LyricsSharingError.groupUnavailable
        }
        return AppGroupLyricsRepository(directory: directory)
    }

    func load() throws -> SharedLyricsSnapshot? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 4_097) ?? Data()
        guard data.count <= 4_096 else { throw LyricsSharingError.invalidSnapshot }
        let snapshot = try JSONDecoder().decode(SharedLyricsSnapshot.self, from: data)
        try validate(snapshot)
        return snapshot
    }

    func save(_ snapshot: SharedLyricsSnapshot) throws {
        try validate(snapshot)
        let data = try JSONEncoder().encode(snapshot)
        guard data.count < 3_500 else { throw LyricsSharingError.invalidSnapshot }
        // Class C remains readable while locked after the first device unlock following restart.
        try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var destination = file
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try destination.setResourceValues(values)
    }

    private func validate(_ snapshot: SharedLyricsSnapshot) throws {
        guard snapshot.schemaVersion == 1, snapshot.updatedAt.timeIntervalSince1970.isFinite,
              snapshot.expiresAt.timeIntervalSince1970.isFinite,
              snapshot.playbackRate.isFinite, snapshot.playbackRate >= 0,
              snapshot.synchronizationOffset.isFinite,
              (snapshot.playbackPosition.map { $0.isFinite && $0 >= 0 } ?? true),
              snapshot.title.utf8.count <= 243, snapshot.artist.utf8.count <= 163,
              (snapshot.lyricLine?.utf8.count ?? 0) <= 603,
              (snapshot.attribution?.utf8.count ?? 0) <= 163,
              (snapshot.trackID?.utf8.count ?? 0) <= 163, snapshot.message.utf8.count <= 163 else {
            throw LyricsSharingError.invalidSnapshot
        }
    }

    func clear() throws {
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }
}
