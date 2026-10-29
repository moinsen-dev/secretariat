import CoreGraphics
import CoreText
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import SecretariatCore

/// Artificial key with dash and underscore.
private let fakeKey = "sk-ant-api-Xq7_zR4-fakeKEY9tesT8Zz"
/// The same with O/0 and l/1, which text recognition mixes up.
private let lookAlikeKey = "sk-ant-api03-O0l1_xQ7-fakeKEY9test4Zz"

/// A PNG like a console page: dark text on white, the key in a monospaced font.
private func renderedScreenshot(_ lines: [(String, String)]) throws -> Data {
    let width = 1200, height = 80 + lines.count * 70
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    for (index, (text, fontName)) in lines.enumerated() {
        let font = CTFontCreateWithName(fontName as CFString, 30, nil)
        let attributed = NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 0, green: 0, blue: 0, alpha: 1)])
        context.textPosition = CGPoint(x: 40, y: height - 70 - index * 70)
        CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
    }
    let output = NSMutableData()
    let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    #expect(CGImageDestinationFinalize(destination))
    return output as Data
}

/// Vision on the Neural Engine fails when two recognitions run at once in the test process (e5rt error 13).
@Suite(.serialized) struct TextRecognition {
    @Test func textRecognitionReadsAKeyExactly() throws {
        let image = try renderedScreenshot([("Anthropic Console · API keys", "Helvetica"), ("Name: pulse-readonly", "Helvetica"),
                                            ("Key: \(fakeKey)", "Menlo")])
        let lines = try ScreenshotReading.recognizeText(in: image)
        #expect(ScreenshotReading.tokens(lines).contains(fakeKey), "\(lines)")
        #expect(!ScreenshotReading.hasLookAlikes("ab-3456_789") && ScreenshotReading.hasLookAlikes("fakeKEY"))
        // Look-alikes may come back swapped (measured: O0l1 read as 0011): same length, and the dialog asks to compare.
        let mixed = ScreenshotReading.tokens(try ScreenshotReading.recognizeText(in: try renderedScreenshot([("Key: \(lookAlikeKey)", "Menlo")])))
        let read = mixed.first { $0.hasPrefix("sk-ant-") }
        #expect(read?.count == lookAlikeKey.count)
        #expect(ScreenshotReading.hasLookAlikes(read ?? ""))
        #expect(throws: SecretariatError.self) { try ScreenshotReading.recognizeText(in: Data("no image".utf8)) }
    }

    @Test func withoutModelTheKeyPrefixFillsTheItem() async throws {
        let image = try renderedScreenshot([("Anthropic Console · API keys", "Helvetica"), ("Key: \(fakeKey)", "Menlo")])
        let suggestion = try await ScreenshotReading.read(image, catalog: .builtin, environment: [ScreenshotReading.noModelVariable: "1"])
        #expect(suggestion.template == "api")
        #expect(suggestion.provider == "anthropic")
        #expect(suggestion.fields == ["api_key": fakeKey])
        #expect(suggestion.method == .textOnly("local model turned off"))
        // No key in the picture: a clear message instead of an empty dialog, and the message carries no recognized text.
        let plain = try renderedScreenshot([("Weekly team meeting notes", "Helvetica")])
        await #expect(throws: SecretariatError.self) {
            try await ScreenshotReading.read(plain, catalog: .builtin, environment: [ScreenshotReading.noModelVariable: "1"])
        }
    }
}

@Test func heuristicPicksPrefixFirstThenLongestKeyLikeToken() {
    let lines = ["Settings", "token: abcdefghij0123456789abcdefXYZ", "ghp_abcdefghijklmnop1234", "export OPENAI_API_KEY=…"]
    let prefixed = ScreenshotReading.heuristic(lines, catalog: .builtin)
    #expect(prefixed?.provider == "github")
    #expect(prefixed?.fields["api_key"] == "ghp_abcdefghijklmnop1234")
    #expect(prefixed?.fields["env_var"] == "OPENAI_API_KEY")
    let unknown = ScreenshotReading.heuristic(["id 42", "a1b2c3d4e5f6g7h8i9j0k1", "x9y8z7w6v5u4t3s2r1q0p9o8n7"], catalog: .builtin)
    #expect(unknown?.provider == "")
    #expect(unknown?.fields["api_key"] == "x9y8z7w6v5u4t3s2r1q0p9o8n7")
    // Addresses, mail addresses and plain words are no keys.
    #expect(ScreenshotReading.heuristic(["https://example.com/a1b2c3d4e5f6g7h8i9", "someone1234567890@example.com", "Hello world"],
                                        catalog: .builtin) == nil)
}

@Test func modelValuesMustAppearInTheText() {
    let lines = ["Cloudflare dashboard", "Access service token: pulse-readonly", "Client ID 1a2b3c4d.access", "Client Secret",
                 "f00dbabe1234deadbeef5678cafe9012"]
    let guess = ScreenshotReading.Guess(template: "token", provider: "cloudflare", label: "pulse-readonly",
                                        fields: ["client_id": "1a2b3c4d.access", "client_secret": "f00dbabe1234deadbeef5678cafeXXXX",
                                                 "invented": "x", "env_var": "NOT_IN_TEMPLATE"])
    let suggestion = ScreenshotReading.ground(guess, in: lines, fallback: ScreenshotReading.heuristic(lines, catalog: .builtin), catalog: .builtin)
    #expect(suggestion.template == "token")
    #expect(suggestion.provider == "cloudflare")
    #expect(suggestion.label == "pulse-readonly")
    // The mistyped secret is replaced by the recognized word it starts like; unknown fields are dropped.
    #expect(suggestion.fields == ["client_id": "1a2b3c4d.access", "client_secret": "f00dbabe1234deadbeef5678cafe9012"])
    #expect(suggestion.method == .localModel)
}

