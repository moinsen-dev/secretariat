import CoreGraphics
import CoreML
import Foundation
import ImageIO
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Reads a screenshot on this Mac only, to prefill a new item the user checks and saves.
/// Text recognition (Vision) and the model (Apple Foundation Models) both run on the device; nothing goes over the network.
/// Recognized text, guesses and values stay in memory: nothing here prints, logs or writes them.
public enum ScreenshotReading {
    public enum Method: Sendable, Equatable {
        /// Apple's on-device model sorted the recognized text into kind, provider and fields.
        case localModel
        /// Text recognition plus known key prefixes; the reason says why the model wasn't used.
        case textOnly(String)
    }

    public struct Suggestion: Sendable, Equatable {
        public var template: String
        public var provider: String
        public var label: String
        /// Field name → value, only names of the template.
        public var fields: [String: String]
        public var method: Method
        public init(template: String, provider: String = "", label: String = "", fields: [String: String] = [:], method: Method) {
            self.template = template; self.provider = provider; self.label = label; self.fields = fields; self.method = method
        }
    }

    /// The model's answer before it is checked against the text.
    public struct Guess: Sendable, Equatable {
        public var template: String
        public var provider: String
        public var label: String
        public var fields: [String: String]
        public init(template: String, provider: String = "", label: String = "", fields: [String: String] = [:]) {
            self.template = template; self.provider = provider; self.label = label; self.fields = fields
        }
    }

    /// Set to 1 to read without the model (to try the text-only path on a Mac that has one).
    public static let noModelVariable = "SECRETARIAT_NO_LOCAL_MODEL"

    // MARK: - Whole pipeline

