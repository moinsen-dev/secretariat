# Product Identification Document (PID) v2.2

## Secretariat

**Version:** 2.2 (Refined Positioning)
**Date:** December 2025
**Status:** Draft for Review

---

## The Hook

> **"Do you hate maintaining .env files?"**

Every developer who hears this thinks: *YES.*

---

## Executive Summary

**Stop copy-pasting API keys. Secretariat manages them all from one place.**

Secretariat is a local-first secrets manager that eliminates `.env` files entirely. One encrypted vault on your machine. All your API keys in one place. Every project just works.

No more:
- Copy-pasting the same OpenAI key into 15 different projects
- Wondering "where did I put that Stripe API key?"
- Duplicating secrets into GitHub Actions, Vercel, and Netlify
- Keeping a spreadsheet or notes file of your credentials
- Having your password manager open but *outside* your dev workflow

---

## 1. Problem Statement

### 1.1 Current Pain Points

Modern developers face significant challenges managing secrets across their projects:

| Problem | Impact |
|---------|--------|
| **Fragmented Storage** | Secrets scattered across dozens of `.env` files in different project folders |
| **Manual Key Management** | Copy-pasting keys between projects leads to errors and inconsistencies |
| **Poor Visibility** | No clear overview of which project uses which secret |
| **Security Risks** | Convenience trumps security; secrets often committed to git or shared insecurely |
| **Prototyping Friction** | Setting up secrets for new projects slows down rapid experimentation |
| **No Runtime Control** | Once a key is leaked, there's no way to instantly revoke access across all projects |
| **Scaling Issues** | Problems compound when moving from solo to team development |
| **AI Agent Risk** | AI coding assistants have unrestricted access to all secrets in `.env` files |

### 1.2 The `.env` File Security Problem

The `.env` file pattern is fundamentally broken from a security perspective:

```bash
# Any attacker or malicious script can run:
find ~ -name ".env" -type f 2>/dev/null

# Result: Instant access to ALL secrets on the machine
/Users/dev/project-a/.env
/Users/dev/project-b/.env
/Users/dev/client-work/secret-project/.env
... dozens more
```

**This is not a theoretical risk.** A single compromised npm package, malicious VS Code extension, or AI agent with terminal access can harvest every secret on a developer's machine in seconds.

### 1.3 The AI Agent Challenge

Modern AI coding assistants (Cursor, Claude Code, GitHub Copilot, etc.) are increasingly powerful:
- They read your codebase
- They execute terminal commands
- They have access to your environment variables

**The problem:** There's no way to control which secrets an AI agent can see or use. If your `.env` contains production database credentials alongside development API keys, the AI has access to both.

### 1.4 Why Existing Solutions Fall Short

- **Vault/Cloud Solutions:** Overkill for local development, require infrastructure
- **Password Managers:** Not designed for programmatic access
- **Manual `.env` Management:** The insecure status quo that causes all these problems
- **IDE Plugins:** Fragmented, not unified across tools

---

## 2. Vision

> **One place for all your API keys. No more .env files. Just works.**

Secretariat is the secrets manager that fits *inside* your dev workflow - not alongside it.

### Core Principles

1. **One Source of Truth:** All your secrets in one encrypted vault on your machine
2. **Zero Friction:** Faster than copy-pasting from `.env` files
3. **No More `.env` Files:** Secrets never touch the filesystem in plain text
4. **Local-First:** Everything works offline, on your machine, under your control
5. **Just Works:** New project? It already has access to your keys
6. **Secure by Default:** Best practices without extra effort
7. **Scalable:** From indie hacker to enterprise team

---

## 3. Target Users

### Primary Persona: The Multi-Project Developer

The developer who juggles multiple projects and feels the pain every day.

**Profile:**
- Works on 3+ projects simultaneously (side projects, client work, experiments)
- Uses AI APIs (OpenAI, Anthropic), payment processors (Stripe), cloud services
- Constantly spinning up new projects for prototyping
- Has the same keys scattered across dozens of `.env` files
- Uses GitHub Actions / CI-CD and has to duplicate secrets there too
- Has a password manager (1Password, Bitwarden) but it's *outside* the dev workflow

**The Pain (in their words):**
> *"I spend more time managing API keys than I should."*

**What they do today:**
- Copy-paste from other projects
- Keep a notes file or spreadsheet with keys
- Dig through old `.env` files to find credentials
- Manually add the same secrets to GitHub, Vercel, Netlify...

