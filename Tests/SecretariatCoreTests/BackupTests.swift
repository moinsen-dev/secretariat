import Foundation
import Testing
@testable import SecretariatCore

private func backups(_ f: AgentFixture) -> URL { Backup.directory(paths: f.vault.configuration.paths).url }

@Test func recoveryKeyIsReadableAndCatchesTypos() throws {
    let key = RecoveryKey.generate()
    let groups = key.split(separator: "-")
    #expect(groups.count == 11 && groups.allSatisfy { $0.count == 5 })
    #expect(key.allSatisfy { "0123456789ABCDEFGHJKMNPQRSTVWXYZ-".contains($0) })
    let secret = try RecoveryKey.decode(key)
    #expect(secret.count == 32)
    #expect(try RecoveryKey.decode(key.lowercased().replacingOccurrences(of: "-", with: " ")) == secret)
    #expect(try RecoveryKey.decode(key.replacingOccurrences(of: "0", with: "O").replacingOccurrences(of: "1", with: "l")) == secret)
    // One wrong character, one missing character, garbage: refused, never a different key.
    var typo = Array(key); typo[7] = typo[7] == "A" ? "B" : "A"
    #expect(throws: AgentError.self) { try RecoveryKey.decode(String(typo)) }
    #expect(throws: AgentError.self) { try RecoveryKey.decode(String(key.dropLast())) }
    #expect(throws: AgentError.self) { try RecoveryKey.decode("hello-world") }
    #expect(RecoveryKey.generate() != key)
}

@Test func backupIsSealedAndOnlyTheRecoveryKeyOpensIt() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    #expect(throws: AgentError.self) { try Backup.write(vault: f.vault) }
    let recovery = try Backup.setUp(vault: f.vault)
    try f.vault.screenshotKeys.add(id: "k1", key: Data(repeating: 7, count: 32))
    let url = try Backup.write(vault: f.vault, mac: "test-mac")
    let raw = try String(contentsOf: url, encoding: .utf8)
    for plain in ["never-output-this-value", "personal-never-out", "moinsen/test/api", "agent-test", "TEST_API_KEY", "KEY-123"] {
        #expect(!raw.contains(plain), "\(plain) in the backup file")
    }
    #expect((try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int) == 0o600)
    let header = try Backup.header(of: url)
    #expect(header.items == 1 && header.mac == "test-mac")

    let (_, payload) = try Backup.open(url, recoveryKey: recovery)
    #expect(payload.items.first?.secrets["secret"] == "never-output-this-value")
    #expect(payload.items.first?.secrets["password"] == "personal-never-out")
    #expect(payload.profiles.map(\.name) == ["agent-test"])
    #expect(payload.screenshotKeys["k1"] == Data(repeating: 7, count: 32))

    let code: (() throws -> Any) -> String? = { body in
        do { _ = try body(); return nil } catch let e as AgentError { return e.code } catch { return "other" }
    }
    #expect(code { try Backup.open(url, recoveryKey: RecoveryKey.generate()) } == "backup_wrong_key")
    // A changed header (more items) or a changed byte in the sealed part: refused, nothing read.
    var lines = raw.split(separator: "\n").map(String.init)
    let original = lines
    lines[0] = lines[0].replacingOccurrences(of: #""items":1"#, with: #""items":2"#)
    try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    #expect(code { try Backup.open(url, recoveryKey: recovery) } == "backup_damaged")
    lines = original
    var body = Array(lines[1]); body[40] = body[40] == "A" ? "B" : "A"; lines[1] = String(body)
    try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    #expect(code { try Backup.open(url, recoveryKey: recovery) } == "backup_damaged")
}

@Test func onePerMacAndDayAndTheNewestThirtyStay() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    _ = try Backup.setUp(vault: f.vault)
    let start = Date(timeIntervalSince1970: 1_790_000_000)
    for day in 0..<35 { try Backup.write(vault: f.vault, now: start.addingTimeInterval(Double(day) * 86_400), mac: "alpha") }
    try Backup.write(vault: f.vault, now: start.addingTimeInterval(34 * 86_400 + 3_600), mac: "alpha")   // same day again: replaces
    try Backup.write(vault: f.vault, now: start, mac: "beta")
    let files = Backup.files(in: backups(f))
    #expect(files.filter { $0.contains("-alpha.") }.count == 30)
    #expect(files.filter { $0.contains("-beta.") }.count == 1)
    #expect(files.first?.hasSuffix("-alpha.secretariat-backup") == true)
}

