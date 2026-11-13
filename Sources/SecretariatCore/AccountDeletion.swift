import Foundation

// How to close an account on a site: direct link to the deletion page, how hard it is, notes and a contact address.
// The guides come from JustDeleteMe (MIT, bundled with its license); a site without a guide gets a web search instead.

public enum AccountDeletion {
    public enum Difficulty: String, Codable, CaseIterable, Sendable, Comparable {
        case easy, medium, hard, impossible
        public var title: String {
            switch self {
            case .easy: "Easy to close"
            case .medium: "Close with extra steps"
            case .hard: "Close via support"
            case .impossible: "Can't be closed"
            }
        }
        public var explanation: String {
            switch self {
            case .easy: "The site has a simple “delete account” button."
            case .medium: "Deleting works, with some extra steps."
            case .hard: "You have to contact support to delete the account."
            case .impossible: "The site doesn't really delete accounts, even on request. Change the password and remove your data instead."
            }
        }
        var rank: Int { Self.allCases.firstIndex(of: self)! }
        public static func < (a: Self, b: Self) -> Bool { a.rank < b.rank }
    }

    public struct Guide: Codable, Equatable, Sendable {
        public let name: String
        /// Deletion page (or help page); nil when only a contact is known.
        public let url: String?
        public let difficulty: Difficulty
        public let domains: [String]
        public let notes: String?
        /// E-mail address (or contact form URL) for a deletion request.
        public let email: String?
        /// Where a researched route was found (a URL); nil for the bundled directory.
        public var source: String? = nil
        /// yyyy-MM-dd when a researched route was recorded.
        public var checked: String? = nil
        public var isResearched: Bool { source != nil }
        public init(name: String, url: String?, difficulty: Difficulty, domains: [String], notes: String?, email: String?,
                    source: String? = nil, checked: String? = nil) {
            self.name = name; self.url = url; self.difficulty = difficulty; self.domains = domains; self.notes = notes; self.email = email
            self.source = source; self.checked = checked
        }
    }

    public struct Directory: Sendable {
        public let source: String
        let bySite: [String: Guide]
        let byHost: [String: Guide]
        public let count: Int

        public init(guides: [Guide], source: String = "") {
            var bySite: [String: Guide] = [:], byHost: [String: Guide] = [:]
            for guide in guides {
                var hosts = guide.domains
                if let url = guide.url, let host = LoginFill.host(url) { hosts.append(host) }
                for host in hosts {
                    let h = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
                    if byHost[h] == nil { byHost[h] = guide }
                    let site = LoginFill.site(h)
                    // A guide found through its own domains wins over one that only links there (e.g. a help center).
                    if bySite[site] == nil || guide.domains.contains(where: { LoginFill.site($0) == site }) && !(bySite[site]!.domains.contains { LoginFill.site($0) == site }) {
                        bySite[site] = guide
                    }
                }
            }
            self.bySite = bySite; self.byHost = byHost; self.source = source; count = guides.count
        }

        /// Guide for a login's host: exact host first, then the registrable site.
        public func guide(host: String?) -> Guide? {
            guard let host, !host.isEmpty else { return nil }
            return byHost[host] ?? bySite[LoginFill.site(host)]
        }
    }

    struct File: Codable { let source: String; let sites: [Guide] }

    /// The bundled directory (empty when the resource is missing, e.g. in a stripped build).
    public static let bundled: Directory = {
        guard let url = Bundle.module.url(forResource: "deletion-sites", withExtension: "json"),
              let data = try? Data(contentsOf: url), let file = try? JSONDecoder().decode(File.self, from: data) else {
            return Directory(guides: [])
        }
        return Directory(guides: file.sites, source: file.source)
    }()
}
