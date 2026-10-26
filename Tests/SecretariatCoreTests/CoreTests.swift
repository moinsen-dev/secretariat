import Foundation
import Testing
@testable import SecretariatCore

private final class MemoryCredentials: CredentialStore {
    var values: [UUID: String] = [:]
    var denied = false
    var afterMutation: (() throws -> Void)?
    func set(_ value: String, id: UUID, label: String) throws { values[id] = value; try afterMutation?() }
    func read(id: UUID) throws -> String {
        if denied { throw SecretariatError("Zugriff verweigert") }
        guard let value = values[id] else { throw CredentialError.notFound }
        return value
    }
    func delete(id: UUID) throws { values.removeValue(forKey: id); try afterMutation?() }
}

private func fixture() throws -> (Vault, MemoryCredentials, URL) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("Secretariat-unit-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let credentials = MemoryCredentials()
    return (Vault(configuration: ConfigurationStore(paths: AppPaths(directory: root)), credentials: credentials), credentials, root)
}

@Test func sharedSecretChangesReachBothProfilesWithoutWritingValuesToJSON() throws {
    let (vault, credentials, root) = try fixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let id = try vault.addSecret(name: "API Entwicklung", value: "unit-private-value-one")
    for name in ["project-a", "project-b"] {
        try vault.saveProfile(Profile(name: name, directory: root.path, bindings: [Binding(variable: "API_KEY", secretID: id)]))
    }
    try vault.updateSecret(id: id, name: "API Entwicklung", newValue: "unit-private-value-two")
    for name in ["project-a", "project-b"] {
        let plan = try vault.preparedLaunch(name: name, arguments: ["/usr/bin/true"], inheritedEnvironment: ["PATH": "/usr/bin"])
        #expect(plan.environment["API_KEY"] == "unit-private-value-two")
    }
    #expect(credentials.values.count == 1)
    let json = try String(contentsOf: vault.configuration.paths.configuration, encoding: .utf8)
    #expect(!json.contains("unit-private-value"))
    #expect(vault.configuration.paths.keychainService != "dev.moinsen.secretariat.daemon")
}

@Test func sameVariableCanUseDifferentSecretsInSeparateProfiles() throws {
    let (vault, _, root) = try fixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let a = try vault.addSecret(name: "A", value: "one")
    let b = try vault.addSecret(name: "B", value: "two")
    try vault.saveProfile(Profile(name: "a", directory: root.path, bindings: [Binding(variable: "KEY", secretID: a)]))
    try vault.saveProfile(Profile(name: "b", directory: root.path, bindings: [Binding(variable: "KEY", secretID: b)]))
    #expect(try vault.preparedLaunch(name: "a", arguments: ["true"], inheritedEnvironment: [:]).environment["KEY"] == "one")
    #expect(try vault.preparedLaunch(name: "b", arguments: ["true"], inheritedEnvironment: [:]).environment["KEY"] == "two")
}

@Test func referencedSecretsCannotBeDeleted() throws {
    let (vault, credentials, root) = try fixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let id = try vault.addSecret(name: "Used", value: "test")
    let profile = Profile(name: "test", directory: root.path, bindings: [Binding(variable: "API_KEY", secretID: id)])
    try vault.saveProfile(profile)
    #expect(throws: SecretariatError.self) { try vault.deleteSecret(id: id) }
    #expect(credentials.values[id] == "test")
    try vault.deleteProfile(id: profile.id)
    try vault.deleteSecret(id: id)
    #expect(credentials.values.isEmpty)
}

@Test func badOrDuplicateBindingsCannotReplaceValidConfiguration() throws {
    let (vault, _, root) = try fixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let id = try vault.addSecret(name: "API", value: "test")
    let before = try Data(contentsOf: vault.configuration.paths.configuration)
    let duplicates = [Binding(variable: "API_KEY", secretID: id), Binding(variable: "API_KEY", secretID: id)]
    #expect(throws: SecretariatError.self) { try vault.saveProfile(Profile(name: "test", directory: root.path, bindings: duplicates)) }
    #expect(throws: SecretariatError.self) { try vault.saveProfile(Profile(name: "test", directory: root.path, bindings: [Binding(variable: "1 BAD", secretID: id)])) }
    #expect(try Data(contentsOf: vault.configuration.paths.configuration) == before)
}

@Test func corruptOrUnknownConfigurationIsPreserved() throws {
    let (vault, _, root) = try fixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let broken = Data("{not valid JSON".utf8)
    try broken.write(to: vault.configuration.paths.configuration)
    #expect(throws: SecretariatError.self) { try vault.addSecret(name: "new", value: "new") }
    #expect(try Data(contentsOf: vault.configuration.paths.configuration) == broken)
    var future = Configuration(); future.version = 99
    let data = try JSONEncoder().encode(future)
    try data.write(to: vault.configuration.paths.configuration)
    #expect(throws: SecretariatError.self) { try vault.configuration.load() }
    #expect(try Data(contentsOf: vault.configuration.paths.configuration) == data)
}

