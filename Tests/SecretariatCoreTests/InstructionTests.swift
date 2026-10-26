import Foundation
import Testing
@testable import SecretariatCore

@Test func setupPreservesExistingBytesAndIsIdempotent() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let agents = f.root.appendingPathComponent("AGENTS.md")
    let claude = f.root.appendingPathComponent("CLAUDE.md")
    let prefix = Data("# Eigene Regeln\r\n\r\nBehalte mein Café.\r\n".utf8)
    try prefix.write(to: agents)
    try Data("# Claude spezifisch\n".utf8).write(to: claude)
    try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: agents.path)
    let plan = try f.preview(); #expect(plan.changedFiles.count == 2)
    try ProjectInstructions.apply(plan)
    let first = try Data(contentsOf: agents), second = try Data(contentsOf: claude)
    #expect(first.starts(with: prefix)); #expect(String(decoding: second, as: UTF8.self).contains("@AGENTS.md"))
    #expect((try FileManager.default.attributesOfItem(atPath: agents.path)[.posixPermissions] as? NSNumber)?.intValue == 0o640)
    let again = try f.preview(); #expect(again.changedFiles.isEmpty)
    try ProjectInstructions.apply(again)
    #expect(try Data(contentsOf: agents) == first); #expect(try Data(contentsOf: claude) == second)
}

@Test func setupRejectsStalePreviewBeforeWritingEitherFile() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let plan = try f.preview()
    let claude = f.root.appendingPathComponent("CLAUDE.md")
    let changed = Data("Parallel hinzugefügt".utf8); try changed.write(to: claude)
    #expect(throws: AgentError.self) { try ProjectInstructions.apply(plan) }
    #expect(try Data(contentsOf: claude) == changed)
    #expect(!FileManager.default.fileExists(atPath: f.root.appendingPathComponent("AGENTS.md").path))
}

@Test func setupRefusesAnotherProfileMalformedMarkersAndInvalidUTF8() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let agents = f.root.appendingPathComponent("AGENTS.md")
    for content in [Data("<!-- secretariat:begin profile=other -->\ncontent\n<!-- secretariat:end -->".utf8), Data("<!-- secretariat:begin profile=agent-test -->\nbroken".utf8), Data([0xff, 0xfe])] {
        try content.write(to: agents)
        #expect(throws: AgentError.self) { try f.preview() }
        #expect(try Data(contentsOf: agents) == content)
        #expect(!FileManager.default.fileExists(atPath: f.root.appendingPathComponent("CLAUDE.md").path))
    }
}

@Test func setupNeverFollowsSymlinksOrModifiesHardlinkTargets() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let agents = f.root.appendingPathComponent("AGENTS.md")
    let target = f.root.appendingPathComponent("external.txt")
    let original = Data("Keep this content".utf8); try original.write(to: target)
    try FileManager.default.createSymbolicLink(at: agents, withDestinationURL: target)
    #expect(throws: AgentError.self) { try f.preview() }
    #expect(try Data(contentsOf: target) == original)
    try FileManager.default.removeItem(at: agents)
    try FileManager.default.linkItem(at: target, to: agents)
    #expect(throws: AgentError.self) { try f.preview() }
    #expect(try Data(contentsOf: target) == original)
}

@Test func setupRollsBackFirstFileIfSecondRenameFails() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let agents = f.root.appendingPathComponent("AGENTS.md")
    let claude = f.root.appendingPathComponent("CLAUDE.md")
    let original = Data("Existing instructions\n".utf8)
    try original.write(to: agents); try original.write(to: claude)
    try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: claude.path)
    defer { try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: claude.path) }
    let plan = try f.preview()
    #expect(throws: AgentError.self) { try ProjectInstructions.apply(plan) }
    #expect(try Data(contentsOf: agents) == original)
    #expect(try Data(contentsOf: claude) == original)
}
