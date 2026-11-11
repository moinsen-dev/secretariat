import ApplicationServices
import Foundation

// Fill a login: the shortcut finds the page behind the focused field, offers the matching items and types the chosen
// password into the field. Values never touch the clipboard; the window shows names, hosts and user names only.

public enum LoginFill {
    /// How well an item fits the page. Lower is better.
    public enum Rank: Int, Comparable, Sendable {
        case sameHost, sameSite, nameMentionsSite, other
        public static func < (a: Rank, b: Rank) -> Bool { a.rawValue < b.rawValue }
    }

    public struct Candidate: Identifiable, Equatable, Sendable {
        public var id: UUID { item.id }
        public let item: ItemMeta
        /// The field whose value gets typed.
        public let field: String
        public let username: String?
        public let host: String?
        public let rank: Rank
    }

    /// Lowercased host of a URL or a bare host name, without `www.`. Nil for file:, about: and the like.
    public static func host(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: withScheme), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              var host = url.host?.lowercased(), host.contains(".") || host == "localhost" else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        // Local services differ only by port: localhost:8765 is not localhost:3000.
        if host == "localhost" || host == "127.0.0.1", let port = url.port { return "\(host):\(port)" }
        return host
    }

    /// `scheme://host[:port]` of a page, kept as the item's address.
    public static func origin(_ url: URL) -> String? {
        guard let scheme = url.scheme, let host = url.host else { return nil }
        return "\(scheme)://\(host)" + (url.port.map { ":\($0)" } ?? "")
    }

    /// The registrable part of a host: "appstoreconnect.apple.com" → "apple.com", "shop.example.co.uk" → "example.co.uk".
    public static func site(_ host: String) -> String {
        let labels = host.split(separator: ".").map(String.init)
        guard labels.count > 2 else { return host }
        let lastTwo = labels.suffix(2).joined(separator: ".")
        let take = twoPartSuffixes.contains(lastTwo) || sharedHosting.contains(lastTwo) ? 3 : 2
        return labels.suffix(take).joined(separator: ".")
    }
    private static let twoPartSuffixes: Set<String> = ["co.uk", "org.uk", "ac.uk", "com.au", "net.au", "co.nz", "co.jp", "com.br", "co.za", "com.tr", "co.at"]
    /// Domains where strangers get their own subdomain (from the private part of the Public Suffix List): two sites there
    /// are never "the same site". Not the whole list; an unknown shared domain only changes the order, never the seal.
    private static let sharedHosting: Set<String> = [
        "github.io", "gitlab.io", "pages.dev", "workers.dev", "vercel.app", "netlify.app", "herokuapp.com", "web.app",
        "firebaseapp.com", "appspot.com", "azurewebsites.net", "cloudfront.net", "blogspot.com", "onrender.com", "fly.dev",
        "ngrok.io", "ngrok.app", "r2.dev", "trycloudflare.com", "ts.net", "cloudflareaccess.com", "glitch.me", "surge.sh", "deno.dev", "wixsite.com", "myshopify.com", "readthedocs.io"]

    /// Only a field named `password` that holds text gets typed; notes, keys and files never do.
    public static func fillableField(_ item: ItemMeta) -> String? {
        item.fields.first { $0.name == "password" && ($0.kind == .personal || $0.kind == .secret) }?.name
    }

    /// A value may be typed only if it has no control characters: a line break or tab would submit the form or move the
    /// rest of the password into the next (possibly visible) field.
    public static func isTypable(_ value: String) -> Bool {
        !value.isEmpty && !value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }

    static func username(_ item: ItemMeta) -> String? {
        for name in ["username", "login", "email", "user"] {
            if let field = item.field(name), field.kind == .identifier, let value = field.value, !value.isEmpty { return value }
        }
        return nil
    }

    /// Host of the address stored with an item (`url`, `website` or any identifier that is a web address).
    static func itemHost(_ item: ItemMeta) -> String? {
        let preferred = ["url", "website", "address"].compactMap { item.field($0) }
        for field in preferred + item.fields where field.kind == .identifier {
            if let value = field.value, preferred.contains(field) || value.contains("://"), let host = host(value) {
                return host
            }
        }
        return nil
    }

    static func rank(_ item: ItemMeta, itemHost: String?, page: String?) -> Rank {
        guard let page else { return .other }
        if let itemHost {
            if itemHost == page { return .sameHost }
            if site(itemHost) == site(page) { return .sameSite }
        }
        // "apple" from apple.com, "lemonsqueezy" from app.lemonsqueezy.com; short labels would match too much.
        let label = String(site(page).split(separator: ".").first ?? "")
        let parts = item.path.lowercased().split(whereSeparator: { "/-_.".contains($0) }).map(String.init)
        if label.count >= 3, parts.contains(label) { return .nameMentionsSite }
        return .other
    }

    /// Items that can fill a field, best fit first. Without a query only the ones that fit the page (all, if none fits);
    /// with a query every item whose path, user name or address contains all its words.
    /// `preferred` (a login just saved) comes first among equally good matches, so its confirm field fills with Enter.
    public static func candidates(_ items: [ItemMeta], page: String?, query: String, preferred: UUID? = nil) -> [Candidate] {
        let pageHost = page.flatMap(host)
        let all = items.compactMap { item -> Candidate? in
            guard let field = fillableField(item) else { return nil }
            let itemHost = itemHost(item)
            return Candidate(item: item, field: field, username: username(item), host: itemHost,
                             rank: rank(item, itemHost: itemHost, page: pageHost))
        }
        let words = query.lowercased().split(separator: " ").map(String.init)
        let chosen: [Candidate]
        if words.isEmpty {
            let fitting = all.filter { $0.rank != .other }
            chosen = fitting.isEmpty ? all : fitting
        } else {
            chosen = all.filter { candidate in
                let haystack = [candidate.item.path, candidate.username ?? "", candidate.host ?? ""].joined(separator: " ").lowercased()
                return words.allSatisfy { haystack.contains($0) }
            }
        }
        func key(_ c: Candidate) -> (Rank, Int, String) { (c.rank, c.item.id == preferred ? 0 : 1, c.item.path.lowercased()) }
        return chosen.sorted { key($0) < key($1) }
    }
}

