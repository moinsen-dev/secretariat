import CryptoKit
import Foundation

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
        public var key: String
        public var items: Int
        public var encapsulatedKey: Data
    }

    public struct StoredItem: Codable, Equatable, Sendable {
        public var meta: ItemMeta
        public var secrets: [String: String]
    }

    /// Everything a restore needs, in plaintext only inside the sealed part.
    public struct Payload: Codable, Equatable, Sendable {
        public var version = 1
        public var items: [StoredItem]
        public var profiles: [Profile]
        public var targets: [Target]
        public var templates: [Template]
        public var screenshotKeys: [String: Data]
    }

    public struct Status: Codable, Equatable, Sendable {
        public var configured: Bool
        public var key: String?
        public var location: String
        public var directory: String
        public var files: [String]
        public var last: Date?
    }

    // MARK: key

    /// Creates a new recovery key and makes its public key the one future backups are sealed to.
    /// Older backups keep needing the key they were made with.
    public static func setUp(vault: Vault) throws -> String {
        let recovery = RecoveryKey.generate()
        let publicKey = try RecoveryKey.privateKey(try RecoveryKey.decode(recovery)).publicKey
        try vault.backupKeys.write("public", publicKey.rawRepresentation)
        vault.audit.record("backup.key", ["key": RecoveryKey.keyID(publicKey)])
        return recovery
    }

    public static func publicKey(vault: Vault) -> Curve25519.KeyAgreement.PublicKey? {
        (try? vault.backupKeys.read("public")).flatMap { $0 }.flatMap { try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: $0) }
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

    /// This Mac's name as it appears in file names ("Uli's MacBook Pro" → "ulis-macbook-pro").
    public static var macName: String {
        let name = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        let slug = name.lowercased().folding(options: .diacriticInsensitive, locale: nil)
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? "mac" : String(slug.prefix(40))
    }

    public static func files(in directory: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []).filter { $0.hasSuffix(suffix) }.sorted(by: >)
    }

    public static func status(vault: Vault) -> Status {
        let (directory, location) = directory(paths: vault.configuration.paths)
        let files = files(in: directory)
        let last = files.lazy.compactMap { try? header(of: directory.appendingPathComponent($0)).created }.max()
        return Status(configured: publicKey(vault: vault) != nil, key: publicKey(vault: vault).map(RecoveryKey.keyID),
                      location: location, directory: directory.path, files: files, last: last)
    }

    // MARK: writing

    public static func payload(vault: Vault) throws -> Payload {
        let configuration = try vault.configuration.load()
        let items = try vault.list().map { StoredItem(meta: $0, secrets: (try? vault.items.secrets(id: $0.id)) ?? [:]) }
        return Payload(items: items.sorted { $0.meta.path < $1.meta.path }, profiles: configuration.profiles, targets: configuration.targets,
                       templates: (try? vault.templates.list()) ?? [], screenshotKeys: (try? vault.screenshotKeys.keys()) ?? [:])
    }

    /// Names, dates and ids of everything a backup holds, without values: a change here means a new backup is due.
    public static func fingerprint(vault: Vault) -> String {
        let configuration = try? vault.configuration.load()
        var parts = ((try? vault.list()) ?? []).map { item in
            "\(item.id)|\(item.path)|\(item.rotated ?? "")|\(item.fields.map { "\($0.name):\($0.kind.rawValue):\($0.value ?? "")" }.joined(separator: ","))"
        }.sorted()
        parts.append("config:\(configuration?.revision ?? -1)")
        parts.append("templates:" + ((try? vault.templates.list()) ?? []).map(\.id).sorted().joined(separator: ","))
        parts.append("screenshots:" + ((try? vault.screenshotKeys.keys()) ?? [:]).keys.sorted().joined(separator: ","))
        return SHA256.hash(data: Data(parts.joined(separator: "\n").utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Seals the vault into today's file for this Mac (replacing an earlier one of the same day) and keeps the newest 30.
    @discardableResult public static func write(vault: Vault, now: Date = Date(), mac: String = macName) throws -> URL {
        guard let publicKey = publicKey(vault: vault) else {
            throw AgentError("backup_not_set_up", "Backup isn't set up yet. Set it up in the Secretariat app (Library → Backup).")
        }
        let payload = try payload(vault: vault)
        let (directory, _) = directory(paths: vault.configuration.paths)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        var sender = try HPKE.Sender(recipientKey: publicKey, ciphersuite: suite, info: info)
        let header = Header(created: Date(timeIntervalSince1970: now.timeIntervalSince1970.rounded(.down)), mac: mac,
                            key: RecoveryKey.keyID(publicKey), items: payload.items.count, encapsulatedKey: sender.encapsulatedKey)
        let headerData = try encoder.encode(header)
        let sealed = try sender.seal(try encoder.encode(payload), authenticating: headerData)
        var file = headerData; file.append(0x0A); file.append(sealed.base64EncodedData()); file.append(0x0A)

        let day = ISO8601DateFormatter.string(from: now, timeZone: .current, formatOptions: [.withFullDate])
        let url = directory.appendingPathComponent("\(day)-\(mac)\(suffix)")
        let temporary = directory.appendingPathComponent(".backup-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard FileManager.default.createFile(atPath: temporary.path, contents: file, attributes: [.posixPermissions: 0o600]),
              rename(temporary.path, url.path) == 0 else { throw SecretariatError("The backup could not be written to \(directory.path).") }
        for old in files(in: directory).filter({ $0.hasSuffix("-\(mac)\(suffix)") }).dropFirst(kept) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(old))
        }
        try? state(vault: vault).write(fingerprint(vault: vault), file: url.lastPathComponent, at: now)
        vault.audit.record("backup", ["file": url.lastPathComponent, "items": String(payload.items.count)])
        return url
    }

    /// The automatic backup: when set up, and the vault changed since the last one or there is none yet today.
    @discardableResult public static func automatic(vault: Vault, now: Date = Date(), onlyDaily: Bool = false) -> URL? {
        guard publicKey(vault: vault) != nil else { return nil }
        let last = try? state(vault: vault).read()
        let today = last.map { Calendar.current.isDate($0.at, inSameDayAs: now) } ?? false
        if today && (onlyDaily || last?.fingerprint == fingerprint(vault: vault)) { return nil }
        return try? write(vault: vault, now: now)
    }

    // MARK: reading

    public static func header(of url: URL) throws -> Header {
        let (headerData, _) = try split(try Data(contentsOf: url))
        return try decoder.decode(Header.self, from: headerData)
    }

    public static func open(_ url: URL, recoveryKey: String) throws -> (Header, Payload) {
        let privateKey = try RecoveryKey.privateKey(try RecoveryKey.decode(recoveryKey))
        let (headerData, body) = try split(try Data(contentsOf: url))
        let header = try decoder.decode(Header.self, from: headerData)
        guard header.key == RecoveryKey.keyID(privateKey.publicKey) else {
            throw AgentError("backup_wrong_key", "This backup was made with a different recovery key (\(header.key)).")
        }
        do {
            var recipient = try HPKE.Recipient(privateKey: privateKey, ciphersuite: suite, info: info, encapsulatedKey: header.encapsulatedKey)
            guard let sealed = Data(base64Encoded: body) else { throw damaged() }
            return (header, try decoder.decode(Payload.self, from: try recipient.open(sealed, authenticating: headerData)))
        } catch let error as AgentError { throw error } catch { throw damaged() }
    }

    public struct Restored: Codable, Equatable, Sendable {
        public var items = 0, profiles = 0, targets = 0, templates = 0, screenshotKeys = 0
        /// Present here under the same name but as something else: left alone.
        public var skipped: [String] = []
    }

    /// Brings back what is missing (by id); everything that exists stays exactly as it is.
    public static func restore(_ payload: Payload, into vault: Vault) throws -> Restored {
        var result = Restored()
        let present = try vault.list()
        for stored in payload.items where !present.contains(where: { $0.id == stored.meta.id }) {
            if present.contains(where: { $0.path == stored.meta.path }) { result.skipped.append(stored.meta.path); continue }
            try vault.save(stored.meta, secrets: stored.secrets)
            result.items += 1
        }
        try vault.configuration.update { configuration in
            for profile in payload.profiles where !configuration.profiles.contains(where: { $0.id == profile.id }) {
                if configuration.profiles.contains(where: { $0.name.lowercased() == profile.name.lowercased() }) { result.skipped.append("profile \(profile.name)"); continue }
                configuration.profiles.append(profile); result.profiles += 1
            }
            for target in payload.targets where !configuration.targets.contains(where: { $0.id == target.id }) {
                if configuration.targets.contains(where: { $0.name.lowercased() == target.name.lowercased() }) { result.skipped.append("target \(target.name)"); continue }
                configuration.targets.append(target); result.targets += 1
            }
        }
        let templates = Set((try? vault.templates.list())?.map(\.id) ?? [])
        for template in payload.templates where !templates.contains(template.id) { try vault.templates.save(template); result.templates += 1 }
        let keys = (try? vault.screenshotKeys.keys()) ?? [:]
        for (id, key) in payload.screenshotKeys where keys[id] == nil { try vault.screenshotKeys.add(id: id, key: key); result.screenshotKeys += 1 }
        vault.audit.record("backup.restore", ["items": String(result.items), "profiles": String(result.profiles), "skipped": String(result.skipped.count)])
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

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; encoder.dateEncodingStrategy = .iso8601; return encoder
    }
    static var decoder: JSONDecoder { let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return decoder }

    /// When this Mac last backed up and what the vault looked like then (no values).
    struct State {
        let url: URL
        struct Stored: Codable { var fingerprint: String; var file: String; var at: Date }
        func read() throws -> Stored { try Backup.decoder.decode(Stored.self, from: Data(contentsOf: url)) }
        func write(_ fingerprint: String, file: String, at: Date) throws {
            let data = try Backup.encoder.encode(Stored(fingerprint: fingerprint, file: file, at: at))
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
    }
    static func state(vault: Vault) -> State { State(url: vault.configuration.paths.directory.appendingPathComponent("backup-state.json")) }
}