    public static func read(_ image: Data, catalog: TemplateCatalog,
                            environment: [String: String] = ProcessInfo.processInfo.environment) async throws -> Suggestion {
        // Vision's text recognizer waits on Swift tasks of its own; called on a cooperative thread it can starve
        // the pool and hang (seen in the app). It runs on a plain dispatch queue instead.
        let lines = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { continuation.resume(with: Result { try recognizeText(in: image) }) }
        }
        guard !lines.isEmpty else { throw SecretariatError("Secretariat found no text in this screenshot.") }
        let fallback = heuristic(lines, catalog: catalog)
        var reason = "no local model on this Mac"
        if environment[noModelVariable] == "1" {
            reason = "local model turned off"
        } else {
            #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                switch SystemLanguageModel.default.availability {
                case .available:
                    if let guess = try? await ask(lines, catalog: catalog) {
                        let suggestion = ground(guess, in: lines, fallback: fallback, catalog: catalog)
                        if !suggestion.fields.isEmpty { return suggestion }
                        reason = "the local model found no field"
                    } else { reason = "the local model couldn't read it" }
                case .unavailable(.appleIntelligenceNotEnabled): reason = "Apple Intelligence is turned off"
                case .unavailable(.modelNotReady): reason = "the local model is still downloading"
                default: break
                }
            }
            #endif
        }
        guard var suggestion = fallback else {
            throw SecretariatError("Secretariat found text but no key in this screenshot (\(reason)). Create the item by hand.")
        }
        suggestion.method = .textOnly(reason)
        return suggestion
    }

    // MARK: - Text recognition

    /// Lines of text, read with Vision on this Mac. Language correction is off: it would "fix" keys into words.
    public static func recognizeText(in image: Data) throws -> [String] {
        guard let source = CGImageSourceCreateWithData(image as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw SecretariatError("The screenshot can't be read as an image.")
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US", "de-DE"]
        request.automaticallyDetectsLanguage = false
        do { try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request]) }
        catch {
            // The Neural Engine is sometimes busy (e5rt error 13, seen with several recognitions at once): read on the CPU.
            for (stage, devices) in (try? request.supportedComputeStageDevices) ?? [:] {
                if let cpu = devices.first(where: { if case .cpu = $0 { true } else { false } }) { request.setComputeDevice(cpu, for: stage) }
            }
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        }
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Characters text recognition mixes up even without language correction (measured: O read as 0, l as 1, and in
    /// monospaced fonts K as k), plus letters whose small and capital forms differ only in size.
    /// A value containing one of them has to be compared with the screenshot.
    public static func isLookAlike(_ character: Character) -> Bool { "0Oo1lI|cCkKpPsSuUvVwWxXzZ".contains(character) }
    public static func hasLookAlikes(_ value: String) -> Bool { value.contains(where: isLookAlike) }

    // MARK: - Heuristic

    /// Words of the text: split at spaces, quotes and separators, a trailing colon removed.
    static func tokens(_ lines: [String]) -> [String] {
        let separators = CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\"'`,;=()<>[]{}|"))
        return lines.flatMap { $0.components(separatedBy: separators) }
            .map { $0.hasSuffix(":") ? String($0.dropLast()) : $0 }.filter { !$0.isEmpty }
    }

    /// Looks like a key: long, no spaces, letters and digits, no address.
    static func isKeyLike(_ token: String) -> Bool {
        guard token.count >= 20, !token.contains("://"), !token.contains("@") else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.+/="))
        guard token.unicodeScalars.allSatisfy(allowed.contains) else { return false }
        return token.contains(where: \.isLetter) && token.contains(where: \.isNumber)
    }

    /// Without the model: the first token with a known key prefix (provider from the prefix), else the longest
    /// key-like token. Sorted into the API key template; nil when nothing looks like a key.
    public static func heuristic(_ lines: [String], catalog: TemplateCatalog) -> Suggestion? {
        let words = tokens(lines)
        let template = catalog.isKnown("api") ? catalog.template("api") : nil
        guard let secretField = template?.fields.first(where: { $0.kind.isSecret })?.name else { return nil }
        var fields: [String: String] = [:]
        var provider = ""
        if let token = words.first(where: { $0.count >= 12 && $0.contains(where: \.isNumber) && Capture.provider(for: $0) != nil }) {
            fields[secretField] = token; provider = Capture.provider(for: token) ?? ""
        } else if let token = words.filter(isKeyLike).max(by: { $0.count < $1.count }) {
            fields[secretField] = token
        } else { return nil }
        if template?.spec("env_var") != nil,
           let variable = words.first(where: { $0.range(of: #"^[A-Z][A-Z0-9_]*_(API_KEY|KEY|TOKEN|SECRET)$"#, options: .regularExpression) != nil }) {
            fields["env_var"] = variable
        }
        return Suggestion(template: "api", provider: provider, fields: fields, method: .textOnly(""))
    }

    // MARK: - Checking the model's answer

    /// Keeps only what the text backs: a known template, fields of that template whose values appear verbatim
    /// (a secret the model copied with a typo is replaced by the recognized token it starts like), and a provider
    /// or label the text names. A key prefix outranks the model's provider.
    public static func ground(_ guess: Guess, in lines: [String], fallback: Suggestion?, catalog: TemplateCatalog) -> Suggestion {
        let text = lines.joined(separator: "\n")
        let words = tokens(lines)
        let id = guess.template.trimmingCharacters(in: .whitespaces).lowercased()
        let usable = catalog.isKnown(id) && id != Capture.kind
        let template = catalog.template(usable ? id : (fallback?.template ?? "api"))

        var fields: [String: String] = [:]
        for (name, raw) in guess.fields {
            guard let spec = template.spec(name), spec.kind != .file else { continue }
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            if spec.kind.isSecret {
                if let secret = groundSecret(value, words: words) { fields[name] = secret }
            } else if value.count >= 2, namesWord(value, in: text, caseSensitive: true) {
                fields[name] = value
            }
        }
        // A key the model missed but the prefixes found, if the model chose the same kind.
        if let fallback, fallback.template == template.id {
            for (name, key) in fallback.fields where fields[name] == nil && !fields.values.contains(key) { fields[name] = key }
        }

        // Provider and label only when the text names them as a word (a key prefix outranks the model).
        let guessed = guess.provider.trimmingCharacters(in: .whitespaces).lowercased()
        let stem = guessed.split(separator: "-").first.map(String.init) ?? ""
        let provider = fallback.map(\.provider).flatMap { $0.isEmpty ? nil : $0 }
            ?? (stem.count >= 3 && namesWord(stem, in: text, caseSensitive: false) ? guessed : "")
        let label = guess.label.trimmingCharacters(in: .whitespaces)
        let namedLabel = label.count >= 3 && namesWord(label, in: text, caseSensitive: false)
        return Suggestion(template: template.id, provider: provider, label: namedLabel ? label : "",
                          fields: fields, method: .localModel)
    }

    /// A secret is a whole recognized word, or words joined across a line break. A value the model cut short becomes
    /// the one word it starts; a value with a typo becomes the one word with the same first 8 characters. Ambiguous: dropped.
    static func groundSecret(_ value: String, words: [String]) -> String? {
        let compact = value.filter { !$0.isWhitespace }
        guard compact.count >= 8 else { return nil }
        let longer = Set(words.filter { $0.count > compact.count && $0.hasPrefix(compact) })
        if longer.count == 1 { return longer.first }
        if longer.isEmpty, words.contains(compact) || joinsWords(compact, words) { return compact }
        guard longer.isEmpty else { return nil }
        let similar = Set(words.filter { $0.count >= 8 && $0.hasPrefix(String(compact.prefix(8))) })
        return similar.count == 1 ? similar.first : nil
    }

    /// `value` is consecutive words put together (a key wrapped over lines).
    static func joinsWords(_ value: String, _ words: [String]) -> Bool {
        for start in words.indices {
            var joined = ""
            for word in words[start...] {
                joined += word
                if joined == value { return true }
                if !value.hasPrefix(joined) { break }
            }
        }
        return false
    }

    /// `value` stands in the text on its own, not as part of a longer word ("api" in "rapid" doesn't count).
    static func namesWord(_ value: String, in text: String, caseSensitive: Bool) -> Bool {
        let pattern = "(?<![A-Za-z0-9])" + NSRegularExpression.escapedPattern(for: value) + "(?![A-Za-z0-9])"
        return text.range(of: pattern, options: caseSensitive ? .regularExpression : [.regularExpression, .caseInsensitive]) != nil
    }

    // MARK: - Model

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    @Generable struct ModelGuess {
        @Guide(description: "The id of the template that fits best, from the list")
        var template: String
        @Guide(description: "The service the credential belongs to as one lowercase word, e.g. openai, stripe, cloudflare. Empty if the text doesn't say.")
        var provider: String
        @Guide(description: "A project or key name shown in the text, empty if none")
        var label: String
        @Guide(description: "Fields of the chosen template found in the text")
        var fields: [ModelField]
    }

    @available(macOS 26.0, *)
    @Generable struct ModelField {
        @Guide(description: "A field name of the chosen template")
        var name: String
        @Guide(description: "The value, copied character for character from the text")
        var value: String
    }

    /// One fresh session per screenshot, greedy so the same text gives the same answer.
    @available(macOS 26.0, *)
    static func ask(_ lines: [String], catalog: TemplateCatalog) async throws -> Guess {
        let templates = catalog.all.filter { $0.id != Capture.kind && !$0.hidden }.map { template in
            "- \(template.id) (\(template.title)): " + template.fields.map { "\($0.name) = \($0.label)" }.joined(separator: "; ")
        }.joined(separator: "\n")
        let session = LanguageModelSession(instructions: """
            You sort text read from a screenshot into a form for a password manager. Pick the template that fits, \
            name the service, and fill the template's fields only with values that appear in the text. Copy values \
            exactly, character for character. Leave out fields the text doesn't contain. Never invent values.
            Templates:
            \(templates)
            """)
        let text = String(lines.joined(separator: "\n").prefix(6000))
        let response = try await session.respond(to: "Text from the screenshot:\n\(text)", generating: ModelGuess.self,
                                                 options: GenerationOptions(sampling: .greedy))
        let answer = response.content
        return Guess(template: answer.template, provider: answer.provider, label: answer.label,
                     fields: Dictionary(answer.fields.map { ($0.name, $0.value) }, uniquingKeysWith: { first, _ in first }))
    }
    #endif
}
