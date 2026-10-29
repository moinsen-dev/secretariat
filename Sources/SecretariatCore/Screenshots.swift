import CryptoKit
import Foundation

/// A screenshot with a note, for the user only: no program, CLI output or agent ever gets it.
/// Image and note are sealed with AES-GCM before they touch the disk; the files sync through the app's
/// private iCloud Drive container, the key through the iCloud keychain (Secretariat's access group only).
public struct Screenshot: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var note: String
    public var created: Date
    public var changed: Date
    /// File name extension of the original image (png, jpg, heic, tiff …).
    public var format: String
    public var byteCount: Int
    public init(id: UUID = UUID(), title: String, note: String, created: Date = Date(), format: String, byteCount: Int) {
        // Whole seconds: the files store ISO 8601 dates, so what was saved compares equal to what is read back.
        let created = Date(timeIntervalSince1970: created.timeIntervalSince1970.rounded(.down))
        self.id = id; self.title = title; self.note = note; self.created = created; self.changed = created
        self.format = format; self.byteCount = byteCount
    }
}

/// Symmetric keys for the screenshots, by key id. Each Mac may create one before iCloud has synced the
/// other's; all of them stay readable because every sealed file names the key it was sealed with.
public protocol ScreenshotKeyring: Sendable {
    func keys() throws -> [String: Data]
    func add(id: String, key: Data) throws
    func removeAll() throws
}

public struct SyncedScreenshotKeyring: ScreenshotKeyring {
    public let service: String
    public let accessGroup: String?
    public init(service: String, accessGroup: String? = SyncedItemStore.accessGroup) {
        self.service = service; self.accessGroup = accessGroup
    }
    private func base() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecUseDataProtectionKeychain as String: true, kSecAttrSynchronizable as String: true,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }
    public func keys() throws -> [String: Data] {
        var query = base()
        query[kSecReturnAttributes as String] = true
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [:] }
        guard status == errSecSuccess else { throw CredentialError.unavailable(status) }
        var keys: [String: Data] = [:]
        for attributes in result as? [[String: Any]] ?? [] {
            if let id = attributes[kSecAttrAccount as String] as? String, let data = attributes[kSecValueData as String] as? Data { keys[id] = data }
        }
        return keys
    }
    public func add(id: String, key: Data) throws {
        var item = base()
        item[kSecAttrAccount as String] = id
        item[kSecAttrLabel as String] = "Secretariat screenshots · key \(id)"
        item[kSecValueData as String] = key
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else { throw CredentialError.unavailable(status) }
    }
    public func removeAll() throws {
        let status = SecItemDelete(base() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CredentialError.unavailable(status) }
    }
}

public final class InMemoryScreenshotKeyring: ScreenshotKeyring, @unchecked Sendable {
    public var values: [String: Data] = [:]
    public init() {}
    public func keys() throws -> [String: Data] { values }
    public func add(id: String, key: Data) throws { values[id] = key }
    public func removeAll() throws { values = [:] }
}

/// Encrypted screenshots in one folder: `<id>.meta` (title, note, dates) and `<id>.image`, both sealed.
/// File names carry only the random id. iCloud may leave a file as placeholder `.<name>.icloud`
/// until it is downloaded; those are counted as pending and their download is requested.
public struct ScreenshotLibrary: Sendable {
    public static let maximumBytes = 25 * 1024 * 1024
    public static let containerIdentifier = "iCloud.dev.moinsen.secretariat"

    public enum Location: Equatable, Sendable {
        /// The app's private iCloud Drive container: syncs to every Mac with the same Apple Account.
        case iCloud
        /// Only on this Mac: no iCloud container (iCloud Drive off, or an unprovisioned build) or a test home.
        case local
    }

    public let directory: URL
    public let location: Location
    public let keyring: any ScreenshotKeyring

    public init(directory: URL, location: Location, keyring: any ScreenshotKeyring) {
        self.directory = directory; self.location = location; self.keyring = keyring
    }

