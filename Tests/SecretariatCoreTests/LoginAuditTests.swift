import Foundation
import Testing
@testable import SecretariatCore

private func login(_ path: String, _ url: String, user: String = "me", origin: String? = nil) -> ItemMeta {
    var fields = [ItemField(name: "url", kind: .identifier, value: url), ItemField(name: "username", kind: .identifier, value: user),
                  ItemField(name: "password", kind: .personal)]
    if let origin { fields.append(ItemField(name: "found_in", kind: .identifier, value: origin)) }
    return ItemMeta(path: path, kind: "login", fields: fields, rotated: "2026-11-13")
}

@Test func localAddressesAreRecognised() {
    for host in ["192.168.178.1", "10.0.0.5", "172.20.1.1", "127.0.0.1", "localhost:3000", "fritz.box", "nas.local", "printer.lan"] {
        #expect(LoginAudit.isLocal(host), "\(host)")
    }
    for host in ["8.8.8.8", "0.0.0.0", "203.0.113.15"] { #expect(LoginAudit.isLocal(host), "\(host)") }   // IP addresses are devices
    for host in ["example.com", "github.com", "shop.example.org", "1st-example.de", "example.co.uk"] { #expect(!LoginAudit.isLocal(host), "\(host)") }
}

@Test func weakPasswords() {
    // Generated examples only; none of them is a real password.
    #expect(LoginAudit.Facts("q7Zp2").weak)                     // short
    #expect(LoginAudit.Facts("58203917465029").weak)            // digits only
    #expect(LoginAudit.Facts("qwmzxnbvlkr").weak)               // one kind of character, under 12
    #expect(!LoginAudit.Facts("Tr4m-polin-Kaffee").weak)
    #expect(LoginAudit.Facts("abc").sha1.hasPrefix("A9993"))    // SHA-1("abc") = A9993E36…
}

@Test func entriesFindLocalReusedWeakLeakedAndGoneDomains() {
    let router = login("web/192.168.178.1", "http://192.168.178.1/", user: "admin")
    let a = login("web/a.test", "https://www.a.test/login", origin: "Chrome: Work")
    let b = login("web/shop.b.test", "https://shop.b.test/", origin: "Chrome: Work, Chrome: Privat")
    let c = login("web/c.test", "https://c.test/")
    let note = ItemMeta(path: "moinsen/x", kind: "api", fields: [ItemField(name: "api_key", kind: .secret)])
    let facts = [router.id: LoginAudit.Facts("admin"), a.id: LoginAudit.Facts("Shared-Secret-42!"),
                 b.id: LoginAudit.Facts("Shared-Secret-42!"), c.id: LoginAudit.Facts("Unique-Long-Pass-99")]
    var online = LoginAudit.Online()
    online.hosts = ["b.test": .gone, "a.test": .ok]
    online.leaks = [c.id.uuidString: .init(count: 12, rotated: "2026-11-13"), a.id.uuidString: .init(count: 3, rotated: "2020-01-01")]
    let entries = LoginAudit.entries([router, a, b, c, note], facts: facts, online: online)
    #expect(entries.count == 4)
    let byPath = Dictionary(uniqueKeysWithValues: entries.map { ($0.item.path, $0) })
    #expect(byPath["web/192.168.178.1"]?.findings == [.local, .weak])
    #expect(byPath["web/a.test"]?.findings == [.reused]); #expect(byPath["web/a.test"]?.reusedWith == ["web/shop.b.test"])
    #expect(byPath["web/a.test"]?.leakCount == nil)                    // checked for an older password
    #expect(byPath["web/shop.b.test"]?.findings == [.reused, .domainGone]); #expect(byPath["web/shop.b.test"]?.site == "b.test")
    #expect(byPath["web/shop.b.test"]?.origins == ["Chrome: Work", "Chrome: Privat"])
    #expect(byPath["web/c.test"]?.findings == [.leaked]); #expect(byPath["web/c.test"]?.leakCount == 12)
    let summary = LoginAudit.summary(entries, online: online)
    #expect(summary.logins == 4 && summary.local == 1 && summary.reused == 2 && summary.weak == 1 && summary.leaked == 1 && summary.domainGone == 1)
    #expect(summary.undecided == 4)
    #expect(LoginAudit.changePasswordURL(byPath["web/a.test"]!)?.absoluteString == "https://a.test/.well-known/change-password")
    #expect(LoginAudit.changePasswordURL(byPath["web/192.168.178.1"]!) == nil)
    #expect(LoginAudit.closeAccountURL(byPath["web/shop.b.test"]!)?.absoluteString.contains("b.test%20delete%20account") == true)
}

@Test func pwnedRangeAnswerIsParsed() {
    let range = LoginAudit.parseRange("1E4C9B93F3F0682250B6CF8331B7EE68FD8:3861493\r\n0018A45C4D1DEF81644B54AB7F969B88D65:0\nBAD\n")
    #expect(range == ["1E4C9B93F3F0682250B6CF8331B7EE68FD8": 3861493])
}

@Test func decisionsChangeOnlyTheReviewFieldAndTheCacheStaysPrivate() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let item = login("web/a.test", "https://a.test/")
    try f.vault.save(item, secrets: ["password": "Kept-As-It-Is-1"])
    let entry = LoginAudit.entries(try f.vault.list(), facts: [:])[0]
    try LoginAudit.decide(entry.item, .close, vault: f.vault)
    #expect(LoginAudit.decision(try f.vault.item(path: "web/a.test")) == .close)
    #expect(try f.vault.personalValue(itemID: item.id, field: "password") == "Kept-As-It-Is-1")
    try LoginAudit.decide(entry.item, nil, vault: f.vault)
    #expect(try f.vault.item(path: "web/a.test").field("review") == nil)

    var online = LoginAudit.Online(); online.hosts = ["a.test": .gone]; online.checked = Date(timeIntervalSince1970: 1_800_000_000)
    let paths = f.vault.configuration.paths
    try LoginAudit.saveOnline(online, paths: paths)
    #expect(LoginAudit.loadOnline(paths) == online)
    let mode = try FileManager.default.attributesOfItem(atPath: LoginAudit.cacheURL(paths).path)[.posixPermissions] as? Int
    #expect(mode == 0o600)
    #expect(!String(decoding: try Data(contentsOf: LoginAudit.cacheURL(paths)), as: UTF8.self).contains("Kept-As-It-Is"))
}

@Test func auditLoginsCommandPrintsCountsAndPathsOnly() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    try f.vault.save(login("web/192.168.0.1", "http://192.168.0.1/", origin: "Chrome: Privat"), secrets: ["password": "router-123"])
    try f.vault.save(login("web/a.test", "https://a.test/", origin: "Chrome: Work"), secrets: ["password": "Same-Secret-Value-7"])
    try f.vault.save(login("web/b.test", "https://b.test/", origin: "Chrome: Work"), secrets: ["password": "Same-Secret-Value-7"])
    let (_, json) = try f.cli("audit-logins", "--finding", "reused")
    #expect(json.contains("\"reused\" : 2")); #expect(json.contains("\"local\" : 1")); #expect(json.contains("web/b.test"))
    #expect(!json.contains("Same-Secret") && !json.contains("router-123"))
    let (_, privat) = try f.cli("audit-logins", "--from", "Chrome: Privat")
    #expect(privat.contains("\"logins\" : 1"))
    #expect(f.code("audit-logins", "--finding", "nope") == "invalid_arguments")
}

