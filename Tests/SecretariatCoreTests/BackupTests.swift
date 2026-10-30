import Foundation
import Testing
@testable import SecretariatCore

private func backups(_ f: AgentFixture) -> URL { Backup.directory(paths: f.vault.configuration.paths).url }
private let alpha = BackupMac(name: "alpha", id: "0000000a")

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
    let url = try Backup.write(vault: f.vault, mac: BackupMac(name: "test-mac", id: "1234abcd"))
    let raw = try String(contentsOf: url, encoding: .utf8)
    for plain in ["never-output-this-value", "personal-never-out", "moinsen/test/api", "agent-test", "TEST_API_KEY", "KEY-123"] {
        #expect(!raw.contains(plain), "\(plain) in the backup file")
    }
    #expect((try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int) == 0o600)
    let header = try Backup.header(of: url)
    #expect(header.items == 1 && header.mac == "test-mac" && header.macID == "1234abcd")

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

@Test func onePerMacAndDayAndTheNewestThirtyStayEvenWithLookAlikeNames() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    _ = try Backup.setUp(vault: f.vault)
    let pro = BackupMac(name: "pro", id: "000000b1"), macbookPro = BackupMac(name: "macbook-pro", id: "000000b2")
    let twin = BackupMac(name: "pro", id: "000000b3")   // another Mac with the same name
    let start = Date(timeIntervalSince1970: 1_790_000_000)
    for day in 0..<35 { try Backup.write(vault: f.vault, now: start.addingTimeInterval(Double(day) * 86_400), mac: pro) }
    try Backup.write(vault: f.vault, now: start.addingTimeInterval(34 * 86_400 + 3_600), mac: pro)   // same day again: replaces
    for day in 0..<3 { try Backup.write(vault: f.vault, now: start.addingTimeInterval(Double(day) * 86_400), mac: macbookPro) }
    try Backup.write(vault: f.vault, now: start.addingTimeInterval(34 * 86_400), mac: twin)
    let files = Backup.files(in: backups(f))
    #expect(files.filter { $0.macID == pro.id }.count == 30)
    #expect(files.filter { $0.macID == macbookPro.id }.count == 3)
    #expect(files.filter { $0.macID == twin.id }.count == 1)
    #expect(files.filter { $0.mac == "pro" }.count == 31)
    // An iCloud placeholder counts like the file it stands for.
    let placeholder = backups(f).appendingPathComponent(".2020-01-01-pro-000000b1-0123456789ab.secretariat-backup.icloud")
    FileManager.default.createFile(atPath: placeholder.path, contents: Data())
    #expect(Backup.files(in: backups(f)).contains { $0.day == "2020-01-01" && $0.inCloudOnly })
    #expect(Backup.parse("2026-10-30-x.secretariat-backup", inCloudOnly: false) == nil)
    #expect(Backup.parse("2026-10-30-macbook-pro-3fa9c2d1-2c44d59b3c3f.secretariat-backup", inCloudOnly: false)
            == Backup.File(name: "2026-10-30-macbook-pro-3fa9c2d1-2c44d59b3c3f.secretariat-backup", day: "2026-10-30", mac: "macbook-pro",
                           macID: "3fa9c2d1", key: "2c44d59b3c3f", inCloudOnly: false))
}

@Test func automaticBacksUpOnChangeAndOncePerDay() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    #expect(Backup.automatic(vault: f.vault) == nil)   // not set up
    #expect(Backup.status(vault: f.vault).problem == nil)
    _ = try Backup.setUp(vault: f.vault)
    let now = Date()
    #expect(Backup.status(vault: f.vault).problem != nil)   // set up, nothing written yet
    #expect(Backup.automatic(vault: f.vault, now: now, mac: alpha) != nil)
    #expect(Backup.status(vault: f.vault, now: now).problem == nil)
    #expect(Backup.status(vault: f.vault, now: now.addingTimeInterval(3 * 86_400)).problem?.contains("two days") == true)
    #expect(Backup.automatic(vault: f.vault, now: now, mac: alpha) == nil)   // nothing changed today
    try f.cli("item", "set", "moinsen/test/api", "--set", "key_id=KEY-456")
    #expect(Backup.automatic(vault: f.vault, now: now, onlyDaily: true, mac: alpha) == nil)   // the CLI waits for the next day
    #expect(Backup.automatic(vault: f.vault, now: now, mac: alpha) != nil)   // the app backs up the change
    // Only a value changes (metadata, date and all else stay): still a change.
    f.items.values[f.item.id]?["secret"] = "changed-the-same-day"
    #expect(Backup.automatic(vault: f.vault, now: now, mac: alpha) != nil)
    #expect(Backup.automatic(vault: f.vault, now: now, mac: alpha) == nil)
    #expect(Backup.automatic(vault: f.vault, now: now.addingTimeInterval(86_400), onlyDaily: true, mac: alpha) != nil)
    #expect(f.vault.audit.tail(20).contains { $0.contains(#""action":"backup""#) && !$0.contains("never-output") })
}