### Launch Focus (First 100 Users)
- **Indie Developers** - Multiple side projects, rapid prototyping
- **Freelancers** - Juggling client projects with different credentials
- **Prototype Builders** - Need speed without sacrificing organization

### Secondary (Growth Phase)
- **Small Teams (2-10)** - Sharing secrets securely without enterprise tooling
- **Startups** - Growing fast, need structure without overhead

### Tertiary (Scale Phase)
- **Organizations** - Multiple developers, environments, compliance needs

---

## 4. Core Concept

A **local daemon-based secrets orchestration system** that acts as the single source of truth for all secrets on a developer's machine.

### Key Characteristics

```
┌─────────────────────────────────────────────────────────────────┐
│                    Developer's Machine                          │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐       │
│  │  Project A  │     │  Project B  │     │  Project C  │       │
│  │   (Flutter) │     │    (Rust)   │     │   (Python)  │       │
│  └──────┬──────┘     └──────┬──────┘     └──────┬──────┘       │
│         │                   │                   │               │
│         └───────────────────┼───────────────────┘               │
│                             ▼                                   │
│                  ┌─────────────────────┐                        │
│                  │   Local Daemon      │                        │
│                  │   (Encrypted Store) │                        │
│                  └─────────────────────┘                        │
│                             │                                   │
│              ┌──────────────┼──────────────┐                    │
│              ▼              ▼              ▼                    │
│         ┌────────┐    ┌──────────┐   ┌─────────┐               │
│         │  CLI   │    │    UI    │   │  Cloud  │ (optional)    │
│         └────────┘    └──────────┘   └─────────┘               │
└─────────────────────────────────────────────────────────────────┘
```

**What Changes:**
- Secrets are **NOT** stored inside project folders
- Applications request secrets **on demand** from the daemon
- User maintains **explicit control** through UI and CLI
- **Optional** cloud sync enables team workflows

---

## 5. High-Level Architecture

### 5.1 Local Daemon

The heart of the system - a persistent background service.

**Responsibilities:**
- Secure, encrypted secret storage
- Runtime access request handling
- Policy enforcement
- Audit logging
- Application identity verification

**Technical Characteristics:**
- Starts automatically on macOS boot
- Minimal resource footprint
- IPC communication with applications
- Graceful degradation (apps get clear errors if daemon unavailable)

### 5.2 User Interface (UI)

Cross-platform Flutter Desktop application for visual management.

**Why Flutter Desktop:**
- Cross-platform from day one (macOS, Windows, Linux)
- Shares code with Dart SDK
- Single codebase for all desktop platforms
- Native-feeling UI with `macos_ui` and platform-adaptive widgets
- System tray integration via `tray_manager` package

**Features:**
- Secret management (CRUD)
- Environment configuration
- Application permissions dashboard
- Key lifecycle actions (rotate, revoke, replace)
- Provider onboarding wizards
- Usage analytics and audit trails
- System tray / menu bar integration
- Platform-native look and feel

### 5.3 Command-Line Interface (CLI)

Developer-friendly scriptable access.

**Use Cases:**
- Quick secret lookup
- Automation scripts
- CI/CD integration (for team/cloud tier)
- Debugging and troubleshooting

**Example Commands:**
```bash
sec list                          # List all secrets
sec get OPENAI_API_KEY            # Get specific secret
sec grant myapp OPENAI_API_KEY    # Grant app access
sec audit --app myapp             # View access history
sec rotate OPENAI_API_KEY         # Trigger rotation
sec agent list                    # List registered AI agents
sec agent grant cursor OPENAI_API_KEY  # Grant AI agent access
```

### 5.4 SDKs (Application Integration)

Lightweight SDKs for application integration.

**Phase 1 SDK Support (Must Have):**
| Language | Framework | Priority |
|----------|-----------|----------|
| Dart | Flutter | Phase 1 |
| Python | Native | Phase 1 |
| Rust | Native | Phase 1 |
| JavaScript/TypeScript | Node.js | Phase 1 |

**Future SDK Support:**
| Language | Framework | Priority |
|----------|-----------|----------|
| Go | Native | Phase 2 |

**SDK Design Principles:**
- Minimal dependencies
- Async-first
- Clear error handling
- Fallback options (for development without daemon)

