import CryptoKit
import Foundation

// Inventory of website logins: which ones are local leftovers, reuse a password, are weak, appear in known leaks or
// belong to a domain that no longer exists, and what the user decided for each. Passwords are read once to compute
// facts (hash fingerprints, length) and never kept, printed or written anywhere.

public enum LoginAudit {
    public enum Finding: String, Codable, CaseIterable, Sendable {
        case local, reused, weak, leaked, domainGone
        public var title: String {
            switch self {
            case .local: "Local or IP address"
            case .reused: "Reused password"
            case .weak: "Weak password"
            case .leaked: "In known leaks"
            case .domainGone: "Domain gone"
            }
        }
        public var symbol: String {
            switch self {
            case .local: "wifi.router"
            case .reused: "rectangle.on.rectangle"
            case .weak: "lock.open"
            case .leaked: "exclamationmark.shield"
            case .domainGone: "globe.badge.chevron.backward"
            }
        }
    }

    /// What the user decided; stored in the item's `review` field (an identifier, so no value is touched).
    public enum Decision: String, Codable, CaseIterable, Sendable {
        case keep, close, change
        public var title: String {
            switch self {
            case .keep: "Keep"
            case .close: "Close account"
            case .change: "Change password"
            }
        }
    }
    public static let decisionField = "review"

    /// What is known about a password without keeping it.
    public struct Facts: Sendable, Equatable {
        public let fingerprint: String   // SHA-256, only for comparing within this run
        public let sha1: String          // uppercase hex, for the k-anonymity leak check (first 5 characters leave the Mac)
        public let weak: Bool
        public init(_ password: String) {
            let data = Data(password.utf8)
            fingerprint = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            sha1 = Insecure.SHA1.hash(data: data).map { String(format: "%02X", $0) }.joined()
            let classes = [password.contains(where: \.isLowercase), password.contains(where: \.isUppercase),
                           password.contains(where: \.isNumber), password.contains(where: { !$0.isLetter && !$0.isNumber })].filter { $0 }.count
            weak = password.count < 8 || password.allSatisfy(\.isNumber) || (classes == 1 && password.count < 12)
        }
    }

    public enum HostState: String, Codable, Sendable { case ok, gone, unknown }

    /// Results of the online check, kept on this Mac only (`login-audit.json`, 0600). Leak counts belong to the
    /// password the item had when checked (`rotated`), so a changed password is checked again.
    public struct Online: Codable, Sendable, Equatable {
        public struct Leak: Codable, Sendable, Equatable { public var count: Int; public var rotated: String? }
        public var hosts: [String: HostState] = [:]
        /// Keyed by item id (uuidString), so the file stays a plain JSON object.
        public var leaks: [String: Leak] = [:]
        public var checked: Date?
        public init() {}
    }

    public struct Entry: Identifiable, Sendable {
        public var id: UUID { item.id }
        public let item: ItemMeta
        public let host: String?
        /// Registrable domain ("example.com"), nil for apps and local addresses.
        public let site: String?
        public let origins: [String]
        public let findings: Set<Finding>
        /// Other logins with the same password.
        public let reusedWith: [String]
        public let leakCount: Int?
        public let decision: Decision?
        /// How to close the account, when the deletion directory knows the site.
        public let deletion: AccountDeletion.Guide?
        public var username: String { item.field("username")?.value ?? "" }
        public var address: String { item.field("url")?.value ?? "" }
    }

    // MARK: building

    public static func isLocal(_ host: String) -> Bool {
        let h = host.split(separator: ":").first.map(String.init) ?? host
        if h == "localhost" || h.hasSuffix(".local") || h.hasSuffix(".lan") || h.hasSuffix(".home") || h.hasSuffix(".internal")
            || h.hasSuffix(".fritz.box") || h == "fritz.box" || h.hasSuffix(".localhost") { return true }
        // Any IP address is a device or server (router, NAS, test machine), not an account at a company.
        let labels = h.split(separator: ".", omittingEmptySubsequences: false)
        return labels.count == 4 && labels.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
    }

    static func host(_ item: ItemMeta) -> String? {
        guard let url = item.field("url")?.value else { return nil }
        if let host = LoginFill.host(url) { return host }
        // LoginFill.host keeps ports only for localhost; IP addresses with a port still count as hosts here.
        return URL(string: url.contains("://") ? url : "http://\(url)").flatMap { $0.scheme?.hasPrefix("http") == true ? $0.host?.lowercased() : nil }
    }

    public static func decision(_ item: ItemMeta) -> Decision? { item.field(decisionField)?.value.flatMap(Decision.init(rawValue:)) }

