import Foundation

// Logins from a browser's password export (Google Password Manager, Apple Passwords, Firefox, Bitwarden, 1Password)
// become "Website login" items. The CSV holds every password in plain text: it is read once, never changed or copied,
// and nothing here prints a value. Existing logins are never overwritten.

public enum PasswordImport {
    /// One login row of the export.
    public struct Row: Equatable, Sendable {
        public var name: String
        public var url: String
        public var username: String
        public var password: String
        public var note: String
        public init(name: String = "", url: String, username: String, password: String, note: String = "") {
            self.name = name; self.url = url; self.username = username; self.password = password; self.note = note
        }
    }

    /// A login that will become a new item.
    public struct NewLogin: Identifiable, Sendable {
        public var id: UUID { meta.id }
        public let meta: ItemMeta
        public let secrets: [String: String]
        public var username: String { meta.field("username")?.value ?? "" }
    }

    /// What an import would do. Built without touching the vault, so the preview and `--dry-run` show exactly this.
    public struct Plan: Sendable {
        public var new: [NewLogin] = []
        /// Same address, user name and password as an existing item.
        public var alreadyThere: [String] = []
        /// Existing items (among `alreadyThere`) that get this import's origin added to `found_in`; values stay as they are.
        public var tagged: [ItemMeta] = []
        /// Chrome profile or account the export came from ("Chrome: Work"); kept per item in `found_in`.
        public var origin: String?
        /// Same address and user name as an existing item, different password: left alone, the user decides.
        public var differs: [String] = []
        /// Rows repeated in the file (same address, user name and password).
        public var duplicates = 0
        /// Rows without a password (Google exports passkey-only and "never save" entries this way).
        public var withoutPassword = 0
        /// Rows with neither a usable address nor a name.
        public var unusable = 0
        public var rows: Int { new.count + alreadyThere.count + differs.count + duplicates + withoutPassword + unusable }
    }

    // MARK: reading

    /// Column names of the known exports, lowercased.
    static let columns: [String: [String]] = [
        "name": ["name", "title"],
        "url": ["url", "login_uri", "website", "web site", "origin_url"],
        "username": ["username", "login_username", "user name", "login", "email"],
        "password": ["password", "login_password"],
        "note": ["note", "notes", "comment", "comments"]
    ]

