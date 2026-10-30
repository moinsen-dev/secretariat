# Secretariat

Your coding agents use your keys. They don't get to read them.

Secretariat is a native Mac app with a command line tool. API keys live in your iCloud keychain; Claude Code, Codex, OpenCode and other agents start your tools through `secretariat run`, so the program gets the values and the agent sees `[masked]`. It also captures keys from the clipboard or a screenshot, guards commits and agent commands, hands MCP tokens to Claude Code without plain text, logs who used which key, and backs up everything sealed to a recovery key only you hold.

Website, download and price: <https://secretariat.moinsen.dev> · What it protects and what it doesn't: [threat model](https://secretariat.moinsen.dev/threat-model.html)

## Why the source is public

So you can check what a tool that holds your keys actually does, instead of taking our word for it.

- **Code:** `Sources/SecretariatCore` (vault, keychain, CLI, masking, guard, history, backup) and `Sources/Secretariat` (the app).
- **Tests:** `Tests/SecretariatCoreTests`. Run them with `xcrun swift test` (Xcode's toolchain; a swift.org toolchain on the PATH lacks the macOS frameworks).
- **How each feature was checked:** `PLAN.md` lists requirements and acceptance criteria, `TRACKER.md` the evidence per task. The evidence reports (`docs/t0xx-evidence.md`) say what was run and observed, including what was *not* tested. New features are reviewed by a separate reviewer agent with a fresh context before release; its findings and our fixes are in `docs/review-*.md`. These are our own checks, not an outside audit.
- **Releases:** `docs/release-*.md` record build, notarization and distribution for each version.

## License

Source-available under the [PolyForm Strict License 1.0.0](LICENSE.md): you may read and audit the code and use it for noncommercial purposes. You may not distribute it or make modified versions. Commercial use needs a [Secretariat license](https://secretariat.moinsen.dev/#pricing), which also gets you the signed, notarized build and all 1.x updates.

Building from source as-is will not get you a working app: keychain access, iCloud sync and the CLI inside the bundle depend on the developer's signing identity and provisioning profile.

## Made by

Ulrich Diedrichsen, Hamburg · business@moinsen.dev · <https://www.moinsen.dev>

Found a security problem? Please write to business@moinsen.dev before opening a public issue.
