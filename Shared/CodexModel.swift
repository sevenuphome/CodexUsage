import Foundation

struct CodexWindow: Identifiable, Codable {
    let id: String
    let name: String
    let percent: Double
    let resetsAt: Date?
}

struct CodexSnapshot: Codable {
    let windows: [CodexWindow]
    /// When Codex recorded this snapshot — data is only as fresh as the
    /// last Codex CLI session.
    let asOf: Date
}

/// Reads the newest rate-limit snapshot from Codex CLI's session logs
/// (~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl). Each `token_count`
/// event carries a `rate_limits` object with primary/secondary windows.
/// Local files only — no network, no credentials.
enum CodexReader {

    static var sessionsRoot: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".codex/sessions")
    }

    static func latest() -> CodexSnapshot? {
        for url in newestSessionFiles(limit: 5) {
            if let snapshot = lastSnapshot(in: url) { return snapshot }
        }
        return nil
    }

    // MARK: - File discovery

    private static func newestSessionFiles(limit: Int) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: sessionsRoot,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [(URL, Date)] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            files.append((url, modified))
        }
        return files.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }

    // MARK: - Tail scan

    /// Reads the file backwards in chunks and returns the last line that
    /// parses as a rate-limit snapshot. Rollout files can be large; this
    /// touches at most ~4 MB from the end.
    private static func lastSnapshot(in url: URL) -> CodexSnapshot? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd(), size > 0 else { return nil }

        let chunkSize: UInt64 = 262_144
        var offset = size
        var buffer = Data()

        while offset > 0, buffer.count < 4_194_304 {
            let readFrom = offset > chunkSize ? offset - chunkSize : 0
            guard (try? handle.seek(toOffset: readFrom)) != nil,
                  let chunk = try? handle.read(upToCount: Int(offset - readFrom)) else { break }
            buffer = chunk + buffer
            offset = readFrom

            var lines = buffer.split(separator: UInt8(ascii: "\n"))
            // The first line may be truncated mid-chunk unless we've
            // reached the start of the file.
            if offset > 0, !lines.isEmpty { lines.removeFirst() }
            for line in lines.reversed() {
                if let snapshot = parse(line: Data(line)) { return snapshot }
            }
        }
        return nil
    }

    private static func parse(line: Data) -> CodexSnapshot? {
        guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let payload = obj["payload"] as? [String: Any],
              let rateLimits = payload["rate_limits"] as? [String: Any] else { return nil }

        var windows: [CodexWindow] = []
        for key in ["primary", "secondary"] {
            guard let entry = rateLimits[key] as? [String: Any],
                  let percent = entry["used_percent"] as? Double else { continue }
            let minutes = entry["window_minutes"] as? Int ?? 0
            let resets = (entry["resets_at"] as? Double).map { Date(timeIntervalSince1970: $0) }
            windows.append(CodexWindow(
                id: key,
                name: windowName(minutes: minutes),
                percent: percent,
                resetsAt: resets
            ))
        }
        guard !windows.isEmpty else { return nil }

        let asOf = (obj["timestamp"] as? String).flatMap(parseTimestamp) ?? Date()
        return CodexSnapshot(windows: windows, asOf: asOf)
    }

    private static func windowName(minutes: Int) -> String {
        switch minutes {
        case 300: return "5-hour"
        case 10080: return "Weekly"
        case 0: return "Usage"
        case let m where m % 1440 == 0: return "\(m / 1440)-day"
        case let m where m % 60 == 0: return "\(m / 60)-hour"
        default: return "\(minutes) min"
        }
    }

    private static func parseTimestamp(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
