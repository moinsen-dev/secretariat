import Foundation

public struct SecretariatError: LocalizedError, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public struct SecretReference: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public init(id: UUID = UUID(), name: String) { self.id = id; self.name = name }
}

public struct Binding: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var variable: String
    public var secretID: UUID
    public init(id: UUID = UUID(), variable: String, secretID: UUID) {
        self.id = id; self.variable = variable; self.secretID = secretID
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
}

public struct Configuration: Codable, Equatable, Sendable {
    public var version = 1
    public var revision = 0
    public var secrets: [SecretReference] = []
    public var profiles: [Profile] = []
    public init() {}

    public func validate() throws {
        guard version == 1 else { throw SecretariatError("Diese Konfiguration stammt aus einer anderen Version. Die Datei bleibt erhalten.") }
        guard Set(secrets.map(\.id)).count == secrets.count,
              Set(profiles.map(\.id)).count == profiles.count,
              Set(secrets.map { $0.name.lowercased() }).count == secrets.count,
              Set(profiles.map { $0.name.lowercased() }).count == profiles.count else {
            throw SecretariatError("Namen oder Kennungen sind doppelt vorhanden. Die Konfiguration bleibt erhalten.")
        }
        for secret in secrets {
            guard !secret.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, secret.name.count <= 128 else {
                throw SecretariatError("Bitte einen Schlüsselnamen mit höchstens 128 Zeichen eingeben.")
            }
        }
        let secretIDs = Set(secrets.map(\.id))
        for profile in profiles {
            guard profile.name.range(of: #"^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$"#, options: .regularExpression) != nil else {
                throw SecretariatError("Profilnamen beginnen mit einem Buchstaben oder einer Zahl und enthalten nur Buchstaben, Zahlen, Punkt, Bindestrich oder Unterstrich (maximal 64 Zeichen).")
            }
            guard profile.directory.hasPrefix("/") else { throw SecretariatError("Bitte einen Projektordner auswählen.") }
            guard Set(profile.bindings.map(\.variable)).count == profile.bindings.count,
                  Set(profile.bindings.map(\.id)).count == profile.bindings.count else {
                throw SecretariatError("Jede Umgebungsvariable darf pro Profil nur einmal vorkommen.")
            }
            for binding in profile.bindings {
                guard binding.variable.range(of: #"^[A-Za-z_][A-Za-z0-9_]*$"#, options: .regularExpression) != nil else {
                    throw SecretariatError("Variablennamen dürfen Buchstaben, Zahlen und Unterstriche enthalten und nicht mit einer Zahl beginnen.")
                }
                guard secretIDs.contains(binding.secretID) else { throw SecretariatError("Ein zugeordneter Schlüssel fehlt. Bitte die Profilzuordnung korrigieren.") }
            }
        }
    }
}

public func shellQuote(_ text: String) -> String {
    "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

public func launchCommand(profile: Profile, executable: String = "secretariat") -> String {
    "\(shellQuote(executable)) run \(shellQuote(profile.name)) -- /bin/zsh -c \(shellQuote(profile.command))"
}
