<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://secretariat.moinsen.dev/og-image.png">
  <img src="https://secretariat.moinsen.dev/og-image.png" alt="Secretariat — Local-First Secrets Manager" width="800">
</picture>

# Secretariat — Local-First Secrets Manager

> **Stop copy-pasting API keys.** One encrypted vault on your machine. All your secrets in one place.

[![License: BSL 1.1](https://img.shields.io/badge/License-BSL%201.1-blue)](LICENSE)
[![macOS](https://img.shields.io/badge/platform-macOS-black?logo=apple)](https://secretariat.moinsen.dev)
[![Rust](https://img.shields.io/badge/built%20with-Rust-orange?logo=rust)](https://www.rust-lang.org/)
![Build](https://img.shields.io/badge/build-passing-brightgreen)

---

## Why Secretariat?

```bash
# Before: Where was that API key again?
grep -r "sk-" ~/Documents/
cat ~/Projects/*/.env 2>/dev/null
# "I'll just regenerate it..." (famous last words)

# After:
secret get /openai/api-key
```

Every developer knows the pain: API keys in `.env` files. Tokens in terminal history. Certificates spread across three machines. Then the `.env` gets committed to GitHub by accident, and you're rotating keys at 2 AM.

**Secretariat fixes this.** One command to store, one to retrieve. Every project, every machine, every time.

---

## Quick Start

```bash
# Install (macOS)
brew tap moinsen-dev/tap
brew install secd

# Initialize your vault
secretd init

# Store your first secret
secret set /github/token ghp_xxxxx

# Retrieve it
secret get /github/token

# List all secrets
secret list

# Import from .env
secret import ~/project/.env

# Export for backup
secret export > backup.json
```

> **No running daemon?** `secret` auto-starts one via LaunchAgent. `secretd` stays in the background, zero-footprint.

---

## Features

### 🛡️ Encrypted Vault
AES-256-GCM encryption, SQLCipher backend. Master key in macOS Keychain — never on disk.

### ⚡ CLI-First
`secret set`, `secret get`, `secret list`, `secret import`, `secret export`. Tab-completion included.

### 🔗 Multi-Device
TCP transport with auth-token security. Access your vault from your main Mac, dev server, or any machine on your network.

### 🐍 Python SDK
```python
from secretariat import Vault

vault = Vault()
db_password = vault.get("/postgres/password")
```

### 🦀 Rust Core
Daemon + CLI in a single Rust binary. Fast, memory-safe, zero GC pauses.

### 🔁 LaunchAgent Auto-Start
Daemon starts with your Mac, ready when you are. No manual setup.

---

## Pricing

| Tier | Features | Price |
|------|----------|-------|
| **Free** 🆓 | Local vault, CLI, SDK, TCP multi-device, LaunchAgent | €0 |
| **Pro** 🔐 | + Cloud Sync, Web UI, Auto-Backup, IDE Plugins | €4/mo |
| **Team** 👥 | + Team Vaults, Audit Log, Granular Permissions, SSO | €12/user/mo |
| **Enterprise** 🏢 | + Self-hosted server, SLA, Custom integrations | Custom |

> **Self-hosting is always free.** The BSL license allows unlimited self-hosted use of all features, including Team-tier. You only pay when you use our cloud services.

---

## License

**BSL 1.1** (Business Source License) — [view full terms](LICENSE)

- ✅ Code is **publicly visible** — auditable, verifiable
- ✅ **Self-host for free** — unlimited users, unlimited secrets
- ✅ **Modify and redistribute** — fork, patch, improve
- ❌ **Don't resell as a competing cloud service** — that's what the BSL prevents
- 🔄 **Becomes Apache 2.0 on 2029-01-01** — fully open source after 3 years

We chose BSL over MIT because: if we gave everything away MIT-style, someone could clone Secretariat Cloud and sell it for €2. With BSL, the code is open and auditable, but the business model is protected. **Fair for everyone.**

---

## Architecture

```
┌─────────────────────────────────────────────┐
│  CLI (secret)         │  SDKs (Python, Dart,  │
│                       │  Rust, Node.js)       │
├─────────────────────────────────────────────┤
│              Unix Socket / TCP               │
├─────────────────────────────────────────────┤
│  Daemon (secretd)     │  Auth-Token Auth      │
├─────────────────────────────────────────────┤
│  SQLCipher Vault      │  AES-256-GCM          │
├─────────────────────────────────────────────┤
│  macOS Keychain       │  File System          │
└─────────────────────────────────────────────┘
```

### Components

| Component | Language | Location |
|-----------|----------|----------|
| Daemon (`secretd`) | Rust | `daemon/` |
| CLI (`secret`) | Rust | `cli/` |
| macOS Menu Bar App | SwiftUI | `app/` |
| Python SDK | Python | `sdk-python/` |
| Rust SDK | Rust | `sdk-rust/` |
| Dart SDK | Dart | `sdk-dart/` |
| Node.js SDK | TypeScript | `sdk-node/` |
| Website | HTML/CSS | `website/` |

---

## Development

```bash
# Clone
git clone https://github.com/moinsen-dev/secretariat.git
cd secretariat

# Build
cargo build --release

# Run daemon (development)
cargo run --bin secretd -- --tcp-port 7357 --auth-token "dev-token"

# Run CLI
cargo run --bin secret -- status --host 127.0.0.1 --auth-token "dev-token"
```

### Prerequisites
- Rust toolchain (1.75+)
- Xcode Command Line Tools (for macOS Keychain)
- Optional: Flutter/Python/Node for SDK development

---

## Roadmap

See [secretariat.moinsen.dev/v2.html](https://secretariat.moinsen.dev/v2.html) for the full V2 vision.

**V1** ✅ — Local vault, CLI, SDK, TCP multi-device, LaunchAgent
**V2** 🔜 — Cloud sync, Web UI, team sharing, IDE plugins, audit log

---

## Community

- **Website:** [secretariat.moinsen.dev](https://secretariat.moinsen.dev)
- **GitHub Issues:** Bug reports, feature requests
- **Email:** [uli@moinsen.dev](mailto:uli@moinsen.dev)

Built with ❤️ by [Moinsen Development Hamburg](https://moinsen.dev)
