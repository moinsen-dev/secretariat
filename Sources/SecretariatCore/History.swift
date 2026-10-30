import Foundation

/// Who asked Secretariat: the app, a person at a terminal, a script, an MCP client or a coding agent.
/// Read from the calling process's environment, so it is a label for the history, not a security boundary.
public enum Origin {
    public static let app = "app", terminal = "terminal", script = "script", mcp = "mcp", earlier = "earlier"

    private static let lock = NSLock()
    nonisolated(unsafe) private static var fixed: String?

    /// The app and the MCP server say who they are; everything else is detected from the environment.
    public static func set(_ origin: String) { lock.withLock { fixed = origin } }
    public static var current: String {
        lock.withLock { fixed } ?? detect(ProcessInfo.processInfo.environment, interactive: isatty(STDIN_FILENO) == 1 || isatty(STDOUT_FILENO) == 1)
    }

    /// The innermost agent wins: Codex started from Claude Code still carries CLAUDECODE, so its own markers come first.
    public static func detect(_ environment: [String: String], interactive: Bool) -> String {
        if environment["CODEX_THREAD_ID"] != nil || environment["CODEX_SESSION_ID"] != nil { return "codex" }
        if environment["OPENCODE"] == "1" { return "opencode" }
        if environment["GEMINI_CLI"] == "1" { return "gemini-cli" }
        if environment["CURSOR_AGENT"] == "1" { return "cursor" }
        if environment["CLAUDECODE"] == "1" { return "claude-code" }
        if let agent = environment["AI_AGENT"].map(slug), !agent.isEmpty { return agent }
        return interactive ? terminal : script
    }

    /// MCP clients name themselves on initialize ("Claude Desktop" → mcp:claude-desktop).
    public static func mcp(client: String?) -> String {
        let name = client.map(slug) ?? ""
        return name.isEmpty ? mcp : "\(mcp):\(name)"
    }

    /// "claude-code_2-1-309_agent" → "claude-code"; anything outside a-z, 0-9 and dashes is dropped.
    static func slug(_ text: String) -> String {
        let head = text.lowercased().split(separator: "_").first.map(String.init) ?? ""
        return String(head.replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-")).prefix(40))
    }

    public enum Kind: String, Sendable, CaseIterable { case app, person, agent, mcp, script, earlier }
    public static func kind(_ origin: String) -> Kind {
        switch origin {
        case app: .app
        case terminal: .person
        case script: .script
        case earlier: .earlier
        default: origin == mcp || origin.hasPrefix(mcp + ":") ? .mcp : .agent
        }
    }

    public static func title(_ origin: String) -> String {
        let known = ["app": "App", "terminal": "Terminal", "script": "Script", "earlier": "Before origins were recorded",
                     "claude-code": "Claude Code", "codex": "Codex", "opencode": "OpenCode", "gemini-cli": "Gemini CLI",
                     "cursor": "Cursor", "mcp": "MCP"]
        if let title = known[origin] { return title }
        if origin.hasPrefix(mcp + ":") { return "MCP · " + origin.dropFirst(mcp.count + 1).split(separator: "-").map(\.capitalized).joined(separator: " ") }
        return origin.split(separator: "-").map(\.capitalized).joined(separator: " ")
    }
}

/// One line of the history: when, what, from where, and the names involved (never values).
public struct HistoryEntry: Identifiable, Equatable, Sendable {
    public let id: Int
    public let at: Date
    public let action: String
    public let via: String
    public let details: [String: String]

