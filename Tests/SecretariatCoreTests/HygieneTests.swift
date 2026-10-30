import Foundation
import Testing
@testable import SecretariatCore

private func bash(_ command: String) -> String? { AgentHook.refusal(tool: "Bash", input: ["command": command]) }

@Test func agentHookRefusesSecretReadsAndAllowsOrdinaryWork() {
    for risky in ["cat .env", "cat ./apps/web/.env.local", "grep OPENAI .env", "head -5 .env.production", "source .env && npm start",
                  "printenv", "env", "env | grep KEY", "cd api && printenv OPENAI_API_KEY", "docker compose config",
                  "docker-compose -f x.yml config", "security find-generic-password -s foo -w",
                  "secretariat run web --no-mask -- env", "cat /proc/42/environ",
                 "secretariat header moinsen/x/mcp/token --bearer", "~/bin/secretariat header a/b | cat"] {
        #expect(bash(risky) != nil, "should refuse: \(risky)")
    }
    for fine in ["cat .env.example", "cp .env.example .env.template", "env NODE_ENV=test npm test", "set -e; npm run build",
                 "grep -r OPENAI src", "ls -la", "secretariat run web -- npm test", "docker compose up -d", "cat README.md",
                 "echo $HOME", "git commit -m 'env cleanup'"] {
        #expect(bash(fine) == nil, "should allow: \(fine)")
    }
    #expect(AgentHook.refusal(tool: "Read", input: ["file_path": "/Users/x/work/app/.env"]) != nil)
    #expect(AgentHook.refusal(tool: "Read", input: ["file_path": "/Users/x/work/app/.env.local"]) != nil)
    #expect(AgentHook.refusal(tool: "Read", input: ["file_path": "/Users/x/work/app/.env.example"]) == nil)
    #expect(AgentHook.refusal(tool: "Read", input: ["file_path": "/Users/x/work/app/src/env.ts"]) == nil)
    #expect(AgentHook.refusal(tool: "Grep", input: ["pattern": "KEY", "glob": "**/.env*"]) != nil)
}

@Test func agentHookAnswersWithADenyDecision() throws {
    let input = #"{"tool_name":"Bash","tool_input":{"command":"cat .env"}}"#
    let answer = try #require(AgentHook.handle(Data(input.utf8)))
    let json = try #require(JSONSerialization.jsonObject(with: Data(answer.utf8)) as? [String: Any])
    let out = try #require(json["hookSpecificOutput"] as? [String: Any])
    #expect(out["permissionDecision"] as? String == "deny")
    #expect((out["permissionDecisionReason"] as? String)?.contains("secretariat run") == true)
    #expect(AgentHook.handle(Data(#"{"tool_name":"Bash","tool_input":{"command":"npm test"}}"#.utf8)) == nil)
}

@Test func agentHookInstallKeepsOtherSettingsAndIsIdempotent() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("hook-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let settings = dir.appendingPathComponent("settings.json").path
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try #"{"model":"opus","hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"x"}]}]}}"#.write(toFile: settings, atomically: true, encoding: .utf8)
    #expect(try AgentHook.install(settings: settings, executable: "/Apps/S/secretariat", remove: false) == "installed")
    #expect(try AgentHook.install(settings: settings, executable: "/Apps/S/secretariat", remove: false) == "already installed")
    let text = try String(contentsOfFile: settings, encoding: .utf8)
    #expect(text.contains("\"model\" : \"opus\"") && text.contains("SessionStart") && text.contains("guard claude-hook"))
    #expect(try AgentHook.install(settings: settings, executable: "/Apps/S/secretariat", remove: true) == "removed")
    let after = try String(contentsOfFile: settings, encoding: .utf8)
    #expect(!after.contains("claude-hook") && after.contains("SessionStart"))
}

