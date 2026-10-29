import Foundation

public struct SecretariatError: LocalizedError, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

// MARK: - Items

/// How a field may be used. The one question: does the value alone let someone do something?
public enum FieldKind: String, Codable, CaseIterable, Sendable {
    /// Not secret (team id, login e-mail, account id). Readable by everyone, exported to the registry.
    case identifier
    /// Secret text (API key, token, client secret). Reaches programs only through run/inject/push.
    case secret
    /// Secret file (.p8, .p12, keystore). Programs get a temporary file path.
    case file
    /// Only for the human (account password, recovery codes). Never leaves the app.
    case personal

    public var title: String {
        switch self {
        case .identifier: "Identifier"
        case .secret: "Secret"
        case .file: "File"
        case .personal: "Only for me"
        }
    }
    public var isSecret: Bool { self != .identifier }
    /// Usable by programs (run, inject, push).
    public var isUsable: Bool { self != .personal }
}

/// One field a template asks for, with a plain-language label.
public struct FieldSpec: Codable, Equatable, Identifiable, Sendable {
    public var id: String { name }
    public var name: String
    public var label: String
    public var kind: FieldKind
    public var required: Bool
    public var prompt: String
    /// Variable suffix when the item is made available everywhere (`<PROVIDER>_<suffix>`).
    public var envSuffix: String?
    public init(_ name: String, _ label: String, _ kind: FieldKind, required: Bool = false, prompt: String = "", env: String? = nil) {
        self.name = name; self.label = label; self.kind = kind; self.required = required; self.prompt = prompt; envSuffix = env
    }
}

