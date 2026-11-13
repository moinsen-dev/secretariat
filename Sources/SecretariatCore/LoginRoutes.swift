import Foundation

// Researched ways to close an account, recorded by an agent (or the user) for a whole site, with the source they came
// from. They live as identifier fields on every login of that site, so they sync like the logins and win over the
// bundled directory. Nothing here touches a password.

public enum LoginRoutes {
    static let urlField = "deletion_url", contactField = "deletion_contact", difficultyField = "deletion_difficulty"
    static let noteField = "deletion_note", sourceField = "deletion_source", checkedField = "deletion_checked"
    static let fields = [urlField, contactField, difficultyField, noteField, sourceField, checkedField]

    /// The researched route stored on a login, if any.
    public static func route(_ item: ItemMeta) -> AccountDeletion.Guide? {
        func value(_ name: String) -> String? { item.field(name)?.value.flatMap { $0.isEmpty ? nil : $0 } }
        guard let source = value(sourceField), let raw = value(difficultyField), let difficulty = AccountDeletion.Difficulty(rawValue: raw),
              value(urlField) != nil || value(contactField) != nil || difficulty == .impossible else { return nil }
        return AccountDeletion.Guide(name: LoginAudit.host(item) ?? item.path, url: value(urlField), difficulty: difficulty, domains: [],
                                     notes: value(noteField), email: value(contactField), source: source, checked: value(checkedField))
    }

    public struct Route: Sendable {
        public var url: String?
        public var contact: String?
        public var difficulty: AccountDeletion.Difficulty
        public var note: String?
        public var source: String
        public init(url: String?, contact: String?, difficulty: AccountDeletion.Difficulty, note: String?, source: String) {
            self.url = url; self.contact = contact; self.difficulty = difficulty; self.note = note; self.source = source
        }

        static func isWebURL(_ text: String) -> Bool {
            guard let url = URL(string: text), let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme), url.host != nil else { return false }
            return !text.contains(where: \.isWhitespace)
        }
        static func isEmail(_ text: String) -> Bool { text.range(of: #"^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$"#, options: .regularExpression) != nil }

        func validate() throws {
            // A service that shut down has neither; its source (and note) is the record.
            guard url != nil || contact != nil || difficulty == .impossible else {
                throw AgentError("invalid_arguments", "Give a deletion page (--url) or a contact (--contact), or both; only 'impossible' may have neither.")
            }
            if let url, !Self.isWebURL(url) { throw AgentError("invalid_arguments", "--url must be an http(s) address.") }
            if let contact, !(Self.isEmail(contact) || Self.isWebURL(contact)) {
                throw AgentError("invalid_arguments", "--contact must be an e-mail address or an http(s) contact form.")
            }
            guard Self.isWebURL(source) else { throw AgentError("invalid_arguments", "--source must be the http(s) page the route was found on.") }
            if let note, note.count > 500 || note.contains(where: { $0.isNewline }) {
                throw AgentError("invalid_arguments", "--note is one line of at most 500 characters.")
            }
        }
    }

    /// Registrable site of a login ("example.com"); nil for local addresses and apps.
    public static func site(_ item: ItemMeta) -> String? {
        guard let host = LoginAudit.host(item), !LoginAudit.isLocal(host) else { return nil }
        return LoginFill.site(host)
    }

    /// Records the route on every login of `site`. Returns the paths changed.
    @discardableResult
    public static func set(_ route: Route, site rawSite: String, vault: Vault, today: String = SecretariatCore.today()) throws -> [String] {
        try route.validate()
        let site = LoginFill.site(LoginFill.host(rawSite) ?? rawSite.lowercased())
        let logins = try vault.list().filter { LoginAudit.isLogin($0) && Self.site($0) == site }
        guard !logins.isEmpty else { throw AgentError("site_not_found", "No website login for \(site). Sites: secretariat login-sites") }
        var changed: [String] = []
        for var item in logins {
            item.fields.removeAll { fields.contains($0.name) }
            let values: [(String, String?)] = [(urlField, route.url), (contactField, route.contact), (difficultyField, route.difficulty.rawValue),
                                               (noteField, route.note), (sourceField, route.source), (checkedField, today)]
            for (name, value) in values { if let value { item.fields.append(ItemField(name: name, kind: .identifier, value: value)) } }
            try item.validate()
            try vault.items.save(item, secrets: nil)
            changed.append(item.path)
        }
        vault.audit.record("inventory.route", ["site": site, "items": String(changed.count), "source": route.source])
        return changed
    }

    // MARK: sites

    /// One site with its logins, as an agent works through them.
    public struct Site: Encodable, Sendable {
        public let site: String
        public let logins: [String]
        public let usernames: [String]
        public let foundIn: [String]
        public let findings: [String]
        public let decisions: [String]
        public let route: RouteInfo?
    }
    public struct RouteInfo: Encodable, Sendable {
        public let url: String?
        public let contact: String?
        public let difficulty: String
        public let note: String?
        /// "JustDeleteMe" for the bundled directory, else the page it was researched on.
        public let source: String
        public let checked: String?
    }

    /// Sites of the given logins, sorted by name; local addresses and apps are left out.
    public static func sites(_ entries: [LoginAudit.Entry]) -> [Site] {
        var groups: [String: [LoginAudit.Entry]] = [:]
        for entry in entries { if let site = entry.site, !entry.findings.contains(.local) { groups[site, default: []].append(entry) } }
        return groups.keys.sorted().map { site in
            let list = groups[site]!
            let guide = list.compactMap(\.deletion).first { $0.isResearched } ?? list.compactMap(\.deletion).first
            return Site(site: site, logins: list.map(\.item.path), usernames: Array(Set(list.map(\.username).filter { !$0.isEmpty })).sorted(),
                        foundIn: Array(Set(list.flatMap(\.origins))).sorted(),
                        findings: Array(Set(list.flatMap { $0.findings.map(\.rawValue) })).sorted(),
                        decisions: Array(Set(list.compactMap { $0.decision?.rawValue })).sorted(),
                        route: guide.map { RouteInfo(url: $0.url, contact: $0.email, difficulty: $0.difficulty.rawValue, note: $0.notes,
                                                     source: $0.source ?? "JustDeleteMe", checked: $0.checked) })
        }
    }
}
