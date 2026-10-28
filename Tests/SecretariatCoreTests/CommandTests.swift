import Foundation
import Testing
@testable import SecretariatCore

@Test func listingAndDescribingNeverPrintSecretValues() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    f.items.secretReads = 0
    let (_, items) = try f.cli("items")
    let (_, show) = try f.cli("item", "show", "moinsen/test/api")
    let (_, profiles) = try f.cli("profiles")
    let (_, describe) = try f.cli("describe", "agent-test")
    #expect(f.items.secretReads == 0)
    for output in [items, show, profiles, describe] {
        #expect(!output.contains("never-output")); #expect(!output.contains("personal-never"))
    }
    #expect(items.contains("KEY-123")); #expect(describe.contains("moinsen/test/api/secret"))
}

@Test func getReturnsIdentifiersAndRefusesSecrets() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let (_, json) = try f.cli("get", "moinsen/test/api/key_id")
    #expect(json.contains("KEY-123"))
    #expect(f.code("get", "moinsen/test/api/secret") == "secret_field")
    #expect(f.code("get", "moinsen/test/api/password") == "secret_field")
    #expect(f.code("get", "moinsen/test/api/nope") == "field_not_found")
    #expect(f.code("get", "moinsen/none/x") == "item_not_found")
}

@Test func itemCreateAndSetHandleIdentifiersOnly() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    try f.cli("item", "create", "moinsen/apple-developer", "--kind", "account", "--set", "team_id=VXX45ZYNM8", "--set", "login=dev@example.com", "--source", "codesigning identity")
    #expect(try f.vault.get("moinsen/apple-developer/team_id") == "VXX45ZYNM8")
    try f.cli("item", "set", "moinsen/apple-developer", "--set", "team_id=NEW", "--unset", "login", "--expires", "2027-01-01")
    let item = try f.vault.item(path: "moinsen/apple-developer")
    #expect(item.field("login") == nil); #expect(item.expires == "2027-01-01"); #expect(item.field("team_id")?.value == "NEW")
    #expect(f.code("item", "set", "moinsen/test/api", "--set", "secret=leak") == "secret_field")
    #expect(f.code("item", "set", "moinsen/test/api", "--unset", "secret") == "secret_field")
    #expect(f.code("item", "create", "moinsen/apple-developer", "--kind", "account") == "path_exists")
    #expect(f.code("item", "create", "x/y", "--kind", "nope") == "invalid_arguments")
    try f.cli("item", "rename", "moinsen/apple-developer", "moinsen/apple")
    #expect(try f.vault.get("moinsen/apple/team_id") == "NEW")
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
    #expect(env["A"] == "last"); #expect(env["B"] == "dq \"x\" \n y"); #expect(env["C"] == "sq # not comment"); #expect(env["D"] == "")
}

@Test func importMovesDotenvValuesIntoItemsAndBindsTheProfile() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let dir = f.root.appendingPathComponent("adventurist"); try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent(".env")
    try "CF_Access_Client_Id=import-one\nCF_Access_Client_Secret=\"import-two\"\n".write(to: file, atomically: true, encoding: .utf8)
    let (_, json) = try f.cli("import", file.path, "CF_Access_Client_Id", "CF_Access_Client_Secret=moinsen/cloudflare/access/client_secret", "--profile", "agent-test")
    #expect(!json.contains("import-"))
    #expect(json.contains("imported/adventurist/cf_access_client_id"))
    let item = try f.vault.item(path: "moinsen/cloudflare/access")
    #expect(try f.vault.value(itemID: item.id, field: "client_secret") == "import-two")
    #expect(try f.service.describe("agent-test").profile.variables == ["CF_Access_Client_Id", "CF_Access_Client_Secret", "TEST_API_KEY"])
    #expect(try f.service.check("agent-test").ok)
    #expect(f.code("import", file.path, "CF_Access_Client_Id") == "field_exists")
    try f.cli("import", file.path, "CF_Access_Client_Id", "--replace")
    #expect(f.code("import", file.path, "NOPE") == "variable_missing")
    #expect(f.code("import", file.path + ".fehlt", "X") == "file_unreadable")
    #expect(f.code("import", file.path, "CF_Access_Client_Id=x/y", "--profile", "fehlt") == "profile_not_found")
}

@Test func importFileStoresAFileFieldUsableByRun() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let key = f.root.appendingPathComponent("AuthKey_T5.p8"); try "-----BEGIN PRIVATE KEY-----\nabc\n".write(to: key, atomically: true, encoding: .utf8)
    let (_, json) = try f.cli("import-file", key.path, "moinsen/app-store-connect/api-key/private_key")
    #expect(!json.contains("BEGIN"))
    let item = try f.vault.item(path: "moinsen/app-store-connect/api-key")
    #expect(item.field("private_key")?.kind == .file); #expect(item.field("private_key")?.fileName == "AuthKey_T5.p8")
    try f.cli("profile", "bind", "agent-test", "ASC_KEY", "moinsen/app-store-connect/api-key/private_key")
    let launch = try f.vault.preparedLaunch(name: "agent-test", arguments: ["true"], inheritedEnvironment: [:])
    #expect(String(decoding: launch.files[0].data, as: UTF8.self).hasPrefix("-----BEGIN"))
}