---

## 6. Application Interaction Model

### 6.1 Standard Flow

```
1. Application starts
         │
         ▼
2. SDK requests secrets from daemon
         │
         ▼
3. Daemon checks authorization
         │
    ┌────┴────┐
    │         │
    ▼         ▼
Authorized  First Request
    │         │
    ▼         ▼
Return      Identify App
Secret      Notify User
            User Decides:
            • Create new app-specific key
            • Use existing global key
            • Assign environment variant
```

### 6.2 Application Identification

**Project Fingerprinting** - Stable app identification via:
- Project path
- Git repository URL
- Package manifest files (pubspec.yaml, Cargo.toml, package.json)
- Explicit app registration

This ensures apps remain identifiable even after folder renames or moves.

---

## 7. Secret Types & Organization

### 7.1 Secret Hierarchy

```
Global Secrets
    └── Provider-specific (e.g., OpenAI, Google Maps)
        └── Environment-specific (dev, staging, prod)
            └── App-specific overrides
```

### 7.2 Secret Categories

| Type | Description | Example |
|------|-------------|---------|
| **Global** | Shared across all projects | Personal OpenAI key |
| **App-Specific** | Dedicated to one project | Client's API key |
| **Environment** | Variant per environment | Dev vs Prod database |
| **Ephemeral** | Auto-expiring, temporary | Test session tokens |

### 7.3 Ephemeral / Session Secrets

Short-lived secrets for specific use cases:
- Local prototyping
- Test runs
- Temporary access grants
- Auto-expire after configurable duration

---

## 8. Environment Management

### 8.1 Supported Environments

- Development (default)
- Staging
- Production
- Custom (user-defined)

### 8.2 Environment Switching

```bash
sec env set staging              # Switch active environment
sec run --env=production myapp   # Run app with specific env
```

### 8.3 Clear Visibility

The UI provides a matrix view:

| Secret | Dev | Staging | Prod |
|--------|-----|---------|------|
| OPENAI_API_KEY | ✓ (global) | ✓ (global) | ✓ (dedicated) |
| DATABASE_URL | ✓ | ✓ | ✓ |
| STRIPE_KEY | - | ✓ (test) | ✓ (live) |

---

## 9. Key Provider Onboarding

### 9.1 Guided Setup

The UI actively assists users in obtaining API keys:

**Supported Providers (Initial):**
- OpenAI
- Anthropic
- Google (Maps, Gemini, Cloud)
- Stripe
- AWS
- GitHub
- Others (extensible)

**Onboarding Flow:**
1. Select provider
2. Guided instructions to create key
3. Best practice recommendations
4. Automatic categorization and policy application

### 9.2 Provider-Specific Policies

Pre-configured best practices per provider:
- Recommended rotation intervals
- Environment separation guidelines
- Scope recommendations
- Cost monitoring hints

---

## 10. Access Control

### 10.1 Permission Levels

| Level | Description |
|-------|-------------|
| **Full Access** | Read any authorized secret |
| **Read-Only** | Cannot modify, only retrieve |
| **Scope-Limited** | Only specific secrets/environments |
| **Time-Limited** | Access expires after duration |

### 10.2 Trust Model

- Trust established **once** per registered application
- Not required on every access (reduces friction)
- Can be revoked instantly
- Trust is environment-specific (app trusted for dev ≠ trusted for prod)

---

## 11. AI Agent Access Control (Bonus Feature)

> *"Wait, it also controls what my AI can see?"*

A discovered benefit: because Secretariat controls all secret access, it can also control what AI coding assistants see.

### 11.1 Why This Matters (Increasingly)

AI coding assistants are becoming more powerful:
- They read and modify code
- They execute terminal commands
- They access environment variables

With `.env` files, AI agents see *everything*. With Secretariat, you control what they can access - a benefit that becomes more valuable as AI tools become more autonomous.

### 11.2 Agent Registration

AI agents are registered as a special application type:

```bash
sec agent register cursor --type ai-assistant
sec agent register claude-code --type ai-assistant
sec agent register copilot --type ai-assistant
```

### 11.3 Agent-Specific Permissions

| Permission | Description |
|------------|-------------|
| **No Access** | Default - AI cannot see the secret |
| **Dev Only** | AI can access development environment secrets only |
| **Read-Only** | AI can read but cannot use in write operations |
| **Full Access** | AI has same access as the application |

