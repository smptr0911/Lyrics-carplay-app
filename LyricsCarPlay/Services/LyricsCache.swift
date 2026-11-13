import Foundation

@MainActor
final class LyricsCache {
    private var entries: [String: LyricsDocument] = [:]
    private var order: [String] = []
    private let capacity: Int

    init(capacity: Int = 64) { self.capacity = max(0, capacity) }

    private func remove(_ key: String) {
        entries[key] = nil
        order.removeAll { $0 == key }
    }
    private func purge(now: Date) {
        for key in order where (entries[key]?.cacheUntil ?? .distantPast) <= now { remove(key) }
    }
    func document(for key: String, now: Date = Date()) -> LyricsDocument? {
        purge(now: now)
        return entries[key]
    }
    func insert(_ document: LyricsDocument, for key: String, now: Date = Date()) {
        purge(now: now)
        remove(key) // A replacement that forbids retention also revokes any cached copy.
        guard capacity > 0, let expiry = document.cacheUntil, expiry > now else { return }
        while order.count >= capacity, let oldest = order.first { remove(oldest) }
        entries[key] = document
        order.append(key)
    }
    func clear() { entries.removeAll(); order.removeAll() }
}
