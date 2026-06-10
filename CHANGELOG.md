# Changelog

## v0.3.0 (2026-06-10) — Multi-Device Sync

🔐 **End-to-end-encrypted secret sync across your Apple devices (macOS).**

### Features
- **iCloud sync:** Secrets now sync across your Macs through your private
  iCloud Drive. Only the AES-256-GCM ciphertext + salt leave the device —
  the master password and key never do. Apple only ever sees ciphertext.
- **Sync protocol (daemon):** `sync.export` / `sync.import` with tombstones
  and last-write-wins conflict resolution; moves ciphertext only, no unlock
  required.
- **Instant sync:** an iCloud file-change watcher (NSMetadataQuery) syncs
  immediately when another device pushes; 30s background poll as a backstop.
- **`sec service install`:** installs the daemon as a Launch Agent so it
  auto-starts on login (the sandboxed app can't, by design).

### Changed
- **macOS app is now sandboxed** (required for iCloud). The daemon's Unix
  socket moved to the shared App Group container
  (`group.dev.moinsen.secretariat`); the daemon stays unsandboxed and runs
  via the Launch Agent. Vault DB remains in Application Support.

### Fixes (since v0.2.0 draft)
- Onboarding now detects an existing vault and shows unlock instead of
  re-creating; readable/copyable error messages; honest password checklist;
  scrollable onboarding; real app icon.
- Add-secret FAB (was hidden behind the debug ribbon); edit-mode crash
  ("obscured fields cannot be multiline"); serialized socket writes
  (fixed "StreamSink is bound to a stream" on launch).

## v0.2.0 (2026-06-10) — App Stability

🛠️ **Reliability pass on the macOS app — connection handling, value loading, and UI polish.**

### Fixes
- **Daemon client:** Persistent response dispatcher + race guards — no more dropped/mismatched responses under concurrent requests
- **VaultProvider:** Re-entrant guard on `connect()` + `isClosed` check to prevent double-connect and use-after-close
- **Socket:** Heartbeat keeps the Unix-socket connection alive; fixed value loading and async-safety edge cases
- **UI:** `ListTile` colors corrected; red error SnackBars replaced with copy-to-clipboard for actionable error messages
- **Password rules:** UI now aligned with CLI/daemon validation

### Infrastructure
- **Release:** New `build-release.sh` pipeline — universal binary, Developer ID signing, Apple notarization, DMG packaging — plus `RELEASE.md` runbook

## v0.1.1 (2026-06-09) — Homebrew Release

🧪 **First Homebrew release with per-arch binary artifacts.**

### Changes
- **CI/CD:** Rewrote build matrix to produce per-architecture tarballs (`darwin-arm64`, `darwin-x86_64`, `linux-x86_64`) with SHA256 checksums
- **CI/CD:** Release workflow now attaches individual archives for Homebrew ingestion
- **Infrastructure:** Homebrew formula added to `moinsen-dev/homebrew-tap` — `brew install moinsen-dev/tap/secretariat`

### Infrastructure
- **Website:** Moved from local Docker/Nginx (port 8082) to GitHub Pages — `secretariat.moinsen.dev` served from `moinsen-dev/secretariat/website/`
- **Cleanup:** Removed `docker-compose.yml` — no more local server dependency
- **CI:** Added `pages.yml` workflow for automatic website deployment on push to `main`

## v0.1.0 (2026-06-09) — Initial Release

🚀 **First public release of Secretariat — Local-First Secrets Manager.**

### Features
- **Daemon (`secretd`):** AES-256-GCM encrypted vault via SQLCipher, macOS Keychain integration, Unix socket IPC, TCP transport with auth-token, LaunchAgent auto-start
- **CLI (`secret`):** `get`, `set`, `list`, `delete`, `import`, `export`, `init`, `status` — full lifecycle management
- **Python SDK:** Async/await Python client with TCP transport
- **Multi-Device:** TCP server with auth-token authentication, optional TLS
- **Keychain Timeout:** 3-second timeout for headless operation

### Known Limitations
- macOS only (Linux/Windows support planned for V2)
- No cloud sync yet (V2)
- No web UI (V2)
- No team sharing (V2)