/// What a kind of item asks for. Templates are data: the built-in ones are only the starting set; the user
/// adds, changes, hides and resets them, and they sync to every Mac like items do. An item stores the
/// template id as its `kind`; an unknown id shows the item with plain field names.
public struct Template: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var symbol: String
    public var explanation: String
    public var fields: [FieldSpec]
    /// Items of this template describe who Uli works as and go into ~/.claude/rules/company.md.
    public var identity: Bool
    /// A built-in template the user removed (kept as a marker so it stays removed on every Mac).
    public var hidden: Bool
    public init(id: String, title: String, symbol: String = "square.dashed", explanation: String = "", fields: [FieldSpec] = [],
                identity: Bool = false, hidden: Bool = false) {
        self.id = id; self.title = title; self.symbol = symbol; self.explanation = explanation
        self.fields = fields; self.identity = identity; self.hidden = hidden
    }
    public func spec(_ name: String) -> FieldSpec? { fields.first { $0.name == name } }
    public var isBuiltin: Bool { Template.builtins.contains { $0.id == id } }

    public static let idPattern = #"^[a-z][a-z0-9-]{0,31}$"#
    public func validate() throws {
        guard id.range(of: Self.idPattern, options: .regularExpression) != nil else {
            throw SecretariatError("Template IDs start with a lowercase letter and contain only lowercase letters, digits and dashes (max. 32), e.g. bank-account.")
        }
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { throw SecretariatError("A template needs a title.") }
        guard Set(fields.map(\.name)).count == fields.count else { throw SecretariatError("Each field may appear only once in a template.") }
        for field in fields {
            guard field.name.range(of: ItemMeta.fieldPattern, options: .regularExpression) != nil, field.name.count <= 64 else {
                throw SecretariatError("Field names start with a lowercase letter and contain only lowercase letters, digits and underscores, e.g. iban.")
            }
            guard !field.label.trimmingCharacters(in: .whitespaces).isEmpty else { throw SecretariatError("The field '\(field.name)' needs a label.") }
        }
    }
    /// Stand-in for an item whose template is unknown here (deleted, or made on another Mac with a newer version).
    public static func generic(_ id: String) -> Template { Template(id: id, title: id, symbol: "square.dashed") }

    public static let builtins: [Template] = [
        Template(id: "company", title: "Company", symbol: "building.columns", explanation: "Who you work as: imprint, legal texts, sender details. Every agent session knows these.",
                 fields: [FieldSpec("legal_name", "Company name", .identifier, required: true, prompt: "moinsen GmbH"),
                        FieldSpec("legal_form", "Legal form", .identifier, prompt: "GmbH, UG, sole proprietor …"),
                        FieldSpec("represented_by", "Owner / managing director", .identifier, required: true),
                        FieldSpec("street", "Street and number", .identifier, required: true),
                        FieldSpec("postal_code", "Postal code", .identifier, required: true),
                        FieldSpec("city", "City", .identifier, required: true),
                        FieldSpec("country", "Country", .identifier, prompt: "Germany"),
                        FieldSpec("email", "Email", .identifier, required: true),
                        FieldSpec("phone", "Phone", .identifier),
                        FieldSpec("website", "Website", .identifier, prompt: "https://…"),
                        FieldSpec("vat_id", "VAT ID", .identifier, prompt: "DE…"),
                        FieldSpec("register", "Commercial register", .identifier, prompt: "Amtsgericht …, HRB …"),
                        FieldSpec("privacy_contact", "Privacy contact", .identifier, prompt: "privacy@…")], identity: true),
        Template(id: "api", title: "API key", symbol: "key.horizontal", explanation: "A key for a service like OpenAI, DeepSeek or Resend.",
                 fields: [FieldSpec("api_key", "Key", .secret, required: true, prompt: "sk-…", env: "API_KEY"),
                    FieldSpec("env_var", "Variable name", .identifier, prompt: "OPENAI_API_KEY")]),
        Template(id: "token", title: "Client ID & secret", symbol: "ticket", explanation: "A public ID paired with a secret, e.g. for OAuth or Cloudflare Access.",
                 fields: [FieldSpec("client_id", "Client ID", .identifier, required: true, env: "CLIENT_ID"),
                      FieldSpec("client_secret", "Client secret", .secret, required: true, env: "CLIENT_SECRET")]),
        Template(id: "account", title: "Account", symbol: "building.2", explanation: "Account details like login, team or account ID. The password stays only for you.",
                 fields: [FieldSpec("login", "Login or email", .identifier, required: true),
                        FieldSpec("account_id", "Account or team ID", .identifier),
                        FieldSpec("password", "Password (only for you)", .personal)]),
        Template(id: "login", title: "Website login", symbol: "person.badge.key", explanation: "Access to a website. No program ever gets the password.",
                 fields: [FieldSpec("url", "Address", .identifier, prompt: "https://…"),
                      FieldSpec("username", "Username", .identifier, required: true),
                      FieldSpec("password", "Password (only for you)", .personal, required: true)]),
        Template(id: "certificate", title: "Key file", symbol: "doc.badge.gearshape", explanation: "A file like .p8, .p12 or a keystore. Programs get a temporary copy.",
                 fields: [FieldSpec("private_key", "File", .file, required: true, env: "KEY_PATH"),
                            FieldSpec("key_id", "Key ID", .identifier, env: "KEY_ID"),
                            FieldSpec("password", "File password", .secret)]),
        Template(id: "database", title: "Database", symbol: "cylinder.split.1x2", explanation: "Connection details for a database.",
                 fields: [FieldSpec("host", "Host", .identifier, required: true), FieldSpec("port", "Port", .identifier),
                         FieldSpec("user", "User", .identifier), FieldSpec("password", "Password", .secret, required: true),
                         FieldSpec("database", "Database", .identifier)]),
        Template(id: "server", title: "Server", symbol: "server.rack", explanation: "Address and user of a machine.",
                 fields: [FieldSpec("host", "Host or IP", .identifier, required: true), FieldSpec("user", "User", .identifier)]),
        Template(id: "note", title: "Note", symbol: "note.text", explanation: "Free text, only for you.",
                 fields: [FieldSpec("notes", "Note", .personal, required: true)]),
        Template(id: "capture", title: "Clipboard capture", symbol: "doc.on.clipboard",
                 explanation: "Something you copied, kept with date and time. Turn it into a proper item later; until then no program gets it.",
                 fields: [FieldSpec("value", "Copied value", .personal, required: true)])
    ]
}

