import CryptoKit
import Foundation
import Testing
@testable import SecretariatCore

/// Two people, each with a vault; A's extra item `acme/stripe/test` exists only on A's side.
private struct Pair {
    let a: AgentFixture, b: AgentFixture
    let stripe: ItemMeta
    init() throws {
        a = try AgentFixture(); b = try AgentFixture()
        stripe = ItemMeta(path: "acme/stripe/test", kind: "api", fields: [ItemField(name: "api_key", kind: .secret)], approval: true)
        try a.vault.save(stripe, secrets: ["api_key": "sk_test_shared-value-Ü€"])
        try Team.setOwnName("Anna", vault: a.vault); try Team.setOwnName("Ben", vault: b.vault)
    }
    func cleanup() { a.cleanup(); b.cleanup() }
    func stored(_ vault: Vault, _ paths: [String]) throws -> [Backup.StoredItem] {
        try vault.list().filter { paths.contains($0.path) }.map { Backup.StoredItem(meta: $0, secrets: try vault.items.secrets(id: $0.id)) }
    }
    /// Both add each other by code.
    func introduce() throws -> (ben: Team.Member, anna: Team.Member) {
        let ben = try Team.addMember(code: try Team.ownCode(vault: b.vault), vault: a.vault)
        let anna = try Team.addMember(code: try Team.ownCode(vault: a.vault), vault: b.vault)
        return (ben, anna)
    }
}

@Test func shareCodeRoundTripsAndCatchesTypos() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    try Team.setOwnName("Ülrich D.", vault: f.vault)
    let code = try Team.ownCode(vault: f.vault)
    #expect(code.hasPrefix("stc1:"))
    let parsed = try Team.parse(code: "  " + code.prefix(20) + "\n" + code.dropFirst(20) + " ")
    #expect(parsed.name == "Ülrich D.")
    #expect(parsed.key == (try Team.privateKey(vault: f.vault)).publicKey.rawRepresentation)
    // The same key every time: the private key is kept, not regenerated.
    #expect(try Team.ownCode(vault: f.vault) == code)
    var typo = Array(code); let i = code.count / 2; typo[i] = typo[i] == "A" ? "B" : "A"
    #expect(throws: AgentError.self) { try Team.parse(code: String(typo)) }
    #expect(throws: AgentError.self) { try Team.parse(code: String(code.dropLast(2))) }
    #expect(throws: AgentError.self) { try Team.parse(code: "stc1:hello") }
    #expect(throws: (any Error).self) { try Team.addMember(code: code, vault: f.vault) }   // own code
}

@Test func packageRoundTripKeepsValuesAndHidesEverythingElse() throws {
    let p = try Pair(); defer { p.cleanup() }
    let (ben, _) = try p.introduce()
    let items = try p.stored(p.a.vault, ["acme/stripe/test", "moinsen/test/api"])
    let data = try Team.package(items: items, to: [ben], vault: p.a.vault)
    #expect(Team.sharedWith(ben, vault: p.a.vault).isEmpty)   // nothing recorded until the file is written
    try Team.recordShared(items, to: [ben], vault: p.a.vault)
    let raw = String(decoding: data, as: UTF8.self)
    for plain in ["sk_test_shared-value", "never-output-this-value", "acme/stripe", "moinsen/test", "api_key", "KEY-123"] {
        #expect(!raw.contains(plain), "\(plain) in the package")
    }
    let opened = try Team.open(data, vault: p.b.vault)
    #expect(opened.sender?.name == "Anna")
    #expect(opened.items.count == 2)
    let result = try Team.importItems(opened, vault: p.b.vault)
    #expect(result.added == ["acme/stripe/test"])
    #expect(result.skipped == ["moinsen/test/api"])   // B already has that path: untouched
    let imported = try #require(try p.b.vault.list().first { $0.path == "acme/stripe/test" })
    #expect(try p.b.vault.items.secrets(id: imported.id)["api_key"] == "sk_test_shared-value-Ü€")
    #expect(imported.source.hasPrefix("Shared by Anna on "))
    #expect(imported.needsApproval)
    #expect(try p.b.vault.items.secrets(id: try p.b.vault.list().first { $0.path == "moinsen/test/api" }!.id)["secret"] == "never-output-this-value")
    // Records on A's side for offboarding; history without values.
    #expect(Team.sharedWith(ben, vault: p.a.vault).map(\.path) == ["acme/stripe/test", "moinsen/test/api"])
    let log = try String(contentsOf: p.a.vault.audit.url!, encoding: .utf8) + (try String(contentsOf: p.b.vault.audit.url!, encoding: .utf8))
    #expect(log.contains("team.share") && log.contains("team.import"))
    #expect(!log.contains("sk_test_shared-value"))
}