@Test func profileCommandsBindByReferenceAndRefusePersonalFields() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let dir = f.root.appendingPathComponent("projekt"); try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try f.cli("profile", "create", "neu", "--dir", dir.path, "--command", "pnpm dev")
    try f.cli("profile", "bind", "neu", "GEMINI_API_KEY", "moinsen/test/api/secret")
    #expect(try f.service.check("neu").ok)
    #expect(f.code("profile", "bind", "neu", "PW", "moinsen/test/api/password") == "personal_field")
    #expect(f.code("profile", "bind", "neu", "X", "moinsen/none/f") == "item_not_found")
    #expect(f.code("profile", "bind", "neu", "1BAD", "moinsen/test/api/secret") == "invalid")
    #expect(f.code("profile", "create", "neu", "--dir", dir.path) == "profile_exists")
    #expect(f.code("profile", "unbind", "neu", "NOPE") == "variable_not_bound")
    try f.cli("profile", "unbind", "neu", "GEMINI_API_KEY")
    try f.cli("profile", "delete", "neu")
    #expect(f.code("describe", "neu") == "profile_not_found")
    #expect(f.code("items", "--bogus") == "invalid_arguments")
}

@Test func checkReportsMissingUnavailableAndPersonalBindings() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    var profile = f.profile
    profile.bindings.append(Binding(variable: "PW", itemID: f.item.id, field: "password"))
    try f.vault.saveProfile(profile)
    let result = try f.service.check("agent-test")
    #expect(!result.ok); #expect(result.variables.first { $0.variable == "PW" }?.status == "personal")
    f.items.denied = true
    #expect(try f.service.check("agent-test").variables.first { $0.variable == "TEST_API_KEY" }?.status == "unavailable")
    f.items.denied = false; f.items.values[f.item.id] = [:]
    #expect(try f.service.check("agent-test").variables.first { $0.variable == "TEST_API_KEY" }?.status == "missing")
    let failure = try Commands.json(AgentFailure(NSError(domain: "x", code: 1, userInfo: [NSLocalizedDescriptionKey: "sensitive-input"])))
    #expect(!failure.contains("sensitive-input")); #expect(failure.contains("operation_failed"))
}

@Test func injectRendersReferencesIntoAnUntrackedPrivateFile() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let template = f.root.appendingPathComponent("config.tmpl")
    try "id={{ moinsen/test/api/key_id }}\nsecret={{moinsen/test/api/secret}}\n".write(to: template, atomically: true, encoding: .utf8)
    let out = f.root.appendingPathComponent("out/config.ini")
    try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
    let (_, json) = try f.cli("inject", template.path, "--out", out.path)
    #expect(!json.contains("never-output"))
    #expect(try String(contentsOf: out, encoding: .utf8) == "id=KEY-123\nsecret=never-output-this-value\n")
    #expect((try FileManager.default.attributesOfItem(atPath: out.path)[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    // inside a git repository the destination must be ignored
    let repo = f.root.appendingPathComponent("repo"); try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
    _ = Inject.git(["-C", repo.path, "init", "-q"])
    #expect(f.code("inject", template.path, "--out", repo.appendingPathComponent("app.env").path) == "tracked_destination")
    try "app.env\n".write(to: repo.appendingPathComponent(".gitignore"), atomically: true, encoding: .utf8)
    try f.cli("inject", template.path, "--out", repo.appendingPathComponent("app.env").path)
    try "x={{ moinsen/test/api/password }}".write(to: template, atomically: true, encoding: .utf8)
    #expect(f.code("inject", template.path, "--out", out.path) == "personal_field")
}

@Test func targetsTrackWhatWasPushedAndFlagStaleCopies() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let sink = f.root.appendingPathComponent("sink"); try FileManager.default.createDirectory(at: sink, withIntermediateDirectories: true)
    try f.cli("target", "add", "worker", "--command", "cat > {var}.txt", "--dir", sink.path)
    try f.cli("target", "map", "worker", "API_KEY", "moinsen/test/api/secret")
    #expect(try Targets.report(vault: f.vault).targets[0].variables[0].status == "never")
    #expect(try f.vault.configuration.load().targets[0].directory.hasPrefix("/"))
    let (_, dry) = try f.cli("push", "worker", "--dry-run")
    #expect(dry.contains("API_KEY")); #expect(!FileManager.default.fileExists(atPath: sink.appendingPathComponent("API_KEY.txt").path))
    let (_, pushed) = try f.cli("push", "worker")
    #expect(!pushed.contains("never-output"))
    #expect(try String(contentsOf: sink.appendingPathComponent("API_KEY.txt"), encoding: .utf8) == "never-output-this-value")
    #expect(try Targets.report(vault: f.vault).targets[0].variables[0].status == "current")
    let stored = try f.vault.configuration.load().targets[0].pushed["API_KEY"] ?? ""
    #expect(!stored.isEmpty); #expect(!stored.contains("never-output"))
    try f.vault.setValue(FieldReference(path: "moinsen/test/api", field: "secret"), value: "rotated", replace: true)
    #expect(try Targets.report(vault: f.vault).targets[0].variables[0].status == "stale")
    #expect(f.code("target", "map", "worker", "PW", "moinsen/test/api/password") == "personal_field")
    #expect(f.code("target", "add", "bad", "--command", "no placeholder") == "invalid")
    #expect(f.code("push", "fehlt") == "target_not_found")
    try f.cli("target", "unmap", "worker", "API_KEY"); try f.cli("target", "delete", "worker")
    #expect(try f.vault.configuration.load().targets.isEmpty)
}