@Test func sweepFindsKnownValuesInFilesAndHistory() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let repo = f.root.appendingPathComponent("leaky").path
    func git(_ args: String...) { _ = GitGuard.git(Array(args), in: repo) }
    try FileManager.default.createDirectory(atPath: repo, withIntermediateDirectories: true)
    git("init", "-q"); git("config", "user.email", "t@t"); git("config", "user.name", "t")
    try "KEY=never-output-this-value\n".write(toFile: repo + "/config.js", atomically: true, encoding: .utf8)
    git("add", "."); git("commit", "-qm", "oops")
    try "KEY=process.env.KEY\n".write(toFile: repo + "/config.js", atomically: true, encoding: .utf8)
    try "pw: personal-never-out\n".write(toFile: repo + "/notes.md", atomically: true, encoding: .utf8)
    git("add", "."); git("commit", "-qm", "fix")
    let repos = Sweep.repositories(under: f.root.path)
    #expect(repos == [repo])
    let findings = try Sweep.run(repositories: repos, secrets: GitGuard.secrets(f.vault), history: true)
    let config = try #require(findings.first { $0.file == "config.js" })
    #expect(config.reference == "moinsen/test/api/secret" && !config.current && config.commit?.count == 10)
    let notes = try #require(findings.first { $0.file == "notes.md" })
    #expect(notes.reference == "moinsen/test/api/password" && notes.current)
    let current = try Sweep.run(repositories: repos, secrets: GitGuard.secrets(f.vault), history: false)
    #expect(current.map(\.file) == ["notes.md"])
    // No value ever appears in the result.
    #expect(!(try Commands.json(findings)).contains("never-output"))
}

@Test func tidyOnlyRetiresEnvFilesFullyCoveredBySecretariat() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let covered = f.root.appendingPathComponent("covered"), partial = f.root.appendingPathComponent("partial")
    for dir in [covered, partial] { try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) }
    try "TEST_API_KEY=never-output-this-value\n".write(to: covered.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    try "TEST_API_KEY=never-output-this-value\nOTHER=unknown-value-123\n".write(to: partial.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    let entries = try Tidy.run(root: f.root, vault: f.vault, apply: false)
    #expect(entries.first { $0.file.contains("/covered/") }?.action == "trash")
    let keep = try #require(entries.first { $0.file.contains("/partial/") })
    #expect(keep.action == "keep" && keep.reason.contains("OTHER") && !keep.reason.contains("unknown-value"))
    #expect(FileManager.default.fileExists(atPath: covered.appendingPathComponent(".env").path))   // dry run touches nothing
}

@Test func matcherFindsValuesAnywhereAndIgnoresTooShortOnes() {
    let m = Matcher(["sk-live-4f9a2b7c1d", "abc"])
    #expect(m.contains(Array("\u{0}\u{1}binary sk-live-4f9a2b7c1d tail".utf8)))
    #expect(!m.contains(Array("sk-live-4f9a2b7c1 almost".utf8)))
    #expect(!m.contains(Array("abc abc".utf8)))
    #expect(Matcher([]).contains(Array("anything".utf8)) == false)
}

@Test func dotEnvTreatsCommentAfterEmptyValueAsEmpty() {
    let env = DotEnv.parse("FAL_KEY=                     # FLUX images\nTAB=abc123def\t# note\nKEEP=a#b\nQ=\"x # y\"\n")
    #expect(env["FAL_KEY"] == "")
    #expect(env["TAB"] == "abc123def")
    #expect(env["KEEP"] == "a#b")
    #expect(env["Q"] == "x # y")
}

@Test func placeholdersAreNotGuardedValues() {
    #expect(Placeholder.reason("# FLUX images, Google Veo video") != nil)
    #expect(Placeholder.reason("your_api_key_here") != nil)
    #expect(Placeholder.reason("<OPENAI_KEY>") != nil)
    #expect(Placeholder.reason("sk-proj-4f9a2b7c1d8e") == nil)
    #expect(!GitGuard.distinctive("# Get your key at https://example.com"))
}
