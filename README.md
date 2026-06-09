<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://secretariat.moinsen.dev/og-image.png">
  <img src="https://secretariat.moinsen.dev/og-image.png" alt="Secretariat — Der Secret-Vault für Mensch & KI" width="800">
</picture>

# Secretariat — Der Secret-Vault für Mensch & KI

> **Ein Vault. Mensch und KI. Nie wieder Secrets im Chat.**

[![License: BSL 1.1](https://img.shields.io/badge/License-BSL%201.1-blue)](LICENSE)
[![macOS](https://img.shields.io/badge/platform-macOS-black?logo=apple)](https://secretariat.moinsen.dev)
[![Rust](https://img.shields.io/badge/built%20with-Rust-orange?logo=rust)](https://www.rust-lang.org/)
[![Homebrew](https://img.shields.io/badge/brew-tap-green?logo=homebrew)](https://github.com/moinsen-dev/homebrew-tap)

---

## Wieso Secretariat?

```bash
# Vorher: Wo war der API-Key noch?
grep -r "sk-" ~/Documents/
cat ~/Projects/*/.env 2>/dev/null
# Oder schlimmer: Du gibst den Key deinem KI-Assistenten im Chat
# → Er taucht in der Prompt-History, in Exports, in Logs auf

# Nachher: Ein Befehl für Mensch & KI
sec get /openai/api-key
```

**Secretariat ist der erste Secret-Manager, der für die Zusammenarbeit von Menschen und KI-Agenten gebaut ist.** Ein gemeinsamer, lokaler Vault. API-Keys, Tokens, Zertifikate — einmal gespeichert, für beide abrufbar. **Das Secret erscheint nie im Chat, nie in Dateien, nie in Prompt-Exports.**

---

## Quick Start

```bash
# Install (macOS)
brew install moinsen-dev/tap/secretariat

# Oder aus Source bauen
cargo build --release

# Vault initialisieren (headless-fähig)
sec init --password "dein-passwort"

# Daemon starten (automatisch via LaunchAgent)
brew services start secretariat

# Erstes Secret speichern
sec set /github/token ghp_xxxxx

# Abrufen — für Mensch & KI
sec get /github/token

# Alle Secrets listen
sec list

# Aus .env importieren
sec import ~/project/.env
```

### Non-Interactive / Headless

```bash
# Initialisierung ohne Terminal
SECRETARIAT_INIT_PASSWORD="pass" sec init

# Unlock ohne Touch-ID
sec unlock --password-value "pass"
# oder via Env-Var:
SECRETARIAT_INIT_PASSWORD="pass" sec unlock
```

---

## Für KI-Agenten

Dein KI-Assistent (Claude, Codex, Hermes, o.ä.) kann Secrets direkt aus dem Vault laden:

```bash
# Der Agent ruft im Terminal auf:
sec get /deepseek/api-key
# → Output: Nur der Key in stdout. Nie im Chat. Nie in Dateien.
```

Damit:
- **Kein Secret** landet im Prompt-Kontext oder in Chat-Logs
- **Rotation** = ein `sec set` — der Agent holt beim nächsten Mal den neuen Key
- **Ein Vault** für dich und all deine Agenten

---

## Features

### 🛡️ Verschlüsselter Vault
AES-256-GCM, SQLCipher-Backend, Argon2id Key-Derivation. Master-Key per Passwort geschützt.

### ⚡ CLI + Daemon
`sec set`, `sec get`, `sec list`, `sec import`. Daemon (`secd`) läuft im Hintergrund, LaunchAgent Auto-Start.

### 🧑‍🤝‍🧑 Mensch + KI
Ein Vault für dich und deine Agenten. Das Secret erscheint nur im stdout des Terminal-Tools — nie im Chat oder in Dateien.

### 🔗 Multi-Device
Unix Socket (lokal) + TCP (Netzwerk). Auth-Token-geschützt. Zugriff vom Mac, Server, oder jedem Device im Netzwerk.

### 🐍 Python SDK
```python
from secretariat import Vault

vault = Vault()
db_password = vault.get("/postgres/password")
```

### 🦀 Rust Core
Daemon (`secd`) + CLI (`sec`) in einem Build. Schnell, speichersicher, kein GC.

### 🤖 Headless-fähig
Funktioniert auf headless Mac Minis und Servern. `--password`-Flag und `SECRETARIAT_INIT_PASSWORD`-Env-Var für Non-Interactive-Betrieb. Keychain-Timeout (3s) verhindert Hänger ohne GUI.

---

## Architektur

```
┌────────────────────────────────────────────────┐
│  CLI (sec)        │  SDKs (Python, Dart,        │
│                   │  Rust, Node.js)             │
├────────────────────────────────────────────────┤
│            Unix Socket / TCP (Port 7357)        │
├────────────────────────────────────────────────┤
│  Daemon (secd)    │  Auth-Token Auth            │
├────────────────────────────────────────────────┤
│  SQLCipher Vault  │  AES-256-GCM               │
├────────────────────────────────────────────────┤
│  macOS Keychain   │  File System                │
└────────────────────────────────────────────────┘
```

### Komponenten

| Component | Language | Location |
|-----------|----------|----------|
| Daemon (`secd`) | Rust | `daemon/` |
| CLI (`sec`) | Rust | `cli/` |
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

# Run daemon (foreground)
./target/release/secd

# Run CLI
./target/release/sec status
```

### Prerequisites
- Rust toolchain (1.75+)
- macOS (für Keychain-Integration)
- Optional: Flutter/Python/Node für SDK-Entwicklung

---

## License

**BSL 1.1** (Business Source License) — [view full terms](LICENSE)

- ✅ Code is **publicly visible** — auditable, verifiable
- ✅ **Self-host for free** — unlimited users, unlimited secrets
- ✅ **Modify and redistribute** — fork, patch, improve
- ❌ **Don't resell as a competing cloud service**
- 🔄 **Becomes Apache 2.0 on 2029-01-01**

---

## Community

- **Website:** [secretariat.moinsen.dev](https://secretariat.moinsen.dev)
- **GitHub Issues:** Bug reports, feature requests
- **Email:** [uli@moinsen.dev](mailto:uli@moinsen.dev)

Built with ❤️ by [Moinsen Development Hamburg](https://moinsen.dev)
