import Foundation
import Testing
@testable import SecretariatCore

private func item(_ path: String, fields: [ItemField] = []) -> ItemMeta {
    ItemMeta(path: path, kind: "api-key", fields: fields, source: "")
}

private struct Vault {
    let fix = item("acme/cloudflare/fix-session", fields: [ItemField(name: "api_key", kind: .secret)])
    let pages = item("acme/cloudflare/pages", fields: [ItemField(name: "api_token", kind: .secret)])
    let github = item("acme/github/deploy", fields: [ItemField(name: "token", kind: .secret), ItemField(name: "user", kind: .identifier, value: "acme-bot")])
    let austria = item("acme/austria-post/login")
    var items: [ItemMeta] { [fix, pages, github, austria] }
    var configuration: Configuration {
        var c = Configuration()
        c.profiles = [
            Profile(name: "edge-worker", directory: "/x/edge-worker", bindings: [
                Binding(variable: "CF_FIX_TOKEN", itemID: fix.id, field: "api_key"),
                Binding(variable: "CLOUDFLARE_API_TOKEN", itemID: pages.id, field: "api_token"),
            ]),
            Profile(name: "shop", directory: "/x/shop", bindings: [Binding(variable: "GH_TOKEN", itemID: github.id, field: "token")]),
        ]
        c.targets = [Target(name: "deploy-box", kind: .envFile, bindings: [Binding(variable: "PAGES_DEPLOY", itemID: pages.id, field: "api_token")])]
        return c
    }
    func find(_ query: String) -> [String] {
        let bindings = Search.bindings(configuration)
        return Search.filter(items, query: query) { Search.itemText($0, bindings: bindings) }.map(\.path)
    }
}

@Test func normalizingIgnoresCaseAccentsAndSeparators() {
    #expect(Search.normalize("CF_FIX_TOKEN") == "cffixtoken")
    #expect(Search.normalize("moinsen-edge/Ä.b") == "moinsenedgeab")
    #expect(Search.terms("Lösch CF_FI in aus") == ["losch", "cffi", "aus"])
    #expect(Search.terms("in") == ["in"])
}

@Test func aBoundVariableFindsItsItemEvenWhenThePathSaysSomethingElse() {
    let v = Vault()
    #expect(v.find("CF_FI") == ["acme/cloudflare/fix-session"])
    #expect(v.find("cf-fix") == ["acme/cloudflare/fix-session"])
    #expect(v.find("cffixtoken") == ["acme/cloudflare/fix-session"])
    #expect(v.find("PAGES_DEPLOY") == ["acme/cloudflare/pages"], "target bindings count too")
    #expect(v.find("deploy-box") == ["acme/cloudflare/pages"])
}

@Test func severalWordsNarrowAndPathsMatchAcrossSeparators() {
    let v = Vault()
    #expect(v.find("cloudflare") == ["acme/cloudflare/fix-session", "acme/cloudflare/pages"])
    #expect(v.find("cloudflare pages") == ["acme/cloudflare/pages"])
    #expect(v.find("fix session") == ["acme/cloudflare/fix-session"])
    #expect(v.find("fixsession") == ["acme/cloudflare/fix-session"])
    #expect(v.find("acme-bot") == ["acme/github/deploy"], "identifier values are searchable")
    #expect(v.find("nothing-like-this").isEmpty)
}

@Test func aPastedSentenceStillFindsItsItem() {
    let v = Vault()
    #expect(v.find("Lösch CF_FIX_TOKEN in Secretariat aus dem Profil edge-worker, weil der Schlüssel ungültig ist.") == ["acme/cloudflare/fix-session"])
    #expect(v.find("Next step: delete CF_FIX_TOKEN from the profile edge-worker") == ["acme/cloudflare/fix-session"])
}

@Test func boundAsNamesTheVariableAndItsProject() {
    let v = Vault()
    #expect(Search.boundAs(v.fix, query: "cf_fi", bindings: Search.bindings(v.configuration)) == ["CF_FIX_TOKEN in edge-worker"])
    #expect(Search.boundAs(v.pages, query: "pages deploy", bindings: Search.bindings(v.configuration)) == ["PAGES_DEPLOY in deploy-box"])
    #expect(Search.boundAs(v.fix, query: "session", bindings: Search.bindings(v.configuration)).isEmpty)
}

@Test func searchingTwoThousandItemsStaysFast() {
    let items = (0..<2000).map { item("org\($0 % 40)/site-\($0)/login", fields: [ItemField(name: "username", kind: .identifier, value: "user\($0)@example.org")]) }
    var configuration = Configuration()
    configuration.profiles = (0..<40).map { p in
        Profile(name: "project-\(p)", bindings: (0..<8).map { Binding(variable: "VAR_\(p)_\($0)", itemID: items[p * 8 + $0].id, field: "username") })
    }
    let start = Date()
    for query in ["s", "si", "site-19", "VAR_3", "Delete VAR_3_1 from project-3 because it is wrong"] {
        let bindings = Search.bindings(configuration)
        _ = Search.filter(items, query: query) { Search.itemText($0, bindings: bindings) }
    }
    let perQuery = Date().timeIntervalSince(start) / 5
    #expect(perQuery < 0.1, "one search over 2000 items took \(perQuery) s")
}