@Test func restoreBringsBackWhatIsMissingAndChangesNothingElse() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let recovery = try Backup.setUp(vault: f.vault)
    var other = ItemMeta(path: "moinsen/other/api", kind: "api", fields: [ItemField(name: "secret", kind: .secret)])
    try f.vault.save(other, secrets: ["secret": "other-old"])
    try f.vault.screenshotKeys.add(id: "k1", key: Data(repeating: 1, count: 32))
    var dated = try f.vault.item(id: f.item.id); dated.rotated = "2026-01-15"; try f.items.save(dated, secrets: nil)
    let url = try Backup.write(vault: f.vault, mac: alpha)

    // Lost: the test item, its profile and the screenshot key. Changed since: the other item. New since: a third one.
    let before = try f.vault.item(id: f.item.id)
    try f.vault.deleteProfile(id: f.profile.id)
    try f.vault.delete(id: f.item.id)
    try f.vault.screenshotKeys.removeAll()
    other = try f.vault.item(path: "moinsen/other/api"); try f.vault.save(other, secrets: ["secret": "other-new"])
    try f.vault.save(ItemMeta(path: "moinsen/new/api", kind: "api", fields: [ItemField(name: "secret", kind: .secret)]), secrets: ["secret": "new"])

    let (_, payload) = try Backup.open(url, recoveryKey: recovery)
    #expect(Backup.additions(payload, to: f.vault) == ["moinsen/test/api", "project agent-test", "screenshot keys"])
    let restored = try Backup.restore(payload, into: f.vault)
    #expect(restored.items == 1 && restored.profiles == 1 && restored.screenshotKeys == 1 && restored.skipped.isEmpty && restored.failed.isEmpty)
    #expect(try f.vault.item(id: f.item.id).rotated == "2026-01-15" && before.rotated == "2026-01-15")
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

@Test func aLockedKeychainStopsTheBackupInsteadOfWritingAThinOne() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    _ = try Backup.setUp(vault: f.vault)
    let url = try Backup.write(vault: f.vault, mac: alpha)
    let good = try Data(contentsOf: url)
    f.items.denied = true
    #expect(throws: CredentialError.self) { try Backup.write(vault: f.vault, mac: alpha) }
    #expect(Backup.automatic(vault: f.vault, mac: alpha) == nil)
    #expect(try Data(contentsOf: url) == good)
    #expect(Backup.status(vault: f.vault).problem?.contains("failed") == true)
    f.items.denied = false
    try Backup.write(vault: f.vault, mac: alpha)
    #expect(Backup.status(vault: f.vault).problem == nil)
}

@Test func restoreSkipsLookAlikePathsAndKeepsGoingAfterAFailure() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let recovery = try Backup.setUp(vault: f.vault)
    let lost = ItemMeta(path: "moinsen/lost/api", kind: "api", fields: [ItemField(name: "secret", kind: .secret)])
    try f.vault.save(lost, secrets: ["secret": "lost-value"])
    let (_, payload) = try Backup.open(try Backup.write(vault: f.vault, mac: alpha), recoveryKey: recovery)
    // Gone here, and another entry took the same path in other letter case; the profile was lost too.
    try f.vault.deleteProfile(id: f.profile.id); try f.vault.delete(id: f.item.id); try f.vault.delete(id: lost.id)
    try f.vault.save(ItemMeta(path: "Moinsen/Test/API", kind: "api", fields: [ItemField(name: "secret", kind: .secret)]), secrets: ["secret": "mine"])
    let restored = try Backup.restore(payload, into: f.vault)
    #expect(restored.skipped == ["moinsen/test/api"])
    #expect(restored.items == 1 && restored.profiles == 1 && restored.failed.isEmpty)
    #expect(try f.vault.value(itemID: lost.id, field: "secret") == "lost-value")
    #expect(try f.vault.value(itemID: try f.vault.item(path: "Moinsen/Test/API").id, field: "secret") == "mine")
}

@Test func aTypedKeyIsCheckedWithoutOpeningABackup() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    #expect(throws: AgentError.self) { try Backup.matches(RecoveryKey.generate(), vault: f.vault) }
    let recovery = try Backup.setUp(vault: f.vault)
    #expect(try Backup.matches(recovery.lowercased(), vault: f.vault))
    #expect(try !Backup.matches(RecoveryKey.generate(), vault: f.vault))
    // A new key: backups sealed to the old one can be removed.
    try Backup.write(vault: f.vault, now: Date().addingTimeInterval(-86_400), mac: alpha)
    _ = try Backup.setUp(vault: f.vault)
    try Backup.write(vault: f.vault, mac: alpha)
    #expect(Backup.files(in: backups(f)).count == 2)
    #expect(Backup.removeBackups(notSealedTo: Backup.status(vault: f.vault).key!, vault: f.vault) == 1)
    #expect(Backup.files(in: backups(f)).count == 1)
}

@Test func aNewKeyTheSameDayReplacesTodaysFileAndParallelWritesLeaveOne() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    _ = try Backup.setUp(vault: f.vault)
    try Backup.write(vault: f.vault, mac: alpha)
    let recovery = try Backup.setUp(vault: f.vault)
    try Backup.write(vault: f.vault, mac: alpha)
    var files = Backup.files(in: backups(f))
    #expect(files.count == 1 && files.first?.key == Backup.status(vault: f.vault).key)
    DispatchQueue.concurrentPerform(iterations: 4) { _ in _ = try? Backup.write(vault: f.vault, mac: alpha) }
    files = Backup.files(in: backups(f))
    #expect(files.count == 1)
    #expect((try? Backup.open(backups(f).appendingPathComponent(files[0].name), recoveryKey: recovery)) != nil)
    #expect(!FileManager.default.fileExists(atPath: f.vault.configuration.paths.directory.appendingPathComponent("backups/.backup").path))
}