    public static func isLogin(_ item: ItemMeta) -> Bool { item.kind == "login" && item.field("password") != nil }

    /// `facts` holds what is known about each login's password (missing: unreadable or empty).
    public static func entries(_ items: [ItemMeta], facts: [UUID: Facts], online: Online = Online(),
                               guides: AccountDeletion.Directory = AccountDeletion.bundled) -> [Entry] {
        let logins = items.filter(isLogin)
        var byFingerprint: [String: [ItemMeta]] = [:]
        for item in logins { if let f = facts[item.id] { byFingerprint[f.fingerprint, default: []].append(item) } }
        return logins.map { item in
            let host = host(item)
            let local = host.map(isLocal) ?? false
            let site = local ? nil : host.map(LoginFill.site)
            var findings = Set<Finding>()
            if local { findings.insert(.local) }
            var reusedWith: [String] = []
            if let f = facts[item.id] {
                reusedWith = (byFingerprint[f.fingerprint] ?? []).filter { $0.id != item.id }.map(\.path).sorted()
                if !reusedWith.isEmpty { findings.insert(.reused) }
                if f.weak { findings.insert(.weak) }
            }
            var leakCount: Int?
            if let leak = online.leaks[item.id.uuidString], leak.rotated == item.rotated {
                leakCount = leak.count
                if leak.count > 0 { findings.insert(.leaked) }
            }
            if let site, online.hosts[site] == .gone { findings.insert(.domainGone) }
            return Entry(item: item, host: host, site: site, origins: PasswordImport.origins(item), findings: findings,
                         reusedWith: reusedWith, leakCount: leakCount, decision: decision(item),
                         deletion: local ? nil : (LoginRoutes.route(item) ?? guides.guide(host: host)))
        }.sorted { $0.item.path < $1.item.path }
    }

    /// Reads every login's password once and keeps only its facts.
    public static func facts(_ items: [ItemMeta], vault: Vault) -> [UUID: Facts] {
        var result: [UUID: Facts] = [:]
        for item in items where isLogin(item) {
            if let password = try? vault.personalValue(itemID: item.id, field: "password"), !password.isEmpty { result[item.id] = Facts(password) }
        }
        return result
    }

    /// Sets or clears the decision; only the identifier field changes.
    public static func decide(_ item: ItemMeta, _ decision: Decision?, vault: Vault) throws {
        var meta = try vault.item(id: item.id)
        meta.fields.removeAll { $0.name == decisionField }
        if let decision { meta.fields.append(ItemField(name: decisionField, kind: .identifier, value: decision.rawValue)) }
        try vault.save(meta)
        vault.audit.record("inventory.decide", ["item": meta.path, "decision": decision?.rawValue ?? "none"])
    }

    // MARK: places to go

    /// The standard address for changing a password (W3C "well-known change-password").
    public static func changePasswordURL(_ entry: Entry) -> URL? {
        guard let host = entry.host, !(entry.findings.contains(.local)) else { return nil }
        return URL(string: "https://\(host)/.well-known/change-password")
    }
    /// The deletion page from the directory, or else a web search for how to delete the account on that site.
    public static func closeAccountURL(_ entry: Entry) -> URL? {
        if let guide = entry.deletion, let url = guide.url.flatMap(URL.init(string:)) { return url }
        guard let site = entry.site else { return nil }
        var components = URLComponents(string: "https://www.google.com/search")!
        components.queryItems = [URLQueryItem(name: "q", value: "\(site) delete account")]
        return components.url
    }

    // MARK: online check

