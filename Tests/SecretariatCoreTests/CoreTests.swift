import Foundation
import Testing
@testable import SecretariatCore

@Test func itemValidationGuardsPathsFieldsAndWhereValuesLive() throws {
    #expect(throws: SecretariatError.self) { try ItemMeta(path: "/bad", kind: .api).validate() }
    #expect(throws: SecretariatError.self) { try ItemMeta(path: "a b", kind: .api).validate() }
    #expect(throws: SecretariatError.self) { try ItemMeta(path: "x", kind: .api, fields: [ItemField(name: "Bad", kind: .secret)]).validate() }
    #expect(throws: SecretariatError.self) { try ItemMeta(path: "x", kind: .api, fields: [ItemField(name: "id", kind: .identifier)]).validate() }
    #expect(throws: SecretariatError.self) { try ItemMeta(path: "x", kind: .api, fields: [ItemField(name: "s", kind: .secret, value: "leak")]).validate() }
    #expect(throws: SecretariatError.self) { try ItemMeta(path: "x", kind: .api, fields: [ItemField(name: "a", kind: .secret), ItemField(name: "a", kind: .file)]).validate() }
    try ItemMeta(path: "moinsen/apple-developer@prod", kind: .account, fields: [ItemField(name: "team_id", kind: .identifier, value: "VXX")], expires: "2027-01-31").validate()
    #expect(try FieldReference("moinsen/cloudflare/access/client_secret") == FieldReference(path: "moinsen/cloudflare/access", field: "client_secret"))
    #expect(throws: AgentError.self) { try FieldReference("nofield") }
}

@Test func valuesStayOutOfMetadataAndPersonalFieldsNeverReachPrograms() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let meta = try JSONEncoder().encode(try f.vault.list())
    #expect(!String(decoding: meta, as: UTF8.self).contains("never-output"))
    #expect(try f.vault.value(itemID: f.item.id, field: "key_id") == "KEY-123")
    #expect(try f.vault.value(itemID: f.item.id, field: "secret") == "never-output-this-value")
    #expect(throws: AgentError.self) { try f.vault.value(itemID: f.item.id, field: "password") }
    #expect(try f.vault.personalValue(itemID: f.item.id, field: "password") == "personal-never-out")
    let config = try String(contentsOf: f.vault.configuration.paths.configuration, encoding: .utf8)
    #expect(!config.contains("never-output")); #expect(!config.contains("personal-never"))
    #expect((try FileManager.default.attributesOfItem(atPath: f.vault.configuration.paths.configuration.path)[.posixPermissions] as? NSNumber)?.intValue == 0o600)
}

@Test func pathsAreUniqueAndRotationIsStampedOnValueChange() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    #expect(throws: AgentError.self) { try f.vault.save(ItemMeta(path: "MOINSEN/test/api", kind: .api)) }
    var item = try f.vault.item(path: "moinsen/test/api")
    item.rotated = "2020-01-01"; try f.vault.save(item)                       // metadata only: no stamp
    #expect(try f.vault.item(path: "moinsen/test/api").rotated == "2020-01-01")
    try f.vault.save(item, secrets: ["secret": "new", "password": "personal-never-out"])
    #expect(try f.vault.item(path: "moinsen/test/api").rotated == today())
    // two Macs created the same path at once: lookups refuse to guess
    f.items.metas[UUID()] = ItemMeta(path: "moinsen/test/api", kind: .api)
    #expect(throws: AgentError.self) { try f.vault.item(path: "moinsen/test/api") }
}

@Test func setValueCreatesItemsAndFieldsButNeverOverwritesSilently() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let ref = FieldReference(path: "moinsen/new/token", field: "client_secret")
    try f.vault.setValue(ref, value: "v1", itemKind: .token)
    #expect(try f.vault.item(path: "moinsen/new/token").kind == .token)
    #expect(throws: AgentError.self) { try f.vault.setValue(ref, value: "v2") }
    try f.vault.setValue(ref, value: "v2", replace: true)
    let item = try f.vault.item(path: "moinsen/new/token")
    #expect(try f.vault.value(itemID: item.id, field: "client_secret") == "v2")
    #expect(throws: SecretariatError.self) { try f.vault.setValue(ref, value: "", replace: true) }
}

