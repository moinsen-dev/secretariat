# Secretariat

**Local-first secrets manager that eliminates .env files entirely.**

One encrypted vault on your machine. All your API keys in one place. Every project just works.

## Overview

Secretariat is a macOS-native secrets management solution designed for developers who work on multiple projects and are tired of managing dozens of scattered .env files.

**Tagline:** Stop copy-pasting API keys.

## Phase 1 Architecture

### Components

1. **Daemon (secd)** - Rust background service
   - Runs on macOS boot via launchd
   - Encrypted SQLite database (SQLCipher)
   - Unix socket IPC
   - AES-256-GCM encryption
   - Master key in macOS Keychain

2. **CLI (sec)** - Rust command-line tool
   - Full secret management (create, read, update, delete, rotate)
   - Application permission management
   - Import wizard for .env files
   - Audit log viewer
   - Human-readable and JSON output formats

3. **macOS Menu Bar App** - SwiftUI application
   - Quick access to secrets
   - Search and filter
   - Copy to clipboard with auto-clear
   - Drag & drop .env import
   - Application permissions manager
   - First-run onboarding

4. **SDKs** - Client libraries for 4 languages
   - **Dart SDK** - Flutter/Dart applications
   - **Python SDK** - Sync and async APIs
   - **Rust SDK** - Zero-cost abstractions
   - **Node.js SDK** - TypeScript types included

## Quick Start

### Installation

```bash
# Run setup script
./init.sh
```

This will:
- Check prerequisites (Rust, Xcode, Node.js, Python, Dart)
- Create project structure
- Set up Cargo workspace for Rust components
- Configure SDK packages

### Development

```bash
# Build Rust components (daemon, CLI, SDK)
cargo build

# Run daemon
cargo run --bin secd

# Run CLI
cargo run --bin sec -- --help

# View features to implement
autocoder-db stats --project $(pwd)
autocoder-db next --project $(pwd)
```

## Project Structure

```
secretariat/
├── daemon/          # Rust daemon (secd)
├── cli/             # Rust CLI (sec)
├── app/             # SwiftUI Menu Bar App (Xcode project)
├── sdk-dart/        # Dart SDK
├── sdk-python/      # Python SDK
├── sdk-rust/        # Rust SDK
├── sdk-node/        # Node.js SDK
└── docs/            # Documentation
```

## Security Features

- **Encryption at Rest**: All secrets encrypted with AES-256-GCM
- **Master Key Protection**: Key stored in macOS Keychain, never on disk
- **Access Control**: Per-app, per-secret authorization
- **Audit Trail**: Complete log of all secret access
- **Touch ID Support**: Biometric authentication for vault unlock
- **Auto-lock**: Configurable timeout and system sleep triggers

## Data Locations

- **Database**: `~/Library/Application Support/Secretariat/vault.db`
- **Socket**: `~/Library/Application Support/Secretariat/secretariat.sock`
- **Logs**: `~/Library/Logs/Secretariat/`
- **Preferences**: `~/Library/Preferences/dev.moinsen.secretariat.plist`

## Features Database

This project uses autocoder-db for feature tracking:

```bash
# View statistics
autocoder-db stats --project $(pwd)

# List all features
autocoder-db list --project $(pwd)

# Search features
autocoder-db search --project $(pwd) <query>

# View session logs
autocoder-db log list --project $(pwd)

# Get next features to implement
autocoder-db next --project $(pwd)
```

## Development Status

**Initialization Complete** ✓

- [x] Project structure created
- [x] Feature database populated (770+ features)
- [x] Build configuration set up
- [x] Documentation created

**Next Steps:**

1. Implement daemon core (storage, crypto, IPC server)
2. Implement CLI commands
3. Create macOS menu bar app in Xcode
4. Develop SDK client libraries
5. Create import wizard for .env migration

## Success Criteria (Phase 1)

### Functional
- Daemon runs stably for 24+ hours
- All CLI commands work correctly
- Menu bar app is responsive
- SDKs connect and retrieve secrets
- Import wizard successfully migrates .env files

### Performance
- Secret retrieval < 10ms
- Daemon memory < 50MB
- App launch < 500ms
- CLI response < 100ms

### Security
- Secrets never written in plaintext to disk
- Master key protected by Keychain
- Audit log captures all access
- Revocation is immediate

### User Experience
- Onboarding completes in < 5 minutes
- Import wizard handles 90% of .env files
- Search finds secrets instantly
- Copy-to-clipboard works reliably

## Technology Stack

- **Platform**: macOS only (Phase 1)
- **Daemon & CLI**: Rust
- **Menu Bar App**: Swift/SwiftUI
- **Database**: SQLite with SQLCipher encryption
- **IPC**: Unix domain sockets
- **Encryption**: AES-256-GCM
- **Key Storage**: macOS Keychain

## Out of Scope (Phase 1)

- Cloud sync / team features
- AI agent access control
- MCP server integration
- Windows/Linux support
- Mobile support
- Browser extension

## License

TBD

## Contact

TBD