@Test func deletionGuidesMatchByHostAndSite() {
    let guides = [AccountDeletion.Guide(name: "Shop", url: "https://help.shop.test/delete", difficulty: .easy, domains: ["shop.test"], notes: nil, email: nil),
                  AccountDeletion.Guide(name: "Mail", url: "https://mail.test/settings", difficulty: .hard, domains: [], notes: "Write to support.", email: "privacy@mail.test")]
    let directory = AccountDeletion.Directory(guides: guides)
    #expect(directory.guide(host: "shop.test")?.name == "Shop")
    #expect(directory.guide(host: "accounts.shop.test")?.name == "Shop")      // same registrable site
    #expect(directory.guide(host: "mail.test")?.email == "privacy@mail.test")
    #expect(directory.guide(host: "other.test") == nil)
    let item = login("web/shop.test", "https://www.shop.test/login")
    let router = login("web/192.168.0.1", "http://192.168.0.1/")
    let entries = LoginAudit.entries([item, router], facts: [:], guides: directory)
    #expect(entries.first { $0.item.path == "web/shop.test" }?.deletion?.difficulty == .easy)
    #expect(entries.first { $0.item.path == "web/192.168.0.1" }?.deletion == nil)
    #expect(LoginAudit.closeAccountURL(entries.first { $0.item.path == "web/shop.test" }!)?.absoluteString == "https://help.shop.test/delete")
    let summary = LoginAudit.summary(entries, online: .init())
    #expect(summary.easy == 1 && summary.withoutGuide == 0)
}

