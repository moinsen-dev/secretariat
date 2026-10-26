import Foundation
import CryptoKit
import Darwin

public struct AppPaths: Sendable {
    public let directory: URL
    public var configuration: URL { directory.appendingPathComponent("profiles.json") }
    public var keychainService: String {
        let digest = SHA256.hash(data: Data(directory.standardizedFileURL.path.utf8))
        return "dev.moinsen.secretariat.local.v1." + digest.prefix(12).map { String(format: "%02x", $0) }.joined()
    }
    /// Service of the synced keys. The real home shares one fixed service across all Macs (the path
    /// and user differ per Mac); any other home (tests, fixtures) gets its own isolated namespace.
    public var syncedKeychainService: String {
        guard directory != AppPaths.defaultDirectory else { return "dev.moinsen.secretariat.keys.v1" }
        let digest = SHA256.hash(data: Data(directory.standardizedFileURL.path.utf8))
        return "dev.moinsen.secretariat.keys.test." + digest.prefix(12).map { String(format: "%02x", $0) }.joined()
    }
    public static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/SecretariatLocal", isDirectory: true).standardizedFileURL
    }
    public func credentialStore(allowInteraction: Bool) -> FleetCredentialStore {
        FleetCredentialStore(synced: SyncedKeychainStore(service: syncedKeychainService),
                             legacy: KeychainStore(service: keychainService, allowInteraction: allowInteraction))
    }
    public init(directory: URL? = nil) {
        if let directory { self.directory = directory.standardizedFileURL }
        else if let override = ProcessInfo.processInfo.environment["SECRETARIAT_HOME"], !override.isEmpty {
            self.directory = URL(fileURLWithPath: override, isDirectory: true).standardizedFileURL
        } else {
            self.directory = AppPaths.defaultDirectory
        }
    }
}

public struct ConfigurationStore {
    public let paths: AppPaths
    public init(paths: AppPaths = AppPaths()) { self.paths = paths }

    public func load() throws -> Configuration {
        guard FileManager.default.fileExists(atPath: paths.configuration.path) else { return Configuration() }
        do {
            let data = try Data(contentsOf: paths.configuration)
            let config = try JSONDecoder().decode(Configuration.self, from: data)
            try config.validate()
            return config
        } catch let error as SecretariatError { throw error }
        catch { throw SecretariatError("Die lokale Konfiguration lässt sich nicht lesen. Sie wurde nicht verändert: \(paths.configuration.path)") }
    }

    public func update(expectedRevision: Int? = nil, _ change: (inout Configuration) throws -> Void) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: paths.directory, withIntermediateDirectories: true,
                                    attributes: [.posixPermissions: 0o700])
        let lockURL = paths.directory.appendingPathComponent("configuration.lock")
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw SecretariatError("Die Konfiguration kann nicht zum Schreiben geöffnet werden.") }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw SecretariatError("Die Konfiguration wird gerade verwendet. Bitte erneut versuchen.") }
        defer { _ = flock(descriptor, LOCK_UN) }
        var configuration = try load()
        if let expectedRevision, expectedRevision != configuration.revision {
            throw SecretariatError("Die Daten wurden in einem anderen Fenster geändert. Bitte die Ansicht aktualisieren und erneut bearbeiten.")
        }
        try change(&configuration)
        try configuration.validate()
        configuration.revision += 1
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configuration)
        let temporary = paths.directory.appendingPathComponent(".profiles-\(UUID().uuidString).tmp")
        defer { try? manager.removeItem(at: temporary) }
        guard manager.createFile(atPath: temporary.path, contents: data, attributes: [.posixPermissions: 0o600]) else {
            throw SecretariatError("Die Konfiguration konnte nicht gespeichert werden. Der bisherige Stand bleibt erhalten.")
        }
        guard rename(temporary.path, paths.configuration.path) == 0 else {
            throw SecretariatError("Die Konfiguration konnte nicht ersetzt werden. Der bisherige Stand bleibt erhalten.")
        }
    }
}