    /// Online state cache next to the configuration.
    public static func cacheURL(_ paths: AppPaths) -> URL { paths.directory.appendingPathComponent("login-audit.json") }
    public static func loadOnline(_ paths: AppPaths) -> Online {
        guard let data = try? Data(contentsOf: cacheURL(paths)) else { return Online() }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(Online.self, from: data)) ?? Online()
    }
    public static func saveOnline(_ online: Online, paths: AppPaths) throws {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.sortedKeys]
        try FileManager.default.createDirectory(at: paths.directory, withIntermediateDirectories: true)
        let url = cacheURL(paths)
        try encoder.encode(online).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    /// Does the domain still resolve? NXDOMAIN → gone; anything else that fails → unknown (offline, timeout).
    public static func resolve(_ site: String) -> HostState {
        var hints = addrinfo(); hints.ai_socktype = SOCK_STREAM
        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(site, nil, &hints, &result)
        if let result { freeaddrinfo(result) }
        if status == 0 { return .ok }
        return status == EAI_NONAME ? .gone : .unknown
    }

    /// Have I Been Pwned "Pwned Passwords" range query: only the first 5 hex characters of the SHA-1 leave the Mac;
    /// the answer lists suffixes with counts (padded, so its size says nothing). Returns suffix → count.
    public static func pwnedRange(_ prefix: String, session: URLSession = .shared) async throws -> [String: Int] {
        var request = URLRequest(url: URL(string: "https://api.pwnedpasswords.com/range/\(prefix)")!)
        request.setValue("true", forHTTPHeaderField: "Add-Padding")
        request.setValue("Secretariat", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw SecretariatError("The leak check answered with an error.") }
        return parseRange(String(decoding: data, as: UTF8.self))
    }
    static func parseRange(_ text: String) -> [String: Int] {
        var result: [String: Int] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":")
            if parts.count == 2, let count = Int(parts[1].trimmingCharacters(in: .whitespaces)), count > 0 {
                result[parts[0].uppercased()] = count
            }
        }
        return result
    }

    /// Checks domains and leaks for the given logins and merges the result into `online`.
    /// `progress(done, total)` is called from background tasks.
    public static func checkOnline(_ items: [ItemMeta], facts: [UUID: Facts], online: Online,
                                   progress: @escaping @Sendable (Int, Int) -> Void = { _, _ in }) async -> Online {
        let logins = items.filter(isLogin)
        let sites = Set(logins.compactMap { item -> String? in
            guard let host = host(item), !isLocal(host) else { return nil }
            return LoginFill.site(host)
        }).sorted()
        let prefixes = Set(logins.compactMap { facts[$0.id].map { String($0.sha1.prefix(5)) } }).sorted()
        let total = sites.count + prefixes.count
        let counter = Counter()

        var result = online
        await withTaskGroup(of: (String, HostState).self) { group in
            var next = sites.makeIterator()
            func add() -> Bool {
                guard let site = next.next() else { return false }
                group.addTask { let state = resolve(site); progress(counter.increment(), total); return (site, state) }
                return true
            }
            for _ in 0..<16 { if !add() { break } }
            for await (site, state) in group { result.hosts[site] = state; _ = add() }
        }
        var ranges: [String: [String: Int]] = [:]
        await withTaskGroup(of: (String, [String: Int]?).self) { group in
            var next = prefixes.makeIterator()
            func add() -> Bool {
                guard let prefix = next.next() else { return false }
                group.addTask { let range = try? await pwnedRange(prefix); progress(counter.increment(), total); return (prefix, range) }
                return true
            }
            for _ in 0..<8 { if !add() { break } }
            for await (prefix, range) in group { if let range { ranges[prefix] = range }; _ = add() }
        }
        for item in logins {
            guard let f = facts[item.id], let range = ranges[String(f.sha1.prefix(5))] else { continue }
            result.leaks[item.id.uuidString] = Online.Leak(count: range[String(f.sha1.dropFirst(5))] ?? 0, rotated: item.rotated)
        }
        result.checked = Date()
        return result
    }

    final class Counter: @unchecked Sendable {
        private var value = 0
        private let lock = NSLock()
        func increment() -> Int { lock.lock(); defer { lock.unlock() }; value += 1; return value }
    }

    // MARK: summary

    public struct Summary: Encodable, Sendable {
        public var logins = 0
        public var local = 0, reused = 0, weak = 0, leaked = 0, domainGone = 0
        public var keep = 0, close = 0, change = 0, undecided = 0
        /// Logins by how hard closing the account is (directory known); `withoutGuide` for the rest outside local addresses.
        public var easy = 0, medium = 0, hard = 0, impossible = 0, withoutGuide = 0
        public var onlineChecked: Date?
    }
    public static func summary(_ entries: [Entry], online: Online) -> Summary {
        var s = Summary(); s.logins = entries.count; s.onlineChecked = online.checked
        for e in entries {
            if e.findings.contains(.local) { s.local += 1 }
            if e.findings.contains(.reused) { s.reused += 1 }
            if e.findings.contains(.weak) { s.weak += 1 }
            if e.findings.contains(.leaked) { s.leaked += 1 }
            if e.findings.contains(.domainGone) { s.domainGone += 1 }
            switch e.decision { case .keep: s.keep += 1; case .close: s.close += 1; case .change: s.change += 1; case nil: s.undecided += 1 }
            switch e.deletion?.difficulty {
            case .easy: s.easy += 1; case .medium: s.medium += 1; case .hard: s.hard += 1; case .impossible: s.impossible += 1
            case nil: if !e.findings.contains(.local) { s.withoutGuide += 1 }
            }
        }
        return s
    }
}