    /// "Run with profile tinideas · 7 variables", for the app and `history`.
    public var summary: String {
        func count(_ key: String, _ noun: String) -> String {
            let n = (details[key] ?? "").split(separator: ",").count
            return n == 1 ? "1 \(noun)" : "\(n) \(noun)s"
        }
        switch action {
        case "run": return "Run with profile \(details["profile"] ?? "?") · \(count("variables", "variable"))"
        case "mcp.run": return "Run through MCP with profile \(details["profile"] ?? "?")"
        case "mcp": return "MCP tool \(details["tool"] ?? "?")"
        case "get": return "Read identifier \(details["field"] ?? "?")"
        case "read": return "\((details["purpose"] ?? "show").capitalized) \(details["field"] ?? "?")"
        case "item.save": return "Saved \(details["item"] ?? "?")" + (details["values"] == "set" ? " (values changed)" : "")
        case "item.delete": return "Deleted \(details["item"] ?? "?")"
        case "field.move": return "Moved \(details["from"] ?? "?") to \(details["to"] ?? "?")"
        case "import": return "Imported \(count("fields", "field")) from \(URL(fileURLWithPath: details["file"] ?? "?").lastPathComponent)"
        case "inject": return "Filled \(details["out"] ?? "?") · \(count("fields", "field"))"
        case "push": return "Pushed to target \(details["target"] ?? "?") · \(count("variables", "variable"))"
        case "approval": return "Asked for Touch ID: \(details["purpose"] ?? "?")"
        case "guard.blocked": return "Commit blocked in \(details["files"] ?? "?")"
        case "guard.agent": return "Agent command refused by the guard"
        case "sweep": return "Leak sweep: \(details["repositories"] ?? "?") repositories, \(details["findings"] ?? "?") findings"
        case "tidy": return "Retired \(details["file"] ?? "?")"
        case "template.save", "template.delete", "template.reset": return "Template \(details["template"] ?? "?"): \(action.split(separator: ".").last ?? "")"
        case "license.activate": return "License activated"
        case "history.retention": return "Automatic deletion \(details["days"].map { "after \($0) days" } ?? "off")"
        case "history.pruned": return "Deleted \(details["entries"] ?? "?") entries older than \(details["days"] ?? "?") days"
        default: return action
        }
    }
}

public enum HistoryPeriod: String, CaseIterable, Identifiable, Sendable {
    case day, week, month, quarter, year
    public var id: String { rawValue }
    public var title: String {
        switch self { case .day: "Day"; case .week: "7 Days"; case .month: "Month"; case .quarter: "Quarter"; case .year: "Year" }
    }
    /// Rolling windows ending now.
    public var days: Int {
        switch self { case .day: 1; case .week: 7; case .month: 30; case .quarter: 91; case .year: 365 }
    }
    /// The chart's bar width: hours for a day, days for a week or month, weeks for a quarter, months for a year.
    public var bucket: Calendar.Component {
        switch self { case .day: .hour; case .week, .month: .day; case .quarter: .weekOfYear; case .year: .month }
    }
    public func start(now: Date) -> Date { now.addingTimeInterval(-Double(days) * 86_400) }
}

public enum History {
    /// Parses audit.log lines; lines without an origin come from before 1.13 and count as "earlier", unreadable ones are skipped.
    /// One JSON pass over the whole file keeps a year of heavy use (200,000 lines) well under two seconds; a damaged
    /// line makes it fall back to reading line by line.
    public static func parse(_ text: String) -> [HistoryEntry] {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let objects: [Any?]
        if body.isEmpty {
            objects = []
        } else if let all = try? JSONSerialization.jsonObject(with: Data(("[" + body.replacingOccurrences(of: "\n", with: ",") + "]").utf8)) as? [Any] {
            objects = all
        } else {
            objects = text.split(separator: "\n", omittingEmptySubsequences: true).map { try? JSONSerialization.jsonObject(with: Data($0.utf8)) }
        }
        var entries: [HistoryEntry] = []
        entries.reserveCapacity(objects.count)
        for (index, object) in objects.enumerated() {
            guard var details = object as? [String: Any], let action = details.removeValue(forKey: "action") as? String,
                  let at = (details.removeValue(forKey: "at") as? String).flatMap(date) else { continue }
            let via = details.removeValue(forKey: "via") as? String ?? Origin.earlier
            entries.append(HistoryEntry(id: index, at: at, action: action, via: via,
                                        details: details.mapValues { $0 as? String ?? "\($0)" }))
        }
        return entries
    }

    /// "2026-10-29T17:40:01Z" without a formatter (the formatter dominated parsing); other forms fall back to it.
    static func date(_ text: String) -> Date? {
        var text = text
        let parsed: Date?? = text.withUTF8 { u -> Date?? in
            guard u.count == 20, u[4] == 45, u[7] == 45, u[10] == 84, u[13] == 58, u[16] == 58, u[19] == 90 else { return .none }
            func number(_ from: Int, _ to: Int) -> Int32? {
                var n: Int32 = 0
                for i in from..<to { let c = u[i]; guard c >= 48, c <= 57 else { return nil }; n = n * 10 + Int32(c - 48) }
                return n
            }
            guard let year = number(0, 4), let month = number(5, 7), let day = number(8, 10),
                  let hour = number(11, 13), let minute = number(14, 16), let second = number(17, 19) else { return .some(nil) }
            var t = tm(); t.tm_year = year - 1900; t.tm_mon = month - 1; t.tm_mday = day; t.tm_hour = hour; t.tm_min = minute; t.tm_sec = second
            return .some(Date(timeIntervalSince1970: TimeInterval(timegm(&t))))
        }
        return parsed ?? ISO8601DateFormatter().date(from: text)
    }

    /// Entries of a period, newest first, optionally of one origin.
    public static func select(_ entries: [HistoryEntry], _ period: HistoryPeriod, now: Date = Date(), via: String? = nil) -> [HistoryEntry] {
        let start = period.start(now: now)
        return entries.filter { $0.at >= start && $0.at <= now && (via == nil || $0.via == via) }.sorted { ($0.at, $0.id) > ($1.at, $1.id) }
    }

    /// Count per origin, most frequent first.
    public static func origins(_ entries: [HistoryEntry]) -> [(via: String, count: Int)] {
        Dictionary(grouping: entries, by: \.via).map { ($0.key, $0.value.count) }.sorted { ($0.count, $1.via) > ($1.count, $0.via) }
    }

    public struct Bucket: Identifiable, Equatable, Sendable {
        public let start: Date
        public let via: String
        public let count: Int
        public var id: String { "\(start.timeIntervalSince1970)-\(via)" }
    }

    /// Counts per bar of the period's chart and per origin.
    public static func buckets(_ entries: [HistoryEntry], _ period: HistoryPeriod, calendar: Calendar = .current) -> [Bucket] {
        var counts: [Date: [String: Int]] = [:]
        for entry in entries {
            guard let start = calendar.dateInterval(of: period.bucket, for: entry.at)?.start else { continue }
            counts[start, default: [:]][entry.via, default: 0] += 1
        }
        return counts.flatMap { start, byVia in byVia.map { Bucket(start: start, via: $0.key, count: $0.value) } }
            .sorted { ($0.start, $0.via) < ($1.start, $1.via) }
    }
}
