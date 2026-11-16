import Foundation

/// Prepared once per document. Each lookup is O(log n), adjacent access O(1).
struct LyricsTimeline: Sendable {
    private let lines: [LyricLine]
    let isTimed: Bool
    var isEmpty: Bool { lines.isEmpty }

    init(lines: [LyricLine]) {
        isTimed = !lines.isEmpty && lines.allSatisfy { line in
            guard let start = line.startTime, start.isFinite, start >= 0 else { return false }
            return line.endTime.map { $0.isFinite && $0 > start } ?? true
        }
        self.lines = isTimed ? lines.enumerated().sorted {
            let a = $0.element.startTime!, b = $1.element.startTime!
            return a == b ? $0.offset < $1.offset : a < b
        }.map(\.element) : lines
    }

    private func latestIndex(at position: TimeInterval) -> Int? {
        var lower = 0, upper = lines.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if lines[middle].startTime! <= position { lower = middle + 1 }
            else { upper = middle }
        }
        return lower > 0 ? lower - 1 : nil
    }

    func state(position: TimeInterval?, isPlaying: Bool = true, duration: TimeInterval? = nil,
               offset: TimeInterval = 0) -> SynchronizedLyricsState {
        guard !lines.isEmpty else { return .unavailable }
        guard isTimed else { return result(status: .untimed) }
        guard let position, position.isFinite, position >= 0, offset.isFinite else {
            return result(status: .positionUnavailable)
        }
        // Track completion uses unadjusted time; an offset must not resurrect a finished song.
        if let duration, duration.isFinite, duration >= 0, position >= duration {
            let previous = latestIndex(at: duration.nextDown).map { lines[$0] }
            return result(previous: previous, status: .ended)
        }
        let adjusted = position + offset
        guard adjusted.isFinite else { return result(status: .positionUnavailable) }
        guard let index = latestIndex(at: adjusted) else { return result(next: lines.first, status: .waiting) }
        let line = lines[index]
        let next = index + 1 < lines.count ? lines[index + 1] : nil
        // Most recently started line wins overlaps; expired lines never reveal an older overlap.
        if let end = line.endTime, adjusted >= end {
            return result(previous: line, next: next, status: .gap)
        }
        return result(current: line, previous: index > 0 ? lines[index - 1] : nil,
                      next: next, status: isPlaying ? .synchronized : .paused)
    }

    private func result(current: LyricLine? = nil, previous: LyricLine? = nil,
                        next: LyricLine? = nil, status: SynchronizationStatus) -> SynchronizedLyricsState {
        SynchronizedLyricsState(currentLine: current, previousLine: previous, nextLine: next,
                                synchronizationStatus: status)
    }

    func activeLineID(position: TimeInterval?) -> UUID? { state(position: position).currentLine?.id }
}

/// Independent of SwiftUI, providers, timers, and actor isolation.
struct LyricsSyncEngine: Sendable {
    private var trackIdentity: String?
    private var timeline = LyricsTimeline(lines: [])
    private(set) var state: SynchronizedLyricsState = .unavailable

    mutating func load(document: LyricsDocument?, for track: Track?) {
        trackIdentity = track?.identity
        timeline = LyricsTimeline(lines: document?.lines ?? [])
        state = .unavailable
    }

    /// Returns true only when the visible line context or status changes.
    @discardableResult
    mutating func update(playback: PlaybackSnapshot, at now: Date, offset: TimeInterval = 0) -> Bool {
        let next: SynchronizedLyricsState
        if trackIdentity == nil || playback.track?.identity != trackIdentity {
            // A switch invalidates the prepared document even if playback later returns.
            trackIdentity = playback.track?.identity
            timeline = LyricsTimeline(lines: [])
            next = .unavailable
        } else {
            next = timeline.state(position: playback.position(at: now), isPlaying: playback.isPlaying,
                                  duration: playback.track?.duration, offset: offset)
        }
        guard next != state else { return false }
        state = next
        return true
    }

    // Convenience compatibility helpers; retain a prepared engine for repeated updates.
    func context(in lines: [LyricLine], position: TimeInterval?) -> LyricContext? {
        let value = LyricsTimeline(lines: lines).state(position: position)
        guard let current = value.currentLine else { return nil }
        return LyricContext(previous: value.previousLine, current: current, next: value.nextLine)
    }

    func activeLineID(in lines: [LyricLine], position: TimeInterval?) -> UUID? {
        LyricsTimeline(lines: lines).activeLineID(position: position)
    }
}
