import Foundation
import Testing
@testable import SecretariatCore

private final class AgentCredentials: CredentialStore {
    var reads = 0
    var values: [UUID: String] = [:]
    var denied = false
    func read(id: UUID) throws -> String {
        reads += 1
        if denied { throw SecretariatError("provider-error-containing-sensitive-input") }
        guard let value = values[id] else { throw CredentialError.notFound }
        return value
    }
    func set(_ value: String, id: UUID, label: String) throws { values[id] = value }
    func delete(id: UUID) throws { values.removeValue(forKey: id) }
}
private struct AgentFixture {
    let root: URL
    let credentials = AgentCredentials()
    let store: ConfigurationStore
    let profile: Profile
    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("secretariat-agents-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = ConfigurationStore(paths: AppPaths(directory: root.appendingPathComponent("vault")))
        let vault = Vault(configuration: store, credentials: credentials)
        let id = try vault.addSecret(name: "Künstlicher Test", value: "never-output-this-value")
        profile = Profile(name: "agent-test", directory: root.path, command: "echo not-run", bindings: [Binding(variable: "TEST_API_KEY", secretID: id)])
        try vault.saveProfile(profile)
    }
    var service: AgentService { AgentService(configuration: store, credentials: credentials) }
    func preview(_ profile: Profile? = nil) throws -> InstructionPlan {
        try ProjectInstructions.preview(profile: profile ?? self.profile, executable: "/tmp/App's folder/Secretariat")
    }
    func cleanup() { try? FileManager.default.removeItem(at: root) }
}

@Test func metadataAndInstructionsReadNoCredentialsAndContainNoValues() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let list = try AgentCommand.json(f.service.profiles())
    let description = try AgentCommand.json(f.service.describe("agent-test"))
    let instructions = try f.preview().instructions
    #expect(f.credentials.reads == 0)
    for result in [list, description, instructions] { #expect(!result.contains("never-output-this-value")) }
    #expect(list.contains("schemaVersion")); #expect(description.contains("TEST_API_KEY"))
    #expect(instructions.contains("'\\''"))
    #expect(!FileManager.default.fileExists(atPath: f.root.appendingPathComponent("AGENTS.md").path))
}

@Test func checkReportsAvailabilityWithoutMutationOrProviderErrors() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let before = try Data(contentsOf: f.store.paths.configuration)
    let good = try f.service.check("agent-test")
    #expect(good.ok); #expect(good.variables.first?.status == "available")
    f.credentials.denied = true
    let denied = try f.service.check("agent-test")
    #expect(!denied.ok); #expect(denied.variables.first?.status == "unavailable")
    #expect(!(try AgentCommand.json(denied)).contains("sensitive-input"))
    f.credentials.denied = false; f.credentials.values.removeAll()
    #expect(try f.service.check("agent-test").variables.first?.status == "missing")
    #expect(try Data(contentsOf: f.store.paths.configuration) == before)
    #expect(throws: AgentError.self) { try f.service.profile(named: "unknown") }
    let error = try AgentCommand.json(AgentFailure(SecretariatError("sensitive-input")))
    #expect(!error.contains("sensitive-input")); #expect(error.contains("operation_failed"))
}

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