@Test func onlyNamedRecipientsOpenAndTamperingIsRefused() throws {
    let p = try Pair(); defer { p.cleanup() }
    let (ben, _) = try p.introduce()
    let carl = try AgentFixture(); defer { carl.cleanup() }
    let data = try Team.package(items: try p.stored(p.a.vault, ["acme/stripe/test"]), to: [ben], vault: p.a.vault)
    #expect(throws: AgentError.self) { try Team.open(data, vault: carl.vault) }

    var lines = data.split(separator: 0x0A).map { Data($0) }
    // A changed header (e.g. the claimed sender name or item count): refused.
    var header = try JSONDecoder.iso.decode(Team.Header.self, from: lines[0]); header.sender = "Mallory"
    var forged = lines; forged[0] = try JSONEncoder.sorted.encode(header)
    #expect(throws: AgentError.self) { try Team.open(forged.joined(separator: Data([0x0A])), vault: p.b.vault) }
    // One flipped byte in the content: refused.
    var content = Data(base64Encoded: lines[2])!; content[content.count / 2] ^= 0x01
    lines[2] = content.base64EncodedData()
    #expect(throws: AgentError.self) { try Team.open(lines.joined(separator: Data([0x0A])), vault: p.b.vault) }
    #expect(throws: AgentError.self) { try Team.open(Data("garbage".utf8), vault: p.b.vault) }
    #expect(throws: AgentError.self) { try Team.open(Data(count: 6 * 1024 * 1024), vault: p.b.vault) }
    #expect(try p.b.vault.list().count == 1)
}

/// B also received A's package to B and C; B must not be able to give C different content "from A".
@Test func coRecipientCannotSwapTheContent() throws {
    let p = try Pair(); defer { p.cleanup() }
    let (ben, _) = try p.introduce()
    let carl = try AgentFixture(); defer { carl.cleanup() }
    let carlMember = try Team.addMember(code: try Team.ownCode(vault: carl.vault), name: "Carl", vault: p.a.vault)
    _ = try Team.addMember(code: try Team.ownCode(vault: p.a.vault), vault: carl.vault)
    let data = try Team.package(items: try p.stored(p.a.vault, ["acme/stripe/test"]), to: [ben, carlMember], vault: p.a.vault)
    let lines = data.split(separator: 0x0A).map { Data($0) }
    // Ben learns the content key and seals other content with it under the same header.
    let opened = try Team.open(data, vault: p.b.vault)
    #expect(opened.items.count == 1)
    let benKey = try Team.privateKey(vault: p.b.vault)
    struct Wrap: Codable { var recipient: String; var encapsulatedKey: Data; var sealed: Data }
    let wraps = try JSONDecoder.iso.decode([Wrap].self, from: lines[1])
    let benWrap = try #require(wraps.first { $0.recipient == Team.keyID(benKey.publicKey.rawRepresentation) })
    var recipient = try HPKE.Recipient(privateKey: benKey, ciphersuite: Team.suite, info: Team.info, encapsulatedKey: benWrap.encapsulatedKey,
                                       authenticatedBy: try Curve25519.KeyAgreement.PublicKey(rawRepresentation: opened.header.senderKey))
    let contentKey = SymmetricKey(data: try recipient.open(benWrap.sealed, authenticating: Team.wrapContext(lines[0], Data(base64Encoded: lines[2])!)))
    var evil = opened.items; evil[0].secrets["api_key"] = "attacker-chosen"
    struct Payload: Codable { var items: [Backup.StoredItem] }
    let swapped = try ChaChaPoly.seal(try JSONEncoder.sorted.encode(Payload(items: evil)), using: contentKey, authenticating: lines[0]).combined
    let forged = [lines[0], lines[1], swapped.base64EncodedData()].joined(separator: Data([0x0A]))
    #expect(throws: AgentError.self) { try Team.open(forged, vault: carl.vault) }
    #expect(try Team.open(data, vault: carl.vault).items.first?.secrets["api_key"] == "sk_test_shared-value-Ü€")
}