/// The web page behind the focused element of an app, read through the accessibility API.
public enum FocusedPage {
    public static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that leads to Privacy & Security › Accessibility (once per app).
    public static func requestTrust() {
        // The value of kAXTrustedCheckOptionPrompt (a global var Swift 6 won't touch from here).
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// What has keyboard focus in an app: the page around it (if it is a web page) and whether it is a password field.
    public struct Focus: Equatable, Sendable {
        public let url: URL?
        /// Only password fields get typed into: a password must never land in a chat box or a visible text field.
        public let isPasswordField: Bool
    }

    /// The focused element of the app with this process id and the web area that contains it.
    public static func focus(pid: pid_t) -> Focus {
        let app = AXUIElementCreateApplication(pid)
        // Chromium/Electron build their accessibility tree only when asked; harmless for other apps.
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        for attempt in 0..<3 {
            if let focused = element(app, kAXFocusedUIElementAttribute) {
                let area = webArea(around: focused)
                // Right after the app comes back to the front, Chromium may report the page itself as focused while the
                // password field inside it still holds the focus; then the field carries AXFocused.
                // The fallback applies only when the page itself is reported as focused, never when another field has the focus.
                let pageFocused = string(focused, kAXRoleAttribute) == "AXWebArea"
                let secure = isSecure(focused) || (pageFocused && area.map { focusedSecureField(in: $0.element) } == true)
                if area != nil || secure || attempt == 2 { return Focus(url: area?.url, isPasswordField: secure) }
            }
            if attempt < 2 { Thread.sleep(forTimeInterval: 0.15) }
        }
        return Focus(url: nil, isPasswordField: false)
    }

    /// Number of characters in the focused password field (macOS shows other apps only dots, but as many as there are
    /// characters), or nil when the focus is not in a password field.
    public static func passwordFieldLength(pid: pid_t) -> Int? {
        let app = AXUIElementCreateApplication(pid)
        guard let field = element(app, kAXFocusedUIElementAttribute), isSecure(field) else { return nil }
        // Unknown length is nil, never "empty": then nothing is cleared or typed.
        return (value(field, kAXNumberOfCharactersAttribute) as? Int) ?? string(field, kAXValueAttribute)?.count
    }

    /// Empties the focused password field so the typed value replaces its content: ⌘→ to the end, ⌘⌫ to delete to the
    /// start, then single ⌫ if needed. These keys sit at the same place on every keyboard layout (unlike ⌘A, which is ⌘Q
    /// on AZERTY). True only when the field is verifiably empty afterwards.
    public static func clearPasswordField(pid: pid_t) -> Bool {
        guard var count = passwordFieldLength(pid: pid) else { return false }
        guard count > 0 else { return true }
        Keystrokes.press(0x7C /* → */, flags: .maskCommand, to: pid)
        Keystrokes.press(0x33 /* ⌫ */, flags: .maskCommand, to: pid)
        Thread.sleep(forTimeInterval: 0.08)
        count = passwordFieldLength(pid: pid) ?? -1
        if count > 0 {
            for _ in 0..<min(count, 256) { Keystrokes.press(0x33, flags: [], to: pid) }
            Thread.sleep(forTimeInterval: 0.08)
            count = passwordFieldLength(pid: pid) ?? -1
        }
        return count == 0
    }

    /// What a field is called: placeholder, description, title, help and DOM id/class, joined.
    static func label(of element: AXUIElement) -> String {
        let names = ["AXPlaceholderValue", kAXDescriptionAttribute, kAXTitleAttribute, kAXHelpAttribute, "AXDOMIdentifier"]
        let texts = names.compactMap { string(element, $0) } + ((value(element, "AXDOMClassList") as? [String]) ?? [])
        return texts.joined(separator: " ")
    }

    static func isSecure(_ element: AXUIElement) -> Bool { string(element, kAXSubroleAttribute) == "AXSecureTextField" }

    /// The web area that is or contains the element, with its address.
    static func webArea(around start: AXUIElement) -> (element: AXUIElement, url: URL)? {
        var current: AXUIElement? = start
        for _ in 0..<100 {
            guard let element = current else { return nil }
            if string(element, kAXRoleAttribute) == "AXWebArea", let url = value(element, "AXURL") as? URL,
               url.scheme == "http" || url.scheme == "https" { return (element, url) }
            current = self.element(element, kAXParentAttribute)
        }
        return nil
    }

    /// A password field inside the page that has the focus (bounded walk; pages are small next to this limit).
    static func focusedSecureField(in area: AXUIElement) -> Bool {
        var stack = [area]
        var visited = 0
        while let element = stack.popLast(), visited < 5000 {
            visited += 1
            if isSecure(element), value(element, kAXFocusedAttribute) as? Bool == true { return true }
            if let children = value(element, kAXChildrenAttribute) as? [AXUIElement] { stack.append(contentsOf: children) }
        }
        return false
    }

    static func value(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var result: AnyObject?
        return AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success ? result : nil
    }
    static func string(_ element: AXUIElement, _ name: String) -> String? { value(element, name) as? String }
    static func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let result = value(element, name), CFGetTypeID(result) == AXUIElementGetTypeID() else { return nil }
        return (result as! AXUIElement)
    }
}

