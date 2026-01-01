# Join Us: Contributing to Secretariat

## Why This Project Matters

We're building the secrets manager that every developer deserves - one that's local-first, privacy-respecting, and actually designed for how developers work.

**Every contribution here helps thousands of developers stop:**
- Hunting through folders for `.env` files
- Copy-pasting API keys between projects
- Worrying about accidentally committing secrets
- Paying subscriptions for simple tools

---

## The Opportunity For You

**Why Contribute to Secretariat?**

| What You Get | Why It Matters |
|--------------|----------------|
| Work on security-critical systems | Resume differentiator |
| Multi-language experience | Rust, Dart, TypeScript, Python, Go |
| Real-world cryptography | AES-256-GCM, Argon2id, Keychain |
| Open source portfolio | Visible, impactful contributions |
| Growing project | Shape the direction early |

---

## Current Project State

**Honest Assessment:**

| Dimension | Score | What It Means For You |
|-----------|-------|----------------------|
| Code Quality | B (76/100) | Clean code, but room to make your mark |
| Architecture | B- (74/100) | Good foundation, refactoring opportunities |
| Test Coverage | ~5% | Major opportunity to add value |
| Documentation | Good | Comprehensive docs to get started |
| Tech Debt | 62/100 | Improvement projects available |

**Lines of Code:** ~30,000 across 98 files
**Languages:** Rust (daemon/CLI), Dart (app/SDK), TypeScript (MCP), Python (SDK), Go (SDK)

---

## Where We Need Help

### High-Impact Areas

#### 1. Test Coverage (Critical Need)

**Current State:** 5% file coverage - unacceptable for a security tool

**The Opportunity:**
```bash
# Files needing tests
daemon/src/handlers/*.rs   # 15+ handlers with no unit tests
app/lib/providers/*.dart   # State management untested
sdk-*/                     # SDK integration tests sparse
```

**Skills Needed:** Rust testing, Flutter testing, pytest, Go testing
**Impact:** Each test you add prevents production bugs

---

#### 2. Refactoring (Architecture Improvement)

**Current State:** Two files are too large

| File | Lines | Problem |
|------|-------|---------|
| `daemon/src/storage.rs` | 1,828 | God class - handles secrets, apps, permissions, audit |
| `daemon/src/server.rs` | 1,755 | Monolithic RPC dispatcher |

**The Opportunity:**
- Split `storage.rs` into 4 focused modules
- Extract handler registry pattern for `server.rs`
- Add trait definitions for testability

**Skills Needed:** Rust, software architecture
**Impact:** Dramatically improve maintainability

---

#### 3. Cross-Platform Support (Phase 2)

**Current State:** macOS only

**The Opportunity:**
- Implement Linux Secret Service integration
- Add Windows Credential Manager support
- Create platform abstraction layer

**Skills Needed:** Systems programming, platform APIs
**Impact:** 3x the addressable user base

---

#### 4. CI/CD Infrastructure (Immediate Need)

**Current State:** No automation

**The Opportunity:**
- Set up GitHub Actions workflows
- Add automated testing on PR
- Create release automation

**Skills Needed:** GitHub Actions, CI/CD
**Impact:** Quality gate for all future contributions

---

#### 5. Documentation & Examples

**Current State:** Good docs, sparse examples

**The Opportunity:**
- Add SDK usage examples
- Create integration guides
- Record demo videos

**Skills Needed:** Technical writing
**Impact:** Lower barrier for adoption

---

## The Codebase

### Tech Stack

```
Rust (Daemon + CLI)
├── tokio (async runtime)
├── serde (serialization)
├── rusqlite + SQLCipher (encrypted storage)
├── aes-gcm (encryption)
└── security-framework (macOS Keychain)

Dart (Flutter App)
├── Provider (state management)
└── Unix socket IPC

TypeScript (MCP Server)
└── Model Context Protocol

Python SDK
└── Sync + async APIs

Go SDK
└── Standard library focused
```

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Clients                            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   │
│  │ CLI      │ │ Flutter  │ │ Python   │ │ Node.js  │   │
│  │ (sec)    │ │ App      │ │ SDK      │ │ SDK      │   │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘   │
│       │            │            │            │          │
│       └────────────┴─────┬──────┴────────────┘          │
│                          │                              │
│                     Unix Socket                         │
│                     JSON-RPC 2.0                        │
│                          │                              │
├──────────────────────────┼──────────────────────────────┤
│                          ▼                              │
│  ┌──────────────────────────────────────────────────┐   │
│  │                 Daemon (secd)                    │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────────────┐  │   │
│  │  │ Storage  │ │ Crypto   │ │ Keychain         │  │   │
│  │  │ (SQLite) │ │ (AES-GCM)│ │ (macOS Security) │  │   │
│  │  └──────────┘ └──────────┘ └──────────────────┘  │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### What You'll Find

