import Foundation
import Testing
@testable import SecretariatCore

@Test func captureStoresTheValueWithDateTimeAndName() throws {
    let fixture = try AgentFixture(); defer { fixture.cleanup() }
    var parts = DateComponents(); parts.year = 2026; parts.month = 10; parts.day = 29; parts.hour = 14; parts.minute = 32
    let date = Calendar.current.date(from: parts)!
    let first = try Capture.save("  sk-ant-abc123secret\n", name: "Cloudflare Pulse", at: date, vault: fixture.vault)
    #expect(first.path == "inbox/cloudflare-pulse-2026-10-29-1432")
    #expect(first.source == "Clipboard · 2026-10-29 14:32")
    #expect(first.rotated == "2026-10-29")
    #expect(first.fields.map(\.kind) == [.personal])
    #expect(fixture.items.values[first.id] == ["value": "sk-ant-abc123secret"])
    // Same name in the same minute gets a counter; no name uses the time alone.
    #expect(try Capture.save("x", name: "Cloudflare Pulse", at: date, vault: fixture.vault).path == "inbox/cloudflare-pulse-2026-10-29-1432-2")
    #expect(try Capture.save("y", name: "", at: date, vault: fixture.vault).path == "inbox/2026-10-29-1432")
    #expect(Capture.name(of: first) == "cloudflare-pulse")
    #expect(Capture.capturedAt(first) == "2026-10-29 14:32")
    #expect(Capture.name(of: try Capture.save("z", name: "", at: date, vault: fixture.vault)) == "")
    #expect(throws: SecretariatError.self) { try Capture.save("  \n", name: "", vault: fixture.vault) }
}

@Test func capturePreviewHidesTheValueAndProviderIsGuessed() {
    #expect(Capture.preview("sk-ant-abc123secretvalue") == "sk-a… · 24 characters")
    #expect(Capture.preview("short") == "••••• · 5 characters")
    #expect(Capture.provider(for: "sk-ant-x") == "anthropic")
    #expect(Capture.provider(for: "sk-proj-x") == "openai")
    #expect(Capture.provider(for: "ghp_x") == "github")
    #expect(Capture.provider(for: "nothing") == nil)
}
