import Foundation
import Testing
@testable import SecretariatCore

@Test func originIsDetectedInnermostAgentFirst() {
    #expect(Origin.detect(["CLAUDECODE": "1", "CODEX_THREAD_ID": "t"], interactive: false) == "codex")
    #expect(Origin.detect(["CLAUDECODE": "1", "OPENCODE": "1"], interactive: true) == "opencode")
    #expect(Origin.detect(["GEMINI_CLI": "1"], interactive: false) == "gemini-cli")
    #expect(Origin.detect(["CURSOR_AGENT": "1"], interactive: false) == "cursor")
    #expect(Origin.detect(["CLAUDECODE": "1", "AI_AGENT": "claude-code_2-1-309_agent"], interactive: true) == "claude-code")
    #expect(Origin.detect(["AI_AGENT": "Hermes_0.22"], interactive: false) == "hermes")
    #expect(Origin.detect(["AI_AGENT": "app"], interactive: false) == "agent-app")
    #expect(Origin.detect(["AI_AGENT": "Terminal"], interactive: true) == "agent-terminal")
    #expect(Origin.detect([:], interactive: true) == "terminal")
    #expect(Origin.detect([:], interactive: false) == "script")
    #expect(Origin.mcp(client: "Claude Desktop") == "mcp:claude-desktop")
    #expect(Origin.mcp(client: "  ") == "mcp")
    #expect(Origin.mcp(client: String(repeating: "x/../", count: 40)).count <= 44)
    #expect(Origin.title("mcp:claude-desktop") == "MCP · Claude Desktop")
    #expect(Origin.kind("claude-code") == .agent && Origin.kind("terminal") == .person && Origin.kind("mcp:x") == .mcp)
}

private func line(_ action: String, _ at: Date, via: String? = nil, _ extra: [String: String] = [:]) -> String {
    var o = extra; o["action"] = action; o["at"] = ISO8601DateFormatter().string(from: at); if let via { o["via"] = via }
    return String(decoding: try! JSONSerialization.data(withJSONObject: o, options: [.sortedKeys]), as: UTF8.self)
}

@Test func historyReadsOldAndNewLinesAndGroupsPeriods() {
    let now = Date(timeIntervalSince1970: 1_793_300_000)
    let text = [line("run", now.addingTimeInterval(-40 * 86_400), ["profile": "old", "variables": "A,B"]),
                "not json", #"{"action":"run"}"#,
                line("run", now.addingTimeInterval(-3_600), via: "claude-code", ["profile": "shop", "variables": "A,B"]),
                line("get", now.addingTimeInterval(-2 * 86_400), via: "terminal", ["field": "acme/x/id"]),
                line("read", now.addingTimeInterval(-60), via: "app", ["field": "acme/db/password", "purpose": "copy"])].joined(separator: "\n")
    let entries = History.parse(text)
    #expect(entries.count == 4)
    #expect(entries.first?.via == Origin.earlier)
    #expect(History.select(entries, .day, now: now).map(\.action) == ["read", "run"])
    #expect(History.select(entries, .week, now: now).count == 3)
    #expect(History.select(entries, .year, now: now).count == 4)
    #expect(History.select(entries, .year, now: now, via: "claude-code").map(\.summary) == ["Run with profile shop · 2 variables"])
    #expect(History.origins(History.select(entries, .year, now: now)).count == 4)
    let week = History.buckets(History.select(entries, .week, now: now), .week)
    #expect(week.map(\.count).reduce(0, +) == 3)
    #expect(entries.last?.summary == "Copy acme/db/password")
}

@Test func pruneRemovesOnlyOlderEntriesAndKeepsThePermissions() throws {
    let fixture = try AgentFixture(); defer { fixture.cleanup() }
    let now = Date()
    let log = AuditLog(url: fixture.vault.audit.url, origin: "terminal")
    log.record("run", ["profile": "day31"], at: now.addingTimeInterval(-31 * 86_400))
    log.record("run", ["profile": "day29"], at: now.addingTimeInterval(-29 * 86_400))
    log.record("run", ["profile": "today"], at: now)
    // Off by default: nothing goes.
    #expect(fixture.vault.pruneHistory(now: now) == 0)
    try fixture.vault.setHistoryRetention(days: 30)
    #expect(fixture.vault.pruneHistory(now: now) == 1)
    let profiles = log.entries().compactMap { $0.details["profile"] }
    #expect(!profiles.contains("day31") && profiles.contains("day29") && profiles.contains("today"))
    // The switch and the deletion are part of the history themselves.
    #expect(log.entries().map(\.action).suffix(2) == ["history.retention", "history.pruned"])
    let mode = try FileManager.default.attributesOfItem(atPath: log.url!.path)[.posixPermissions] as? Int
    #expect(mode == 0o600)
    #expect((try fixture.vault.configuration.load()).historyRetentionDays == 30)
    try fixture.vault.setHistoryRetention(days: nil)
    #expect((try fixture.vault.configuration.load()).historyRetentionDays == nil)
}

