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
    for i in 0..<200 { AuditLog(url: url, origin: "script").record("run", ["profile": "old\(i)"], at: old) }
    DispatchQueue.concurrentPerform(iterations: 3) { worker in
        if worker == 0 {
            for _ in 0..<30 { _ = try? AuditLog(url: url).prune(olderThan: Date().addingTimeInterval(-86_400)) }
        } else {
            for i in 0..<300 { AuditLog(url: url, origin: "script").record("run", ["profile": "w\(worker)-\(i)"]) }
        }
    }
    // The fixture's own item.save stays; all 200 old runs went, all 600 new ones are there.
    let runs = AuditLog(url: url).entries().compactMap { $0.details["profile"] }
    #expect(runs.count == 600)
    #expect(runs.allSatisfy { $0.hasPrefix("w") })
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
    let text = Array(repeating: sample, count: 200_000).joined(separator: "\n")
    let clock = ContinuousClock()
    let elapsed = clock.measure { #expect(History.parse(text).count == 200_000) }
    #expect(elapsed < .seconds(2))
}
