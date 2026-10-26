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

@Test func keysListNamesAndUsageWithoutReadingValues() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let keys = try f.service.keys()
    let json = try AgentCommand.json(keys)
    #expect(f.credentials.reads == 0)
    #expect(keys.keys.map(\.name) == ["Künstlicher Test"])
    #expect(keys.keys.first?.profiles == ["agent-test"])
    #expect(!json.contains("never-output-this-value"))
}

@Test func profileCreateBindUnbindDeleteRoundTrip() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let dir = f.root.appendingPathComponent("projekt"); try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let created = try f.service.createProfile(name: "neu", directory: dir.path, command: "pnpm dev")
    #expect(created.profile.directory == dir.resolvingSymlinksInPath().path)
    #expect(created.profile.variables.isEmpty)
    // bind by name, case-insensitive fallback; rebinding a variable replaces it
    _ = try f.service.bind(profile: "neu", variable: "GEMINI_API_KEY", key: "künstlicher test")
    let rebound = try f.service.bind(profile: "neu", variable: "GEMINI_API_KEY", key: "Künstlicher Test")
    #expect(rebound.profile.variables == ["GEMINI_API_KEY"])
    #expect(try f.service.check("neu").ok)
    #expect(try f.service.keys().keys.first?.profiles == ["agent-test", "neu"])
    let unbound = try f.service.unbind(profile: "neu", variable: "GEMINI_API_KEY")
    #expect(unbound.profile.variables.isEmpty)
    _ = try f.service.deleteProfile(name: "neu")
    #expect(throws: AgentError.self) { try f.service.describe("neu") }
    #expect(!(try f.service.profiles().profiles.map(\.name).contains("neu")))
}

@Test func profileCommandsRejectInvalidInputWithStableCodes() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    func code(_ body: () throws -> Void) -> String? {
        do { try body(); return nil } catch let e as AgentError { return e.code } catch { return "other" }
    }
    #expect(code { _ = try f.service.createProfile(name: "agent-test", directory: f.root.path, command: nil) } == "profile_exists")
    #expect(code { _ = try f.service.createProfile(name: "x", directory: f.root.appendingPathComponent("fehlt").path, command: nil) } == "invalid_profile")
    #expect(code { _ = try f.service.createProfile(name: "-bad name", directory: f.root.path, command: nil) } == "invalid_profile")
    #expect(code { _ = try f.service.bind(profile: "agent-test", variable: "OK_VAR", key: "gibt es nicht") } == "key_not_found")
    #expect(code { _ = try f.service.bind(profile: "agent-test", variable: "1BAD", key: "Künstlicher Test") } == "invalid_profile")
    #expect(code { _ = try f.service.unbind(profile: "agent-test", variable: "NOPE") } == "variable_not_bound")
    #expect(code { _ = try f.service.deleteProfile(name: "fehlt") } == "profile_not_found")
    // a failed mutation leaves the configuration untouched
    let before = try Data(contentsOf: f.store.paths.configuration)
    _ = code { _ = try f.service.bind(profile: "agent-test", variable: "1BAD", key: "Künstlicher Test") }
    #expect(try Data(contentsOf: f.store.paths.configuration) == before)
    #expect(f.credentials.reads == 0)
}

@Test func profileArgumentParserHandlesValuesAndRejectsUnknownOptions() throws {
    let p = try ProfileCommand.parse(["neu", "--dir", "/tmp/x", "--command", "--weird but valid", "--json"][...], valueOptions: ["--dir", "--command"])
    #expect(p.positional == ["neu"]); #expect(p.options["--dir"] == "/tmp/x")
    #expect(p.options["--command"] == "--weird but valid"); #expect(p.json)
    #expect(throws: AgentError.self) { try ProfileCommand.parse(["neu", "--force"][...], valueOptions: ["--dir"]) }
    #expect(throws: AgentError.self) { try ProfileCommand.parse(["neu", "--dir"][...], valueOptions: ["--dir"]) }
    #expect(throws: AgentError.self) { try ProfileCommand.parse(["--json", "--json"][...], valueOptions: []) }
}

@Test func dotenvParsingHandlesExportQuotesAndComments() {
    let env = DotEnv.parse("""
    # comment
    export A=plain # trailing
    B="dq \\"x\\" \\n y"
    C='sq # not comment'
    D=
    A=last
    """)
    #expect(env["A"] == "last")
    #expect(env["B"] == "dq \"x\" \n y")
    #expect(env["C"] == "sq # not comment")
    #expect(env["D"] == "")
}

@Test func importStoresValuesBindsProfileAndOutputsNamesOnly() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let file = f.root.appendingPathComponent(".env")
    try "CF_ID=import-secret-one\nCF_SECRET=\"import-secret-two\"\n".write(to: file, atomically: true, encoding: .utf8)
    let result = try f.service.importKeys(file: file.path, requests: ["CF_ID", "CF_SECRET=Routing Secret"], profile: "agent-test", replace: false)
    let json = try AgentCommand.json(result)
    #expect(!json.contains("import-secret"))
    #expect(result.imported.map(\.action) == ["created", "created"])
    #expect(Set(f.credentials.values.values).isSuperset(of: ["import-secret-one", "import-secret-two"]))
    #expect(try f.service.describe("agent-test").profile.variables.sorted() == ["CF_ID", "CF_SECRET", "TEST_API_KEY"])
    #expect(try f.service.check("agent-test").ok)
    // existing key: refused without --replace, overwritten with it
    func code(_ body: () throws -> Void) -> String? {
        do { try body(); return nil } catch let e as AgentError { return e.code } catch { return "other" }
    }
    try "CF_ID=rotated-value\n".write(to: file, atomically: true, encoding: .utf8)
    #expect(code { _ = try f.service.importKeys(file: file.path, requests: ["CF_ID"], profile: nil, replace: false) } == "key_exists")
    let replaced = try f.service.importKeys(file: file.path, requests: ["CF_ID"], profile: nil, replace: true)
    #expect(replaced.imported.first?.action == "updated")
    #expect(f.credentials.values.values.contains("rotated-value"))
    #expect(code { _ = try f.service.importKeys(file: file.path, requests: ["NOPE"], profile: nil, replace: false) } == "variable_missing")
    #expect(code { _ = try f.service.importKeys(file: file.path + ".fehlt", requests: ["CF_ID"], profile: nil, replace: false) } == "file_unreadable")
    #expect(code { _ = try f.service.importKeys(file: file.path, requests: ["CF_ID=Neu"], profile: "fehlt", replace: false) } == "profile_not_found")
    #expect(!f.credentials.values.isEmpty)
}