@Test func entriesWrittenWhilePruningAreNotLost() throws {
    let fixture = try AgentFixture(); defer { fixture.cleanup() }
    let url = fixture.vault.audit.url!
    let old = Date().addingTimeInterval(-100 * 86_400)
    // Writers keep adding old and new lines, so every pruning pass has something to remove and rewrites the file.
    final class Progress: @unchecked Sendable { let lock = NSLock(); var passes = 0, writersDone = 0 }
    let progress = Progress()
    DispatchQueue.concurrentPerform(iterations: 3) { worker in
        if worker == 0 {
            while progress.lock.withLock({ progress.writersDone < 2 }) {
                if ((try? AuditLog(url: url).prune(olderThan: Date().addingTimeInterval(-86_400))) ?? 0) > 0 { progress.lock.withLock { progress.passes += 1 } }
            }
        } else {
            defer { progress.lock.withLock { progress.writersDone += 1 } }
            for i in 0..<300 {
                AuditLog(url: url, origin: "script").record("run", ["profile": "old\(worker)-\(i)"], at: old)
                AuditLog(url: url, origin: "script").record("run", ["profile": "w\(worker)-\(i)"])
            }
        }
    }
    try AuditLog(url: url).prune(olderThan: Date().addingTimeInterval(-86_400))
    #expect(progress.passes > 5, "pruning rewrote the file \(progress.passes) times")
    let runs = AuditLog(url: url).entries().compactMap { $0.details["profile"] }
    #expect(runs.count == 600)
    #expect(Set(runs).count == 600 && runs.allSatisfy { $0.hasPrefix("w") })
}