@Test func bundledDeletionDirectoryLoads() {
    let directory = AccountDeletion.bundled
    #expect(directory.count > 400)
    #expect(directory.source.contains("MIT"))
    #expect(directory.guide(host: "github.com") != nil)
}

@Test func auditLoginsListsByClosingDifficulty() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    try f.vault.save(login("web/github.com", "https://github.com/login"), secrets: ["password": "Artificial-Long-Value-31"])
    let (_, json) = try f.cli("audit-logins", "--closing", AccountDeletion.bundled.guide(host: "github.com")!.difficulty.rawValue)
    #expect(json.contains("web/github.com"))
    #expect(f.code("audit-logins", "--closing", "sometimes") == "invalid_arguments")
}

@Test func researchedRouteCoversEverySiteLoginAndWinsOverTheDirectory() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let a = login("web/shop.test", "https://www.shop.test/login", user: "one")
    let b = login("web/shop.test/two", "https://accounts.shop.test/", user: "two")
    let other = login("web/other.test", "https://other.test/")
    for item in [a, b, other] { try f.vault.save(item, secrets: ["password": "Artificial-\(item.path)"]) }
    let route = LoginRoutes.Route(url: nil, contact: "privacy@shop.test", difficulty: .hard, note: "Request by e-mail with the account address.",
                                  source: "https://shop.test/privacy")
    let changed = try LoginRoutes.set(route, site: "https://shop.test/", vault: f.vault, today: "2026-11-13")
    #expect(changed.sorted() == ["web/shop.test", "web/shop.test/two"])
    #expect(try f.vault.personalValue(itemID: a.id, field: "password") == "Artificial-web/shop.test")
    let directory = AccountDeletion.Directory(guides: [.init(name: "Shop", url: "https://shop.test/delete", difficulty: .easy, domains: ["shop.test"], notes: nil, email: nil)])
    let entries = LoginAudit.entries(try f.vault.list(), facts: [:], guides: directory)
    let guide = entries.first { $0.item.path == "web/shop.test" }?.deletion
    #expect(guide?.difficulty == .hard); #expect(guide?.email == "privacy@shop.test"); #expect(guide?.source == "https://shop.test/privacy")
    #expect(guide?.checked == "2026-11-13"); #expect(guide?.url == nil)
    // Recording again replaces the route instead of adding fields.
    try LoginRoutes.set(.init(url: "https://shop.test/account/delete", contact: nil, difficulty: .easy, note: nil, source: "https://shop.test/help"),
                        site: "shop.test", vault: f.vault, today: "2026-11-14")
    let item = try f.vault.item(path: "web/shop.test")
    #expect(item.fields.filter { $0.name.hasPrefix("deletion_") }.count == 4)   // url, difficulty, source, checked
    #expect(LoginRoutes.route(item)?.difficulty == .easy)
    // Rules: a source page is required, contacts are mail or http(s), notes are one line.
    func code(_ r: LoginRoutes.Route) -> String? { do { try LoginRoutes.set(r, site: "shop.test", vault: f.vault); return nil } catch let e as AgentError { return e.code } catch { return "other" } }
    #expect(code(.init(url: "https://x.test", contact: nil, difficulty: .easy, note: nil, source: "not a url")) == "invalid_arguments")
    #expect(code(.init(url: nil, contact: nil, difficulty: .easy, note: nil, source: "https://x.test")) == "invalid_arguments")
    #expect(code(.init(url: nil, contact: nil, difficulty: .impossible, note: "Service shut down in 2017.", source: "https://x.test/news")) == nil)
    #expect(LoginRoutes.route(try f.vault.item(path: "web/shop.test"))?.difficulty == .impossible)
    #expect(code(.init(url: nil, contact: "javascript:alert(1)", difficulty: .easy, note: nil, source: "https://x.test")) == "invalid_arguments")
    #expect(code(.init(url: "https://x.test", contact: nil, difficulty: .easy, note: "two\nlines", source: "https://x.test")) == "invalid_arguments")
    #expect((try? LoginRoutes.set(route, site: "nowhere.test", vault: f.vault)) == nil)
}

