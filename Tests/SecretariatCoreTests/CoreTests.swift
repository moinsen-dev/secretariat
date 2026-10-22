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
