import Foundation
import Testing
@testable import SecretariatCore

private func library(_ keyring: InMemoryScreenshotKeyring = InMemoryScreenshotKeyring(), in root: URL) -> ScreenshotLibrary {
    ScreenshotLibrary(directory: root, location: .local, keyring: keyring)
}
private func temporaryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("secretariat-shots-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func screenshotRoundTripsAndNothingReadableLandsOnDisk() throws {
    let root = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: root) }
    let shots = library(in: root)
    let image = Data("PNG-PIXELS-visible-only-in-the-app".utf8)
    let shot = try shots.add(image: image, format: ".PNG", title: " Stripe dashboard ", note: "Webhook secret shown once: whsec_123")
    #expect(shot.title == "Stripe dashboard")
    #expect(shot.format == "png")
    #expect(try shots.image(shot.id) == image)
    #expect(try shots.list().screenshots == [shot])
    // On disk: random file names, no title, note or image bytes in the clear.
    for name in try FileManager.default.contentsOfDirectory(atPath: root.path) {
        #expect(name.hasPrefix(shot.id.uuidString))
        let raw = try Data(contentsOf: root.appendingPathComponent(name))
        for plain in ["PNG-PIXELS", "Stripe", "whsec_123"] { #expect(raw.range(of: Data(plain.utf8)) == nil) }
    }
    let changed = try shots.update(shot.id, title: "Stripe", note: "rotated")
    #expect(try shots.list().screenshots.first?.note == "rotated")
    #expect(changed.created == shot.created)
    try shots.delete(shot.id)
    #expect(try shots.list().screenshots.isEmpty)
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
}

@Test func filesFromAnotherMacStayReadableWithItsKey() throws {
    let root = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: root) }
    // Two Macs each created a key before iCloud synced; the keyring later holds both.
    let first = InMemoryScreenshotKeyring(), second = InMemoryScreenshotKeyring()
    let a = try library(first, in: root).add(image: Data("from A".utf8), format: "png", title: "A", note: "")
    let b = try library(second, in: root).add(image: Data("from B".utf8), format: "png", title: "B", note: "")
    let merged = InMemoryScreenshotKeyring(); merged.values = first.values.merging(second.values) { old, _ in old }
    let shots = library(merged, in: root)
    #expect(Set(try shots.list().screenshots.map(\.title)) == ["A", "B"])
    #expect(try shots.image(a.id) == Data("from A".utf8))
    #expect(try shots.image(b.id) == Data("from B".utf8))
    // Without the other Mac's key that file is reported, not shown and not fatal.
    let partial = try library(first, in: root).list()
    #expect(partial.screenshots.map(\.title) == ["A"])
    #expect(partial.unreadable == 1)
    // New files use the same key on every Mac (smallest id).
    #expect(try shots.currentKey().0 == merged.values.keys.min())
}

@Test func wrongKeyTamperingAndLimitsAreRefused() throws {
    let root = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: root) }
    let keyring = InMemoryScreenshotKeyring()
    let shots = library(keyring, in: root)
    let shot = try shots.add(image: Data("pixels".utf8), format: "png", title: "x", note: "")
    // Same key id, different key bytes: AES-GCM authentication fails.
    let id = try #require(keyring.values.keys.first)
    let forged = InMemoryScreenshotKeyring(); forged.values = [id: Data(repeating: 7, count: 32)]
    #expect(throws: (any Error).self) { try library(forged, in: root).image(shot.id) }
    // A flipped byte in the ciphertext is detected.
    let url = root.appendingPathComponent("\(shot.id.uuidString).image")
    var raw = try Data(contentsOf: url); raw[raw.count - 1] ^= 0xFF; try raw.write(to: url)
    #expect(throws: (any Error).self) { try shots.image(shot.id) }
    #expect(throws: SecretariatError.self) { try shots.add(image: Data(), format: "png", title: "", note: "") }
    #expect(throws: SecretariatError.self) {
        try shots.add(image: Data(count: ScreenshotLibrary.maximumBytes + 1), format: "png", title: "", note: "")
    }
}

@Test func iCloudPlaceholdersCountAsPendingAndTestHomesStayLocal() throws {
    let root = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: root) }
    let id = UUID().uuidString
    try Data().write(to: root.appendingPathComponent(".\(id).meta.icloud"))
    try Data().write(to: root.appendingPathComponent(".\(id).image.icloud"))
    let listing = try library(in: root).list()
    #expect(listing.pending == 1 && listing.screenshots.isEmpty && listing.unreadable == 0)
    #expect(throws: SecretariatError.self) { try library(in: root).image(UUID(uuidString: id)!) }

    let paths = AppPaths(directory: root.appendingPathComponent("vault"))
    let resolved = ScreenshotLibrary.resolve(paths: paths)
    #expect(resolved.location == .local)
    #expect(resolved.directory == paths.directory.appendingPathComponent("screenshots", isDirectory: true))
    #expect(paths.screenshotKeyService.hasPrefix("dev.moinsen.secretariat.screenshots.test."))
}
