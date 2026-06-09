# Changelog

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