@Test func modelGuessesTheTextDoesNotBackAreDropped() {
    let lines = ["Key: \(fakeKey)"]
    let fallback = ScreenshotReading.heuristic(lines, catalog: .builtin)
    // Unknown template, invented provider and label, an invented value: kept is only what the text says.
    let guess = ScreenshotReading.Guess(template: "bank-account", provider: "acme", label: "production",
                                        fields: ["api_key": "totally-invented-value-0000"])
    let suggestion = ScreenshotReading.ground(guess, in: lines, fallback: fallback, catalog: .builtin)
    #expect(suggestion.template == "api")
    #expect(suggestion.provider == "anthropic")
    #expect(suggestion.label == "")
    #expect(suggestion.fields == ["api_key": fakeKey])
    // The capture template is never suggested.
    #expect(ScreenshotReading.ground(.init(template: "capture"), in: lines, fallback: fallback, catalog: .builtin).template == "api")
}

@Test func keyWrappedOverTwoLinesIsJoined() {
    let lines = ["API key", "sk-proj-abcdefghij", "klmnopqrstuv0123"]
    let guess = ScreenshotReading.Guess(template: "api", provider: "openai",
                                        fields: ["api_key": "sk-proj-abcdefghij klmnopqrstuv0123"])
    let suggestion = ScreenshotReading.ground(guess, in: lines, fallback: nil, catalog: .builtin)
    #expect(suggestion.fields["api_key"] == "sk-proj-abcdefghijklmnopqrstuv0123")
    // "openai" is not in the text and no prefix backs it without the heuristic: no provider.
    #expect(suggestion.provider == "")
}

extension TextRecognition {
    /// The real on-device model: not deterministic across OS versions, so only on request (SECRETARIAT_MODEL_TEST=1).
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SECRETARIAT_MODEL_TEST"] == "1"))
    func localModelSortsAConsoleScreenshot() async throws {
        let image = try renderedScreenshot([("Anthropic Console", "Helvetica-Bold"), ("Settings › API keys", "Helvetica"),
                                            ("Name: pulse-readonly", "Helvetica"), ("Key: \(fakeKey)", "Menlo")])
        let suggestion = try await ScreenshotReading.read(image, catalog: .builtin, environment: [:])
        #expect(suggestion.method == .localModel)
        #expect(suggestion.template == "api")
        #expect(suggestion.provider == "anthropic")
        #expect(suggestion.fields["api_key"] == fakeKey)
    }
}

@Test func cutShortOrAmbiguousSecretsAndLooseNamesAreNotTaken() {
    let lines = ["Stripe API keys", "Publishable pk_live_1234567890abcdef", "Secret sk_live_51Habcdefghijklmnop0987"]
    let fallback = ScreenshotReading.heuristic(lines, catalog: .builtin)
    // The model gave only the start of the key: the whole recognized word is taken.
    let cut = ScreenshotReading.ground(.init(template: "api", provider: "stripe", fields: ["api_key": "sk_live_51Habc"]),
                                       in: lines, fallback: nil, catalog: .builtin)
    #expect(cut.fields["api_key"] == "sk_live_51Habcdefghijklmnop0987")
    #expect(cut.provider == "stripe")
    // Provider and label must stand as words: "a", "api" inside "rapid", or one the text doesn't name, are dropped.
    let loose = ScreenshotReading.ground(.init(template: "api", provider: "pi", label: "key"), in: ["rapid setup", "monkey"],
                                         fallback: nil, catalog: .builtin)
    #expect(loose.provider == "")
    #expect(loose.label == "")
    // Identifier values must stand as words too.
    let partial = ScreenshotReading.ground(.init(template: "server", fields: ["host": "ample", "user": "deploy"]),
                                           in: ["host example.com", "user deploy"], fallback: nil, catalog: .builtin)
    #expect(partial.fields == ["user": "deploy"])
    // Two keys with the same beginning: a mistyped value matches both and is dropped.
    let twins = ["sk-proj-abcdefgh1111111111", "sk-proj-abcdefgh2222222222"]
    #expect(ScreenshotReading.groundSecret("sk-proj-abcdefgh3333333333", words: twins) == nil)
    // The prefix key goes only into the kind the prefixes chose, never into another kind's password.
    let login = ScreenshotReading.ground(.init(template: "login", fields: ["username": "Secret"]), in: lines,
                                         fallback: fallback, catalog: .builtin)
    #expect(login.template == "login")
    #expect(login.fields["password"] == nil)
    #expect(fallback?.fields["api_key"] == "pk_live_1234567890abcdef" || fallback?.fields["api_key"] == "sk_live_51Habcdefghijklmnop0987")
}
