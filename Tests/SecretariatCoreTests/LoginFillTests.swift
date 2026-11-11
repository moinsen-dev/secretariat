import Foundation
import Testing
@testable import SecretariatCore

private func login(_ path: String, url: String? = nil, user: String? = "uli@example.com") -> ItemMeta {
    var fields: [ItemField] = []
    if let url { fields.append(ItemField(name: "url", kind: .identifier, value: url)) }
    if let user { fields.append(ItemField(name: "username", kind: .identifier, value: user)) }
    fields.append(ItemField(name: "password", kind: .personal))
    return ItemMeta(path: path, kind: "login", fields: fields)
}

@Test func hostIsLowercasedWithoutWwwAndOnlyForWebAddresses() {
    #expect(LoginFill.host("https://www.GitHub.com/login?x=1") == "github.com")
    #expect(LoginFill.host("appstoreconnect.apple.com") == "appstoreconnect.apple.com")
    #expect(LoginFill.host("http://localhost:8765/login.html") == "localhost:8765")
    #expect(LoginFill.host("file:///Applications/Claude.app/index.html") == nil)
    #expect(LoginFill.host("about:blank") == nil)
    #expect(LoginFill.host("  ") == nil)
    #expect(LoginFill.host("not a host") == nil)
}

@Test func siteIsTheRegistrablePart() {
    #expect(LoginFill.site("appstoreconnect.apple.com") == "apple.com")
    #expect(LoginFill.site("apple.com") == "apple.com")
    #expect(LoginFill.site("shop.example.co.uk") == "example.co.uk")
    #expect(LoginFill.site("localhost") == "localhost")
}

@Test func onlyAFieldNamedPasswordIsFilled() {
    #expect(LoginFill.fillableField(login("a/b")) == "password")
    let api = ItemMeta(path: "moinsen/openai", kind: "api", fields: [ItemField(name: "env_var", kind: .identifier, value: "X"),
                                                                    ItemField(name: "api_key", kind: .secret)])
    #expect(LoginFill.fillableField(api) == nil)
    let note = ItemMeta(path: "n", kind: "note", fields: [ItemField(name: "notes", kind: .personal)])
    #expect(LoginFill.fillableField(note) == nil)
    let database = ItemMeta(path: "d", kind: "database", fields: [ItemField(name: "host", kind: .identifier, value: "h"),
                                                                 ItemField(name: "password", kind: .secret)])
    #expect(LoginFill.fillableField(database) == "password")
    let wrongKind = ItemMeta(path: "w", kind: "x", fields: [ItemField(name: "password", kind: .file)])
    #expect(LoginFill.fillableField(wrongKind) == nil)
}

@Test func valuesWithControlCharactersAreNotTyped() {
    #expect(LoginFill.isTypable("Lang-Test_Pw:ÄÖÜ-ß-€-42!x 🔑"))
    #expect(!LoginFill.isTypable("first line\nsecond"))
    #expect(!LoginFill.isTypable("pass\tword"))
    #expect(!LoginFill.isTypable("bell\u{7}"))
    #expect(!LoginFill.isTypable(""))
}

@Test func sharedHostingSubdomainsAreNotTheSameSite() {
    #expect(LoginFill.site("evil.pages.dev") == "evil.pages.dev")
    #expect(LoginFill.site("a.b.github.io") == "b.github.io")
    let items = [login("moinsen/site", url: "https://moinsen.pages.dev")]
    #expect(LoginFill.candidates(items, page: "https://evil.pages.dev/login", query: "").first?.rank == .other)
    #expect(LoginFill.candidates(items, page: "https://moinsen.pages.dev/login", query: "").first?.rank == .sameHost)
}

@Test func pageMatchesComeFirstAndOthersStayHiddenWithoutAQuery() {
    let items = [login("moinsen/apple/appstoreconnect", url: "https://appstoreconnect.apple.com"),
                 login("moinsen/apple/developer", url: "https://developer.apple.com"),
                 login("private/apple-id"),
                 login("moinsen/github", url: "https://github.com/login"),
                 ItemMeta(path: "moinsen/server", kind: "server", fields: [ItemField(name: "host", kind: .identifier, value: "x")])]
    let found = LoginFill.candidates(items, page: "https://appstoreconnect.apple.com/login?targetUrl=x", query: "")
    #expect(found.map(\.item.path) == ["moinsen/apple/appstoreconnect", "moinsen/apple/developer", "private/apple-id"])
    #expect(found.map(\.rank) == [.sameHost, .sameSite, .nameMentionsSite])
    #expect(found.first?.username == "uli@example.com")
    #expect(found.first?.host == "appstoreconnect.apple.com")
}

@Test func withoutAMatchOrPageEveryFillableItemIsOffered() {
    let items = [login("b/one", url: "https://one.example"), login("a/two")]
    #expect(LoginFill.candidates(items, page: "https://unknown.org/", query: "").map(\.item.path) == ["a/two", "b/one"])
    #expect(LoginFill.candidates(items, page: nil, query: "").count == 2)
}

@Test func searchNeedsEveryWordInPathUserOrHost() {
    let items = [login("moinsen/apple/appstoreconnect", url: "https://appstoreconnect.apple.com"),
                 login("moinsen/github", url: "https://github.com", user: "moinsen-dev"),
                 login("private/bank", user: "kontonummer")]
    #expect(LoginFill.candidates(items, page: "https://github.com", query: "apple").map(\.item.path) == ["moinsen/apple/appstoreconnect"])
    #expect(LoginFill.candidates(items, page: nil, query: "Moinsen dev").map(\.item.path) == ["moinsen/github"])
    #expect(LoginFill.candidates(items, page: nil, query: "konto").map(\.item.path) == ["private/bank"])
    #expect(LoginFill.candidates(items, page: nil, query: "nothing").isEmpty)
    // A search still ranks the page's own items first.
    #expect(LoginFill.candidates(items, page: "https://github.com", query: "moinsen").map(\.item.path) == ["moinsen/github", "moinsen/apple/appstoreconnect"])
}

