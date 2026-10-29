import Foundation

/// Clipboard captures: a copied credential lands in the inbox with date and time, to be sorted into a proper item later.
/// The value is a personal field, so no program gets it before it is filed.
public enum Capture {
    public static let folder = "inbox"
    public static let kind = "capture"

    public static func isCapture(_ item: ItemMeta) -> Bool { item.kind == kind }
    /// The name given at capture time ("cloudflare-pulse"), empty if none.
    public static func name(of item: ItemMeta) -> String {
        let last = item.path.split(separator: "/").last.map(String.init) ?? ""
        return last.replacingOccurrences(of: #"-?\d{4}-\d{2}-\d{2}-\d{4}(-\d+)?$"#, with: "", options: .regularExpression)
    }
    /// "2026-10-29 14:32" from the source line.
    public static func capturedAt(_ item: ItemMeta) -> String? {
        item.source.range(of: #"\d{4}-\d{2}-\d{2} \d{2}:\d{2}"#, options: .regularExpression).map { String(item.source[$0]) }
    }

    /// inbox/<name>-2026-10-29-1432, or inbox/2026-10-29-1432 without a name.
    public static func path(name: String, at date: Date) -> String {
        let slug = name.lowercased().replacingOccurrences(of: #"[^a-z0-9._@-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-."))
        let stamp = format("yyyy-MM-dd-HHmm", date)
        return "\(folder)/" + (slug.isEmpty ? stamp : "\(String(slug.prefix(80)))-\(stamp)")
    }

    @discardableResult
    public static func save(_ value: String, name: String, at date: Date = Date(), vault: Vault) throws -> ItemMeta {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw SecretariatError("The clipboard holds no text.") }
        guard value.utf8.count <= 64 * 1024 else { throw SecretariatError("The clipboard text is too long for a credential (more than 64 KB).") }
        var path = path(name: name, at: date)
        // Two captures in the same minute with the same name get a counter.
        let taken = Set(try vault.items.list().map { $0.path.lowercased() })
        var counter = 2
        while taken.contains(path.lowercased()) { path = self.path(name: name, at: date) + "-\(counter)"; counter += 1 }
        let meta = ItemMeta(path: path, kind: kind, fields: [ItemField(name: "value", kind: .personal)],
                            rotated: format("yyyy-MM-dd", date), source: "Clipboard · \(format("yyyy-MM-dd HH:mm", date))")
        try vault.save(meta, secrets: ["value": value])
        return meta
    }

    /// What the capture panel shows instead of the value: "sk-a… · 51 characters".
    public static func preview(_ value: String) -> String {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = value.split(whereSeparator: \.isNewline).count
        let head = value.count > 12 ? String(value.prefix(4)) + "…" : String(repeating: "•", count: min(value.count, 8))
        return "\(head) · \(value.count) characters" + (lines > 1 ? " · \(lines) lines" : "")
    }

    /// Provider guessed from well-known key prefixes, to prefill filing ("anthropic" for sk-ant-…).
    public static func provider(for value: String) -> String? {
        let prefixes: [(String, String)] = [
            ("sk-ant-", "anthropic"), ("sk-or-", "openrouter"), ("sk-proj-", "openai"), ("sk-", "openai"),
            ("ghp_", "github"), ("github_pat_", "github"), ("gho_", "github"), ("re_", "resend"),
            ("sk_live_", "stripe"), ("sk_test_", "stripe"), ("rk_live_", "stripe"), ("gsk_", "groq"),
            ("AIza", "google-gemini"), ("hf_", "huggingface"), ("xai-", "xai"), ("tvly-", "tavily"), ("expo_", "expo")]
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return prefixes.first { value.hasPrefix($0.0) }?.1
    }

    private static func format(_ pattern: String, _ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = pattern
        return f.string(from: date)
    }
}
