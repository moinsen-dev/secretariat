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
        return host
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
        "ngrok.io", "ngrok.app", "glitch.me", "surge.sh", "deno.dev", "wixsite.com", "myshopify.com", "readthedocs.io"]

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
            if let value = field.value, value.contains("."), let host = host(value), preferred.contains(field) || value.contains("://") {
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
    public static func candidates(_ items: [ItemMeta], page: String?, query: String) -> [Candidate] {
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
        return chosen.sorted { ($0.rank, $0.item.path.lowercased()) < ($1.rank, $1.item.path.lowercased()) }
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
