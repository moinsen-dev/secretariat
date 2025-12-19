# Getting Started with Secretariat

Secretariat is a local-first secrets manager that eliminates .env files entirely.
One encrypted vault on your machine. All your API keys in one place. Every project just works.

## Installation (macOS)

### Option 1: Homebrew (Recommended)

```bash
# Install Secretariat
brew install secretariat

# Verify installation
sec version
```

### Option 2: Download from GitHub

1. Download the latest release from [GitHub Releases](https://github.com/secretariat/secretariat/releases)
2. Move `Secretariat.app` to `/Applications`
3. Launch the app - the daemon starts automatically

### Option 3: Build from Source

```bash
# Clone the repository
git clone https://github.com/secretariat/secretariat.git
cd secretariat

# Build the daemon and CLI
cargo build --release

# Install binaries
sudo cp target/release/secd /usr/local/bin/
sudo cp target/release/sec /usr/local/bin/
```

## First Run Setup

### 1. Initialize Your Vault

```bash
# Create your secure vault
sec init
```

You'll be prompted to:
- Create a master password
- Enable Touch ID (optional, recommended)

Your master password is stored securely in macOS Keychain.

### 2. Import Existing Secrets

**From a single .env file:**

```bash
sec import ~/projects/my-app/.env
```

**Scan all projects for .env files:**

```bash
sec import --scan ~/projects
```

The import wizard will:
- Detect duplicate secrets across projects
- Auto-detect providers (OpenAI, Stripe, etc.)
- Let you review before importing

### 3. Add Your First Secret Manually

```bash
# Add a secret
sec set OPENAI_API_KEY sk-proj-xxxxx

# Or securely from stdin (no shell history)
echo "sk-proj-xxxxx" | sec set OPENAI_API_KEY --stdin
```

### 4. Verify It Works

```bash
# List all secrets
sec list

# Retrieve a secret
sec get OPENAI_API_KEY
```

## Using Secrets in Your Projects

### Dart/Flutter

```dart
import 'package:secretariat/secretariat.dart';

final client = Secretariat();
final apiKey = await client.get('OPENAI_API_KEY');
```

### Python

```python
from secretariat import Secretariat

client = Secretariat()
api_key = client.get('OPENAI_API_KEY')
```

### Rust

```rust
use secretariat::Secretariat;

let client = Secretariat::new()?;
let api_key = client.get("OPENAI_API_KEY")?;
```

### Node.js/TypeScript

```typescript
import { Secretariat } from '@secretariat/node';

const client = new Secretariat();
const apiKey = await client.get('OPENAI_API_KEY');
```

## Desktop App

Click the Secretariat icon in your menu bar to:

- **Quick search** - Find secrets instantly with ⌘F
- **Copy to clipboard** - Secrets auto-clear after 30 seconds
- **Manage permissions** - Control which apps can access which secrets
- **View audit log** - See all access history

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘⇧S | Open Secretariat popup |
| ⌘F | Focus search |
| ⌘N | Add new secret |
| ⌘C | Copy selected secret |
| Esc | Close popup |

## Security Overview

- **AES-256-GCM encryption** - Military-grade encryption for all secrets
- **macOS Keychain** - Master key protected by system security
- **Touch ID / Password** - Biometric or password required to unlock
- **Audit logging** - All access tracked and reviewable
- **Memory safety** - Secrets zeroed from memory after use

## Next Steps

- [CLI Reference](cli-reference.md) - All 17 CLI commands explained
- [Dart SDK Guide](sdk-dart.md) - Flutter integration details
- [Python SDK Guide](sdk-python.md) - Python integration details
- [Security Architecture](security.md) - Technical security details

## Troubleshooting

### Daemon not running

```bash
# Check daemon status
sec status

# Start daemon manually
secd &
```

### Permission denied

Make sure your app has been granted access:

```bash
# List apps and their permissions
sec apps

# Grant access to specific secret
sec grant my-app OPENAI_API_KEY
```

### Reset vault

**Warning: This deletes all secrets!**

```bash
# Remove vault and start fresh
rm -rf ~/Library/Application\ Support/Secretariat/
sec init
```

## Getting Help

- [Documentation](https://secretariat.dev/docs)
- [GitHub Issues](https://github.com/secretariat/secretariat/issues)
- [Discord Community](https://discord.gg/secretariat)
