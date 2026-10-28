import Foundation
import Testing
@testable import SecretariatCore

@Test func maskerReplacesValuesEvenWhenSplitAcrossReads() {
    var m = StreamMasker([.init(value: Data("sk-secret-123".utf8), label: "moinsen/openai/api_key"),
                          .init(value: Data("tiny".utf8), label: "too/short")])
    var out = Data()
    for chunk in ["log: key=sk-sec", "ret-123 done; again sk-secret-1", "23\nend tiny"] { out.append(m.feed(Data(chunk.utf8))) }
    out.append(m.finish())
    let text = String(decoding: out, as: UTF8.self)
    #expect(!text.contains("sk-secret-123"))
    #expect(text == "log: key=[masked moinsen/openai/api_key] done; again [masked moinsen/openai/api_key]\nend tiny")
}

@Test func runMasksSecretValuesButNotIdentifiers() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    var profile = f.profile
    profile.bindings.append(Binding(variable: "KEY_ID", itemID: f.item.id, field: "key_id"))
    try f.vault.saveProfile(profile)
    let launch = try f.vault.preparedLaunch(name: "agent-test", arguments: ["true"], inheritedEnvironment: [:])
    #expect(launch.masks.map(\.label) == ["moinsen/test/api/secret"])
}

@Test func approvalItemsNeedConfirmationForRunPushAndInject() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    var item = try f.vault.item(path: "moinsen/test/api"); item.approval = true; try f.vault.save(item)
    f.approver.allow = false
    #expect(throws: AgentError.self) { try f.vault.preparedLaunch(name: "agent-test", arguments: ["npm", "test"], inheritedEnvironment: [:]) }
    #expect(f.approver.reasons.last?.contains("moinsen/test/api") == true)
    f.approver.allow = true
    _ = try f.vault.preparedLaunch(name: "agent-test", arguments: ["npm", "test"], inheritedEnvironment: [:])
    #expect(f.vault.audit.tail(3).contains { $0.contains("\"approval\"") })
    // inject and push ask too
    let template = f.root.appendingPathComponent("t.tmpl"); try "x={{ moinsen/test/api/secret }}".write(to: template, atomically: true, encoding: .utf8)
    f.approver.allow = false
    #expect(f.code("inject", template.path, "--out", f.root.appendingPathComponent("o.txt").path) == "approval_denied")
    try f.cli("target", "add", "w", "--command", "cat > /dev/null # {var}", "--dir", f.root.path)
    try f.cli("target", "map", "w", "K", "moinsen/test/api/secret")
    #expect(f.code("push", "w") == "approval_denied")
    // agents can switch approval on, never off
    try f.cli("item", "set", "moinsen/test/api", "--approval", "on")
    #expect(f.code("item", "set", "moinsen/test/api", "--approval", "off") == "app_only")
    #expect(try f.vault.item(path: "moinsen/test/api").needsApproval)
}

@Test func gitGuardFindsKnownValuesOnlyInAddedLines() throws {
    let diff = """
    diff --git a/src/config.ts b/src/config.ts
    +++ b/src/config.ts
    @@ -0,0 +1,3 @@
    +export const a = 1
    +const key = "never-output-this-value"
    +const ok = process.env.KEY
    @@ -10 +12 @@
    -old "never-output-this-value"
    +const again = "never-output-this-value"
    """
    let findings = GitGuard.scan(diff: diff, secrets: [("never-output-this-value", "moinsen/test/api/secret")])
    #expect(findings.map { "\($0.file):\($0.line)" } == ["src/config.ts:2", "src/config.ts:12"])
    #expect(findings.allSatisfy { $0.reference == "moinsen/test/api/secret" })
}

@Test func gitGuardBlocksARealStagedCommitAndInstallsIdempotently() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let repo = f.root.appendingPathComponent("repo"); try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
    _ = Inject.git(["-C", repo.path, "init", "-q"])
    try "API=never-output-this-value\n".write(to: repo.appendingPathComponent("leak.env"), atomically: true, encoding: .utf8)
    _ = Inject.git(["-C", repo.path, "add", "leak.env"])
    let (code, json) = try f.cli("guard", "check", repo.path)
    #expect(code == 1); #expect(json.contains("leak.env")); #expect(!json.contains("never-output"))
    #expect(try GitGuard.install(in: repo.path, executable: "/tmp/secretariat") == "installed")
    #expect(try GitGuard.install(in: repo.path, executable: "/tmp/secretariat") == "already installed")
    let hook = try String(contentsOf: repo.appendingPathComponent(".git/hooks/pre-commit"), encoding: .utf8)
    #expect(hook.hasPrefix("#!/bin/sh")); #expect(hook.contains("guard check || exit 1"))
    #expect(try GitGuard.install(in: repo.path, executable: "/tmp/secretariat", remove: true) == "removed")
    #expect(!(try String(contentsOf: repo.appendingPathComponent(".git/hooks/pre-commit"), encoding: .utf8)).contains("guard check"))
}

@Test func mcpToolsMapOntoCliAndRunMasksOutput() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let (list, listError) = McpServer.call("list_items", [:], service: f.service, executable: "/tmp/s")
    #expect(!listError); #expect(list.contains("moinsen/test/api")); #expect(!list.contains("never-output"))
    let (secret, secretError) = McpServer.call("get_identifier", ["reference": "moinsen/test/api/secret"], service: f.service, executable: "/tmp/s")
    #expect(secretError); #expect(secret.contains("secret_field"))
    let (id, _) = McpServer.call("get_identifier", ["reference": "moinsen/test/api/key_id"], service: f.service, executable: "/tmp/s")
    #expect(id.contains("KEY-123"))
    let (run, runError) = McpServer.call("run_command", ["profile": "agent-test", "command": ["/bin/sh", "-c", "echo got $TEST_API_KEY; exit 3"]], service: f.service, executable: "/tmp/s")
    #expect(runError); #expect(run.contains("[masked moinsen/test/api/secret]")); #expect(!run.contains("never-output")); #expect(run.contains("\"exitCode\" : 3"))
    let (unknown, unknownError) = McpServer.call("nope", [:], service: f.service, executable: "/tmp/s")
    #expect(unknownError); #expect(unknown.contains("unknown_tool"))
}

@Test func gitGuardIgnoresPlainWordsButKeepsCredentialLikeValues() {
    #expect(!GitGuard.distinctive("identifier")); #expect(!GitGuard.distinctive("short1"))
    #expect(GitGuard.distinctive("password123")); #expect(GitGuard.distinctive("sk-proj-abc9")); #expect(GitGuard.distinctive("averyveryverylongword"))
}