### 11.4 Use Cases

**Scenario 1: Safe AI Prototyping**
> "I want Cursor to help me build an OpenAI integration, but I don't want it to see my production database credentials."

```bash
sec agent grant cursor OPENAI_API_KEY --env dev
# Cursor can now use the dev OpenAI key
# But has no access to DATABASE_URL, STRIPE_KEY, etc.
```

**Scenario 2: Audit AI Activity**
> "What secrets has Claude Code accessed in the last week?"

```bash
sec audit --agent claude-code --since 7d
# Shows all secret access by the AI agent
```

**Scenario 3: Emergency Lockdown**
> "I suspect my AI agent is compromised or behaving unexpectedly."

```bash
sec agent revoke-all cursor
# Instantly revokes all secret access for Cursor
```

### 11.5 Integration with AI Tools

Secretariat integrates with AI coding assistants via:
- Environment variable injection (when AI spawns processes)
- MCP (Model Context Protocol) server for direct integration
- SDK support within AI agent environments

### 11.6 AI-Specific Audit Trail

Track AI agent behavior separately:
- Which secrets were accessed
- What operations were performed
- Timestamps and frequency
- Unusual patterns (e.g., production access attempts)

---

## 12. Security Model

### 12.1 Encryption

- All secrets encrypted at rest using industry-standard encryption
- Encryption key protected by macOS Keychain
- Transparent encryption/decryption by daemon

### 12.2 Authentication

**Local Authentication Options:**
- Passkeys
- Biometric (Touch ID)
- System password

**When Required:**
- First-time daemon unlock after boot
- Sensitive operations (export, bulk delete)
- Configurable re-authentication intervals

### 12.3 Runtime Access Control

Instant control capabilities:
- Revoke access to specific apps
- Block individual applications
- Disable specific keys globally
- **Security Kill-Switch:** Panic button to revoke ALL secrets for ALL apps instantly

### 12.4 Zero-Trust Principles

- No implicit trust between applications
- Explicit grants required
- Audit trail for all access
- Principle of least privilege by default

---

## 13. Key Lifecycle Management

### 13.1 Rotation

- Scheduled rotation reminders
- One-click rotation with automatic propagation
- Version history maintained
- Rollback capability

### 13.2 Compromise Response

When a key is leaked:
1. Instant revocation across all apps
2. Notification to affected projects
3. Guided re-creation flow
4. Audit of exposure window

### 13.3 Versioning

- Keep history of previous key values
- Controlled rollout of new keys
- A/B testing support (gradual rotation)

---

## 14. Audit & Monitoring

### 14.1 Usage Tracking

Track every access:
- Which application (or AI agent)
- Which secret
- Which environment
- Timestamp
- Success/failure

### 14.2 Dry-Run & Explain Mode

Developer UX feature for transparency:
```bash
sec explain myapp
# Output:
# myapp would receive:
#   OPENAI_API_KEY    → global (dev environment)
#   DATABASE_URL      → app-specific (dev environment)
#   STRIPE_KEY        → denied (not authorized)

sec explain --agent cursor
# Output:
# AI Agent 'cursor' would receive:
#   OPENAI_API_KEY    → granted (dev only)
#   DATABASE_URL      → denied (no AI access)
#   STRIPE_KEY        → denied (no AI access)
```

### 14.3 Anomaly Detection

Basic signals for misuse detection:
- Unusual access patterns
- High-frequency requests
- Access from unexpected apps or AI agents
- After-hours activity (configurable)

---

## 15. Migration & Import

Smooth transition path from existing `.env` file chaos to Secretariat.

### 15.1 Import Wizard

One-click migration from existing `.env` files:

```bash
sec import ~/projects/my-app/.env
# Output:
# Found 12 secrets in .env file:
#   OPENAI_API_KEY      → Detected: OpenAI (existing match found)
#   DATABASE_URL        → Detected: PostgreSQL connection string
#   STRIPE_SECRET_KEY   → Detected: Stripe (new)
#   ...
#
# Import options:
#   [1] Import all as app-specific secrets
#   [2] Match with existing global secrets where possible
#   [3] Interactive review (recommended)
```

### 15.2 Bulk Import

Scan and import from multiple projects:

