import Foundation
import Testing
@testable import SecretariatCore

/// Artificial Google Password Manager export: quotes, comma and line break inside fields, an Android app,
/// a router address, a repeated row, a row without password.
private let googleCSV = """
\u{FEFF}name,url,username,password,note
example.com,https://www.example.com/login,ann@example.test,"pa,ss""word",
example.com,https://www.example.com/login,ann@example.test,"pa,ss""word",
shop.test,https://shop.test/,bob,shop-secret-1,"two
lines"
com.example.app,android://hashvalue@com.example.app/,carl,app-secret,
192.168.178.1,http://192.168.178.1/,admin,router-pw,
passkey-only.test,https://passkey-only.test/,dora,,
"""

@Test func csvParsesQuotesCommasAndLineBreaks() {
    let table = CSV.parse("a,b\r\n\"x,1\",\"he said \"\"hi\"\"\nnext\"\r\n")
    #expect(table == [["a", "b"], ["x,1", "he said \"hi\"\nnext"]])
    #expect(CSV.parse("a,b\n1,2") == [["a", "b"], ["1", "2"]])
    #expect(CSV.parse("a,,c\n") == [["a", "", "c"]])
}

@Test func rowsReadGoogleAndOtherExportsAndRejectOtherFiles() throws {
    let rows = try PasswordImport.rows(googleCSV)
    #expect(rows.count == 6)
    #expect(rows[0].password == "pa,ss\"word")
    #expect(rows[2].note == "two\nlines")
    let apple = try PasswordImport.rows("Title,URL,Username,Password,Notes,OTPAuth\nGitHub,https://github.com/,u,p,n,\n")
    #expect(apple == [PasswordImport.Row(name: "GitHub", url: "https://github.com/", username: "u", password: "p", note: "n")])
    let bitwarden = try PasswordImport.rows("folder,favorite,type,name,notes,fields,reprompt,login_uri,login_username,login_password,login_totp\n,,login,X,,,0,https://x.test,me,pw,\n")
    #expect(bitwarden.first?.url == "https://x.test"); #expect(bitwarden.first?.password == "pw")
    #expect(throws: SecretariatError.self) { try PasswordImport.rows("KEY=value\n") }
}

@Test func planSortsRowsWithoutTouchingTheVault() throws {
    let rows = try PasswordImport.rows(googleCSV)
    let plan = PasswordImport.plan(rows, existing: [], source: "Imported from test.csv") { _ in nil }
    #expect(plan.new.map(\.meta.path) == ["web/example.com", "web/shop.test", "app/com.example.app", "web/192.168.178.1"])
    #expect(plan.duplicates == 1); #expect(plan.withoutPassword == 1); #expect(plan.rows == 6)
    let first = plan.new[0]
    #expect(first.meta.kind == "login"); #expect(first.meta.field("url")?.value == "https://www.example.com")
    #expect(first.username == "ann@example.test"); #expect(first.meta.field("password")?.kind == .personal)
    #expect(first.meta.field("password")?.value == nil); #expect(first.secrets == ["password": "pa,ss\"word"])
    #expect(plan.new[1].secrets["notes"] == "two\nlines"); #expect(plan.new[1].meta.field("notes")?.kind == .personal)
    for login in plan.new { try login.meta.validate() }
}

@Test func importLoginsSkipsWhatIsThereAndNeverOverwrites() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let csv = f.root.appendingPathComponent("Google Passwords.csv")
    try googleCSV.write(to: csv, atomically: true, encoding: .utf8)

    let (_, dry) = try f.cli("import-logins", csv.path, "--dry-run")
    #expect(dry.contains("\"dryRun\" : true")); #expect(dry.contains("web/shop.test"))
    #expect(try f.vault.list().count == 1)

    f.items.secretReads = 0
    let (_, json) = try f.cli("import-logins", csv.path)
    #expect(try f.vault.list().count == 5)
    for value in ["pa,ss", "shop-secret-1", "app-secret", "router-pw", "two\nlines"] { #expect(!json.contains(value)) }
    let shop = try f.vault.item(path: "web/shop.test")
    #expect(try f.vault.personalValue(itemID: shop.id, field: "password") == "shop-secret-1")
    #expect(shop.source == "Imported from Google Passwords.csv"); #expect(shop.rotated == today())
    #expect(FileManager.default.fileExists(atPath: csv.path))   // the CSV stays; the user deletes it
    #expect(f.vault.audit.tail(1).first?.contains("import.logins") == true)

    // Second run: everything is there. A changed password is named, not written.
    try googleCSV.replacingOccurrences(of: "router-pw", with: "router-new").write(to: csv, atomically: true, encoding: .utf8)
    let (_, again) = try f.cli("import-logins", csv.path)
    #expect(again.contains("\"new\" : [\n\n  ]") || again.contains("\"new\" : []"))
    #expect(again.contains("\"differs\" : [\n    \"web/192.168.178.1\""))
    let router = try f.vault.item(path: "web/192.168.178.1")
    #expect(try f.vault.personalValue(itemID: router.id, field: "password") == "router-pw")
    #expect(try f.vault.list().count == 5)
    #expect(f.code("import-logins", f.root.appendingPathComponent("missing.csv").path) == "file_unreadable")
}