@Test func staleEditsAreRejectedBeforeCredentialMutation() throws {
    let (vault, credentials, root) = try fixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let id = try vault.addSecret(name: "Original", value: "first")
    let revision = try vault.configuration.load().revision
    let stale = Vault(configuration: vault.configuration, credentials: credentials, expectedRevision: revision)
    try vault.updateSecret(id: id, name: "New name", newValue: "second")
    #expect(throws: SecretariatError.self) { try stale.updateSecret(id: id, name: "Stale", newValue: "third") }
    #expect(credentials.values[id] == "second")
    #expect(try vault.configuration.load().secrets.first?.name == "New name")
}

@Test func deniedAndMissingCredentialsPreventPreparingAProgram() throws {
    let (vault, credentials, root) = try fixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let id = try vault.addSecret(name: "API", value: "test")
    try vault.saveProfile(Profile(name: "test", directory: root.path, bindings: [Binding(variable: "KEY", secretID: id)]))
    credentials.denied = true
    #expect(throws: SecretariatError.self) { try vault.preparedLaunch(name: "test", arguments: ["true"], inheritedEnvironment: [:]) }
    credentials.denied = false
    credentials.values.removeAll()
    #expect(throws: CredentialError.self) { try vault.preparedLaunch(name: "test", arguments: ["true"], inheritedEnvironment: [:]) }
    #expect(throws: SecretariatError.self) { try vault.preparedLaunch(name: "other", arguments: ["true"], inheritedEnvironment: [:]) }
}

@Test func shellQuotingContainsNoCredentialValues() throws {
    let profile = Profile(name: "project", directory: "/tmp/space here", command: "printf '%s' 'hello world'")
    let command = launchCommand(profile: profile, executable: "/tmp/app's directory/Secretariat")
    #expect(command.contains("'\\''"))
    #expect(command.contains(" run 'project' -- /bin/zsh -c "))
}

@Test func configurationNamespacesAreIndependentAndFilesPrivate() throws {
    let (vault, _, root) = try fixture()
    defer { try? FileManager.default.removeItem(at: root) }
    try vault.addSecret(name: "API", value: "test")
    let attributes = try FileManager.default.attributesOfItem(atPath: vault.configuration.paths.configuration.path)
    #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    #expect(AppPaths(directory: root).keychainService != AppPaths(directory: root.appendingPathComponent("other")).keychainService)
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["SECRETARIAT_RUN_KEYCHAIN_TESTS"] == "1", "Opt-in: echter ungesperrter Schlüsselbund; Standardtests bleiben ohne Systemdialoge")) func realKeychainRoundTripUsesUniqueDisposableService() throws {
    let store = KeychainStore(service: "dev.moinsen.secretariat.local.tests.\(UUID().uuidString)", allowInteraction: false)
    let id = UUID()
    defer { try? store.delete(id: id) }
    try store.set("artificial-value", id: id, label: "Disposable unit check")
    #expect(try store.read(id: id) == "artificial-value")
    try store.set("artificial-updated", id: id, label: "Disposable unit check")
    #expect(try store.read(id: id) == "artificial-updated")
    try store.delete(id: id)
    #expect(throws: CredentialError.self) { try store.read(id: id) }
}

@Test func missingKeychainValuesCanBeRepairedAndTheirMetadataRemoved() throws {
    let (vault, credentials, root) = try fixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let id = try vault.addSecret(name: "Repair", value: "first")
    credentials.values.removeAll()
    try vault.updateSecret(id: id, name: "Repaired", newValue: "second")
    #expect(credentials.values[id] == "second")
    credentials.values.removeAll()
    try vault.deleteSecret(id: id)
    #expect(try vault.configuration.load().secrets.isEmpty)
}

@Test func credentialChangesRollBackWhenMetadataCannotBeCommitted() throws {
    let (vault, credentials, root) = try fixture()
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path); try? FileManager.default.removeItem(at: root) }
    let id = try vault.addSecret(name: "Original", value: "original-value")
    let before = try Data(contentsOf: vault.configuration.paths.configuration)
    credentials.afterMutation = { try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: root.path) }
    #expect(throws: SecretariatError.self) { try vault.updateSecret(id: id, name: "Changed", newValue: "new-value") }
    #expect(credentials.values[id] == "original-value")
    #expect(try Data(contentsOf: vault.configuration.paths.configuration) == before)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
    #expect(throws: SecretariatError.self) { try vault.deleteSecret(id: id) }
    #expect(credentials.values[id] == "original-value")
    #expect(try Data(contentsOf: vault.configuration.paths.configuration) == before)
}

// MARK: - 0.3 synced keys