public struct Vault {
    public let configuration: ConfigurationStore
    public let credentials: any CredentialStore
    public let expectedRevision: Int?
    public init(configuration: ConfigurationStore, credentials: any CredentialStore, expectedRevision: Int? = nil) {
        self.configuration = configuration; self.credentials = credentials; self.expectedRevision = expectedRevision
    }
    public init(paths: AppPaths = AppPaths(), expectedRevision: Int? = nil) {
        configuration = ConfigurationStore(paths: paths)
        credentials = paths.credentialStore(allowInteraction: true)
        self.expectedRevision = expectedRevision
    }

    @discardableResult public func addSecret(name: String, value: String) throws -> UUID {
        guard !value.isEmpty else { throw SecretariatError("Bitte einen Schlüsselwert eingeben.") }
        guard !value.utf8.contains(0) else { throw SecretariatError("Schlüsselwerte für Umgebungsvariablen dürfen kein Nullzeichen enthalten.") }
        let reference = SecretReference(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        var stored = false
        do {
            try configuration.update(expectedRevision: expectedRevision) { config in
                config.secrets.append(reference)
                try config.validate()
                try credentials.set(value, id: reference.id, label: reference.name)
                stored = true
            }
        } catch {
            if stored { try? credentials.delete(id: reference.id) }
            throw error
        }
        return reference.id
    }

    public func updateSecret(id: UUID, name: String, newValue: String?) throws {
        if let newValue, newValue.utf8.contains(0) { throw SecretariatError("Schlüsselwerte für Umgebungsvariablen dürfen kein Nullzeichen enthalten.") }
        var previous: (String?, String)?
        do {
            try configuration.update(expectedRevision: expectedRevision) { config in
                guard let index = config.secrets.firstIndex(where: { $0.id == id }) else { throw SecretariatError("Dieser Schlüssel wurde inzwischen entfernt.") }
                let oldName = config.secrets[index].name
                config.secrets[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                try config.validate()
                // A rename rewrites the keychain item too: its label carries the name to the other Macs.
                var value = newValue.flatMap { $0.isEmpty ? nil : $0 }
                if value == nil, oldName != config.secrets[index].name { value = try? credentials.read(id: id) }
                if let newValue = value {
                    let oldValue: String?
                    do { oldValue = try credentials.read(id: id) }
                    catch CredentialError.notFound { oldValue = nil }
                    try credentials.set(newValue, id: id, label: config.secrets[index].name)
                    previous = (oldValue, oldName)
                }
            }
        } catch {
            if let previous {
                do {
                    if let value = previous.0 { try credentials.set(value, id: id, label: previous.1) }
                    else { try credentials.delete(id: id) }
                }
                catch { throw SecretariatError("Speichern und Wiederherstellen im Schlüsselbund sind fehlgeschlagen. Bitte den bisherigen Schlüsselwert erneut speichern.") }
            }
            throw error
        }
    }

    public func deleteSecret(id: UUID) throws {
        var previous: (String?, String)?
        do {
            try configuration.update(expectedRevision: expectedRevision) { config in
                let usedBy = config.profiles.filter { $0.bindings.contains(where: { $0.secretID == id }) }.map(\.name)
                guard usedBy.isEmpty else { throw SecretariatError("Dieser Schlüssel wird noch verwendet: \(usedBy.joined(separator: ", ")). Bitte zuerst die Zuordnungen entfernen.") }
                guard let reference = config.secrets.first(where: { $0.id == id }) else { throw SecretariatError("Dieser Schlüssel wurde inzwischen entfernt.") }
                let oldValue: String?
                do { oldValue = try credentials.read(id: id) }
                catch CredentialError.notFound { oldValue = nil }
                try credentials.delete(id: id)
                previous = (oldValue, reference.name)
                config.secrets.removeAll { $0.id == id }
            }
        } catch {
            if let previous {
                do { if let value = previous.0 { try credentials.set(value, id: id, label: previous.1) } }
                catch { throw SecretariatError("Löschen und Wiederherstellen im Schlüsselbund sind fehlgeschlagen. Bitte den bisherigen Schlüsselwert erneut speichern.") }
            }
            throw error
        }
    }

    /// Add references for keys that arrived from another Mac and take over renames made there;
    /// a name clash gets a short id suffix (new keys) or keeps the local name (renames).
    @discardableResult public func importSyncedKeys() throws -> Int {
        guard let listing = credentials as? SyncedKeyListing else { return 0 }
        let entries = try listing.syncedKeys()
        func renamable(_ entry: SyncedKeyEntry, in secrets: [SecretReference]) -> Int? {
            let name = String(entry.name.prefix(128))
            guard let index = secrets.firstIndex(where: { $0.id == entry.id }), secrets[index].name != name,
                  !secrets.contains(where: { $0.id != entry.id && $0.name.lowercased() == name.lowercased() }) else { return nil }
            return index
        }
        let current = try configuration.load().secrets
        guard entries.contains(where: { entry in !current.contains { $0.id == entry.id } || renamable(entry, in: current) != nil })
        else { return 0 }
        var added = 0
        try configuration.update { config in
            for entry in entries {
                guard let index = renamable(entry, in: config.secrets) else { continue }
                config.secrets[index].name = String(entry.name.prefix(128)); added += 1
            }
            for entry in entries where !config.secrets.contains(where: { $0.id == entry.id }) {
                var name = String(entry.name.prefix(128))
                if config.secrets.contains(where: { $0.name.lowercased() == name.lowercased() }) {
                    name = String(name.prefix(118)) + " (" + entry.id.uuidString.prefix(4) + ")"
                }
                config.secrets.append(SecretReference(id: entry.id, name: name)); added += 1
            }
        }
        return added
    }

    /// Move values stored by 0.1/0.2 in the local login keychain into the synced store.
    @discardableResult public func migrateLocalKeys() throws -> Int {
        guard let fleet = credentials as? FleetCredentialStore else { return 0 }
        var moved = 0
        for secret in try configuration.load().secrets where try fleet.migrate(id: secret.id, label: secret.name) { moved += 1 }
        return moved
    }

    public func saveProfile(_ profile: Profile) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: profile.directory, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw SecretariatError("Der gewählte Projektordner existiert nicht. Bitte erneut auswählen.")
        }
        try configuration.update(expectedRevision: expectedRevision) { config in
            if let index = config.profiles.firstIndex(where: { $0.id == profile.id }) { config.profiles[index] = profile }
            else { config.profiles.append(profile) }
        }
    }

    public func deleteProfile(id: UUID) throws {
        try configuration.update(expectedRevision: expectedRevision) { $0.profiles.removeAll { $0.id == id } }
    }

    public func preparedLaunch(name: String, arguments: [String], inheritedEnvironment: [String: String]) throws -> PreparedLaunch {
        let config = try configuration.load()
        guard let profile = config.profiles.first(where: { $0.name == name }) else {
            throw SecretariatError("Profil nicht gefunden. Bitte in Secretariat ein Profil anlegen oder ‚secretariat profiles‘ verwenden.")
        }
        guard !arguments.isEmpty, !arguments[0].isEmpty else { throw SecretariatError("Bitte nach -- ein Programm angeben.") }
        var environment = inheritedEnvironment
        for binding in profile.bindings {
            let value = try credentials.read(id: binding.secretID)
            guard !value.utf8.contains(0) else { throw SecretariatError("Ein gespeicherter Schlüssel enthält ein für Umgebungsvariablen unzulässiges Nullzeichen. Bitte seinen Wert neu speichern.") }
            environment[binding.variable] = value
        }
        return PreparedLaunch(directory: profile.directory, arguments: arguments, environment: environment)
    }
}
