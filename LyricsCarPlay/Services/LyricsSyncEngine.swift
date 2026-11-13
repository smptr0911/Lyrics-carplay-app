import Foundation

/// Prepared once per document; position updates use binary search.
struct LyricsTimeline {
    private let entries: [(time: TimeInterval, id: UUID)]

    init(lines: [LyricLine]) {
        guard lines.allSatisfy({ line in
            guard let time = line.startTime else { return false }
            return time.isFinite && time >= 0
        }) else { entries = []; return }
        entries = lines.enumerated().sorted {
            let a = $0.element.startTime!, b = $1.element.startTime!
            return a == b ? $0.offset < $1.offset : a < b
        }.map { ($0.element.startTime!, $0.element.id) }
    }

    func activeLineID(position: TimeInterval?) -> UUID? {
        guard let position, position.isFinite, position >= 0 else { return nil }
        var lower = 0
        var upper = entries.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if entries[middle].time <= position { lower = middle + 1 }
            else { upper = middle }
        }
        return lower > 0 ? entries[lower - 1].id : nil
    }
}

struct LyricsSyncEngine {
    func activeLineID(in lines: [LyricLine], position: TimeInterval?) -> UUID? {
        LyricsTimeline(lines: lines).activeLineID(position: position)
    }
}
