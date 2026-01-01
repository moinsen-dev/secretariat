# Secretariat

## Stop Copy-Pasting API Keys. Start Just Building.

> One encrypted vault on your machine. All your API keys in one place. Every project just works.

---

## The Problem You Know Too Well

You're working on your third project this week. You need the Stripe API key. Where is it?

- Is it in the `.env` in the payments project?
- Or the `.env.local` in the frontend?
- Maybe you saved it in 1Password... somewhere?
- Oh wait, you copy-pasted it into Slack that one time...

**Sound Familiar?**

- Your API keys are scattered across dozens of `.env` files
- You've copy-pasted the same OpenAI key into 15 different projects
- You've accidentally committed a secret to Git (at least once)
- You pay for a password manager but still use `.env` files
- Every new project starts with "where's that API key again?"

---

## The Solution You've Been Waiting For

**Secretariat**: A local-first secrets manager built by developers, for developers.

```bash
# Import all your scattered .env files (5-minute migration)
sec import ~/projects/*/.env

# Get any secret, instantly
sec get STRIPE_SECRET_KEY

# Or use it directly in your code
```

**In Python:**
```python
from secretariat import get_secret
stripe.api_key = get_secret("STRIPE_SECRET_KEY")
```

**In Node.js:**
```javascript
import { getSecret } from 'secretariat';
const apiKey = await getSecret('OPENAI_API_KEY');
```

**In Dart/Flutter:**
```dart
final apiKey = await Secretariat.get('FIREBASE_API_KEY');
```

**In Go:**
```go
apiKey, _ := secretariat.Get("AWS_ACCESS_KEY")
```

---

## What You Get

### Your Secrets, Your Machine

- **All secrets in one encrypted vault** - no more hunting through folders
- **Works offline** - no cloud, no subscription, no data leaving your device
- **Touch ID unlock** - secure and fast, just like Apple Pay

### Native Integration

- **5 SDKs included** - Python, Node.js, Dart, Go, Rust
- **AI assistant ready** - Works with Claude, Copilot via MCP
- **CLI for power users** - Full control from your terminal

### Real Security

- **AES-256-GCM encryption** - same as 1Password
- **Argon2id key derivation** - OWASP recommended
- **macOS Keychain integration** - master key never on disk
- **Audit logging** - know who accessed what, when

---

## Why It Works

**Built with Purpose:**

> We built Secretariat because we were tired of the .env dance. Every developer deserves a secrets manager that's actually designed for how developers work - local, fast, and free.

**Quality You Can Trust:**

| What We Measure | Our Score | What It Means |
|-----------------|-----------|---------------|
| Code Quality | B (76/100) | Clean, maintainable code |
| Security | 88/100 | Production-grade encryption |
| Architecture | 74/100 | Well-designed, extensible |

**30,000+ lines of Rust** powering a daemon that:
- Uses <50MB memory
- Retrieves secrets in <10ms
- Runs 24/7 without issues

---

## See It In Action

### Quick Start (5 Minutes)

```bash
# 1. Install (macOS)
./scripts/install.sh

# 2. Initialize your vault
sec init

# 3. Import your .env files
sec import ~/projects/*/.env

# 4. You're done. Use your secrets anywhere.
```

### Common Workflows

**Starting a new project:**
```bash
# No more copying .env.example and filling it in
# Just use your existing secrets
from secretariat import get_secret
openai_key = get_secret("OPENAI_API_KEY")
```

**Rotating a secret:**
```bash
# Update once, works everywhere
sec set STRIPE_SECRET_KEY sk_live_new...
```

**Auditing access:**
```bash
# See who accessed what
sec audit --secret PRODUCTION_DB_PASSWORD
```

**Quick copy to clipboard:**
```bash
# Copy with auto-clear after 30 seconds
sec get GITHUB_TOKEN --copy
```

---

## What's Coming

**We're Building What You Need:**

**Coming Soon:**
- Linux support (Ubuntu, Debian, Arch)
- Windows support
- VS Code extension for inline secret preview
- Browser extension for web dev workflows

**On the Roadmap:**
- Team sync via encrypted Git
- CI/CD environment injection
- Secret templates and generators

---

## Try It Today

### Installation

```bash
# Clone and install
git clone https://github.com/moinsen/secretariat
cd secretariat
./scripts/install.sh
```

### Requirements

- macOS 12+ (Monterey or later)
- Touch ID recommended (optional)

### Get Help

- **Documentation:** `./docs/getting-started.md`
- **CLI Reference:** `./docs/cli-reference.md`
- **Issues:** GitHub Issues

---

## Frequently Asked Questions

**Is it really free?**
Yes. MIT licensed. No subscription, no cloud costs, no catch.

**Is my data safe?**
Your secrets never leave your machine. The vault is encrypted with AES-256-GCM, the same encryption used by 1Password and Signal.

**What about teams?**
Phase 1 is for individual developers. Team sync is coming in Phase 2.

**What if I switch machines?**
Export your vault and import on the new machine. Encrypted backup/restore included.

**Does it work with my language?**
We ship SDKs for Python, Node.js, Dart, Go, and Rust. More coming based on demand.

---

## Comparison

| Feature | Secretariat | .env files | 1Password | Doppler |
|---------|-------------|------------|-----------|---------|
| Cost | Free | Free | $3/month | $4/month |
| Data Location | Local | Local | Cloud | Cloud |
| Offline | Yes | Yes | Limited | No |
| Developer SDKs | 5 languages | None | 1 | 3 |
| Setup Time | 5 min | N/A | 30 min | 20 min |
| AI Integration | MCP native | None | None | None |

---

## Ready to Stop the .env Chaos?

```bash
git clone https://github.com/moinsen/secretariat
cd secretariat && ./scripts/install.sh
```

**5 minutes from now, all your API keys will be in one place.**

---

*Built with love by developers who understand the .env struggle.*

*"Stop copy-pasting API keys."*
