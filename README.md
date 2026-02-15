# Secretariat

**Local-first secrets manager to replace scattered `.env` files with one encrypted local vault.**

## Overview

Secretariat is a macOS-focused secrets platform with a Rust daemon, CLI, desktop app, MCP integration, and multi-language SDKs.

## Components

1. **Daemon (`secd`)**
- Rust background service
- Unix socket JSON-RPC
- SQLCipher-backed local vault
- Keychain-backed key handling

2. **CLI (`sec`)**
- Secret CRUD and rotation
- Vault lifecycle (`init`, `unlock`, `lock`, `status`)
- App/agent permission management

3. **Desktop App (`app/`)**
- Flutter desktop surface
- Contract-aware daemon client
- Unit/contract tests separated from opt-in integration tests

4. **MCP Server (`mcp-server/`)**
- TypeScript MCP tools for agent secret access
- Agent permission filtering and lock-state handling
- Dedicated tool tests

5. **SDKs**
- Node (`sdk-node/`)
- Python (`sdk-python/`)
- Dart (`sdk-dart/`)
- Rust (`sdk-rust/`)
- Go (`sdk-go/`)

## Quick Start

```bash
# Build Rust binaries
cargo build --workspace

# Start/boot daemon and inspect status
sec status
```

## Release Gate

Single command path for release validation:

```bash
make release-gate
```

or

```bash
./scripts/release-gate.sh
```

Gate documentation:

- `docs/release-gate.md`
- `docs/local-state-recovery.md`
- `Fixing-Plan-Tracker.md`

## Runtime Paths

Defaults:

- Database: `~/Library/Application Support/Secretariat/vault.db`
- Socket: `~/Library/Application Support/Secretariat/secretariat.sock`

Overrides:

- `SECRETARIAT_DB_PATH`
- `SECRETARIAT_SOCKET_PATH`
- `SECRETARIAT_SOCKET` (legacy alias)
- `SECRETARIAT_DATA_DIR`

## Project Structure

```text
secretariat/
├── daemon/
├── cli/
├── app/
├── mcp-server/
├── sdk-node/
├── sdk-python/
├── sdk-dart/
├── sdk-rust/
├── sdk-go/
├── tests/
└── docs/
```

## License

TBD