@Test func unknownSenderIsReportedNotTrusted() throws {
    let p = try Pair(); defer { p.cleanup() }
    let ben = try Team.addMember(code: try Team.ownCode(vault: p.b.vault), vault: p.a.vault)   // B doesn't know A
    let data = try Team.package(items: try p.stored(p.a.vault, ["acme/stripe/test"]), to: [ben], vault: p.a.vault)
    let opened = try Team.open(data, vault: p.b.vault)
    #expect(opened.sender == nil)
    #expect(opened.header.sender == "Anna")
    let result = try Team.importItems(opened, vault: p.b.vault)
    let item = try #require(try p.b.vault.list().first { $0.path == "acme/stripe/test" })
    #expect(result.added.count == 1 && item.source.contains("unknown"))
}

@Test func membersLiveInTheKeychainStoreNotInTheConfiguration() throws {
    let p = try Pair(); defer { p.cleanup() }
    let (ben, _) = try p.introduce()
    let config = try String(contentsOf: p.a.vault.configuration.paths.configuration, encoding: .utf8)
    #expect(!config.contains("Ben") && !config.contains(ben.keyID))
    #expect(throws: (any Error).self) { try Team.addMember(code: try Team.ownCode(vault: p.b.vault), name: "Ben again", vault: p.a.vault) }
    // CLI: read only.
    let (code, list) = try p.a.cli("team", "list")
    #expect(code == 0 && list.contains("\"Ben\"") && list.contains(Team.fingerprint(ben.key)))
    #expect(try p.a.cli("team", "code").1.contains(try Team.ownCode(vault: p.a.vault)))
    for forbidden in [["team", "add", "x"], ["team", "share"], ["team", "open", "file"], ["share"]] {
        #expect(p.a.code(forbidden[0], forbidden.count > 1 ? forbidden[1] : "", forbidden.count > 2 ? forbidden[2] : "") != nil)
    }
}

@Test func offboardingMarksSharedItemsUntilTheValueChanges() throws {
    let p = try Pair(); defer { p.cleanup() }
    let (ben, _) = try p.introduce()
    let items = try p.stored(p.a.vault, ["acme/stripe/test"])
    _ = try Team.package(items: items, to: [ben], vault: p.a.vault)
    try Team.recordShared(items, to: [ben], vault: p.a.vault)
    let affected = try Team.removeMember(ben, vault: p.a.vault)
    #expect(affected.map(\.path) == ["acme/stripe/test"])
    #expect(Team.members(vault: p.a.vault).isEmpty)
    try Team.markForRotation(affected.map(\.item), reason: "Ben left the team", vault: p.a.vault)
    var item = try #require(try p.a.vault.list().first { $0.path == "acme/stripe/test" })
    #expect(item.rotateReason == "Ben left the team")
    #expect(try p.a.cli("status").1.contains("Ben left the team"))
    #expect(try p.a.cli("items").1.contains("Ben left the team"))
    // Saving the description keeps the mark; a new value clears it.
    try p.a.vault.save(item)
    #expect(try p.a.vault.list().first { $0.path == "acme/stripe/test" }?.rotateReason == "Ben left the team")
    let entry = try #require(Team.shares(of: item.id, vault: p.a.vault).first)
    #expect(!Team.changedSince(entry, vault: p.a.vault))
    try p.a.vault.save(item, secrets: ["api_key": "sk_test_rotated"])
    #expect(Team.changedSince(entry, vault: p.a.vault))
    item = try #require(try p.a.vault.list().first { $0.path == "acme/stripe/test" })
    #expect(item.rotateReason == nil)
}

