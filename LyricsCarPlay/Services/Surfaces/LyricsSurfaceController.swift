import Combine
import Foundation
import WidgetKit

@MainActor
final class LyricsSurfaceController: ObservableObject {
    @Published private(set) var message = "Best-effort system snapshots"
    @Published private(set) var activityRequested = false
    private let repository: (any SharedLyricsRepository)?
    private let activity: any LyricsActivityClient
    private let reloadWidget: () -> Void
    private var policy = LyricsSurfaceUpdatePolicy()
    private var latest: SharedLyricsSnapshot?
    private var pending: SharedLyricsSnapshot?
    private var worker: Task<Void, Never>?
    private var foreground = false
    private var startRequested = false
    private var stopRequested = false

    init(repository: (any SharedLyricsRepository)?, activity: any LyricsActivityClient,
         reloadWidget: @escaping () -> Void = { WidgetCenter.shared.reloadTimelines(ofKind: SharedLyricsSnapshot.widgetKind) }) {
        self.repository = repository
        self.activity = activity
        self.reloadWidget = reloadWidget
        activityRequested = activity.hasActivity
        if repository == nil { message = LyricsSharingError.groupUnavailable.localizedDescription }
    }

    func receive(_ snapshot: SharedLyricsSnapshot) {
        guard foreground else { return }
        latest = snapshot
        guard policy.shouldSave(snapshot) else { return }
        enqueue(snapshot)
    }

    func setForeground(_ value: Bool, at now: Date = Date()) {
        guard foreground != value else { return }
        foreground = value
        if !value {
            startRequested = false
            if let latest {
                let suspended = latest.redacted(status: .suspended, message: "Open iPhone to refresh", at: now)
                self.latest = suspended
                enqueue(suspended)
            }
        }
    }

    func startActivity() {
        guard foreground, let latest, latest.trackID != nil, latest.playbackState != .stopped else {
            message = "Choose a track in Now Playing before starting a Live Activity."
            return
        }
        startRequested = true
        stopRequested = false
        activityRequested = true
        enqueue(latest)
    }

    func endActivity() {
        startRequested = false
        stopRequested = true
        activityRequested = false
        enqueue(latest ?? .unavailable(at: Date()))
    }

    private func enqueue(_ snapshot: SharedLyricsSnapshot) {
        pending = snapshot
        guard worker == nil else { return }
        worker = Task { [weak self] in
            guard let self else { return }
            await drain()
            worker = nil
        }
    }

    /// Also allows deterministic tests to await a coalesced batch without sleeping.
    func waitForPendingUpdates() async { await worker?.value }

    private func drain() async {
        while let snapshot = pending {
            pending = nil
            guard policy.shouldSave(snapshot) || startRequested || stopRequested else { continue }
            let shouldReload = policy.shouldReloadWidget(snapshot, at: snapshot.updatedAt)
            if let repository {
                do {
                    try await repository.save(snapshot)
                    if shouldReload {
                        reloadWidget()
                        policy.lastReloadAt = snapshot.updatedAt
                    }
                    message = "Best effort; system refresh timing varies."
                } catch { message = "Shared storage could not be updated. Check App Group configuration." }
            }
            policy.lastSaved = snapshot
            // If newer content arrived while saving, do not send older lyrics to ActivityKit.
            guard pending == nil else { continue }
            if stopRequested || snapshot.trackID == nil || snapshot.playbackState == .stopped {
                startRequested = false
                stopRequested = false
                activityRequested = false
                await activity.end()
            } else if activity.hasActivity {
                startRequested = false
                await activity.update(snapshot)
            } else if startRequested && foreground {
                startRequested = false
                do { try activity.start(snapshot) }
                catch { activityRequested = false; message = "Live Activity could not start. Check system Live Activities settings." }
            } else {
                // Honor dismissal by the user or the system: never automatically re-request.
                activityRequested = false
            }
        }
    }
}