@Test func automaticBacksUpOnChangeAndOncePerDay() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    #expect(Backup.automatic(vault: f.vault) == nil)   // not set up
    _ = try Backup.setUp(vault: f.vault)
    let now = Date()
    #expect(Backup.automatic(vault: f.vault, now: now) != nil)
    #expect(Backup.automatic(vault: f.vault, now: now) == nil)   // nothing changed today
    try f.cli("item", "set", "moinsen/test/api", "--set", "key_id=KEY-456")
    #expect(Backup.automatic(vault: f.vault, now: now, onlyDaily: true) == nil)   // the CLI waits for the next day
    #expect(Backup.automatic(vault: f.vault, now: now) != nil)   // the app backs up the change
    #expect(Backup.automatic(vault: f.vault, now: now.addingTimeInterval(86_400), onlyDaily: true) != nil)
    #expect(f.vault.audit.tail(20).contains { $0.contains(#""action":"backup""#) && !$0.contains("never-output") })
}

@Test func restoreBringsBackWhatIsMissingAndChangesNothingElse() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let recovery = try Backup.setUp(vault: f.vault)
    var other = ItemMeta(path: "moinsen/other/api", kind: "api", fields: [ItemField(name: "secret", kind: .secret)])
    try f.vault.save(other, secrets: ["secret": "other-old"])
    try f.vault.screenshotKeys.add(id: "k1", key: Data(repeating: 1, count: 32))
    let url = try Backup.write(vault: f.vault, mac: "m")

    // Lost: the test item, its profile and the screenshot key. Changed since: the other item. New since: a third one.
    try f.vault.deleteProfile(id: f.profile.id)
    try f.vault.delete(id: f.item.id)
    try f.vault.screenshotKeys.removeAll()
    other = try f.vault.item(path: "moinsen/other/api"); try f.vault.save(other, secrets: ["secret": "other-new"])
    try f.vault.save(ItemMeta(path: "moinsen/new/api", kind: "api", fields: [ItemField(name: "secret", kind: .secret)]), secrets: ["secret": "new"])

    let (_, payload) = try Backup.open(url, recoveryKey: recovery)
    let restored = try Backup.restore(payload, into: f.vault)
    #expect(restored.items == 1 && restored.profiles == 1 && restored.screenshotKeys == 1 && restored.skipped.isEmpty)
    #expect(try f.vault.value(itemID: f.item.id, field: "secret") == "never-output-this-value")
    #expect(try f.vault.value(itemID: other.id, field: "secret") == "other-new")
    #expect((try? f.vault.item(path: "moinsen/new/api")) != nil)
    let launch = try f.vault.preparedLaunch(name: "agent-test", arguments: ["true"], inheritedEnvironment: [:])
    #expect(launch.environment["TEST_API_KEY"] == "never-output-this-value")
    // Again: nothing left to bring back.
    #expect(try Backup.restore(payload, into: f.vault) == Backup.Restored())
}

@Test func theCliShowsStatusAndBacksUpButNeverAKey() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    #expect(f.code("backup", "now") == "backup_not_set_up")
    #expect(f.code("backup", "setup") == "invalid_arguments")
    #expect(f.code("backup", "restore", "x") == "invalid_arguments")
    let recovery = try Backup.setUp(vault: f.vault)
    let (_, now) = try f.cli("backup", "now")
    let (_, status) = try f.cli("backup", "status")
    #expect(now.contains(".secretariat-backup") && status.contains(#""configured" : true"#) && status.contains(#""location" : "local""#))
    let secret = try RecoveryKey.decode(recovery)
    for output in [now, status] {
        #expect(!output.contains(recovery) && !output.contains("never-output"))
        #expect(!output.contains(Data(secret).base64EncodedString()))
    }
}