@Test func resetKeyMakesOldPackagesUnreadable() throws {
    let p = try Pair(); defer { p.cleanup() }
    let (ben, _) = try p.introduce()
    let data = try Team.package(items: try p.stored(p.a.vault, ["acme/stripe/test"]), to: [ben], vault: p.a.vault)
    let old = try Team.ownCode(vault: p.b.vault)
    try Team.resetKey(vault: p.b.vault)
    #expect(try Team.ownCode(vault: p.b.vault) != old)
    #expect(throws: AgentError.self) { try Team.open(data, vault: p.b.vault) }
}

@Test func managedMembersComeOnlyFromForcedSettingsOrATestFixture() throws {
    let p = try Pair(); defer { p.cleanup() }
    let benCode = try Team.ownCode(vault: p.b.vault)
    let managed = ManagedSettings(values: ["TeamMembers": [benCode, "stc1:broken", benCode]])
    let members = Team.members(vault: p.a.vault, managed: managed)
    #expect(members.count == 1 && members[0].managed && members[0].name == "Ben")
    #expect(throws: (any Error).self) { try Team.removeMember(members[0], vault: p.a.vault) }

    // Fixture: only for a test home, never for the real one.
    let plist = p.a.root.appendingPathComponent("managed.plist")
    try PropertyListSerialization.data(fromPropertyList: ["TeamMembers": [benCode]], format: .xml, options: 0).write(to: plist)
    let env = ["SECRETARIAT_MANAGED_FIXTURE": plist.path]
    #expect(ManagedSettings(paths: p.a.vault.configuration.paths, environment: env).teamMembers().count == 1)
    #expect(ManagedSettings(paths: AppPaths(directory: AppPaths.defaultDirectory), environment: env).values == nil)
    // Unforced values (defaults write by the user or an agent) aren't read for the real domain.
    // A value written like `defaults write` (not enforced by a profile) is ignored. Throwaway domain, removed afterwards.
    let domain = "dev.moinsen.secretariat.test.\(UUID().uuidString)" as CFString
    CFPreferencesSetAppValue("TeamMembers" as CFString, [benCode] as CFArray, domain)
    CFPreferencesAppSynchronize(domain)
    defer { CFPreferencesSetAppValue("TeamMembers" as CFString, nil, domain); CFPreferencesAppSynchronize(domain) }
    #expect((CFPreferencesCopyAppValue("TeamMembers" as CFString, domain) as? [String]) == [benCode])   // the value is there …
    let unforced = ManagedSettings(paths: AppPaths(directory: AppPaths.defaultDirectory), environment: [:], domain: domain as String)
    #expect(unforced.teamMembers().isEmpty)                                                            // … but not enforced, so ignored
}

private extension JSONDecoder {
    static var iso: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }
}
private extension JSONEncoder {
    static var sorted: JSONEncoder { let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]; e.dateEncodingStrategy = .iso8601; return e }
}
private extension Array where Element == Data {
    func joined(separator: Data) -> Data {
        var out = Data()
        for (i, part) in enumerated() { if i > 0 { out.append(separator) }; out.append(part) }
        out.append(separator)
        return out
    }
}