@Test func mcpToolsLetAnAgentWorkThroughSitesWithoutValues() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    try f.vault.save(login("web/github.com", "https://github.com/login", origin: "Chrome: Work"), secrets: ["password": "Artificial-Github-Value-1"])
    try f.vault.save(login("web/unknown-shop.test", "https://unknown-shop.test/", origin: "Chrome: Privat"), secrets: ["password": "Artificial-Shop-Value-2"])
    try f.vault.save(login("web/192.168.0.1", "http://192.168.0.1/"), secrets: ["password": "Artificial-Router-3"])

    let (sites, sitesError) = McpServer.call("login_sites", ["needs_route": true], service: f.service, executable: "/tmp/s")
    #expect(!sitesError); #expect(sites.contains("unknown-shop.test")); #expect(!sites.contains("\"site\" : \"github.com\""))
    #expect(!sites.contains("192.168.0.1")); #expect(sites.contains("\"total\" : 1"))
    let (set, setError) = McpServer.call("set_deletion_route", ["site": "unknown-shop.test", "difficulty": "hard", "contact": "privacy@unknown-shop.test",
                                                                "source": "https://unknown-shop.test/privacy"], service: f.service, executable: "/tmp/s")
    #expect(!setError); #expect(set.contains("web/unknown-shop.test"))
    let (after, _) = McpServer.call("login_sites", ["needs_route": true], service: f.service, executable: "/tmp/s")
    #expect(after.contains("\"total\" : 0"))
    let (all, _) = McpServer.call("login_sites", ["from": "Chrome: Privat"], service: f.service, executable: "/tmp/s")
    #expect(all.contains("privacy@unknown-shop.test")); #expect(all.contains("https://unknown-shop.test/privacy"))
    let (inventory, inventoryError) = McpServer.call("login_inventory", ["closing": "hard"], service: f.service, executable: "/tmp/s")
    #expect(!inventoryError); #expect(inventory.contains("web/unknown-shop.test"))
    for output in [sites, set, after, all, inventory] { #expect(!output.contains("Artificial-")) }
    let (bad, badError) = McpServer.call("set_deletion_route", ["site": "unknown-shop.test", "difficulty": "hard", "source": "https://x.test"],
                                         service: f.service, executable: "/tmp/s")
    #expect(badError); #expect(bad.contains("invalid_arguments"))
}