/// The templates in effect: built-ins, overridden or hidden by stored ones, plus the user's own.
public struct TemplateCatalog: Sendable {
    public let stored: [Template]
    public init(stored: [Template]) { self.stored = stored }
    public var all: [Template] {
        let overrides = Dictionary(stored.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let builtins = Template.builtins.map { overrides[$0.id] ?? $0 }
        let own = stored.filter { s in !Template.builtins.contains { $0.id == s.id } }.sorted { $0.title < $1.title }
        return (builtins + own).filter { !$0.hidden }
    }
    public func template(_ id: String) -> Template { all.first { $0.id == id } ?? Template.generic(id) }
    public func isKnown(_ id: String) -> Bool { all.contains { $0.id == id } }
    public static let builtin = TemplateCatalog(stored: [])
}

public struct ItemField: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: FieldKind
    /// Only identifiers keep their value here; secret values live in the item's encrypted payload.
    public var value: String?
    /// Original file name of a file field.
    public var fileName: String?
    public init(id: UUID = UUID(), name: String, kind: FieldKind, value: String? = nil, fileName: String? = nil) {
        self.id = id; self.name = name; self.kind = kind; self.value = value; self.fileName = fileName
    }
}

/// Everything about an item except secret values. Travels as a keychain attribute, so listing items
/// never reads a secret.
public struct ItemMeta: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var path: String
    public var kind: String
    public var fields: [ItemField]
    /// yyyy-MM-dd; certificates and tokens that run out.
    public var expires: String?
    /// yyyy-MM-dd of the last value change.
    public var rotated: String?
    /// Where the values came from (console, file, command).
    public var source: String
    /// Agent Guard: a program may use this item's values only after Uli confirms with Touch ID (or the Mac password).
    /// Agents can switch it on, never off.
    public var approval: Bool?
    public var needsApproval: Bool { approval == true }
    public init(id: UUID = UUID(), path: String, kind: String, fields: [ItemField] = [], expires: String? = nil,
                rotated: String? = nil, source: String = "", approval: Bool? = nil) {
        self.id = id; self.path = path; self.kind = kind; self.fields = fields
        self.expires = expires; self.rotated = rotated; self.source = source; self.approval = approval
    }
    public func field(_ name: String) -> ItemField? { fields.first { $0.name == name } }
    /// Org and account part of the path, for grouping ("moinsen/cloudflare").
    public var group: String { path.split(separator: "/").prefix(2).joined(separator: "/") }

    public static let pathPattern = #"^[A-Za-z0-9][A-Za-z0-9._@-]*(/[A-Za-z0-9][A-Za-z0-9._@-]*)*$"#
    public static let fieldPattern = #"^[a-z][a-z0-9_]*$"#

    public func validate() throws {
        guard path.count <= 128, path.range(of: Self.pathPattern, options: .regularExpression) != nil else {
            throw SecretariatError("Paths consist of parts made of letters, digits, dot, @, hyphen or underscore, separated by / (at most 128 characters), e.g. moinsen/cloudflare/api-token.")
        }
        guard Set(fields.map(\.name)).count == fields.count else { throw SecretariatError("Each field may appear only once in an item.") }
        for field in fields {
            guard field.name.range(of: Self.fieldPattern, options: .regularExpression) != nil, field.name.count <= 64 else {
                throw SecretariatError("Field names start with a lowercase letter and contain only lowercase letters, digits and underscores, e.g. client_id.")
            }
            if field.kind == .identifier {
                guard let value = field.value, !value.isEmpty else { throw SecretariatError("The identifier '\(field.name)' needs a value.") }
            } else if field.value != nil {
                throw SecretariatError("Secret values don't belong in an item's description.")
            }
        }
        for date in [expires, rotated].compactMap({ $0 }) where date.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) == nil {
            throw SecretariatError("Please enter dates as YYYY-MM-DD.")
        }
    }
}

/// `path/field` — the last segment names the field.
public struct FieldReference: Equatable, Hashable, Sendable, CustomStringConvertible {
    public let path: String
    public let field: String
    public init(path: String, field: String) { self.path = path; self.field = field }
    public init(_ text: String) throws {
        guard let slash = text.lastIndex(of: "/"), slash != text.startIndex, text.index(after: slash) != text.endIndex else {
            throw AgentError("invalid_reference", "References have the form PATH/FIELD, e.g. moinsen/cloudflare/access-routing/client_secret.")
        }
        path = String(text[..<slash]); field = String(text[text.index(after: slash)...])
    }
    public var description: String { "\(path)/\(field)" }
}

// MARK: - Profiles and targets (per Mac)

/// Environment variable → item field. A file field yields the path of a temporary file.
public struct Binding: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var variable: String
    public var itemID: UUID
    public var field: String
    public init(id: UUID = UUID(), variable: String, itemID: UUID, field: String) {
        self.id = id; self.variable = variable; self.itemID = itemID; self.field = field
    }
}

