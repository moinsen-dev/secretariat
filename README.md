<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://secretariat.moinsen.dev/og-image.png">
  <img src="https://secretariat.moinsen.dev/og-image.png" alt="Secretariat — Secrets deine KI nutzen, aber nie sehen kann" width="800">
</picture>

# Secretariat

> **Secrets, die deine KI *nutzen*, aber nie *sehen* kann.**
> Keine `.env`-Dateien. Keine Keys im Chat. Kein „darf ich mal kurz den API-Key?".

[![License: BSL 1.1](https://img.shields.io/badge/License-BSL%201.1-blue)](LICENSE)
[![macOS](https://img.shields.io/badge/platform-macOS-black?logo=apple)](https://secretariat.moinsen.dev)
[![Rust](https://img.shields.io/badge/built%20with-Rust-orange?logo=rust)](https://www.rust-lang.org/)

---

## Das Problem im Zeitalter des Agentic Coding

Deine KI baut, deployt, testet — und braucht ständig Credentials. Heute heißt das:

```bash
# Secrets liegen im Klartext herum…
cat .env                     # OPENAI_API_KEY=sk-...
grep -r "sk-" ~/Projects/    # über zig Projekte verstreut

# …und landen im KI-Kontext, sobald der Agent sie „braucht":
#   → in der Prompt-History, in Session-Exports, in Logs, in Tool-Outputs.
```

Entweder du **vertraust der KI nicht** (und tippst jeden Key von Hand) — oder du **vertraust ihr zu viel** (und dein Stripe-Key liegt in einem Transcript).

## Die Lösung: asymmetrischer Zugriff

Secretariat gibt Mensch und KI **unterschiedliche Fähigkeiten am selben Vault**:

| | Mensch | KI-Agent |
|---|:---:|:---:|
| Werte **lesen** | ✅ (Touch ID) | ❌ **nie** |
| Secrets **benutzen** (in Prozesse injizieren) | ✅ | ✅ |
| Secrets **anlegen** (auch generiert) | ✅ | ✅ |
| Namen **auflisten** | ✅ | ✅ |
| Audit-Log lesen | ✅ | ✅ |

Klartext existiert nur **im Daemon-Speicher** und **in der Umgebung des Zielprozesses** — nie in einer Datei, nie im Kontext der KI. Das ist keine Policy, das ist im Protokoll verankert: **es gibt kein Tool, das einen Wert zurückgibt.**

---

## Die drei Befehle, die alles ändern

### 1. `sec run` — Secrets benutzen, ohne sie zu sehen

```bash
sec run -- npm run dev
```

Injiziert die Secrets aus `.secretariat.toml` (committable, enthält **nur Namen**) in die Umgebung des Kindprozesses. Output wird **redaktiert**: taucht ein Wert in stdout/stderr auf, wird er zu `[REDACTED:NAME]`. Selbst ein versehentliches `console.log(apiKey)` leakt nichts.

```toml
# .secretariat.toml  — sicher zu committen
[secrets]
OPENAI_API_KEY = "OPENAI_API_KEY"
DATABASE_URL   = "myapp/db_url"
```

### 2. `sec mcp` — der MCP-Server für KI-Agenten

```jsonc
// .mcp.json  (Claude Code / Codex / jeder MCP-Client)
{ "mcpServers": { "secretariat": { "command": "sec", "args": ["mcp"] } } }
```

Stellt vier bewusst **asymmetrische** Tools bereit:
`list_secret_names` · `run_with_secrets` (Befehl ausführen + injizieren + Output redaktieren) · `set_secret` (write-only; `generate: true` erzeugt einen starken Zufallswert serverseitig, der **nie** in den KI-Kontext gelangt) · `read_audit`.
**Kein** `get_value` — by design.

### 3. `sec import --eradicate` — raus aus dem .env-Zeitalter

```bash
sec import . --scan --eradicate
```

Importiert alle Secrets, schreibt das committable Manifest, ergänzt `.gitignore`, **überschreibt + löscht** die `.env`-Dateien und **scannt** das Projekt nach Klartext-Resten (zeigt Datei + KEY, nie den Wert). Eine Datei wird nur gelöscht, wenn **jeder** Wert daraus nachweislich im Vault liegt.

---

## Quick Start

```bash
# Bauen
cargo build --release

# Daemon als Hintergrund-Dienst installieren (signiert → keine Dauer-Prompts)
sec service install

# Vault initialisieren + entsperren
sec init                 # fragt nach Master-Passwort
sec unlock

# Migrieren + loslegen
sec import . --scan --eradicate
sec run -- npm run dev
```

---

## Sicherheitsmodell

- **E2E-verschlüsselter Multi-Device-Sync** über deine private iCloud — nur Chiffrat (AES-256-GCM) + Salt verlassen das Gerät, das Master-Passwort nie. Alle deine Macs teilen einen Vault.
- **Peer-Attestation:** der Daemon identifiziert den verbindenden Prozess über die Socket-Identität (PID → Pfad → Code-Signatur), nicht über eine selbst-behauptete ID. Mit `SECRETARIAT_REQUIRE_SIGNED` bekommen nur signierte Erst-Anbieter-Binaries Zugriff.
- **Sandboxed App + Touch-ID-Unlock:** die macOS-App ist sandboxed; der Daemon-Socket liegt im geteilten App-Group-Container. Quick-Insert per System-Shortcut entsperrt via Touch ID.
- **Krypto:** Argon2id-Key-Derivation, AES-256-GCM, geteilter Rust-Core (`secretariat-core`) für byte-identische Krypto auf allen Plattformen.

---

## Architektur

```
  Mensch:  macOS-App (sandboxed) · sec CLI · System-Shortcuts (Touch ID)
  KI:      sec mcp (MCP)         · sec run

                    ▼  App-Group Unix-Socket (JSON-RPC, peer-attested)

  Daemon (secd, Rust)  ── Argon2id + AES-256-GCM ── SQLCipher-Vault
        │
        └── E2E-verschlüsselte iCloud-Sync-Datei  ⇄  deine anderen Macs
```

| Komponente | Sprache | Ort |
|---|---|---|
| Daemon (`secd`) | Rust | `daemon/` |
| CLI (`sec`) — run, mcp, import, service | Rust | `cli/` |
| Krypto-Core (FFI-fähig) | Rust | `core/` |
| macOS-App (sandboxed, App Intents) | Flutter/Swift | `app/` |
| SDKs | Python · Dart · Rust · Node | `sdk-*/` |

---

## License

**BSL 1.1** — Code öffentlich & auditierbar, self-host frei, kein Resale als konkurrierender Cloud-Dienst. Wird am **2029-01-01** zu Apache 2.0.

Built with ❤️ by [Moinsen Development Hamburg](https://moinsen.dev) · [uli@moinsen.dev](mailto:uli@moinsen.dev)
