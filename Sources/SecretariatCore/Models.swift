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
        case .identifier: "Kennung"
        case .secret: "Geheimnis"
        case .file: "Datei"
        case .personal: "Nur für mich"
        }
    }
    public var isSecret: Bool { self != .identifier }
    /// Usable by programs (run, inject, push).
    public var isUsable: Bool { self != .personal }
}

/// One field an item kind asks for, with a plain-language label.
public struct FieldSpec: Sendable {
    public let name: String
    public let label: String
    public let kind: FieldKind
    public let required: Bool
    public let prompt: String
    /// Variable suffix when the item is made available everywhere (`<ANBIETER>_<suffix>`).
    public let envSuffix: String?
    init(_ name: String, _ label: String, _ kind: FieldKind, required: Bool = false, prompt: String = "", env: String? = nil) {
        self.name = name; self.label = label; self.kind = kind; self.required = required; self.prompt = prompt; envSuffix = env
    }
}

public enum ItemKind: String, Codable, CaseIterable, Sendable {
    case api, token, account, login, certificate, database, server, note

    public var title: String {
        switch self {
        case .api: "API-Schlüssel"
        case .token: "Client-ID und Secret"
        case .account: "Konto"
        case .login: "Website-Anmeldung"
        case .certificate: "Schlüsseldatei"
        case .database: "Datenbank"
        case .server: "Server"
        case .note: "Notiz"
        }
    }
    public var explanation: String {
        switch self {
        case .api: "Ein Schlüssel für einen Dienst wie OpenAI, DeepSeek oder Resend."
        case .token: "Ein Paar aus öffentlicher ID und geheimem Secret, z. B. OAuth oder Cloudflare Access."
        case .account: "Kontodaten wie Login, Team- oder Account-ID; das Passwort bleibt nur für dich."
        case .login: "Zugang zu einer Website. Das Passwort bekommt kein Programm."
        case .certificate: "Eine Datei wie .p8, .p12 oder ein Keystore. Programme bekommen eine temporäre Kopie."
        case .database: "Verbindungsdaten einer Datenbank."
        case .server: "Adresse und Benutzer eines Rechners."
        case .note: "Freier Text nur für dich."
        }
    }
    public var symbol: String {
        switch self {
        case .api: "key.horizontal"
        case .token: "ticket"
        case .account: "building.2"
        case .login: "person.badge.key"
        case .certificate: "doc.badge.gearshape"
        case .database: "cylinder.split.1x2"
        case .server: "server.rack"
        case .note: "note.text"
        }
    }
    /// What this kind asks for, in order. Further fields can be added freely.
    public var fields: [FieldSpec] {
        switch self {
        case .api: [FieldSpec("api_key", "Schlüssel", .secret, required: true, prompt: "sk-…", env: "API_KEY"),
                    FieldSpec("env_var", "Variablenname", .identifier, prompt: "OPENAI_API_KEY")]
        case .token: [FieldSpec("client_id", "Client-ID", .identifier, required: true, env: "CLIENT_ID"),
                      FieldSpec("client_secret", "Client-Secret", .secret, required: true, env: "CLIENT_SECRET")]
        case .account: [FieldSpec("login", "Login oder E-Mail", .identifier, required: true),
                        FieldSpec("account_id", "Account- oder Team-ID", .identifier),
                        FieldSpec("password", "Passwort (nur für dich)", .personal)]
        case .login: [FieldSpec("url", "Adresse", .identifier, prompt: "https://…"),
                      FieldSpec("username", "Benutzername", .identifier, required: true),
                      FieldSpec("password", "Passwort (nur für dich)", .personal, required: true)]
        case .certificate: [FieldSpec("private_key", "Datei", .file, required: true, env: "KEY_PATH"),
                            FieldSpec("key_id", "Key-ID", .identifier, env: "KEY_ID"),
                            FieldSpec("password", "Passwort der Datei", .secret)]
        case .database: [FieldSpec("host", "Host", .identifier, required: true), FieldSpec("port", "Port", .identifier),
                         FieldSpec("user", "Benutzer", .identifier), FieldSpec("password", "Passwort", .secret, required: true),
                         FieldSpec("database", "Datenbank", .identifier)]
        case .server: [FieldSpec("host", "Host oder IP", .identifier, required: true), FieldSpec("user", "Benutzer", .identifier)]
        case .note: [FieldSpec("notes", "Notiz", .personal, required: true)]
        }
    }
    public func spec(_ name: String) -> FieldSpec? { fields.first { $0.name == name } }
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
    public var kind: ItemKind
    public var fields: [ItemField]
    /// yyyy-MM-dd; certificates and tokens that run out.
    public var expires: String?
    /// yyyy-MM-dd of the last value change.
    public var rotated: String?
    /// Where the values came from (console, file, command).
    public var source: String
    public init(id: UUID = UUID(), path: String, kind: ItemKind, fields: [ItemField] = [], expires: String? = nil,
                rotated: String? = nil, source: String = "") {
        self.id = id; self.path = path; self.kind = kind; self.fields = fields
        self.expires = expires; self.rotated = rotated; self.source = source
    }
    public func field(_ name: String) -> ItemField? { fields.first { $0.name == name } }
    /// Org and account part of the path, for grouping ("moinsen/cloudflare").
    public var group: String { path.split(separator: "/").prefix(2).joined(separator: "/") }