@Test func shortSiteLabelsDoNotMatchPathParts() {
    let items = [login("moinsen/x/admin")]
    #expect(LoginFill.candidates(items, page: "https://x.com", query: "").first?.rank == .other)
}

@Test func generatedPasswordsAreStrongAndTypable() {
    var seen = Set<String>()
    for _ in 0..<200 {
        let password = PasswordGenerator.make()
        #expect(password.count == 20)
        #expect(password.contains { $0.isLowercase } && password.contains { $0.isUppercase } && password.contains { $0.isNumber })
        #expect(password.contains { "-_.!?#%+=".contains($0) })
        #expect(!password.contains { "lIO01".contains($0) })
        #expect(LoginFill.isTypable(password))
        seen.insert(password)
    }
    #expect(seen.count == 200)
}

@Test func capturedLoginGetsAFreePathAndTheLoginShape() {
    #expect(LoginCapture.path(host: "github.com", username: "uli", existing: []) == "web/github.com")
    #expect(LoginCapture.path(host: "github.com", username: "Uli Test", existing: ["web/GitHub.com"]) == "web/github.com/Uli-Test")
    #expect(LoginCapture.path(host: "github.com", username: "", existing: ["web/github.com"]) == "web/github.com-2")
    #expect(LoginCapture.path(host: "github.com", username: "a@b.de", existing: ["web/github.com", "web/github.com/a@b.de"]) == "web/github.com/a@b.de-2")
    let item = LoginCapture.item(address: "https://app.example.com", path: "web/app.example.com", username: " uli@example.com ")
    #expect(item.kind == "login")
    #expect(item.field("url")?.value == "https://app.example.com")
    #expect(item.field("username")?.value == "uli@example.com")
    #expect(item.field("password")?.kind == .personal && item.field("password")?.value == nil)
    #expect(throws: Never.self) { try item.validate() }
    #expect(LoginFill.fillableField(item) == "password")
    #expect(LoginCapture.item(address: "https://x.org", path: "web/x.org", username: "").field("username") == nil)
    #expect(LoginCapture.item(address: "http://localhost:8765", path: "web/l", username: "u1").field("url")?.value == "http://localhost:8765")
}

@Test func aJustSavedLoginComesFirstAmongEqualMatches() {
    let old = login("test/old", url: "http://localhost:8765/x"), new = login("web/localhost", url: "http://localhost:8765")
    #expect(LoginFill.candidates([old, new], page: "http://localhost:8765/signup", query: "").first?.item.path == "test/old")
    #expect(LoginFill.candidates([old, new], page: "http://localhost:8765/signup", query: "", preferred: new.id).first?.item.path == "web/localhost")
    // Never ahead of a better match.
    let other = login("zzz/other", url: "https://other.example")
    #expect(LoginFill.candidates([old, other], page: "http://localhost/", query: "local", preferred: other.id).first?.item.path == "test/old")
}

@Test func onlyPlausibleUserNamesAreKept() {
    #expect(LoginCapture.plausibleUsername(" uli@example.com ") == "uli@example.com")
    #expect(LoginCapture.plausibleUsername("moinsen-dev") == nil)            // unlabelled field: not taken
    #expect(LoginCapture.plausibleUsername("moinsen-dev", label: "Username") == "moinsen-dev")
    #expect(LoginCapture.plausibleUsername("ABCD-EFGH-1234", label: "Recovery code") == nil)
    #expect(LoginCapture.plausibleUsername("DE89370400440532013000", label: "IBAN") == nil)
    #expect(LoginCapture.plausibleUsername("JBSWY3DPEHPK3PXP") == nil)        // TOTP secret
    #expect(LoginCapture.plausibleUsername("ABCD-EFGH", label: "Account recovery code") == nil)
    #expect(LoginCapture.plausibleUsername("ab12cd34", label: "Login PIN") == nil)
    #expect(LoginCapture.plausibleUsername("Kontonummer12", label: "Kontonummer") == nil)
    #expect(LoginCapture.plausibleUsername("123456") == nil)            // one-time code
    #expect(LoginCapture.plausibleUsername("4111 1111 1111 1111") == nil) // card number
    #expect(LoginCapture.plausibleUsername("+49 151 2345") == nil)      // phone
    #expect(LoginCapture.plausibleUsername("cheap flights berlin") == nil) // search text
    #expect(LoginCapture.plausibleUsername("x") == nil)
    #expect(LoginCapture.plausibleUsername(nil) == nil)
}

@Test func localServicesAreTellApartByPort() {
    #expect(LoginFill.host("http://localhost:8765/signup") == "localhost:8765")
    #expect(LoginFill.host("http://localhost/") == "localhost")
    #expect(LoginFill.origin(URL(string: "http://localhost:8765/a?b=1")!) == "http://localhost:8765")
    #expect(LoginFill.origin(URL(string: "https://www.github.com/login")!) == "https://www.github.com")
    let other = login("dev/other", url: "http://localhost:3000")
    #expect(LoginFill.candidates([other], page: "http://localhost:8765/login", query: "").first?.rank != .sameHost)
    #expect(LoginCapture.path(host: "localhost:8765", username: "", existing: []) == "web/localhost-8765")
}