@Test func movingAFieldKeepsItsValueAndRebindsProfilesAndTargets() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    try f.vault.saveTarget(Target(name: "worker", kind: .command, command: "cat > /dev/null # {var}",
                                  bindings: [Binding(variable: "TEST_API_KEY", itemID: f.item.id, field: "secret")]))
    try f.vault.moveField(from: FieldReference(path: "moinsen/test/api", field: "secret"), to: FieldReference(path: "moinsen/routing", field: "client_secret"))
    let destination = try f.vault.item(path: "moinsen/routing")
    #expect(try f.vault.value(itemID: destination.id, field: "client_secret") == "never-output-this-value")
    #expect(try f.vault.item(path: "moinsen/test/api").field("secret") == nil)
    let config = try f.vault.configuration.load()
    #expect(config.profiles[0].bindings[0].itemID == destination.id)
    #expect(config.targets[0].bindings[0].field == "client_secret")
    // identifiers move too; the emptied source item disappears
    try f.vault.moveField(from: FieldReference(path: "moinsen/test/api", field: "key_id"), to: FieldReference(path: "moinsen/routing", field: "key_id"))
    try f.vault.moveField(from: FieldReference(path: "moinsen/test/api", field: "password"), to: FieldReference(path: "moinsen/routing", field: "password"))
    #expect(throws: AgentError.self) { try f.vault.item(path: "moinsen/test/api") }
    #expect(try f.vault.get("moinsen/routing/key_id") == "KEY-123")
}

@Test func usedItemsCannotBeDeleted() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    #expect(throws: SecretariatError.self) { try f.vault.delete(id: f.item.id) }
    try f.vault.deleteProfile(id: f.profile.id)
    try f.vault.delete(id: f.item.id)
    #expect(try f.vault.list().isEmpty)
}

@Test func launchPutsSecretsInTheEnvironmentAndFilesIntoTemporaryPaths() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    try f.vault.setValue(FieldReference(path: "moinsen/asc", field: "private_key"), value: Data("-----BEGIN KEY-----".utf8).base64EncodedString(),
                         kind: .file, fileName: "AuthKey_X.p8", itemKind: .certificate)
    let asc = try f.vault.item(path: "moinsen/asc")
    var profile = f.profile
    profile.bindings.append(Binding(variable: "ASC_KEY_PATH", itemID: asc.id, field: "private_key"))
    profile.bindings.append(Binding(variable: "KEY_ID", itemID: f.item.id, field: "key_id"))
    try f.vault.saveProfile(profile)
    let launch = try f.vault.preparedLaunch(name: "agent-test", arguments: ["true"], inheritedEnvironment: ["PATH": "/usr/bin"])
    #expect(launch.environment["TEST_API_KEY"] == "never-output-this-value")
    #expect(launch.environment["KEY_ID"] == "KEY-123")
    #expect(launch.environment["ASC_KEY_PATH"] == nil)
    #expect(launch.files.first?.name == "AuthKey_X.p8"); #expect(launch.files.first?.variable == "ASC_KEY_PATH")
    f.items.denied = true
    #expect(throws: CredentialError.self) { try f.vault.preparedLaunch(name: "agent-test", arguments: ["true"], inheritedEnvironment: [:]) }
    f.items.denied = false
    #expect(throws: SecretariatError.self) { try f.vault.preparedLaunch(name: "other", arguments: ["true"], inheritedEnvironment: [:]) }
    #expect(f.vault.audit.tail(5).contains { $0.contains("\"run\"") && !$0.contains("never-output") })
}