```bash
sec import --scan ~/projects
# Output:
# Found 47 .env files across 23 projects
# Identified 156 total secrets (67 unique)
#
# Common secrets found:
#   OPENAI_API_KEY      → 18 projects (same value)
#   ANTHROPIC_API_KEY   → 12 projects (same value)
#   DATABASE_URL        → 8 projects (3 unique values)
```

### 15.3 Post-Import Cleanup

After successful migration:

```bash
sec cleanup --dry-run
# Output:
# The following .env files can be safely removed:
#   ~/projects/my-app/.env (all secrets imported)
#   ~/projects/other-app/.env (all secrets imported)
#
# Run 'sec cleanup --execute' to remove files
# Or 'sec cleanup --archive' to move to secure backup
```

### 15.4 Gradual Adoption

Support hybrid mode during transition:
- Some secrets in Secretariat
- Some secrets still in `.env` (temporarily)
- Clear visibility of migration status per project

---

## 16. Virtual Environment Emulation

### 16.1 Secrets as Virtual Env

Drop-in replacement for `.env` files:
- Applications see standard environment variables
- No actual files written to disk
- Full compatibility with existing tools

### 16.2 Integration Modes

| Mode | Description |
|------|-------------|
| **SDK** | Native integration, recommended |
| **Env Injection** | Inject vars at process start |
| **File Emulation** | Virtual `.env` for legacy tools (transitional only) |

---

## 17. Team Features (Cloud Extension)

### 17.1 Purpose

Enable team and organization workflows while preserving local-first operation.

### 17.2 Capabilities

- **Secret Synchronization:** Sync across team members' machines
- **Team Access Control:** Role-based permissions
- **Organizational Policies:** Enforce standards across teams
- **Centralized Audit Logs:** Compliance-ready logging
- **Offboarding:** Instant access revocation when team members leave
- **Team Templates:** Pre-configured secret sets for common project types

### 17.3 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Cloud Control Plane                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Sync      │  │   Policies  │  │   Audit & Compliance│  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└───────────────────────────┬─────────────────────────────────┘
                            │ (encrypted sync)
         ┌──────────────────┼──────────────────┐
         ▼                  ▼                  ▼
    ┌─────────┐        ┌─────────┐        ┌─────────┐
    │ Dev A   │        │ Dev B   │        │ Dev C   │
    │ (Local) │        │ (Local) │        │ (Local) │
    └─────────┘        └─────────┘        └─────────┘
```

### 17.4 Offline-First Guarantee

- Local development works **100% without cloud**
- Cloud is additive, never mandatory
- Sync conflicts resolved gracefully
- Offline changes merge when reconnected

---

## 18. Business Model

### 18.1 Pricing Tiers

| Tier | Price | Features |
|------|-------|----------|
| **Free** | $0 | Local usage, unlimited projects, core SDKs |
| **Pro** | $X/month | Cloud sync, multiple machines, priority support |
| **Team** | $Y/user/month | Team features, shared secrets, audit logs |
| **Enterprise** | Custom | SSO, compliance, dedicated support, SLAs |

### 18.2 Open Source Strategy

**OSS Core + Paid Control Plane:**
- Daemon and SDKs: Open source (permissive license)
- CLI: Open source
- Cloud & Governance: Commercial

**Benefits:**
- Community trust and contributions
- Transparent security (auditable)
- Low barrier to adoption
- Clear upgrade path for teams

### 18.3 Target Customers

| Segment | Value Proposition |
|---------|-------------------|
| Freelancers | Organization without overhead |
| Agencies | Client isolation, easy offboarding |
| Startups | Scale without changing tools |
| Security-conscious orgs | Audit trails, compliance |

---

## 19. Strategic Value

### 19.1 Market Positioning

- **Not a vault replacement:** Complements, doesn't compete with HashiCorp Vault
- **Not enterprise-first:** Developer-first, enterprise-capable
- **Not cloud-dependent:** Local-first with cloud benefits
- **Inside the workflow:** Unlike password managers, it's where you code

### 19.2 Competitive Advantages

1. **Solves daily pain:** Every developer knows the `.env` struggle
2. **Zero friction:** Faster than the status quo (copy-paste)
3. **Fits the workflow:** Not another tab, not another app - it's just *there*
4. **Secure by default:** Better security without extra effort
5. **Flexibility:** Works for solo devs AND teams
6. **Open source core:** Community trust and transparency
7. **Bonus: AI control:** Future-proof for AI-assisted development

### 19.3 Growth Vectors

```
Indie Dev → Multiple Machines → Team → Organization
    │              │              │           │
    └──────────────┴──────────────┴───────────┘
         Natural expansion path, no tool change
