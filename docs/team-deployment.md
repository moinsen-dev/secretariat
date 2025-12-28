# Secretariat Team Deployment Guide

This guide covers deploying Secretariat to your team for internal use on macOS.

## Quick Start

### One-Line Install (for team members)

```bash
# Clone and install
git clone <repo-url> secretariat && cd secretariat
./scripts/install.sh --build
```

### Manual Installation

1. **Build release binaries:**
   ```bash
   ./scripts/build-release.sh
   ```

2. **Install:**
   ```bash
   ./scripts/install.sh
   ```

3. **Add to PATH** (add to `~/.zshrc` or `~/.bashrc`):
   ```bash
   export PATH="$HOME/.local/bin:$PATH"
   ```

4. **Initialize vault:**
   ```bash
   sec init
   ```

## What Gets Installed

| Component | Location | Purpose |
|-----------|----------|---------|
| `secd` | `~/.local/bin/secd` | Background daemon |
| `sec` | `~/.local/bin/sec` | CLI tool |
| Secretariat.app | `/Applications/` | Desktop app (optional) |
| LaunchAgent | `~/Library/LaunchAgents/` | Auto-start daemon |
| Data | `~/Library/Application Support/Secretariat/` | Vault database, logs |

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Your Applications                      │
│  (Node.js, Python, Rust, Dart, or any language)          │
└─────────────────────┬───────────────────────────────────┘
                      │ SDK / CLI
                      ▼
┌─────────────────────────────────────────────────────────┐
│                   Unix Domain Socket                      │
│        ~/Library/Application Support/Secretariat/         │
│                   secretariat.sock                        │
└─────────────────────┬───────────────────────────────────┘
                      │ JSON-RPC 2.0
                      ▼
┌─────────────────────────────────────────────────────────┐
│                   Secretariat Daemon                      │
│                       (secd)                              │
├─────────────────────────────────────────────────────────┤
│  • AES-256-GCM encryption                                │
│  • Argon2id key derivation                               │
│  • Per-app permission control                            │
│  • Audit logging                                         │
└─────────────────────┬───────────────────────────────────┘
                      │
          ┌───────────┴───────────┐
          ▼                       ▼
┌──────────────────┐    ┌──────────────────┐
│  macOS Keychain  │    │   SQLCipher DB   │
│  (Master Key)    │    │   (Encrypted)    │
└──────────────────┘    └──────────────────┘
```

## CLI Commands

### Vault Management
```bash
sec init              # Initialize vault (first run)
sec status            # Show vault and daemon status
sec lock              # Lock vault (clears key from memory)
sec unlock            # Unlock vault with password
sec change-password   # Change master password
```

### Secret Management
```bash
sec list              # List all secrets
sec get <KEY>         # Get secret value
sec set <KEY> <VALUE> # Set secret value
sec delete <KEY>      # Delete secret
sec rotate <KEY>      # Rotate secret to new value
```

### App Permissions
```bash
sec apps              # List registered apps
sec grant <APP> <KEY> # Grant app access to secret
sec revoke <APP> <KEY># Revoke app access
sec explain <APP>     # Show what secrets app can access
```

### Import/Export
```bash
sec import .env       # Import from .env file
sec import --scan .   # Scan directory for .env files
sec audit             # View access log
```

## SDK Integration

### Node.js
```javascript
const { SecretariatClient } = require('@secretariat/node');

const client = new SecretariatClient();
await client.connect();

const apiKey = await client.get('OPENAI_API_KEY');
```

### Python
```python
from secretariat import SecretariatClient

client = SecretariatClient()
client.connect()

api_key = client.get('OPENAI_API_KEY')
```

### Dart/Flutter
```dart
import 'package:secretariat_sdk/secretariat_sdk.dart';

final client = SecretariatClient();
await client.connect();

final apiKey = await client.get('OPENAI_API_KEY');
```

### Rust
```rust
use secretariat_sdk::SecretariatClient;

let client = SecretariatClient::connect()?;
let api_key = client.get("OPENAI_API_KEY")?;
```

## Security Features

### Encryption
- **At Rest:** AES-256-GCM with SQLCipher
- **Key Derivation:** Argon2id (memory-hard)
- **Master Key:** Stored in macOS Keychain only

### Access Control
- Per-application permissions
- Audit logging of all access
- Auto-lock on system sleep

### Protection
- Failed attempt lockout (exponential backoff)
- Socket permissions (user-only: 0600)
- Memory cleared on lock

## Troubleshooting

### Daemon not starting
```bash
# Check daemon status
launchctl list | grep secretariat

# View logs
cat ~/Library/Application\ Support/Secretariat/daemon.log

# Manually start daemon
~/.local/bin/secd
```

### CLI can't connect
```bash
# Check if socket exists
ls -la ~/Library/Application\ Support/Secretariat/secretariat.sock

# Restart daemon
launchctl unload ~/Library/LaunchAgents/dev.moinsen.secretariat.daemon.plist
launchctl load ~/Library/LaunchAgents/dev.moinsen.secretariat.daemon.plist
```

### Forgot master password
The master password cannot be recovered. You'll need to:
1. Stop the daemon
2. Delete the vault: `rm ~/Library/Application\ Support/Secretariat/vault.db`
3. Delete the keychain entry: `security delete-generic-password -s dev.moinsen.secretariat.daemon`
4. Re-initialize: `sec init`

## Uninstalling

```bash
./scripts/install.sh --uninstall
```

This removes:
- Binaries (`secd`, `sec`)
- LaunchAgent
- Secretariat.app

Data is preserved at `~/Library/Application Support/Secretariat/`. To remove completely:
```bash
rm -rf ~/Library/Application\ Support/Secretariat/
```

## Configuration

The daemon uses sensible defaults. Optional configuration can be set via environment variables in the LaunchAgent plist:

| Variable | Default | Description |
|----------|---------|-------------|
| `RUST_LOG` | `info` | Log level (trace, debug, info, warn, error) |
| `SECRETARIAT_SOCKET_PATH` | (auto) | Custom socket path |

## Updating

```bash
cd secretariat
git pull
./scripts/install.sh --build
```

The install script handles stopping the old daemon and starting the new one.
