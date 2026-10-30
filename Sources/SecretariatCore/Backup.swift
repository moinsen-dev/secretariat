import CryptoKit
import Foundation
import SystemConfiguration

/// The recovery key: 32 random bytes plus 2 check bytes, written as 11 groups of 5 Crockford Base32 characters.
/// Secretariat shows it once and never stores it; only the public key derived from it stays on the Mac.
public enum RecoveryKey {
    static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    public static func generate() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        precondition(SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess)
        return encode(bytes)
    }

    static func encode(_ secret: [UInt8]) -> String {
        let bytes = secret + Array(SHA256.hash(data: secret).prefix(2))
        var bits = 0, value = 0, characters: [Character] = []
        for byte in bytes {
            value = (value << 8) | Int(byte); bits += 8
            while bits >= 5 { bits -= 5; characters.append(alphabet[(value >> bits) & 31]) }
        }
        if bits > 0 { characters.append(alphabet[(value << (5 - bits)) & 31]) }
        return stride(from: 0, to: characters.count, by: 5).map { String(characters[$0..<min($0 + 5, characters.count)]) }.joined(separator: "-")
    }

    /// The 32 secret bytes; spaces, dashes and case don't matter, O/I/L read as 0/1/1. A typo fails the check bytes.
    public static func decode(_ text: String) throws -> [UInt8] {
        var bits = 0, value = 0, bytes: [UInt8] = []
        for character in text.uppercased() where !" -\t\n".contains(character) {
            let normalized: Character = character == "O" ? "0" : (character == "I" || character == "L") ? "1" : character
            guard let index = alphabet.firstIndex(of: normalized) else { throw invalid() }
            value = ((value << 5) | index) & 0xFFFF; bits += 5
            if bits >= 8 { bits -= 8; bytes.append(UInt8((value >> bits) & 0xFF)) }
        }
        guard bytes.count == 34 else { throw invalid() }
        let secret = Array(bytes.prefix(32))
        guard Array(SHA256.hash(data: secret).prefix(2)) == Array(bytes.suffix(2)) else { throw invalid() }
        return secret
    }
    static func invalid() -> AgentError { AgentError("recovery_key_invalid", "This is not a valid recovery key. Please check it group by group.") }

    /// The backup key pair belonging to a recovery key.
    public static func privateKey(_ secret: [UInt8]) throws -> Curve25519.KeyAgreement.PrivateKey {
        let derived = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: secret), salt: Data("secretariat-backup".utf8),
                                            info: Data("curve25519 v1".utf8), outputByteCount: 32)
        return try derived.withUnsafeBytes { try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: Data($0)) }
    }
    /// Short id of a public key, shown in the app and written into every backup.
    public static func keyID(_ publicKey: Curve25519.KeyAgreement.PublicKey) -> String {
        SHA256.hash(data: publicKey.rawRepresentation).prefix(6).map { String(format: "%02x", $0) }.joined()
    }
}

/// This Mac in backup file names: its name for people, a random id (kept locally) so two Macs with the same name
/// never share or prune each other's files.
public struct BackupMac: Equatable, Sendable {
    public let name: String
    public let id: String
    public var label: String { "\(name)-\(id)" }
    public init(name: String, id: String) { self.name = name; self.id = id }

