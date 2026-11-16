import ActivityKit
import Foundation

@MainActor
protocol LyricsActivityClient: AnyObject {
    var hasActivity: Bool { get }
    func start(_ snapshot: SharedLyricsSnapshot) throws
    func update(_ snapshot: SharedLyricsSnapshot) async
    func end() async
}

@MainActor
final class SystemLyricsActivityClient: LyricsActivityClient {
    private var activities: [Activity<LyricsActivityAttributes>] {
        Activity<LyricsActivityAttributes>.activities.filter { $0.activityState == .active || $0.activityState == .stale }
    }
    var hasActivity: Bool { !activities.isEmpty }

    func start(_ snapshot: SharedLyricsSnapshot) throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw ActivityError.disabled }
        guard !hasActivity else { return }
        _ = try Activity.request(attributes: LyricsActivityAttributes(sessionID: UUID()),
            content: ActivityContent(state: LyricsActivityAttributes.ContentState(snapshot: snapshot), staleDate: snapshot.expiresAt),
            pushType: nil)
    }

    func update(_ snapshot: SharedLyricsSnapshot) async {
        let content = ActivityContent(state: LyricsActivityAttributes.ContentState(snapshot: snapshot), staleDate: snapshot.expiresAt)
        for activity in activities { await activity.update(content) }
    }

    func end() async {
        // Also dismiss ended activities that the system may still retain on the Lock Screen.
        for activity in Activity<LyricsActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    enum ActivityError: LocalizedError {
        case disabled
        var errorDescription: String? { "Live Activities are disabled in system settings." }
    }
}