```

---

## 20. Technical Constraints & Decisions

### 20.1 Platform

- **Desktop (v1):** macOS, Windows, Linux (all via Flutter Desktop)
- **Mobile:** Not in scope for v1
- **UI Framework:** Flutter Desktop with platform-adaptive widgets

### 20.2 Not In Scope (v1)

- Detailed cryptographic specifications
- Exact IPC protocol design
- Provider-specific API automation
- Compliance certifications (SOC2, etc.)
- Mobile platform support

### 20.3 Open Questions

- [ ] Exact encryption algorithm selection
- [ ] IPC protocol (Unix sockets vs. gRPC vs. HTTP)
- [ ] SDK distribution strategy
- [ ] Pricing specifics

---

## 21. Success Metrics

### 21.1 Adoption

- Daily active developers
- Projects connected
- Secrets managed
- AI agents registered

### 21.2 Engagement

- Access requests per day
- UI vs CLI usage ratio
- Feature utilization
- AI agent access patterns

### 21.3 Business

- Free to paid conversion
- Team tier adoption
- Churn rate

---

## 22. Next Steps

### Immediate (PID → PRD)

1. Technical architecture deep dive
2. Security model specification
3. UX/UI design exploration
4. SDK interface design
5. AI agent integration design (MCP server)
6. Pricing validation research

### Development Phases

| Phase | Focus | Deliverable |
|-------|-------|-------------|
| 1 | Core | Daemon + CLI + macOS Menu Bar App + 4 SDKs (Dart, Python, Rust, JS/TS) + Import Wizard |
| 2 | Polish | Go SDK, provider onboarding |
| 3 | AI | AI agent access control (bonus feature) |
| 4 | Teams | Cloud sync, team features |

---

## Appendix A: Glossary

| Term | Definition |
|------|------------|
| **Daemon** | Background service managing secrets |
| **Secret** | Any sensitive credential (API key, token, password) |
| **Provider** | External service requiring authentication (OpenAI, Stripe) |
| **Environment** | Context for secret variants (dev, staging, prod) |
| **Trust** | Established permission for an app to access secrets |
| **AI Agent** | AI coding assistant (Cursor, Claude Code, Copilot) registered for access control |
| **MCP** | Model Context Protocol - standard for AI tool integration |
| **Kill Switch** | Emergency button to revoke all secret access instantly |

---

## Appendix B: User Stories

### Indie Developer
> "I start a new Flutter project. Instead of copying my OpenAI key from another project, the app requests it from Secretariat. I approve once, and it just works."

### Team Lead
> "A contractor's engagement ends. I remove them from our team in the cloud dashboard. Their local daemon instantly loses access to all shared secrets."

### Security-Conscious Dev
> "I notice suspicious activity on my OpenAI account. I hit the kill switch, and within seconds, no app on my machine can access any API key until I re-authorize."

### AI-Assisted Developer
> "I'm using Cursor to help build an integration. I've granted it access to my dev OpenAI key, but it can't see my production database credentials or my Stripe keys. I can see exactly which secrets it accessed in the audit log."

### Migration User
> "I ran `sec import --scan ~/projects` and it found 47 .env files with 67 unique secrets. After a 5-minute import wizard, all my secrets are centralized and I can finally delete those scattered .env files."

---

## Appendix C: Feature Priority Matrix

| Feature | Must Have | Should Have | Nice to Have |
|---------|-----------|-------------|--------------|
| Encrypted local storage | ✓ | | |
| Daemon + CLI | ✓ | | |
| SDKs (4 languages: Dart, Python, Rust, JS/TS) | ✓ | | |
| Import wizard | ✓ | | |
| macOS Menu Bar App | ✓ | | |
| Provider onboarding | | ✓ | |
| Environment management | | ✓ | |
| AI agent access control | | ✓ | |
| MCP server integration | | | ✓ |
| Cloud sync | | | ✓ |
| Team features | | | ✓ |
| Ephemeral secrets | | | ✓ |

---

*Document Version: 2.2*
*Product Name: Secretariat*
*Tagline: Stop copy-pasting API keys.*
*Last Updated: December 2025*
