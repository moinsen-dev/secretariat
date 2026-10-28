import CryptoKit
import Foundation
import Testing
@testable import SecretariatCore

/// Signs like the Worker does: email.lowercased() + "\n" + ISO8601 (internet date-time).
private func signed(_ email: String, _ date: Date, _ key: Curve25519.Signing.PrivateKey) throws -> String {
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]
    let stamp = f.string(from: date)
    let signature = try key.signature(for: Data("\(email.lowercased())\n\(stamp)".utf8))
    return #"{"email":"\#(email.lowercased())","issuedAt":"\#(stamp)","signature":"\#(signature.base64EncodedString())"}"#
}

@Test func licenseFromTheWorkerVerifiesAndSyncsThroughTheStore() throws {
    let key = Curve25519.Signing.PrivateKey()
    let store = InMemoryLicenseStore()
    let licensing = Licensing(store: store, publicKeyBase64: key.publicKey.rawRepresentation.base64EncodedString())
    #expect(licensing.state() == .trial(daysLeft: 14))
    let license = try licensing.activate(try signed("Buyer@Example.com", Date(timeIntervalSince1970: 1_793_000_000), key))
    #expect(license.email == "buyer@example.com")
    // Another Mac reads the same synced store.
    let other = Licensing(store: store, publicKeyBase64: key.publicKey.rawRepresentation.base64EncodedString())
    #expect(other.state() == .licensed(email: "buyer@example.com"))
    try other.remove()
    #expect(licensing.license == nil)
}

@Test func foreignOrTamperedLicensesAreRefused() throws {
    let key = Curve25519.Signing.PrivateKey()
    let licensing = Licensing(store: InMemoryLicenseStore(), publicKeyBase64: key.publicKey.rawRepresentation.base64EncodedString())
    let foreign = try signed("a@b.de", Date(timeIntervalSince1970: 1_793_000_000), Curve25519.Signing.PrivateKey())
    #expect(throws: AgentError.self) { try licensing.activate(foreign) }
    let tampered = try signed("a@b.de", Date(timeIntervalSince1970: 1_793_000_000), key).replacingOccurrences(of: "a@b.de", with: "c@b.de")
    #expect(throws: AgentError.self) { try licensing.activate(tampered) }
    #expect(throws: AgentError.self) { try licensing.activate("not json") }
}

@Test func trialEndsAfterFourteenDaysAndOnlyReminds() throws {
    let key = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation.base64EncodedString()
    let store = InMemoryLicenseStore()
    let start = Date(timeIntervalSince1970: 1_793_000_000)
    #expect(Licensing(store: store, publicKeyBase64: key, now: { start }).state() == .trial(daysLeft: 14))
    #expect(Licensing.reminder(.trial(daysLeft: 14)) == nil)
    let day12 = Licensing(store: store, publicKeyBase64: key, now: { start.addingTimeInterval(12 * 86_400) }).state()
    #expect(day12 == .trial(daysLeft: 2))
    #expect(Licensing.reminder(day12)?.contains("2 days left") == true)
    let later = Licensing(store: store, publicKeyBase64: key, now: { start.addingTimeInterval(15 * 86_400) }).state()
    #expect(later == .expired)
    #expect(Licensing.reminder(later)?.contains("keeps working") == true)
    // A clock set back doesn't stretch the trial beyond 14 days.
    #expect(Licensing(store: store, publicKeyBase64: key, now: { start.addingTimeInterval(-30 * 86_400) }).state() == .trial(daysLeft: 14))
}

@Test func buildWithoutKeyEnforcesNothing() {
    #expect(Licensing(store: InMemoryLicenseStore(), publicKeyBase64: "").state() == .licensed(email: ""))
}