@Test func importedLoginIsFoundByFillLogin() throws {
    let rows = try PasswordImport.rows(googleCSV)
    let plan = PasswordImport.plan(rows, existing: [], source: "t") { _ in nil }
    let candidates = LoginFill.candidates(plan.new.map(\.meta), page: "https://example.com/signin", query: "")
    #expect(candidates.first?.item.path == "web/example.com")
}

@Test func secondLoginForTheSameSiteGetsItsOwnPath() {
    let rows = [PasswordImport.Row(url: "https://a.test", username: "one", password: "1"),
                PasswordImport.Row(url: "https://a.test", username: "two", password: "2")]
    let plan = PasswordImport.plan(rows, existing: [], source: "t") { _ in nil }
    #expect(plan.new.map(\.meta.path) == ["web/a.test", "web/a.test/two"])
}

@Test func secondProfileAddsItsOriginWithoutTouchingValues() throws {
    let f = try AgentFixture(); defer { f.cleanup() }
    let work = f.root.appendingPathComponent("Google Passwords.csv")
    try "name,url,username,password,note\nx,https://shared.test/,me,same-pw,\ny,https://work.test/,me,work-pw,\n".write(to: work, atomically: true, encoding: .utf8)
    try f.cli("import-logins", work.path, "--from", "Chrome: Work")
    let shared = try f.vault.item(path: "web/shared.test")
    #expect(shared.field("found_in")?.value == "Chrome: Work"); #expect(shared.field("found_in")?.kind == .identifier)

    // The private profile's export: same login with the same password, one with another password, one new.
    let personal = f.root.appendingPathComponent("Google Passwords (1).csv")
    try "name,url,username,password,note\nx,https://shared.test/,me,same-pw,\ny,https://work.test/,me,other-pw,\nz,https://shop.test/,me,shop-pw,\n"
        .write(to: personal, atomically: true, encoding: .utf8)
    f.items.secretReads = 0
    let (_, json) = try f.cli("import-logins", personal.path, "--from", "Chrome: Privat")
    #expect(json.contains("\"originAdded\" : [\n    \"web/shared.test\""))
    #expect(try f.vault.item(path: "web/shared.test").field("found_in")?.value == "Chrome: Work, Chrome: Privat")
    #expect(try f.vault.personalValue(itemID: shared.id, field: "password") == "same-pw")
    #expect(try f.vault.item(path: "web/work.test").field("found_in")?.value == "Chrome: Work")   // differs: left alone
    #expect(try f.vault.item(path: "web/shop.test").field("found_in")?.value == "Chrome: Privat")
    // Third run of the same file changes nothing more.
    let (_, again) = try f.cli("import-logins", personal.path, "--from", "Chrome: Privat")
    #expect(again.contains("\"originAdded\" : [\n\n  ]") || again.contains("\"originAdded\" : []"))
    #expect(f.vault.audit.tail(3).contains { $0.contains("Chrome: Privat") })
}

@Test func originSuggestionsComeFromEarlierImportsAndGoogleSignIns() {
    let rows = [PasswordImport.Row(url: "https://accounts.google.com/", username: "me@gmail.example", password: "p"),
                PasswordImport.Row(url: "https://other.test/", username: "x@y.test", password: "p")]
    let earlier = ItemMeta(path: "web/a.test", kind: "login", fields: [ItemField(name: "found_in", kind: .identifier, value: "Chrome: Work, Chrome: Privat")])
    #expect(PasswordImport.originSuggestions(rows, existing: [earlier]) == ["Chrome: Work", "Chrome: Privat", "Chrome: me@gmail.example"])
    let plan = PasswordImport.plan(rows, existing: [], source: "t", origin: " Chrome, Work ") { _ in nil }
    #expect(plan.origin == "Chrome  Work")
}