@Test func scanFindsDotenvFilesAndRecognisesStoredValues() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let project = f.root.appendingPathComponent("work/app"); try FileManager.default.createDirectory(at: project.appendingPathComponent("node_modules/x"), withIntermediateDirectories: true)
    try "API=never-output-this-value\nOTHER=fresh\nEMPTY=\n".write(to: project.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    try "API=x\n".write(to: project.appendingPathComponent(".env.example"), atomically: true, encoding: .utf8)
    try "API=x\n".write(to: project.appendingPathComponent("node_modules/x/.env"), atomically: true, encoding: .utf8)
    let (_, json) = try f.cli("scan", f.root.appendingPathComponent("work").path)
    #expect(!json.contains("never-output")); #expect(!json.contains("fresh"))
    let findings = try Scan.run(root: f.root.appendingPathComponent("work"), vault: f.vault)
    #expect(findings.count == 1)
    #expect(findings[0].variables.map(\.name) == ["API", "OTHER"])
    #expect(findings[0].variables[0].storedAs == "moinsen/test/api/secret")
}

@Test func argumentParserRejectsUnknownAndDuplicateFlags() {
    #expect(throws: AgentError.self) { try Arguments(["a", "--bogus"], usage: "u") }
    #expect(throws: AgentError.self) { try Arguments(["--json", "--json"], usage: "u") }
    #expect(throws: AgentError.self) { try Arguments(["--dir"], values: ["--dir"], usage: "u") }
    let a = try? Arguments(["p", "--set", "a=1", "--set", "b=2", "--json"], values: ["--set"], usage: "u")
    #expect(a?.options["--set"] == ["a=1", "b=2"]); #expect(a?.json == true); #expect(a?.positional == ["p"])
}

@Test func profileWhichFindsTheClosestProjectProfile() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let sub = f.root.appendingPathComponent("src/deep"); try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
    let (_, json) = try f.cli("profile", "which", sub.path)
    #expect(json.contains("agent-test"))
    #expect(f.code("profile", "which", "/") == "profile_not_found")
}

@Test func templatesAreDataUsersCanExtendHideAndReset() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    // a new template with its own fields, usable as a kind right away
    try f.cli("template", "create", "bank-account", "--title", "Bank account", "--symbol", "banknote", "--identity")
    try f.cli("template", "field", "add", "bank-account", "iban", "--label", "IBAN", "--required")
    try f.cli("template", "field", "add", "bank-account", "online_pin", "--label", "Online banking PIN", "--kind", "personal")
    let t = f.vault.catalog().template("bank-account")
    #expect(t.title == "Bank account"); #expect(t.fields.map(\.name) == ["iban", "online_pin"]); #expect(t.identity)
    #expect(t.spec("online_pin")?.kind == .personal); #expect(t.spec("iban")?.required == true)
    try f.cli("item", "create", "moinsen/bank", "--kind", "bank-account", "--set", "iban=DE00 1234")
    #expect(CompanyRule.render(try f.vault.list(), catalog: f.vault.catalog()).contains("- IBAN: DE00 1234"))
    #expect(f.code("item", "create", "x/y", "--kind", "nope") == "invalid_arguments")
    // built-ins: change, hide everywhere, bring back
    try f.cli("template", "field", "add", "company", "trade_name", "--label", "Trade name")
    #expect(f.vault.catalog().template("company").spec("trade_name") != nil)
    try f.cli("template", "delete", "note")
    #expect(!f.vault.catalog().isKnown("note"))
    try f.cli("template", "reset", "note"); try f.cli("template", "reset", "company")
    #expect(f.vault.catalog().isKnown("note")); #expect(f.vault.catalog().template("company").spec("trade_name") == nil)
    // deleting an own template keeps its items readable with plain field names
    try f.cli("template", "delete", "bank-account")
    #expect(f.vault.catalog().template("bank-account").title == "bank-account")
    #expect(try f.vault.get("moinsen/bank/iban") == "DE00 1234")
    #expect(f.code("template", "create", "Bad ID") == "invalid")
    #expect(f.code("template", "create", "company") == "template_exists")
    #expect(f.code("template", "reset", "bank-account") == "not_builtin")
}