/// Types text into the app with this process id, as Unicode key events: no clipboard, independent of the keyboard layout.
/// Stops (returns false) as soon as another app comes to the front, so no part of the value reaches it.
public enum Keystrokes {
    /// One key by its position code (only layout-independent keys such as arrows and delete), down and up, to the app.
    public static func press(_ key: CGKeyCode, flags: CGEventFlags, to pid: pid_t) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for keyDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: keyDown) else { return }
            event.flags = flags
            event.postToPid(pid)
        }
        Thread.sleep(forTimeInterval: 0.005)
    }

    @discardableResult
    public static func type(_ text: String, to pid: pid_t, isFront: () -> Bool) -> Bool {
        let source = CGEventSource(stateID: .combinedSessionState)
        let units = Array(text.utf16)
        var start = 0
        while start < units.count {
            guard isFront() else { return false }
            // Keep surrogate pairs together.
            var end = min(start + 16, units.count)
            if end < units.count, UTF16.isLeadSurrogate(units[end - 1]) { end -= 1 }
            var chunk = Array(units[start..<end])
            for keyDown in [true, false] {
                guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: keyDown) else { return false }
                event.flags = []
                event.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
                event.postToPid(pid)
            }
            start = end
            Thread.sleep(forTimeInterval: 0.01)
        }
        return true
    }
}

/// Strong passwords for new logins: 20 characters from letters, digits and a few symbols most sites accept, without
/// look-alikes (l, I, O, 0, 1), at least one of each kind. Unbiased choice from the system's secure random source.
public enum PasswordGenerator {
    static let lower = Array("abcdefghijkmnopqrstuvwxyz"), upper = Array("ABCDEFGHJKLMNPQRSTUVWXYZ")
    static let digits = Array("23456789"), symbols = Array("-_.!?#%+=")

