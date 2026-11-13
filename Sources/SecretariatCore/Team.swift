import CryptoKit
import Foundation

/// Secretariat in a team: every user has a sharing key pair; items travel between people as sealed share packages.
///
/// Everything team-related lives in the synced keychain (own service per vault namespace), not in profiles.json:
/// a process running as the user (an agent) can edit files, but can't swap a member's key for its own.
/// Sharing, adding members and opening packages happen only in the app; the CLI can only show the code and the list.
public enum Team {
    // MARK: identity and codes

    public struct Member: Codable, Equatable, Identifiable, Sendable {
        public var name: String
        /// Raw Curve25519 key-agreement public key (32 bytes).
        public var key: Data
        public var added: Date
        /// Comes from the organization's managed settings (MDM); not stored, can't be removed in the app.
        public var managed: Bool
        public var id: String { keyID }
        public var keyID: String { Team.keyID(key) }
        public var code: String { Team.code(name: name, key: key) }
        public init(name: String, key: Data, added: Date = Date(), managed: Bool = false) {
            self.name = name; self.key = key; self.added = added; self.managed = managed
        }
        enum CodingKeys: String, CodingKey { case name, key, added }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decode(String.self, forKey: .name); key = try c.decode(Data.self, forKey: .key)
            added = try c.decode(Date.self, forKey: .added); managed = false
        }
    }

    /// One item given to one member: what offboarding needs to know. Names only, never values.
    public struct Shared: Codable, Equatable, Sendable {
        public var item: UUID
        public var path: String
        public var member: String
        public var memberKey: String
        public var at: Date
        /// Keyed hash of the values as shared (key random, kept in the same synced store): tells whether a value
        /// changed since, without keeping the value.
        public var values: String?
    }

    static let codePrefix = "stc1:"
    static let maxName = 40

    /// `stc1:` + base64url(name length, name, 32 key bytes, 4 check bytes). The check bytes catch typos and truncation.
    public static func code(name: String, key: Data) -> String {
        let nameBytes = Data(name.utf8.prefix(maxName))
        var body = Data([UInt8(nameBytes.count)]); body.append(nameBytes); body.append(key)
        body.append(contentsOf: SHA256.hash(data: Data("secretariat-team-code".utf8) + body).prefix(4))
        return codePrefix + body.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    /// Name and key from a code; spaces and line breaks (from mail or chat) don't matter.
    public static func parse(code text: String) throws -> (name: String, key: Data) {
        let compact = text.filter { !$0.isWhitespace }
        guard compact.hasPrefix(codePrefix) else { throw invalidCode() }
        var b64 = String(compact.dropFirst(codePrefix.count)).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let body = Data(base64Encoded: b64), body.count >= 1 + 32 + 4 else { throw invalidCode() }
        let length = Int(body[body.startIndex])
        guard length <= maxName, body.count == 1 + length + 32 + 4 else { throw invalidCode() }
        let content = body.prefix(1 + length + 32)
        guard Data(SHA256.hash(data: Data("secretariat-team-code".utf8) + content).prefix(4)) == body.suffix(4) else { throw invalidCode() }
        guard let name = String(data: body.dropFirst().prefix(length), encoding: .utf8) else { throw invalidCode() }
        let key = Data(body.dropFirst(1 + length).prefix(32))
        guard (try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: key)) != nil else { throw invalidCode() }
        return (name, key)
    }

    /// 12 hex characters, shown grouped as fingerprint.
    public static func keyID(_ key: Data) -> String {
        SHA256.hash(data: key).prefix(6).map { String(format: "%02x", $0) }.joined()
    }
    /// 128 bits for comparing a code over a second channel (the short key id only addresses recipients).
    public static func fingerprint(_ key: Data) -> String {
        let id = SHA256.hash(data: key).prefix(16).map { String(format: "%02x", $0) }.joined()
        return stride(from: 0, to: id.count, by: 4).map { i in
            String(id[id.index(id.startIndex, offsetBy: i)..<id.index(id.startIndex, offsetBy: min(i + 4, id.count))])
        }.joined(separator: " ")
    }

    static func invalidCode() -> AgentError {
        AgentError("team_code_invalid", "This is not a valid Secretariat share code. Ask for it again and paste it in full.")
    }

    /// This user's key pair, created on first use. The private key never leaves the synced keychain.
    public static func privateKey(vault: Vault) throws -> Curve25519.KeyAgreement.PrivateKey {
        if let raw = try vault.teamKeys.read("private") { return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: raw) }
        let key = Curve25519.KeyAgreement.PrivateKey()
        try vault.teamKeys.write("private", key.rawRepresentation)
        vault.audit.record("team.key", ["key": keyID(key.publicKey.rawRepresentation)])
        return key
    }

    /// The name others see in this user's code; defaults to the Mac user's full name.
    public static func ownName(vault: Vault) -> String {
        if let data = try? vault.teamKeys.read("name"), let name = String(data: data, encoding: .utf8), !name.isEmpty { return name }
        let full = NSFullUserName().trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? NSUserName() : full
    }
    public static func setOwnName(_ name: String, vault: Vault) throws {
        let clean = try validName(name)
        try vault.teamKeys.write("name", Data(clean.utf8))
    }
    public static func ownCode(vault: Vault) throws -> String {
        code(name: ownName(vault: vault), key: try privateKey(vault: vault).publicKey.rawRepresentation)
    }

    static func validName(_ name: String) throws -> String {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.utf8.count <= maxName, !clean.contains(where: { $0.isNewline || $0.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) } }) else {
            throw SecretariatError("Names have 1 to \(maxName) bytes and no line breaks.")
        }
        return clean
    }

    // MARK: members

    /// Members added in the app plus those the organization manages (MDM), managed ones first.
    public static func members(vault: Vault, managed: ManagedSettings = ManagedSettings()) -> [Member] {
        let stored = (try? storedMembers(vault: vault)) ?? []
        let fromOrg = managed.teamMembers().filter { m in !stored.contains { $0.key == m.key } }
        return fromOrg + stored.map { m in var m = m; m.managed = managed.teamMembers().contains { $0.key == m.key }; return m }
    }
    static func storedMembers(vault: Vault) throws -> [Member] {
        guard let data = try vault.teamKeys.read("members") else { return [] }
        return try decoder.decode([Member].self, from: data)
    }
    static func saveMembers(_ members: [Member], vault: Vault) throws {
        try vault.teamKeys.write("members", try encoder.encode(members))
    }

    /// Adds a member from a code. App only.
    @discardableResult
    public static func addMember(code: String, name: String? = nil, vault: Vault) throws -> Member {
        let parsed = try parse(code: code)
        let own = try privateKey(vault: vault).publicKey.rawRepresentation
        guard parsed.key != own else { throw SecretariatError("That's your own code.") }
        var members = try storedMembers(vault: vault)
        let display = try validName(name ?? parsed.name)
        if let existing = members.first(where: { $0.key == parsed.key }) {
            throw SecretariatError("\(existing.name) is already in your team with this code.")
        }
        if members.contains(where: { $0.name.lowercased() == display.lowercased() }) {
            throw SecretariatError("There is already a member called \(display). Choose another name.")
        }
        let member = Member(name: display, key: parsed.key)
        members.append(member)
        try saveMembers(members, vault: vault)
        vault.audit.record("team.add", ["member": display, "key": member.keyID])
        return member
    }

    /// Removes a member (not a managed one) and returns the items that were shared with them.
    public static func removeMember(_ member: Member, vault: Vault) throws -> [Shared] {
        guard !member.managed else { throw SecretariatError("\(member.name) is managed by your organization and can't be removed here.") }
        var members = try storedMembers(vault: vault)
        members.removeAll { $0.key == member.key }
        try saveMembers(members, vault: vault)
        vault.audit.record("team.remove", ["member": member.name, "key": member.keyID])
        return sharedWith(member, vault: vault)
    }

    // MARK: record of what was shared

    public static func sharedLog(vault: Vault) -> [Shared] {
        guard let data = try? vault.teamKeys.read("shared") else { return [] }
        return (try? decoder.decode([Shared].self, from: data)) ?? []
    }
    public static func sharedWith(_ member: Member, vault: Vault) -> [Shared] {
        let items = Set(((try? vault.list()) ?? []).map(\.id))
        var latest: [UUID: Shared] = [:]
        for entry in sharedLog(vault: vault) where entry.memberKey == member.keyID && items.contains(entry.item) {
            if let existing = latest[entry.item], existing.at >= entry.at { continue }
            latest[entry.item] = entry
        }
        return latest.values.sorted { $0.path.lowercased() < $1.path.lowercased() }
    }
    /// Who got this item and when (latest per member).
    public static func shares(of item: UUID, vault: Vault) -> [Shared] {
        var latest: [String: Shared] = [:]
        for entry in sharedLog(vault: vault) where entry.item == item {
            if let existing = latest[entry.memberKey], existing.at >= entry.at { continue }
            latest[entry.memberKey] = entry
        }
        return latest.values.sorted { $0.member.lowercased() < $1.member.lowercased() }
    }

    /// True when the item's values differ from what was shared in `entry`.
    public static func changedSince(_ entry: Shared, vault: Vault) -> Bool {
        guard let recorded = entry.values, let key = try? valuesKey(vault: vault),
              let current = try? vault.items.secrets(id: entry.item) else { return false }
        return valuesHash(current, key: key) != recorded
    }
    static func valuesKey(vault: Vault) throws -> SymmetricKey {
        if let raw = try vault.teamKeys.read("values-key") { return SymmetricKey(data: raw) }
        let key = SymmetricKey(size: .bits256)
        try vault.teamKeys.write("values-key", key.withUnsafeBytes { Data($0) })
        return key
    }
    static func valuesHash(_ secrets: [String: String], key: SymmetricKey) -> String {
        var data = Data()
        for name in secrets.keys.sorted() { data.append(Data(name.utf8)); data.append(0); data.append(Data(secrets[name]!.utf8)); data.append(0) }
        return Data(HMAC<SHA256>.authenticationCode(for: data, using: key)).base64EncodedString()
    }

    /// Marks the items for rotation, with a reason shown in the list. The mark goes away when a value changes.
    public static func markForRotation(_ ids: [UUID], reason: String, vault: Vault) throws {
        for id in ids {
            guard var meta = try vault.list().first(where: { $0.id == id }) else { continue }
            meta.rotateReason = reason
            try vault.save(meta)
        }
        vault.audit.record("team.rotate", ["items": String(ids.count), "reason": reason])
    }

    // MARK: packages

    public static let fileExtension = "secretariat-share"
    static let maxFileSize = 5 * 1024 * 1024
    static let maxItems = 500
    static let suite = HPKE.Ciphersuite.Curve25519_SHA256_ChachaPoly
    static let info = Data("secretariat-share v1".utf8)

    /// Authenticated in full: it is the associated data of the content and of every wrapped key.
    public struct Header: Codable, Equatable, Sendable {
        public var format = "secretariat-share"
        public var version = 1
        public var created: Date
        /// The sender's chosen name; the app shows the name from its own member list instead when the key is known.
        public var sender: String
        public var senderKey: Data
        public var recipients: [String]
        public var items: Int
    }
    struct Wrap: Codable, Equatable { var recipient: String; var encapsulatedKey: Data; var sealed: Data }
    struct Payload: Codable, Equatable { var items: [Backup.StoredItem] }

    public struct Opened: Sendable {
        public var header: Header
        /// The member with the sender's key, nil for an unknown sender.
        public var sender: Member?
        public var senderKeyID: String { Team.keyID(header.senderKey) }
        public var items: [Backup.StoredItem]
    }

    /// Seals items to the given members. App only; the caller asks for Touch ID before every share.
    public static func package(items: [Backup.StoredItem], to recipients: [Member], vault: Vault, now: Date = Date()) throws -> Data {
        guard !items.isEmpty else { throw SecretariatError("Choose at least one item to share.") }
        guard !recipients.isEmpty else { throw SecretariatError("Choose at least one person to share with.") }
        guard items.count <= maxItems else { throw SecretariatError("A package holds at most \(maxItems) items.") }
        let own = try privateKey(vault: vault)
        let header = Header(created: Date(timeIntervalSince1970: now.timeIntervalSince1970.rounded(.down)), sender: ownName(vault: vault),
                            senderKey: own.publicKey.rawRepresentation, recipients: recipients.map(\.keyID), items: items.count)
        let headerData = try encoder.encode(header)
        let contentKey = SymmetricKey(size: .bits256)
        let content = try ChaChaPoly.seal(try encoder.encode(Payload(items: items)), using: contentKey, authenticating: headerData).combined
        let rawContentKey = contentKey.withUnsafeBytes { Data($0) }
        let wrapAAD = wrapContext(headerData, content)
        var wraps: [Wrap] = []
        for member in recipients {
            let key = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: member.key)
            var sender = try HPKE.Sender(recipientKey: key, ciphersuite: suite, info: info, authenticatedBy: own)
            wraps.append(Wrap(recipient: member.keyID, encapsulatedKey: sender.encapsulatedKey,
                              sealed: try sender.seal(rawContentKey, authenticating: wrapAAD)))
        }
        var file = headerData; file.append(0x0A)
        file.append(try encoder.encode(wraps)); file.append(0x0A)
        file.append(content.base64EncodedData()); file.append(0x0A)
        return file
    }

    /// Call once the package file is written: records who got what (for offboarding) and logs it, names only.
    public static func recordShared(_ items: [Backup.StoredItem], to recipients: [Member], vault: Vault, now: Date = Date()) throws {
        let at = Date(timeIntervalSince1970: now.timeIntervalSince1970.rounded(.down))
        let key = try valuesKey(vault: vault)
        let log = sharedLog(vault: vault) + items.flatMap { item in
            recipients.map { Shared(item: item.meta.id, path: item.meta.path, member: $0.name, memberKey: $0.keyID, at: at,
                                    values: valuesHash(item.secrets, key: key)) }
        }
        try vault.teamKeys.write("shared", try encoder.encode(log))
        vault.audit.record("team.share", ["items": String(items.count), "to": recipients.map(\.name).joined(separator: ", ")])
    }

    /// Opens a package addressed to this user. Throws before anything is decrypted for files too large, damaged
    /// or meant for someone else.
    public static func open(_ data: Data, vault: Vault, managed: ManagedSettings = ManagedSettings()) throws -> Opened {
        guard data.count <= maxFileSize else { throw damaged() }
        let lines = data.split(separator: 0x0A, omittingEmptySubsequences: true)
        guard lines.count == 3 else { throw damaged() }
        let headerData = Data(lines[0])
        guard let header = try? decoder.decode(Header.self, from: headerData), header.format == "secretariat-share",
              (try? validName(header.sender)) == header.sender else { throw damaged() }
        guard header.version == 1 else { throw AgentError("share_version", "This package needs a newer Secretariat.") }
        guard header.items <= maxItems, let wraps = try? decoder.decode([Wrap].self, from: Data(lines[1])),
              let content = Data(base64Encoded: Data(lines[2])),
              let senderKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: header.senderKey) else { throw damaged() }
        let own = try privateKey(vault: vault)
        let ownID = keyID(own.publicKey.rawRepresentation)
        guard header.recipients.contains(ownID), let wrap = wraps.first(where: { $0.recipient == ownID }) else {
            throw AgentError("share_not_for_you", "This package isn't addressed to you. Ask the sender to share it with your code (\(fingerprint(own.publicKey.rawRepresentation))).")
        }
        do {
            var recipient = try HPKE.Recipient(privateKey: own, ciphersuite: suite, info: info, encapsulatedKey: wrap.encapsulatedKey,
                                               authenticatedBy: senderKey)
            // The wrap binds header and ciphertext: a co-recipient knows the content key but can't swap the content.
            let contentKey = SymmetricKey(data: try recipient.open(wrap.sealed, authenticating: wrapContext(headerData, content)))
            let payload = try decoder.decode(Payload.self, from: try ChaChaPoly.open(ChaChaPoly.SealedBox(combined: content), using: contentKey, authenticating: headerData))
            guard payload.items.count == header.items else { throw damaged() }
            let sender = members(vault: vault, managed: managed).first { $0.key == header.senderKey }
            return Opened(header: header, sender: sender, items: payload.items)
        } catch let error as AgentError { throw error } catch { throw damaged() }
    }

    public struct Imported: Equatable, Sendable {
        public var added: [String] = []
        public var skipped: [String] = []
        public var failed: [String] = []
    }

    /// Adds the chosen items. Existing paths (any case) and items already here stay untouched and are listed.
    public static func importItems(_ opened: Opened, only paths: Set<String>? = nil, vault: Vault, now: Date = Date()) throws -> Imported {
        var result = Imported()
        let present = try vault.list()
        let day = ISO8601DateFormatter.string(from: now, timeZone: .current, formatOptions: [.withFullDate])
        let from = opened.sender?.name ?? "\(opened.header.sender) (unknown, \(fingerprint(opened.header.senderKey)))"
        for stored in opened.items where paths?.contains(stored.meta.path) ?? true {
            if present.contains(where: { $0.id == stored.meta.id || $0.path.lowercased() == stored.meta.path.lowercased() }) {
                result.skipped.append(stored.meta.path); continue
            }
            var meta = stored.meta
            meta.source = "Shared by \(from) on \(day)" + (stored.meta.source.isEmpty ? "" : " · \(stored.meta.source)")
            meta.rotateReason = nil
            // Through Vault.save: path, fields, values and dates are checked like any other item; nothing is trusted.
            do { try vault.save(meta, secrets: stored.secrets); result.added.append(meta.path) }
            catch { result.failed.append("\(meta.path): \(error.localizedDescription)") }
        }
        vault.audit.record("team.import", ["from": from, "added": String(result.added.count), "skipped": String(result.skipped.count),
                                           "failed": String(result.failed.count)])
        vault.exportRegistry()
        return result
    }

    static func wrapContext(_ header: Data, _ content: Data) -> Data {
        var data = header; data.append(contentsOf: SHA256.hash(data: content)); return data
    }

    /// Replaces this user's sharing key. Old packages to this user can't be opened any more; others need the new code.
    public static func resetKey(vault: Vault) throws {
        let key = Curve25519.KeyAgreement.PrivateKey()
        try vault.teamKeys.write("private", key.rawRepresentation)
        vault.audit.record("team.key", ["key": keyID(key.publicKey.rawRepresentation), "reset": "yes"])
    }

    static func damaged() -> AgentError { AgentError("share_damaged", "This share package is damaged or was changed. Nothing was imported.") }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; encoder.dateEncodingStrategy = .iso8601; return encoder
    }
    static var decoder: JSONDecoder { let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return decoder }
}