@Test func oldOrBrokenConfigurationIsPreserved() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let url = f.vault.configuration.paths.configuration
    let old = Data(#"{"version":1,"revision":3,"secrets":[],"profiles":[]}"#.utf8)
    try old.write(to: url)
    #expect(throws: SecretariatError.self) { try f.vault.configuration.load() }
    #expect(throws: SecretariatError.self) { try f.vault.saveProfile(f.profile) }
    #expect(try Data(contentsOf: url) == old)
    let broken = Data("{not json".utf8); try broken.write(to: url)
    #expect(throws: SecretariatError.self) { try f.vault.configuration.load() }
    #expect(try Data(contentsOf: url) == broken)
}

@Test func staleEditsAreRejected() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let revision = try f.vault.configuration.load().revision
    let stale = Vault(configuration: f.vault.configuration, items: f.items, expectedRevision: revision)
    try f.vault.saveProfile(Profile(name: "other", directory: f.root.path))
    #expect(throws: SecretariatError.self) { try stale.saveProfile(Profile(name: "third", directory: f.root.path)) }
}

@Test func registryExportListsIdentifiersAndNamesSecretsWithoutValues() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    var item = try f.vault.item(path: "moinsen/test/api"); item.source = "Konsole \"Integrations\""; item.expires = "2027-02-01"
    let text = RegistryExport.render([item])
    #expect(text.contains(#"["moinsen/test/api"]"#))
    #expect(text.contains(#"key_id = "KEY-123""#))
    #expect(text.contains(#"secret = "secret:moinsen/test/api/secret""#))
    #expect(text.contains(#"_source = "Konsole \"Integrations\"""#)); #expect(text.contains(#"_expires = "2027-02-01""#))
    #expect(!text.contains("never-output")); #expect(!text.contains("personal-never"))
    // only the real home exports
    #expect(f.vault.registryDirectory == nil)
}

@Test func testHomesNeverShareTheRealItemNamespace() {
    let test = AppPaths(directory: FileManager.default.temporaryDirectory.appendingPathComponent("x"))
    #expect(test.itemService.hasPrefix("dev.moinsen.secretariat.items.test."))
    #expect(AppPaths(directory: AppPaths.defaultDirectory).itemService == "dev.moinsen.secretariat.items.v1")
}

@Test func shellQuotingContainsNoCredentialValues() {
    let profile = Profile(name: "project", directory: "/tmp/space here", command: "printf '%s' 'hello world'")
    let command = launchCommand(profile: profile, executable: "/tmp/app's directory/Secretariat")
    #expect(command.contains("'\\''")); #expect(command.contains(" run 'project' -- /bin/zsh -c "))
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["SECRETARIAT_RUN_KEYCHAIN_TESTS"] == "1", "Opt-in: braucht das signierte Paket mit Entitlement"))
func realKeychainRoundTripInATestNamespace() throws {
    let store = SyncedItemStore(service: "dev.moinsen.secretariat.items.test.\(UUID().uuidString)")
    let meta = ItemMeta(path: "test/roundtrip", kind: .api, fields: [ItemField(name: "id", kind: .identifier, value: "x"), ItemField(name: "s", kind: .secret)])
    defer { try? store.delete(id: meta.id) }
    try store.save(meta, secrets: ["s": "artificial"])
    #expect(try store.list().map(\.path) == ["test/roundtrip"])
    #expect(try store.secrets(id: meta.id) == ["s": "artificial"])
}

extension Vault {
    func get(_ reference: String) throws -> String? { try resolve(try FieldReference(reference)).1.value }
}

@Test func anywhereProfilesRunInTheCallersFolder() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    try f.vault.saveProfile(Profile(name: "werkzeuge", directory: Profile.anywhere, bindings: [Binding(variable: "TOKEN", itemID: f.item.id, field: "secret")]))
    let launch = try f.vault.preparedLaunch(name: "werkzeuge", arguments: ["true"], inheritedEnvironment: [:])
    #expect(launch.directory == FileManager.default.currentDirectoryPath)
    #expect(try f.service.check("werkzeuge").ok)
    #expect(throws: AgentError.self) { try ProjectInstructions.preview(profile: try f.service.profile(named: "werkzeuge"), executable: "/tmp/s") }
}