private final class FakeSynced: CredentialStore, SyncedKeyListing {
    var values: [UUID: (String, String)] = [:]
    var missingEntitlement = false
    private func gate() throws { if missingEntitlement { throw CredentialError.unavailable(errSecMissingEntitlement) } }
    func set(_ value: String, id: UUID, label: String) throws { try gate(); values[id] = (value, label) }
    func read(id: UUID) throws -> String { try gate(); guard let v = values[id] else { throw CredentialError.notFound }; return v.0 }
    func delete(id: UUID) throws { try gate(); values.removeValue(forKey: id) }
    func syncedKeys() throws -> [SyncedKeyEntry] { try gate(); return values.map { SyncedKeyEntry(id: $0.key, name: $0.value.1) } }
}
private final class FakeLocal: CredentialStore {
    var values: [UUID: String] = [:]
    func set(_ value: String, id: UUID, label: String) throws { values[id] = value }
    func read(id: UUID) throws -> String { guard let v = values[id] else { throw CredentialError.notFound }; return v }
    func delete(id: UUID) throws { values.removeValue(forKey: id) }
}
private func syncFixture() throws -> (Vault, FakeSynced, FakeLocal, URL) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("secretariat-sync-\(UUID().uuidString)")
    let synced = FakeSynced(), local = FakeLocal()
    let vault = Vault(configuration: ConfigurationStore(paths: AppPaths(directory: root)),
                      credentials: FleetCredentialStore(synced: synced, legacy: local))
    return (vault, synced, local, root)
}

@Test func newValuesGoToTheSyncedStoreWithTheirName() throws {
    let (vault, synced, local, root) = try syncFixture(); defer { try? FileManager.default.removeItem(at: root) }
    let id = try vault.addSecret(name: "Gemini", value: "artificial-1")
    #expect(synced.values[id]?.0 == "artificial-1"); #expect(synced.values[id]?.1 == "Gemini")
    #expect(local.values[id] == nil)
}

@Test func legacyValuesStayReadableAndMigrateWithoutLoss() throws {
    let (vault, synced, local, root) = try syncFixture(); defer { try? FileManager.default.removeItem(at: root) }
    synced.missingEntitlement = true                      // written by 0.2: only in the login keychain
    let id = try vault.addSecret(name: "Alt", value: "artificial-old")
    #expect(local.values[id] == "artificial-old")
    synced.missingEntitlement = false
    #expect(try vault.credentials.read(id: id) == "artificial-old")   // fallback before migration
    #expect(try vault.migrateLocalKeys() == 1)
    #expect(synced.values[id]?.0 == "artificial-old"); #expect(local.values[id] == nil)
    #expect(try vault.migrateLocalKeys() == 0)                        // repeat is a no-op
}

@Test func keysFromAnotherMacAreImportedOnceAndNameClashesGetASuffix() throws {
    let (vault, synced, _, root) = try syncFixture(); defer { try? FileManager.default.removeItem(at: root) }
    _ = try vault.addSecret(name: "Gemini", value: "artificial-here")
    let remote = UUID(); synced.values[remote] = ("artificial-there", "Gemini")
    let other = UUID(); synced.values[other] = ("artificial-x", "Stripe")
    #expect(try vault.importSyncedKeys() == 2)
    let names = try vault.configuration.load().secrets.map(\.name).sorted()
    #expect(names == ["Gemini", "Gemini (\(remote.uuidString.prefix(4)))", "Stripe"])
    #expect(try vault.importSyncedKeys() == 0)
    try vault.credentials.delete(id: other)                            // deleting on one Mac removes it everywhere
    #expect(synced.values[other] == nil)
}

@Test func withoutEntitlementEverythingStaysLocal() throws {
    let (vault, synced, local, root) = try syncFixture(); defer { try? FileManager.default.removeItem(at: root) }
    synced.missingEntitlement = true
    let id = try vault.addSecret(name: "Lokal", value: "artificial-local")
    #expect(local.values[id] == "artificial-local")
    #expect(try vault.credentials.read(id: id) == "artificial-local")
    #expect(try vault.importSyncedKeys() == 0)
}

@Test func testHomesNeverShareTheRealSyncedNamespace() {
    let test = AppPaths(directory: FileManager.default.temporaryDirectory.appendingPathComponent("x"))
    #expect(test.syncedKeychainService.hasPrefix("dev.moinsen.secretariat.keys.test."))
    #expect(AppPaths(directory: AppPaths.defaultDirectory).syncedKeychainService == "dev.moinsen.secretariat.keys.v1")
}

@Test func renameRewritesTheSyncedLabelAndOtherMacsTakeItOver() throws {
    let (vault, synced, _, root) = try syncFixture(); defer { try? FileManager.default.removeItem(at: root) }
    let id = try vault.addSecret(name: "Adventurist CF Access Client ID", value: "artificial-cf")
    // second Mac: own configuration, same synced keychain
    let otherRoot = root.appendingPathComponent("other-mac")
    let other = Vault(configuration: ConfigurationStore(paths: AppPaths(directory: otherRoot)), credentials: vault.credentials)
    #expect(try other.importSyncedKeys() == 1)
    try vault.updateSecret(id: id, name: "moinsen/cloudflare/access-routing-client-id", newValue: nil)
    #expect(synced.values[id]?.0 == "artificial-cf")                                   // value untouched
    #expect(synced.values[id]?.1 == "moinsen/cloudflare/access-routing-client-id")     // label carries the new name
    #expect(try other.importSyncedKeys() == 1)
    #expect(try other.configuration.load().secrets.map(\.name) == ["moinsen/cloudflare/access-routing-client-id"])
    #expect(try other.importSyncedKeys() == 0)
}