    /// Rows of a password export. Throws when the header has no address and password column.
    public static func rows(_ text: String) throws -> [Row] {
        let table = CSV.parse(text)
        guard let header = table.first else { throw SecretariatError("The file is empty.") }
        let names = header.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        func index(_ key: String) -> Int? { columns[key]!.lazy.compactMap { names.firstIndex(of: $0) }.first }
        guard let url = index("url"), let password = index("password") else {
            throw SecretariatError("This is not a password export: the first line needs the columns url and password (Google: name,url,username,password,note).")
        }
        let name = index("name"), username = index("username"), note = index("note")
        func cell(_ row: [String], _ i: Int?) -> String { i.flatMap { $0 < row.count ? row[$0] : nil } ?? "" }
        return table.dropFirst().filter { !($0.count == 1 && $0[0].isEmpty) }.map {
            Row(name: cell($0, name).trimmingCharacters(in: .whitespacesAndNewlines), url: cell($0, url).trimmingCharacters(in: .whitespacesAndNewlines),
                username: cell($0, username).trimmingCharacters(in: .whitespacesAndNewlines), password: cell($0, password),
                note: cell($0, note).trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    // MARK: planning

    /// Where a row's login lives: `web/<host>` for web pages, `app/<package>` for Android apps.
    static func base(_ row: Row) -> (base: String, address: String)? {
        if row.url.lowercased().hasPrefix("android://"), let at = row.url.lastIndex(of: "@") {
            let package = row.url[row.url.index(after: at)...].trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
            let clean = LoginCapture.clean(package)
            if !clean.isEmpty { return ("app/" + clean, row.url) }
        }
        if let host = LoginFill.host(row.url) {
            let address = URL(string: row.url.contains("://") ? row.url : "https://\(row.url)").flatMap(LoginFill.origin) ?? row.url
            let clean = LoginCapture.clean(host.replacingOccurrences(of: ":", with: "-"))
            if !clean.isEmpty { return ("web/" + clean, address) }
        }
        let clean = LoginCapture.clean(row.name.isEmpty ? row.url : row.name)
        return clean.isEmpty ? nil : ("web/" + clean, row.url)
    }

    /// Key that identifies one login: address (host or app) and user name.
    static func key(base: String, username: String) -> String { base.lowercased() + "\u{1}" + username.lowercased() }

    /// Field that names where a login was found (browser profile, account); several origins comma-separated.
    public static let originField = "found_in"

    static func origins(_ item: ItemMeta) -> [String] {
        (item.field(originField)?.value ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Origins to offer for a new import: those used before (newest items first), then the Google accounts whose
    /// sign-in the export holds (usually the profile's own account). The CSV itself does not say which profile it came from.
    public static func originSuggestions(_ rows: [Row], existing: [ItemMeta]) -> [String] {
        var result: [String] = []
        func add(_ value: String) { if !value.isEmpty, !result.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) { result.append(value) } }
        for item in existing.sorted(by: { ($0.rotated ?? "") > ($1.rotated ?? "") }) { origins(item).forEach(add) }
        for row in rows where row.username.contains("@") {
            guard let host = LoginFill.host(row.url), host == "accounts.google.com" || LoginFill.site(host).hasPrefix("google.") else { continue }
            add("Chrome: \(row.username)")
        }
        return result
    }

    /// `existingPassword` reads the stored password of an existing login (nil when unreadable).
    public static func plan(_ rows: [Row], existing: [ItemMeta], source: String, origin: String? = nil,
                            existingPassword: (ItemMeta) -> String?) -> Plan {
        var plan = Plan()
        let origin = origin?.replacingOccurrences(of: ",", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        plan.origin = origin?.isEmpty == false ? origin : nil
        // Existing logins by address and user name.
        var known: [String: ItemMeta] = [:]
        for item in existing where item.field("password") != nil {
            let row = Row(url: item.field("url")?.value ?? "", username: item.field("username")?.value ?? "", password: "")
            if let base = base(row) { known[key(base: base.base, username: row.username)] = item }
        }
        var paths = existing.map(\.path)
        var seen: [String: String] = [:]   // key → password of the first row in the file
        for row in rows {
            guard !row.password.isEmpty else { plan.withoutPassword += 1; continue }
            guard let (base, address) = base(row) else { plan.unusable += 1; continue }
            let k = key(base: base, username: row.username)
            if let first = seen[k] {
                if first == row.password { plan.duplicates += 1; continue }
            }
            if let item = known[k] {
                if existingPassword(item) == row.password {
                    plan.alreadyThere.append(item.path)
                    if let origin = plan.origin, !origins(item).contains(where: { $0.caseInsensitiveCompare(origin) == .orderedSame }),
                       !plan.tagged.contains(where: { $0.id == item.id }) {
                        var tagged = item
                        let value = (origins(item) + [origin]).joined(separator: ", ")
                        if let i = tagged.fields.firstIndex(where: { $0.name == originField }) { tagged.fields[i].value = value }
                        else { tagged.fields.append(ItemField(name: originField, kind: .identifier, value: value)) }
                        plan.tagged.append(tagged)
                    }
                } else { plan.differs.append(item.path) }
                seen[k] = row.password
                continue
            }
            if seen[k] == nil { seen[k] = row.password }
            let path = LoginCapture.path(base: base, username: row.username, existing: paths)
            paths.append(path)
            var fields = [ItemField(name: "url", kind: .identifier, value: address)]
            if !row.username.isEmpty { fields.append(ItemField(name: "username", kind: .identifier, value: row.username)) }
            fields.append(ItemField(name: "password", kind: .personal))
            if let origin = plan.origin { fields.append(ItemField(name: originField, kind: .identifier, value: origin)) }
            var secrets = ["password": row.password]
            if !row.note.isEmpty { fields.append(ItemField(name: "notes", kind: .personal)); secrets["notes"] = row.note }
            var meta = ItemMeta(path: path, kind: "login", fields: fields, rotated: nil, source: source)
            meta.rotated = today()
            plan.new.append(NewLogin(meta: meta, secrets: secrets))
        }
        return plan
    }

    /// Plan against the vault's current items.
    public static func plan(_ rows: [Row], vault: Vault, source: String, origin: String? = nil) throws -> Plan {
        let existing = try vault.list()
        return plan(rows, existing: existing, source: source, origin: origin) { try? vault.personalValue(itemID: $0.id, field: "password") }
    }

    /// Saves the plan's new logins (returned) and the origin of logins already stored, in one pass (one listing, one registry export, one history line), reporting progress.
    /// Stops at the first failure; what was saved until then stays saved and is returned.
    @discardableResult
    public static func apply(_ plan: Plan, vault: Vault, file: String, progress: (Int) -> Void = { _ in }) throws -> [String] {
        let taken = Set(try vault.list().map { $0.path.lowercased() })
        var saved: [String] = [], tagged = 0
        defer {
            if !saved.isEmpty || tagged > 0 {
                var details = ["file": (file as NSString).lastPathComponent, "items": String(saved.count)]
                if let origin = plan.origin { details["from"] = origin }
                if tagged > 0 { details["origin_added"] = String(tagged) }
                vault.audit.record("import.logins", details)
                vault.exportRegistry()
            }
        }
        for login in plan.new {
            try login.meta.validate()
            guard !taken.contains(login.meta.path.lowercased()) else {
                throw AgentError("path_exists", "An item \(login.meta.path) appeared meanwhile. Run the import again.")
            }
            try vault.items.save(login.meta, secrets: login.secrets)
            saved.append(login.meta.path)
            progress(saved.count)
        }
        // Logins already stored: only the origin is added, the values stay untouched.
        for item in plan.tagged {
            try item.validate()
            try vault.items.save(item, secrets: nil)
            tagged += 1
        }
        return saved
    }
}

extension LoginCapture {
    /// `<base>`; taken → `<base>/<user>`; still taken → numbered. Same rule as Save Login, for any base.
    static func path(base: String, username: String, existing: [String]) -> String {
        let taken = Set(existing.map { $0.lowercased() })
        var candidates = [base]
        let user = clean(username)
        if !user.isEmpty { candidates.append("\(base)/\(user)") }
        if let free = candidates.first(where: { !taken.contains($0.lowercased()) }) { return free }
        let last = candidates.last!
        var n = 2
        while taken.contains("\(last)-\(n)".lowercased()) { n += 1 }
        return "\(last)-\(n)"
    }
}

/// RFC 4180: comma separated, fields in double quotes may hold commas, line breaks and "" for a quote. A BOM is dropped.
public enum CSV {
    public static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], field = ""
        var quoted = false, atFieldStart = true
        var chars = Array(text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text)
        chars.append("\n")
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" { field.append("\""); i += 1 } else { quoted = false }
                } else { field.append(c) }
            } else if c == "\"" && atFieldStart {
                quoted = true
            } else if c == "," {
                row.append(field); field = ""; atFieldStart = true; i += 1; continue
            } else if c == "\n" || c == "\r\n" || c == "\r" {
                row.append(field); field = ""
                if !(row.count == 1 && row[0].isEmpty && i == chars.count - 1) { rows.append(row) }
                row = []; atFieldStart = true; i += 1; continue
            } else { field.append(c) }
            atFieldStart = false
            i += 1
        }
        return rows
    }
}