@Test func aDamagedLineCostsOnlyItself() throws {
    let fixture = try AgentFixture(); defer { fixture.cleanup() }
    let url = fixture.vault.audit.url!
    let now = Date()
    var data = Data((line("run", now.addingTimeInterval(-40 * 86_400), via: "script", ["profile": "old"]) + "\n").utf8)
    data.append(Data(#"{"action":"run","at":""#.utf8)); data.append(contentsOf: [0xC3]); data.append(Data("\n".utf8))   // cut-off umlaut
    data.append(Data((line("run", now, via: "codex", ["profile": "f\u{00FC}r"]) + "\n").utf8))
    data.append(Data(#"{"action":"get","at":"2026-10-30T10:00:00Z","field":"a/b/c"#.utf8)); data.append(Data("\n".utf8))  // missing end
    data.append(Data(#""via":"x"}"#.utf8)); data.append(Data("\n".utf8))
    try data.write(to: url)
    let entries = AuditLog(url: url).entries()
    #expect(entries.map { $0.details["profile"] ?? "" } == ["old", "f\u{00FC}r"])
    #expect(try AuditLog(url: url).prune(olderThan: now.addingTimeInterval(-30 * 86_400)) == 1)
    #expect(AuditLog(url: url).entries().map { $0.details["profile"] ?? "" } == ["f\u{00FC}r"])
    #expect(AuditLog(url: url).tail(10).count == 4)   // damaged lines stay in the file
}

@Test func injectAndImportShowOnlyTheFileName() {
    let entry = HistoryEntry(id: 0, at: Date(), action: "inject", via: "script", details: ["out": "/Users/x/work/client-acme/.env", "fields": "a/b/c"])
    #expect(entry.summary == "Filled .env · 1 field")
}

@Test func historyNeverHoldsValuesAndTheCliOnlyReads() throws {
    let fixture = try AgentFixture(); defer { fixture.cleanup() }
    _ = try fixture.vault.preparedLaunch(name: fixture.profile.name, arguments: ["true"], inheritedEnvironment: [:])
    try fixture.cli("get", "moinsen/test/api/key_id")
    let text = try String(contentsOf: fixture.vault.audit.url!, encoding: .utf8)
    #expect(!text.contains("never-output-this-value") && !text.contains("personal-never-out") && !text.contains("KEY-123"))
    #expect(text.contains(#""action":"get""#) && text.contains(#""via":"#))
    let (code, json) = try fixture.cli("history", "--period", "day")
    #expect(code == 0 && json.contains(#""total""#) && json.contains(#""autoDeleteDays""#) == false, "\(json)")
    #expect(fixture.code("history", "retention", "30") == "invalid_arguments")
    #expect(fixture.code("history", "--period", "decade") == "invalid_arguments")
}

@Test func twoHundredThousandLinesParseQuickly() {
    let now = Date()
    let sample = line("run", now, via: "claude-code", ["profile": "shop", "variables": "A,B,C"])
    var lines = Array(repeating: sample, count: 200_000)
    lines[123_456] = #"{"action":"run","at":"2026-1"#   // one damaged line must not switch to a slow path
    let text = lines.joined(separator: "\n")
    let clock = ContinuousClock()
    let elapsed = clock.measure { #expect(History.parse(text).count == 199_999) }
    #expect(elapsed < .seconds(2))
}

@Test func prunedSummaryCountsInTheRightNumber() {
    #expect(HistoryEntry(id: 0, at: Date(), action: "history.pruned", via: "app", details: ["entries": "1", "days": "30"]).summary == "Deleted 1 entry older than 30 days")
    #expect(HistoryEntry(id: 0, at: Date(), action: "history.pruned", via: "app", details: ["entries": "300", "days": "30"]).summary == "Deleted 300 entries older than 30 days")
}

@Test func fastDatesMatchTheFormatter() {
    for text in ["2026-10-30T05:35:26Z", "2024-02-29T23:59:59Z", "1999-12-31T00:00:00Z", "2026-01-01T00:00:00Z", "2100-03-01T12:00:00Z"] {
        #expect(History.date(text) == ISO8601DateFormatter().date(from: text), "\(text)")
    }
    #expect(History.date("2026-13-01T00:00:00Z") == nil)
}

@Test func lineDatesAreFoundWithOrWithoutSpaces() {
    let expected = History.date("2026-08-01T10:00:00Z")
    #expect(History.lineDate(Data(#"{"action":"run","at":"2026-08-01T10:00:00Z","via":"x"}"#.utf8)) == expected)
    #expect(History.lineDate(Data(#"{"action": "run", "at": "2026-08-01T10:00:00Z", "via": "x"}"#.utf8)) == expected)
    #expect(History.lineDate(Data(#"{"field":"at","at" : "2026-08-01T10:00:00Z"}"#.utf8)) == expected)
    #expect(History.lineDate(Data(#"{"action":"run","at":"2026-1"#.utf8)) == nil)
    #expect(History.lineDate(Data(#"{"action":"run"}"#.utf8)) == nil)
}

@Test func strictDatesAndMergedHalvesAndAMissingNewline() throws {
    #expect(History.date("2026-02-31T00:00:00Z") == nil && History.date("2026-10-30T24:00:00Z") == nil && History.date("2026-10-30T10:60:00Z") == nil)
    #expect(History.date("2024-02-29T00:00:00Z") != nil && History.date("2026-02-29T00:00:00Z") == nil)
    // Two damaged halves that would form one valid object when joined with a comma: the block falls back to single lines.
    let good = #"{"action":"get","at":"2026-10-30T10:00:00Z","field":"a/b/c","via":"x"}"#
    let halves = [#"{"action":"run","at":"2026-10-30T10:00:00Z","profile":"p""#, #""via":"y"}"#]
    #expect(History.parse(([good] + halves + [good]).joined(separator: "\n")).map(\.action) == ["get", "get"])
    // A log that ends without a newline (crash) keeps the next entry on its own line.
    let fixture = try AgentFixture(); defer { fixture.cleanup() }
    let url = fixture.vault.audit.url!
    try Data(#"{"action":"run","at":"2026-10-30T10:00:00Z","profile":"cut"#.utf8).write(to: url)
    AuditLog(url: url, origin: "script").record("get", ["field": "a/b/c"])
    #expect(AuditLog(url: url).entries().map(\.action) == ["get"])
}