/// Settings an organization pushes with MDM (`com.apple.ManagedClient.preferences`, domain = bundle id dev.moinsen.secretariat.local).
/// Only forced values count: a value the user (or an agent) writes with `defaults write` is ignored.
public struct ManagedSettings: Sendable {
    public static let domain = "dev.moinsen.secretariat.local"
    let values: [String: any Sendable]?
    /// The preferences domain read when no fixture is used; tests point it at a throwaway domain.
    let domain: String

    /// Reads forced values from macOS. A test vault (SECRETARIAT_HOME) may point SECRETARIAT_MANAGED_FIXTURE at a
    /// plist instead; the real vault never reads a fixture.
    public init(paths: AppPaths = AppPaths(), environment: [String: String] = ProcessInfo.processInfo.environment, domain: String = ManagedSettings.domain) {
        self.domain = domain
        if !paths.isDefault, let fixture = environment["SECRETARIAT_MANAGED_FIXTURE"], !fixture.isEmpty {
            let plist = (try? Data(contentsOf: URL(fileURLWithPath: fixture)))
                .flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any] }
            values = plist.map { dict in dict.compactMapValues { ManagedSettings.sendable($0) } } ?? [:]
        } else {
            values = nil
        }
    }
    init(values: [String: any Sendable]) { self.values = values; domain = Self.domain }

    static func sendable(_ value: Any) -> (any Sendable)? {
        if let s = value as? String { return s }
        if let a = value as? [String] { return a }
        return nil
    }

    func value(_ key: String) -> Any? {
        if let values { return values[key] }
        guard CFPreferencesAppValueIsForced(key as CFString, domain as CFString) else { return nil }
        return CFPreferencesCopyAppValue(key as CFString, domain as CFString)
    }

    /// `TeamMembers`: share codes; invalid ones are ignored.
    public func teamMembers() -> [Team.Member] {
        guard let codes = value("TeamMembers") as? [String] else { return [] }
        var seen = Set<Data>()
        return codes.compactMap { code in
            guard let parsed = try? Team.parse(code: code), (try? Team.validName(parsed.name)) == parsed.name,
                  seen.insert(parsed.key).inserted else { return nil }
            return Team.Member(name: parsed.name, key: parsed.key, added: .distantPast, managed: true)
        }
    }
}
