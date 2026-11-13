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
    for host in ["example.com", "172.32.0.1", "8.8.8.8", "github.com"] { #expect(!LoginAudit.isLocal(host), "\(host)") }
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
    #expect(LoginAudit.closeAccountSearchURL(byPath["web/shop.b.test"]!)?.absoluteString.contains("b.test%20delete%20account") == true)
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