**The Good:**
- Well-documented code (1,928 doc comments in daemon)
- Consistent error handling (anyhow + thiserror)
- Strong typing throughout
- JSON-RPC 2.0 protocol makes SDK development predictable

**The Challenges (Opportunities):**
- Large files need refactoring (perfect learning project)
- Test coverage is low (major impact opportunity)
- Flutter uses Provider (should migrate to Bloc per preferences)

---

## How to Get Started

### Setup (10 minutes)

```bash
# 1. Clone the repo
git clone https://github.com/moinsen/secretariat
cd secretariat

# 2. Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 3. Install Flutter (if working on app)
# https://flutter.dev/docs/get-started/install

# 4. Build everything
cargo build

# 5. Run tests
cargo test

# 6. Start the daemon
cargo run --bin secd

# 7. Try the CLI
cargo run --bin sec -- --help
```

### Project Structure

```
secretariat/
├── daemon/          # Rust daemon (main backend)
│   └── src/
│       ├── server.rs    # RPC server (needs refactor)
│       ├── storage.rs   # Database (needs refactor)
│       ├── crypto.rs    # Encryption (well-tested)
│       └── handlers/    # Command handlers
├── cli/             # Rust CLI
├── app/             # Flutter menu bar app
├── sdk-dart/        # Dart SDK
├── sdk-python/      # Python SDK
├── sdk-node/        # Node.js SDK
├── sdk-go/          # Go SDK
├── mcp-server/      # AI assistant integration
└── docs/            # Documentation
```

### Good First Issues

**Easy (1-2 hours):**
- Add README.md to Go SDK
- Add missing doc comments to handlers
- Create example usage in each SDK

**Medium (4-8 hours):**
- Add unit tests for a single handler
- Implement one new CLI command
- Add GitHub Actions workflow

**Challenging (1-2 days):**
- Refactor storage.rs into modules
- Add Linux Secret Service support
- Implement property-based tests for crypto

---

## Our Values

**What We Care About:**

1. **Security First** - We're handling people's secrets. Every decision prioritizes security.

2. **Developer Experience** - If it's annoying to use, it's a bug.

3. **Local-First** - Your data, your machine, your control.

4. **Quality Over Speed** - We'd rather ship less, well-tested, than rush bugs to users.

5. **Honest Documentation** - If something's broken, we document it. No hiding tech debt.

---

## Contribution Guidelines

### Pull Request Process

1. **Fork & Branch** - Create a feature branch from `develop`
2. **Write Tests** - All new code should have tests
3. **Update Docs** - If you change behavior, update docs
4. **Conventional Commits** - Use `feat:`, `fix:`, `refactor:`, etc.
5. **Small PRs** - Easier to review, faster to merge

### Code Style

**Rust:**
```bash
cargo fmt
cargo clippy
```

**Dart:**
```bash
dart format .
dart analyze
```

**TypeScript:**
```bash
pnpm format
pnpm lint
```

### Commit Messages

```
feat: Add vault export command
fix: Handle empty secrets gracefully
refactor: Split storage into modules
test: Add handler unit tests
docs: Update SDK examples
```

---

## Join the Team

**Ways to Contribute:**

| Type | Examples |
|------|----------|
| Code | Features, bug fixes, refactoring |
| Tests | Unit tests, integration tests, fuzzing |
| Docs | Tutorials, examples, API reference |
| Design | UX improvements, accessibility |
| Community | Answer questions, triage issues |

**Get In Touch:**

- **GitHub Issues:** Best place to start
- **Pull Requests:** We review within 48 hours
- **Discussions:** For ideas and RFCs

---

## Recognition

All contributors are:
- Listed in CONTRIBUTORS.md
- Credited in release notes
- Part of shaping a tool used by thousands

---

## FAQ for Contributors

**How do I know what to work on?**
Check GitHub Issues labeled `good-first-issue` or `help-wanted`. Or look at the project rating - anything with a low score is an opportunity.

**What if I break something?**
That's what tests are for! And why we need more tests. We have a forgiving code review culture.

**Can I work on what interests me?**
Absolutely. If it makes Secretariat better, we want it.

**How long until my PR is reviewed?**
We aim for 48 hours. Complex PRs may take longer.

---

## Ready to Contribute?

```bash
git clone https://github.com/moinsen/secretariat
cd secretariat
cargo build && cargo test
```

**Pick an issue, make a branch, and start building.**

We're excited to have you!

---

*"Stop copy-pasting API keys." - Help us make it happen.*