    public static let pathPattern = #"^[A-Za-z0-9][A-Za-z0-9._@-]*(/[A-Za-z0-9][A-Za-z0-9._@-]*)*$"#
    public static let fieldPattern = #"^[a-z][a-z0-9_]*$"#

    public func validate() throws {
        guard path.count <= 128, path.range(of: Self.pathPattern, options: .regularExpression) != nil else {
            throw SecretariatError("Pfade bestehen aus Teilen mit Buchstaben, Zahlen, Punkt, @, Bindestrich oder Unterstrich, getrennt durch / (höchstens 128 Zeichen), z. B. moinsen/cloudflare/api-token.")
        }
        guard Set(fields.map(\.name)).count == fields.count else { throw SecretariatError("Jedes Feld darf in einem Eintrag nur einmal vorkommen.") }
        for field in fields {
            guard field.name.range(of: Self.fieldPattern, options: .regularExpression) != nil, field.name.count <= 64 else {
                throw SecretariatError("Feldnamen beginnen mit einem Kleinbuchstaben und enthalten nur Kleinbuchstaben, Zahlen und Unterstriche, z. B. client_id.")
            }
            if field.kind == .identifier {
                guard let value = field.value, !value.isEmpty else { throw SecretariatError("Die Kennung ‚\(field.name)‘ braucht einen Wert.") }
            } else if field.value != nil {
                throw SecretariatError("Geheime Werte gehören nicht in die Beschreibung eines Eintrags.")
            }
        }
        for date in [expires, rotated].compactMap({ $0 }) where date.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) == nil {
            throw SecretariatError("Daten bitte als JJJJ-MM-TT angeben.")
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
            throw AgentError("invalid_reference", "Verweise haben die Form PFAD/FELD, z. B. moinsen/cloudflare/access-routing/client_secret.")
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
            throw SecretariatError("Diese Konfiguration stammt aus einer älteren Version. Bitte einmal die Übernahme auf 1.0 ausführen (script/migrate_v1). Die Datei bleibt erhalten.")
        }
        guard Set(profiles.map(\.id)).count == profiles.count, Set(profiles.map { $0.name.lowercased() }).count == profiles.count,
              Set(targets.map { $0.name.lowercased() }).count == targets.count else {
            throw SecretariatError("Namen oder Kennungen sind doppelt vorhanden. Die Konfiguration bleibt erhalten.")
        }
        for profile in profiles {
            guard profile.name.range(of: Self.namePattern, options: .regularExpression) != nil else {
                throw SecretariatError("Profilnamen beginnen mit einem Buchstaben oder einer Zahl und enthalten nur Buchstaben, Zahlen, Punkt, Bindestrich oder Unterstrich (maximal 64 Zeichen).")
            }
            guard profile.directory.hasPrefix("/") || profile.isAnywhere else { throw SecretariatError("Bitte einen Projektordner auswählen.") }
            try Self.validate(profile.bindings)
        }
        for target in targets {
            guard target.name.range(of: Self.namePattern, options: .regularExpression) != nil else {
                throw SecretariatError("Zielnamen enthalten nur Buchstaben, Zahlen, Punkt, Bindestrich oder Unterstrich.")
            }
            switch target.kind {
            case .command:
                guard target.command.contains("{var}") else { throw SecretariatError("Der Befehl eines Ziels braucht den Platzhalter {var}.") }
            case .envFile:
                guard !target.host.isEmpty, target.path.hasPrefix("/") || target.path.hasPrefix("~/") else {
                    throw SecretariatError("Ein Datei-Ziel braucht Host und absoluten Pfad, z. B. root@hub:/opt/dienst/.env.")
                }
            }
            try Self.validate(target.bindings)
        }
    }

    static func validate(_ bindings: [Binding]) throws {
        guard Set(bindings.map(\.variable)).count == bindings.count, Set(bindings.map(\.id)).count == bindings.count else {
            throw SecretariatError("Jede Umgebungsvariable darf nur einmal vorkommen.")
        }
        for binding in bindings where binding.variable.range(of: variablePattern, options: .regularExpression) == nil {
            throw SecretariatError("Variablennamen dürfen Buchstaben, Zahlen und Unterstriche enthalten und nicht mit einer Zahl beginnen.")
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