    public static func current(paths: AppPaths) -> BackupMac {
        let file = paths.directory.appendingPathComponent("backup-mac-id")
        var id = (try? String(contentsOf: file, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if id.range(of: "^[0-9a-f]{8}$", options: .regularExpression) == nil {
            id = (0..<4).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
            try? FileManager.default.createDirectory(at: paths.directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            FileManager.default.createFile(atPath: file.path, contents: Data(id.utf8), attributes: [.posixPermissions: 0o600])
        }
        return BackupMac(name: slug((SCDynamicStoreCopyComputerName(nil, nil) as String?) ?? "mac"), id: id)
    }
    static func slug(_ text: String) -> String {
        let slug = text.lowercased().folding(options: .diacriticInsensitive, locale: nil)
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? "mac" : String(slug.prefix(40))
    }
}

/// Automatic encrypted backups. Each file is sealed to the backup public key with HPKE, so this Mac can write
/// backups without being able to read them; opening one needs the recovery key.
public enum Backup {
    public static let suffix = ".secretariat-backup"
    public static let kept = 30
    static let suite = HPKE.Ciphersuite.Curve25519_SHA256_ChachaPoly
    static let info = Data("secretariat backup v1".utf8)

    public struct Header: Codable, Equatable, Sendable {
        public var version = 1
        public var created: Date
        public var mac: String
        public var macID: String
        public var key: String
        public var items: Int
        public var encapsulatedKey: Data
    }

    public struct StoredItem: Codable, Equatable, Sendable {
        public var meta: ItemMeta
        public var secrets: [String: String]
    }

    /// Everything a restore needs, in plaintext only inside the sealed part. Not included: license and trial.
    public struct Payload: Codable, Equatable, Sendable {
        public var version = 1
        public var items: [StoredItem]
        public var profiles: [Profile]
        public var targets: [Target]
        public var templates: [Template]
        public var screenshotKeys: [String: Data]
    }

    /// One backup file as listed: name parts only, nothing is read or downloaded.
    public struct File: Codable, Equatable, Sendable {
        public var name: String
        public var day: String
        public var mac: String
        public var macID: String
        /// iCloud keeps only a placeholder on this Mac; it is downloaded when opened.
        public var inCloudOnly: Bool
    }

    public struct Status: Codable, Equatable, Sendable {
        public var configured: Bool
        public var key: String?
        public var location: String
        public var directory: String
        public var files: [File]
        /// This Mac's last backup.
        public var last: Date?
        /// Why backups may have stopped: key missing, writing failed, nothing for two days.
        public var problem: String?
    }

    // MARK: key

    /// The app generates the key first and calls this only once the user confirmed they kept it.
    public static func setUp(vault: Vault, recoveryKey recovery: String = RecoveryKey.generate()) throws -> String {
        let publicKey = try RecoveryKey.privateKey(try RecoveryKey.decode(recovery)).publicKey
        try vault.backupKeys.write("public", publicKey.rawRepresentation)
        vault.audit.record("backup.key", ["key": RecoveryKey.keyID(publicKey)])
        return recovery
    }

    public static func publicKey(vault: Vault) -> Curve25519.KeyAgreement.PublicKey? {
        (try? vault.backupKeys.read("public")).flatMap { $0 }.flatMap { try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: $0) }
    }

    /// Whether a typed recovery key belongs to the current backup key, without opening any backup.
    public static func matches(_ recovery: String, vault: Vault) throws -> Bool {
        guard let publicKey = publicKey(vault: vault) else { throw notSetUp() }
        return RecoveryKey.keyID(try RecoveryKey.privateKey(try RecoveryKey.decode(recovery)).publicKey) == RecoveryKey.keyID(publicKey)
    }

    // MARK: where

    /// The app's iCloud Drive container for the real home; test homes and Macs without iCloud keep backups locally.
    /// Resolving the container can take a moment: call it off the main thread.
    public static func directory(paths: AppPaths) -> (url: URL, location: String) {
        if paths.isDefault, let container = FileManager.default.url(forUbiquityContainerIdentifier: ScreenshotLibrary.containerIdentifier) {
            return (container.appendingPathComponent("Backups", isDirectory: true), "icloud")
        }
        return (paths.directory.appendingPathComponent("backups", isDirectory: true), "local")
    }

    /// "2026-10-30-ulis-macbook-pro-3fa9c2d1.secretariat-backup", also as iCloud placeholder ".<name>.icloud". Newest first.
    public static func files(in directory: URL) -> [File] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        var files: [String: File] = [:]
        for raw in names {
            let placeholder = raw.hasPrefix(".") && raw.hasSuffix(".icloud")
            let name = placeholder ? String(raw.dropFirst().dropLast(7)) : raw
            guard name.hasSuffix(suffix), let file = parse(name, inCloudOnly: placeholder) else { continue }
            if files[name] == nil || !placeholder { files[name] = file }
        }
        return files.values.sorted { ($0.day, $0.name) > ($1.day, $1.name) }
    }
    static func parse(_ name: String, inCloudOnly: Bool) -> File? {
        let stem = String(name.dropLast(suffix.count))
        guard stem.count > 20, stem.dropFirst(10).first == "-", let dash = stem.lastIndex(of: "-") else { return nil }
        let day = String(stem.prefix(10)), id = String(stem[stem.index(after: dash)...])
        let mac = String(stem[stem.index(stem.startIndex, offsetBy: 11)..<dash])
        guard day.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil,
              id.range(of: "^[0-9a-f]{8}$", options: .regularExpression) != nil, !mac.isEmpty else { return nil }
        return File(name: name, day: day, mac: mac, macID: id, inCloudOnly: inCloudOnly)
    }

    public static func status(vault: Vault, now: Date = Date()) -> Status {
        let (directory, location) = directory(paths: vault.configuration.paths)
        let state = try? state(vault: vault).read()
        let key = publicKey(vault: vault)
        var problem: String?
        if key == nil, state != nil {
            problem = "The backup key is missing on this Mac (iCloud keychain?). Backups have stopped. Set up backup again."
        } else if key != nil, let error = state?.error {
            problem = "The last backup failed: \(error)"
        } else if key != nil, (state?.at).map({ now.timeIntervalSince($0) > 2 * 86_400 }) ?? true {
            problem = "No backup from this Mac for more than two days."
        }
        return Status(configured: key != nil, key: key.map(RecoveryKey.keyID), location: location, directory: directory.path,
                      files: files(in: directory), last: state?.at, problem: problem)
    }

    // MARK: writing

    /// Every value is read; a keychain that refuses (locked, denied) stops the backup instead of producing a thin one.
    public static func payload(vault: Vault) throws -> Payload {
        let configuration = try vault.configuration.load()
        let items = try vault.list().map { meta in
            do { return StoredItem(meta: meta, secrets: try vault.items.secrets(id: meta.id)) }
            catch CredentialError.notFound { return StoredItem(meta: meta, secrets: [:]) }
        }
        return Payload(items: items.sorted { $0.meta.path < $1.meta.path }, profiles: configuration.profiles, targets: configuration.targets,
                       templates: try vault.templates.list().sorted { $0.id < $1.id }, screenshotKeys: try vault.screenshotKeys.keys())
    }

    /// Seals the vault into today's file for this Mac (replacing an earlier one of the same day) and keeps the newest 30.
    @discardableResult public static func write(vault: Vault, now: Date = Date(), mac: BackupMac? = nil) throws -> URL {
        let paths = vault.configuration.paths
        let mac = mac ?? BackupMac.current(paths: paths)
        guard publicKey(vault: vault) != nil else { throw notSetUp() }
        do {
            let payload = try payload(vault: vault)
            return try seal(payload, encoded: try encoder.encode(payload), vault: vault, now: now, mac: mac)
        } catch {
            try? state(vault: vault).update { $0.error = error.localizedDescription }
            throw error
        }
    }

    static func seal(_ payload: Payload, encoded: Data, vault: Vault, now: Date, mac: BackupMac) throws -> URL {
        guard let publicKey = publicKey(vault: vault) else { throw notSetUp() }
        let paths = vault.configuration.paths
        let (directory, _) = directory(paths: paths)
        var sender = try HPKE.Sender(recipientKey: publicKey, ciphersuite: suite, info: info)
        let header = Header(created: Date(timeIntervalSince1970: now.timeIntervalSince1970.rounded(.down)), mac: mac.name, macID: mac.id,
                            key: RecoveryKey.keyID(publicKey), items: payload.items.count, encapsulatedKey: sender.encapsulatedKey)
        let headerData = try encoder.encode(header)
        let sealed = try sender.seal(encoded, authenticating: headerData)
        var file = headerData; file.append(0x0A); file.append(sealed.base64EncodedData()); file.append(0x0A)

        let day = ISO8601DateFormatter.string(from: now, timeZone: .current, formatOptions: [.withFullDate])
        let url = directory.appendingPathComponent("\(day)-\(mac.label)\(suffix)")
        // Staged outside the iCloud container, then moved in under file coordination.
        let temporary = paths.directory.appendingPathComponent(".backup-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard FileManager.default.createFile(atPath: temporary.path, contents: file, attributes: [.posixPermissions: 0o600]) else {
            throw SecretariatError("The backup could not be staged in \(paths.directory.path).")
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try coordinate(writing: url, options: .forReplacing) { target in
            if FileManager.default.fileExists(atPath: target.path) {
                _ = try FileManager.default.replaceItemAt(target, withItemAt: temporary)
            } else {
                try FileManager.default.moveItem(at: temporary, to: target)
            }
        }
        for old in files(in: directory).filter({ $0.macID == mac.id }).dropFirst(kept) {
            try? coordinate(writing: directory.appendingPathComponent(old.name), options: .forDeleting) { try FileManager.default.removeItem(at: $0) }
        }
        let fingerprint = try state(vault: vault).fingerprint(encoded)
        try state(vault: vault).update { $0.fingerprint = fingerprint; $0.file = url.lastPathComponent; $0.at = now; $0.error = nil }
        vault.audit.record("backup", ["file": url.lastPathComponent, "items": String(payload.items.count)])
        return url
    }

    /// The automatic backup: when set up, and the content changed since the last one (a keyed hash over everything,
    /// values included, taken before sealing) or there is none yet today.
    @discardableResult public static func automatic(vault: Vault, now: Date = Date(), onlyDaily: Bool = false, mac: BackupMac? = nil) -> URL? {
        guard publicKey(vault: vault) != nil else { return nil }
        let store = state(vault: vault)
        let last = try? store.read()
        let today = (last?.at).map { Calendar.current.isDate($0, inSameDayAs: now) } ?? false
        if today && onlyDaily { return nil }
        do {
            let payload = try payload(vault: vault)
            let encoded = try encoder.encode(payload)
            if today, let fingerprint = try? store.fingerprint(encoded), fingerprint == last?.fingerprint { return nil }
            return try seal(payload, encoded: encoded, vault: vault, now: now, mac: mac ?? BackupMac.current(paths: vault.configuration.paths))
        } catch {
            try? store.update { $0.error = error.localizedDescription }
            return nil
        }
    }

    /// After a suspected leak: removes every backup not sealed to the current key. Returns how many went.
    @discardableResult public static func removeBackups(notSealedTo key: String, vault: Vault) -> Int {
        let (directory, _) = directory(paths: vault.configuration.paths)
        var removed = 0
        for file in files(in: directory) {
            let url = directory.appendingPathComponent(file.name)
            guard let header = try? header(of: url), header.key != key else { continue }
            if (try? coordinate(writing: url, options: .forDeleting) { try FileManager.default.removeItem(at: $0) }) != nil { removed += 1 }
        }
        vault.audit.record("backup.removed", ["files": String(removed)])
        return removed
    }

    // MARK: reading

    /// Reads a backup file under file coordination; a file iCloud has only as placeholder is downloaded first.
    static func read(_ url: URL) throws -> Data {
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        var data: Data?
        try coordinate(reading: url) { data = try Data(contentsOf: $0) }
        guard let data else { throw damaged() }
        return data
    }

    public static func header(of url: URL) throws -> Header {
        let (headerData, _) = try split(try read(url))
        return try decoder.decode(Header.self, from: headerData)
    }

    public static func open(_ url: URL, recoveryKey: String) throws -> (Header, Payload) {
        let privateKey = try RecoveryKey.privateKey(try RecoveryKey.decode(recoveryKey))
        let (headerData, body) = try split(try read(url))
        guard let header = try? decoder.decode(Header.self, from: headerData) else { throw damaged() }
        guard header.key == RecoveryKey.keyID(privateKey.publicKey) else {
            throw AgentError("backup_wrong_key", "This backup was made with a different recovery key (\(header.key)).")
        }
        do {
            var recipient = try HPKE.Recipient(privateKey: privateKey, ciphersuite: suite, info: info, encapsulatedKey: header.encapsulatedKey)
            guard let sealed = Data(base64Encoded: body) else { throw damaged() }
            return (header, try decoder.decode(Payload.self, from: try recipient.open(sealed, authenticating: headerData)))
        } catch let error as AgentError { throw error } catch { throw damaged() }
    }

    // MARK: restoring

    public struct Restored: Codable, Equatable, Sendable {
        public var items = 0, profiles = 0, targets = 0, templates = 0, screenshotKeys = 0
        /// Present here under the same name but as something else: left alone.
        public var skipped: [String] = []
        /// Could not be brought back; everything else still was.
        public var failed: [String] = []
    }

    /// What a restore would add, for the user to look at first.
    public static func additions(_ payload: Payload, to vault: Vault) -> [String] {
        let items = (try? vault.list()) ?? []
        let configuration = try? vault.configuration.load()
        let templates = Set(((try? vault.templates.list()) ?? []).map(\.id))
        let keys = (try? vault.screenshotKeys.keys()) ?? [:]
        return payload.items.filter { stored in !items.contains { $0.id == stored.meta.id || $0.path.lowercased() == stored.meta.path.lowercased() } }.map(\.meta.path)
            + payload.profiles.filter { p in !(configuration?.profiles ?? []).contains { $0.id == p.id || $0.name.lowercased() == p.name.lowercased() } }.map { "project \($0.name)" }
            + payload.targets.filter { t in !(configuration?.targets ?? []).contains { $0.id == t.id || $0.name.lowercased() == t.name.lowercased() } }.map { "target \($0.name)" }
            + payload.templates.filter { !templates.contains($0.id) }.map { "template \($0.title)" }
            + (payload.screenshotKeys.keys.contains { keys[$0] == nil } ? ["screenshot keys"] : [])
    }

    /// Brings back what is missing (by id); everything that exists stays exactly as it is, values keep their dates.
    public static func restore(_ payload: Payload, into vault: Vault) throws -> Restored {
        var result = Restored()
        let present = try vault.list()
        for stored in payload.items where !present.contains(where: { $0.id == stored.meta.id }) {
            if present.contains(where: { $0.path.lowercased() == stored.meta.path.lowercased() }) { result.skipped.append(stored.meta.path); continue }
            do { try vault.items.save(stored.meta, secrets: stored.secrets); result.items += 1 }
            catch { result.failed.append("\(stored.meta.path): \(error.localizedDescription)") }
        }
        do {
            try vault.configuration.update { configuration in
                for profile in payload.profiles where !configuration.profiles.contains(where: { $0.id == profile.id }) {
                    if configuration.profiles.contains(where: { $0.name.lowercased() == profile.name.lowercased() }) { result.skipped.append("project \(profile.name)"); continue }
                    configuration.profiles.append(profile); result.profiles += 1
                }
                for target in payload.targets where !configuration.targets.contains(where: { $0.id == target.id }) {
                    if configuration.targets.contains(where: { $0.name.lowercased() == target.name.lowercased() }) { result.skipped.append("target \(target.name)"); continue }
                    configuration.targets.append(target); result.targets += 1
                }
            }
        } catch {
            result.profiles = 0; result.targets = 0
            result.failed.append("projects and targets: \(error.localizedDescription)")
        }
        let templates = Set(((try? vault.templates.list()) ?? []).map(\.id))
        for template in payload.templates where !templates.contains(template.id) {
            do { try vault.templates.save(template); result.templates += 1 } catch { result.failed.append("template \(template.id): \(error.localizedDescription)") }
        }
        let keys = (try? vault.screenshotKeys.keys()) ?? [:]
        for (id, key) in payload.screenshotKeys where keys[id] == nil {
            do { try vault.screenshotKeys.add(id: id, key: key); result.screenshotKeys += 1 } catch { result.failed.append("screenshot key: \(error.localizedDescription)") }
        }
        vault.audit.record("backup.restore", ["items": String(result.items), "profiles": String(result.profiles),
                                              "skipped": String(result.skipped.count), "failed": String(result.failed.count)])
        return result
    }

    // MARK: helpers

    static func split(_ data: Data) throws -> (Data, Data) {
        guard let newline = data.firstIndex(of: 0x0A) else { throw damaged() }
        var body = data[data.index(after: newline)...]
        while body.last == 0x0A { body = body.dropLast() }
        return (Data(data[..<newline]), Data(body))
    }
    static func damaged() -> AgentError { AgentError("backup_damaged", "This backup file is damaged or was changed. Nothing was restored.") }
    static func notSetUp() -> AgentError { AgentError("backup_not_set_up", "Backup isn't set up yet. Set it up in the Secretariat app (Library → Backup).") }

    static func coordinate(writing url: URL, options: NSFileCoordinator.WritingOptions, _ body: (URL) throws -> Void) throws {
        var coordinationError: NSError?, bodyError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: options, error: &coordinationError) { target in
            do { try body(target) } catch { bodyError = error }
        }
        if let error = coordinationError ?? bodyError { throw error }
    }
    static func coordinate(reading url: URL, _ body: (URL) throws -> Void) throws {
        var coordinationError: NSError?, bodyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { target in
            do { try body(target) } catch { bodyError = error }
        }
        if let error = coordinationError ?? bodyError { throw error }
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; encoder.dateEncodingStrategy = .iso8601; return encoder
    }
    static var decoder: JSONDecoder { let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return decoder }

    /// This Mac's backup state: when it last backed up, a keyed hash of what it backed up (the key is random and
    /// stays in this file, so the hash says nothing about values), and the last error.
    struct State {
        let url: URL
        struct Stored: Codable { var hashKey: Data?; var fingerprint: String?; var file: String?; var at: Date?; var error: String? }
        func read() throws -> Stored { try Backup.decoder.decode(Stored.self, from: Data(contentsOf: url)) }
        func update(_ change: (inout Stored) -> Void) throws {
            var stored = (try? read()) ?? Stored()
            change(&stored)
            let data = try Backup.encoder.encode(stored)
            guard FileManager.default.createFile(atPath: url.path, contents: data, attributes: [.posixPermissions: 0o600]) else {
                throw SecretariatError("The backup state could not be saved.")
            }
        }
        func fingerprint(_ encoded: Data) throws -> String {
            var key = (try? read())?.hashKey
            if key == nil {
                let fresh = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
                try update { $0.hashKey = fresh }
                key = fresh
            }
            return Data(HMAC<SHA256>.authenticationCode(for: encoded, using: SymmetricKey(data: key!))).base64EncodedString()
        }
    }
    static func state(vault: Vault) -> State { State(url: vault.configuration.paths.directory.appendingPathComponent("backup-state.json")) }
}