public struct Profile: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var directory: String
    public var command: String
    public var bindings: [Binding]
    public init(id: UUID = UUID(), name: String = "", directory: String = "", command: String = "", bindings: [Binding] = []) {
        self.id = id; self.name = name; self.directory = directory; self.command = command; self.bindings = bindings
    }
    /// Directory "*": not tied to a project — `run` starts in the caller's current folder (tool tokens).
    public static let anywhere = "*"
    public var isAnywhere: Bool { directory == Self.anywhere }
}

/// A place outside the Macs that holds copies of values: a Cloudflare Worker, Supabase, GitHub, a Linux host.
public struct Target: Codable, Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case command, envFile }
    public var id: UUID
    public var name: String
    public var kind: Kind
    /// command: run once per variable with the value on stdin; `{var}` is replaced by the variable name.
    public var command: String
    /// command: working directory.
    public var directory: String
    /// envFile: ssh destination and file path; the whole file is written (0600).
    public var host: String
    public var path: String
    public var bindings: [Binding]
    /// variable → fingerprint of the value last pushed (salted SHA-256, never the value).
    public var pushed: [String: String]
    public var pushedAt: String?
    public init(id: UUID = UUID(), name: String, kind: Kind, command: String = "", directory: String = "", host: String = "",
                path: String = "", bindings: [Binding] = [], pushed: [String: String] = [:], pushedAt: String? = nil) {
        self.id = id; self.name = name; self.kind = kind; self.command = command; self.directory = directory
        self.host = host; self.path = path; self.bindings = bindings; self.pushed = pushed; self.pushedAt = pushedAt
    }
}

public struct Configuration: Codable, Equatable, Sendable {
    public var version = 2
    public var revision = 0
    public var profiles: [Profile] = []
    public var targets: [Target] = []
    /// Random per Mac; salts target fingerprints.
    public var salt = UUID().uuidString
    public init() {}

    static let namePattern = #"^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$"#
    static let variablePattern = #"^[A-Za-z_][A-Za-z0-9_]*$"#

    public func validate() throws {
        guard version == 2 else {
            throw SecretariatError("This configuration comes from an older version. Run the 1.0 migration once (script/migrate_v1). The file is kept.")
        }
        guard Set(profiles.map(\.id)).count == profiles.count, Set(profiles.map { $0.name.lowercased() }).count == profiles.count,
              Set(targets.map { $0.name.lowercased() }).count == targets.count else {
            throw SecretariatError("Some names or identifiers appear twice. The configuration is kept.")
        }
        for profile in profiles {
            guard profile.name.range(of: Self.namePattern, options: .regularExpression) != nil else {
                throw SecretariatError("Profile names start with a letter or digit and contain only letters, digits, dot, hyphen or underscore (at most 64 characters).")
            }
            guard profile.directory.hasPrefix("/") || profile.isAnywhere else { throw SecretariatError("Please choose a project folder.") }
            try Self.validate(profile.bindings)
        }
        for target in targets {
            guard target.name.range(of: Self.namePattern, options: .regularExpression) != nil else {
                throw SecretariatError("Target names contain only letters, digits, dot, hyphen or underscore.")
            }
            switch target.kind {
            case .command:
                guard target.command.contains("{var}") else { throw SecretariatError("A target's command needs the placeholder {var}.") }
            case .envFile:
                guard !target.host.isEmpty, target.path.hasPrefix("/") || target.path.hasPrefix("~/") else {
                    throw SecretariatError("A file target needs a host and an absolute path, e.g. root@hub:/opt/service/.env.")
                }
            }
            try Self.validate(target.bindings)
        }
    }

    static func validate(_ bindings: [Binding]) throws {
        guard Set(bindings.map(\.variable)).count == bindings.count, Set(bindings.map(\.id)).count == bindings.count else {
            throw SecretariatError("Each environment variable may appear only once.")
        }
        for binding in bindings where binding.variable.range(of: variablePattern, options: .regularExpression) == nil {
            throw SecretariatError("Variable names may contain letters, digits and underscores and must not start with a digit.")
        }
    }
}

public func shellQuote(_ text: String) -> String {
    "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

public func launchCommand(profile: Profile, executable: String = "secretariat") -> String {
    "\(shellQuote(executable)) run \(shellQuote(profile.name)) -- /bin/zsh -c \(shellQuote(profile.command))"
}

public func today() -> String {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
}