    /// The real home uses the iCloud container when it is available; test homes always stay local and
    /// get their own keychain namespace. Resolving the container can take a moment: call it off the main thread.
    public static func resolve(paths: AppPaths = AppPaths()) -> ScreenshotLibrary {
        let keyring = SyncedScreenshotKeyring(service: paths.screenshotKeyService)
        if paths.isDefault, let container = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) {
            return ScreenshotLibrary(directory: container.appendingPathComponent("Screenshots", isDirectory: true), location: .iCloud, keyring: keyring)
        }
        return ScreenshotLibrary(directory: paths.directory.appendingPathComponent("screenshots", isDirectory: true), location: .local, keyring: keyring)
    }

    // MARK: reading

    public struct Listing: Sendable {
        public var screenshots: [Screenshot]
        /// Files iCloud has not downloaded yet; they appear after the next reload.
        public var pending: Int
        /// Files that are present but can't be opened (key not synced yet, or damaged).
        public var unreadable: Int
    }

    public func list() throws -> Listing {
        guard FileManager.default.fileExists(atPath: directory.path) else { return Listing(screenshots: [], pending: 0, unreadable: 0) }
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        var listing = Listing(screenshots: [], pending: 0, unreadable: 0)
        let keys = try keyring.keys()
        for name in names {
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                // ".<id>.meta.icloud" / ".<id>.image.icloud": not downloaded yet.
                try? FileManager.default.startDownloadingUbiquitousItem(at: directory.appendingPathComponent(name))
                if name.contains(".meta.") { listing.pending += 1 }
                continue
            }
            guard name.hasSuffix(".meta"), UUID(uuidString: String(name.dropLast(5))) != nil else { continue }
            do {
                let data = try open(try Data(contentsOf: directory.appendingPathComponent(name)), keys: keys)
                listing.screenshots.append(try JSONDecoder.screenshots.decode(Screenshot.self, from: data))
            } catch { listing.unreadable += 1 }
        }
        listing.screenshots.sort { $0.created > $1.created }
        return listing
    }

    public func image(_ id: UUID) throws -> Data {
        let url = file(id, "image")
        guard FileManager.default.fileExists(atPath: url.path) else {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            throw SecretariatError("The image is still downloading from iCloud. Try again in a moment.")
        }
        return try open(try Data(contentsOf: url), keys: try keyring.keys())
    }

    // MARK: writing

    @discardableResult
    public func add(image: Data, format: String, title: String, note: String, at date: Date = Date()) throws -> Screenshot {
        guard !image.isEmpty else { throw SecretariatError("The image is empty.") }
        guard image.count <= Self.maximumBytes else { throw SecretariatError("The image is larger than 25 MB.") }
        let format = format.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let shot = Screenshot(title: title.trimmingCharacters(in: .whitespacesAndNewlines), note: note, created: date,
                              format: format.isEmpty ? "png" : format, byteCount: image.count)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let (keyID, key) = try currentKey()
        // Image first: a meta file without its image would list a screenshot that can't be shown.
        try write(seal(image, keyID: keyID, key: key), to: file(shot.id, "image"))
        try write(seal(try JSONEncoder.screenshots.encode(shot), keyID: keyID, key: key), to: file(shot.id, "meta"))
        return shot
    }

    public func update(_ id: UUID, title: String, note: String, at date: Date = Date()) throws -> Screenshot {
        let keys = try keyring.keys()
        var shot = try JSONDecoder.screenshots.decode(Screenshot.self, from: try open(try Data(contentsOf: file(id, "meta")), keys: keys))
        shot.title = title.trimmingCharacters(in: .whitespacesAndNewlines); shot.note = note; shot.changed = Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
        let (keyID, key) = try currentKey()
        try write(seal(try JSONEncoder.screenshots.encode(shot), keyID: keyID, key: key), to: file(id, "meta"))
        return shot
    }

    public func delete(_ id: UUID) throws {
        // Meta first: an orphaned image is invisible, an orphaned meta would show a broken entry.
        for kind in ["meta", "image"] {
            let url = file(id, kind)
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        }
    }

    /// Test homes only: removes every screenshot and the keys, so test runs leave nothing in the synced keychain.
    public func removeEverything() throws {
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
        try keyring.removeAll()
    }

    // MARK: sealing

    /// Sealed file: "SCR1" + 16 hex characters key id + AES-GCM combined box (nonce, ciphertext, tag).
    static let magic = Data("SCR1".utf8)

    func seal(_ plain: Data, keyID: String, key: SymmetricKey) throws -> Data {
        guard let combined = try AES.GCM.seal(plain, using: key).combined else { throw SecretariatError("Encryption failed.") }
        return Self.magic + Data(keyID.utf8) + combined
    }

    func open(_ sealed: Data, keys: [String: Data]) throws -> Data {
        guard sealed.count > 20, sealed.prefix(4) == Self.magic,
              let keyID = String(data: sealed.dropFirst(4).prefix(16), encoding: .utf8) else {
            throw SecretariatError("The screenshot file is damaged.")
        }
        guard let key = keys[keyID] else { throw SecretariatError("The key for this screenshot hasn't arrived from iCloud yet.") }
        return try AES.GCM.open(try AES.GCM.SealedBox(combined: sealed.dropFirst(20)), using: SymmetricKey(data: key))
    }

    /// The key new files are sealed with: the existing one with the smallest id (the same choice on every Mac
    /// once the keychain has synced), or a new random key on first use.
    func currentKey() throws -> (String, SymmetricKey) {
        if let (id, data) = try keyring.keys().min(by: { $0.key < $1.key }) { return (id, SymmetricKey(data: data)) }
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        let id = SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
        try keyring.add(id: id, key: data)
        return (id, key)
    }

    private func file(_ id: UUID, _ kind: String) -> URL { directory.appendingPathComponent("\(id.uuidString).\(kind)") }

    private func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

extension JSONEncoder {
    static var screenshots: JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }
}
extension JSONDecoder {
    static var screenshots: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }
}
