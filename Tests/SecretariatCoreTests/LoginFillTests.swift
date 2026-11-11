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
    #expect(LoginFill.host("http://localhost:8765/login.html") == "localhost")
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
