import Foundation

struct LRCParser: Sendable {
    enum ImportError: LocalizedError {
        case tooLarge, invalidEncoding, invalidTimestamp, noTimedLines
        var errorDescription: String? {
            switch self {
            case .tooLarge: return "Choose an LRC file smaller than 1 MB with at most 50,000 lyric entries."
            case .invalidEncoding: return "The LRC file must use UTF-8 text."
            case .invalidTimestamp: return "The LRC file contains an invalid timestamp or offset."
            case .noTimedLines: return "No synchronized lyric timestamps were found."
            }
        }
    }

    func parse(_ text: String, track: Track) throws -> LyricsDocument {
        guard text.utf8.count <= 1_000_000 else { throw ImportError.tooLarge }
        var entries: [(time: Double, text: String, ordinal: Int)] = []
        var offset: Double = 0
        var expandedBytes = 0
        for raw in text.replacingOccurrences(of: "\u{feff}", with: "").components(separatedBy: .newlines) {
            try Task.checkCancellation()
            var remainder = Substring(raw.trimmingCharacters(in: .whitespaces))
            var timestamps: [Double] = []
            while remainder.first == "[" {
                guard let close = remainder.firstIndex(of: "]") else { throw ImportError.invalidTimestamp }
                let tag = String(remainder[remainder.index(after: remainder.startIndex)..<close])
                remainder = remainder[remainder.index(after: close)...]
                if tag.lowercased().hasPrefix("offset:") {
                    guard let value = Double(tag.dropFirst(7)), value.isFinite, abs(value) <= 3_600_000 else {
                        throw ImportError.invalidTimestamp
                    }
                    offset = value / 1_000
                } else if tag.first?.isNumber == true || tag.first == "-" {
                    guard timestamps.count + entries.count < 50_000 else { throw ImportError.tooLarge }
                    timestamps.append(try timestamp(tag))
                } // Artist/title and other metadata never become lyric text.
            }
            let content = remainder.trimmingCharacters(in: .whitespaces)
            let additionalBytes = content.utf8.count * timestamps.count
            guard additionalBytes <= 1_000_000 - expandedBytes else { throw ImportError.tooLarge }
            expandedBytes += additionalBytes
            for time in timestamps {
                guard entries.count < 50_000 else { throw ImportError.tooLarge }
                entries.append((time, content, entries.count))
            }
        }
        guard !entries.isEmpty else { throw ImportError.noTimedLines }
        let ordered = entries.sorted { $0.time == $1.time ? $0.ordinal < $1.ordinal : $0.time < $1.time }
        let lines = ordered.map { entry in
            // LRC positive offset advances lyric display; UI offset follows the same convention.
            LyricLine(id: LyricLine.stableID(namespace: track.identity,
                value: "lrc|\(entry.ordinal)|\(entry.time)|\(entry.text)"),
                startTime: max(0, entry.time - offset), text: entry.text)
        }
        return LyricsDocument(lines: lines, attribution: "User-imported LRC - use only lyrics you have permission to display.", cacheUntil: nil)
    }

    private func timestamp(_ tag: String) throws -> Double {
        let parts = tag.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[0].allSatisfy({ $0.isASCII && $0.isNumber }),
              let minutes = Double(parts[0]), minutes.isFinite else { throw ImportError.invalidTimestamp }
        let secondsParts = parts[1].split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(secondsParts.count), secondsParts[0].count == 2,
              secondsParts.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ $0.isASCII && $0.isNumber }) }),
              secondsParts.count == 1 || (1...3).contains(secondsParts[1].count),
              let seconds = Double(parts[1]), seconds < 60 else { throw ImportError.invalidTimestamp }
        let result = minutes * 60 + seconds
        guard result.isFinite else { throw ImportError.invalidTimestamp }
        return result
    }
}

/// Session-only imports. Conservative cross-provider matching requires all metadata to agree.
actor ImportedLRCLyricsProvider: LyricsProvider, LyricsCatalog {
    private var documents: [String: LyricsDocument] = [:]
    private var tracks: [String: Track] = [:]
    func candidates(for track: Track) -> [LyricsCandidate] {
        documents.compactMap { key, document in
            tracks[key].map { LyricsCandidate(track: $0, document: document, source: "User-imported LRC") }
        }
    }

    func importText(_ text: String, for track: Track) throws -> LyricsDocument {
        let document = try LRCParser().parse(text, track: track)
        documents[track.identity] = document
        tracks[track.identity] = track
        return document
    }

    func importFile(_ url: URL, for track: Track) throws -> LyricsDocument {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        // A bounded read avoids allocating an arbitrarily large selected file.
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 1_000_001) ?? Data()
        guard data.count <= 1_000_000 else { throw LRCParser.ImportError.tooLarge }
        guard let text = String(data: data, encoding: .utf8) else { throw LRCParser.ImportError.invalidEncoding }
        return try importText(text, for: track)
    }

    func remove(for track: Track) { documents.removeValue(forKey: track.identity); tracks.removeValue(forKey: track.identity) }
    func remove(identity: String) { documents.removeValue(forKey: identity); tracks.removeValue(forKey: identity) }
    func clear() { documents.removeAll(); tracks.removeAll() }
    func lyrics(for track: Track) async throws -> LyricsDocument? { documents[track.identity] }
}