    public static func make(length: Int = 20, index: (Int) -> Int = secureIndex) -> String {
        let groups = [lower, upper, digits, symbols]
        let all = groups.flatMap { $0 }
        var characters = groups.map { $0[index($0.count)] }
        while characters.count < max(length, groups.count) { characters.append(all[index(all.count)]) }
        // Shuffle so the guaranteed characters don't sit at fixed places.
        for i in stride(from: characters.count - 1, to: 0, by: -1) { characters.swapAt(i, index(i + 1)) }
        return String(characters)
    }

    /// Uniform 0..<bound from SecRandomCopyBytes (rejection sampling, no modulo bias).
    public static func secureIndex(_ bound: Int) -> Int {
        precondition(bound > 0 && bound <= 256)
        let limit = 256 - 256 % bound
        while true {
            var byte: UInt8 = 0
            // Without a secure random source no password may be made at all.
            guard SecRandomCopyBytes(kSecRandomDefault, 1, &byte) == errSecSuccess else { fatalError("No secure random bytes") }
            if Int(byte) < limit { return Int(byte) % bound }
        }
    }
}

/// A new login item from the page the user is on.
public enum LoginCapture {
    /// `web/<host>`; taken → `web/<host>/<user>`; still taken → numbered.
    public static func path(host: String, username: String, existing: [String]) -> String {
        let taken = Set(existing.map { $0.lowercased() })
        let base = "web/" + clean(host)
        var candidates = [base]
        let user = clean(username)
        if !user.isEmpty { candidates.append("\(base)/\(user)") }
        if let free = candidates.first(where: { !taken.contains($0.lowercased()) }) { return free }
        let last = candidates.last!
        var n = 2
        while taken.contains("\(last)-\(n)".lowercased()) { n += 1 }
        return "\(last)-\(n)"
    }

    /// Only the characters item paths allow; anything else becomes a hyphen.
    static func clean(_ text: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._@-")
        let mapped = String(text.trimmingCharacters(in: .whitespaces).unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
        return String(mapped.drop(while: { !$0.isLetter && !$0.isNumber }).prefix(60))
    }

    /// Item of the built-in "Website login" kind; the password goes into the item's encrypted values, not into the meta.
    public static func item(address: String, path: String, username: String) -> ItemMeta {
        let host = LoginFill.host(address) ?? address
        var fields = [ItemField(name: "url", kind: .identifier, value: address)]
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if !user.isEmpty { fields.append(ItemField(name: "username", kind: .identifier, value: user)) }
        fields.append(ItemField(name: "password", kind: .personal))
        return ItemMeta(path: path, kind: "login", fields: fields, source: "Saved from \(host)")
    }

    /// A user name worth keeping as an identifier (agents may read identifiers): an e-mail address, or – only from a field
    /// that is labelled as user name, login or e-mail – 2–100 characters without spaces that contain a letter. Anything else
    /// (codes, keys, numbers, search text, unlabelled fields) is dropped and the user types the name.
    public static func plausibleUsername(_ text: String?, label: String? = nil) -> String? {
        guard let value = text?.trimmingCharacters(in: .whitespacesAndNewlines), (2...100).contains(value.count),
              !value.contains(where: { $0.isWhitespace }), value.contains(where: { $0.isLetter }) else { return nil }
        if value.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]{2,}$"#, options: .regularExpression) != nil { return value }
        let name = (label ?? "").lowercased()
        let labelled = ["user", "login", "e-mail", "email", "benutzer", "account", "konto", "anmeld"].contains { name.contains($0) }
        return labelled ? value : nil
    }
}

extension FocusedPage {
    /// The user name on the page: the focused field if it is a filled text field, else the last filled text field before
    /// the first password field of the page. Never reads a password field (macOS shows those only as bullets anyway).
    public static func username(pid: pid_t) -> String? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        guard let focused = element(app, kAXFocusedUIElementAttribute) else { return nil }
        if string(focused, kAXRoleAttribute) == "AXTextField", !isSecure(focused), let value = string(focused, kAXValueAttribute),
           let user = LoginCapture.plausibleUsername(value, label: label(of: focused)) { return user }
        guard let area = webArea(around: focused)?.element else { return nil }
        var stack = [area], visited = 0, lastText: String?
        while let element = stack.popLast(), visited < 5000 {
            visited += 1
            if string(element, kAXRoleAttribute) == "AXTextField" {
                if isSecure(element) { return lastText }
                if let user = LoginCapture.plausibleUsername(string(element, kAXValueAttribute), label: label(of: element)) { lastText = user }
            }
            // Depth-first in document order: push children reversed.
            if let children = value(element, kAXChildrenAttribute) as? [AXUIElement] { stack.append(contentsOf: children.reversed()) }
        }
        return nil
    }
}
