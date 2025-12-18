# Product Identification Document (PID) v2.1

## Secretariat

**Version:** 2.1 (Consolidated)
**Date:** December 2025
**Status:** Draft for Review

---

## Executive Summary

**Secretariat** is a local-first, developer-centric secrets management system designed to **eliminate `.env` files entirely** while maintaining developer velocity. It provides a unified, secure, and auditable way to manage API keys, tokens, and credentials across multiple projects from a single point of control.

In an era of AI coding assistants, Secretariat also provides critical infrastructure for **controlling what secrets AI agents can access** - a capability that becomes essential as autonomous coding tools gain broader access to developer environments.

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

> **Eliminate `.env` files.** Create infrastructure that disappears while giving developers and teams full control over their secrets - including control over what AI agents can access.

### Core Principles

1. **Local-First:** Everything works offline, on your machine, under your control
2. **Zero Friction:** Faster than copy-pasting `.env` files
3. **No More `.env` Files:** Secrets never touch the filesystem in plain text
4. **Explicit & Auditable:** Know exactly what's being used where, by whom (human or AI)
5. **Secure by Default:** Best practices without extra effort
6. **AI-Ready:** First-class support for controlling AI agent access
7. **Scalable:** From indie hacker to enterprise team

---

## 3. Target Users

### Primary (Launch Focus)
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

Native macOS application for visual management.

**Features:**
- Secret management (CRUD)
- Environment configuration
- Application permissions dashboard
- Key lifecycle actions (rotate, revoke, replace)
- Provider onboarding wizards
- Usage analytics and audit trails

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

**Initial Platform Support:**
| Language | Framework | Priority |
|----------|-----------|----------|
| Dart | Flutter | High |
| Rust | Native | High |
| Go | Native | High |
| JavaScript | Node.js | High |
| Python | Native | High |

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

## 11. AI Agent Access Control

A dedicated system for managing what secrets AI coding assistants can access.

### 11.1 The Problem with AI Agents

AI coding assistants are powerful tools that:
- Read and modify code
- Execute terminal commands
- Access environment variables
- Make API calls on your behalf

**Without Secretariat:** AI agents have unrestricted access to every secret in your `.env` files - production credentials, API keys, database passwords - everything.

**With Secretariat:** You explicitly control which secrets each AI agent can access, with full audit trails.

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

### 11.1 Encryption

- All secrets encrypted at rest using industry-standard encryption
- Encryption key protected by macOS Keychain
- Transparent encryption/decryption by daemon

### 11.2 Authentication

**Local Authentication Options:**
- Passkeys
- Biometric (Touch ID)
- System password

**When Required:**
- First-time daemon unlock after boot
- Sensitive operations (export, bulk delete)
- Configurable re-authentication intervals

### 11.3 Runtime Access Control

Instant control capabilities:
- Revoke access to specific apps
- Block individual applications
- Disable specific keys globally
- **Security Kill-Switch:** Panic button to revoke ALL secrets for ALL apps instantly

### 11.4 Zero-Trust Principles

- No implicit trust between applications
- Explicit grants required
- Audit trail for all access
- Principle of least privilege by default

---

## 12. Key Lifecycle Management

### 12.1 Rotation

- Scheduled rotation reminders
- One-click rotation with automatic propagation
- Version history maintained
- Rollback capability

### 12.2 Compromise Response

When a key is leaked:
1. Instant revocation across all apps
2. Notification to affected projects
3. Guided re-creation flow
4. Audit of exposure window

### 12.3 Versioning

- Keep history of previous key values
- Controlled rollout of new keys
- A/B testing support (gradual rotation)

---

## 13. Audit & Monitoring

### 13.1 Usage Tracking

Track every access:
- Which application
- Which secret
- Which environment
- Timestamp
- Success/failure

### 13.2 Dry-Run & Explain Mode

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

### 13.3 Anomaly Detection

Basic signals for misuse detection:
- Unusual access patterns
- High-frequency requests
- Access from unexpected apps
- After-hours activity (configurable)

---

## 14. Virtual Environment Emulation

### 14.1 Secrets as Virtual Env

Drop-in replacement for `.env` files:
- Applications see standard environment variables
- No actual files written to disk
- Full compatibility with existing tools

### 14.2 Integration Modes

| Mode | Description |
|------|-------------|
| **SDK** | Native integration, recommended |
| **Env Injection** | Inject vars at process start |
| **File Emulation** | Virtual `.env` for legacy tools |

---

## 15. Team Features (Cloud Extension)

### 15.1 Purpose

Enable team and organization workflows while preserving local-first operation.

### 15.2 Capabilities

- **Secret Synchronization:** Sync across team members' machines
- **Team Access Control:** Role-based permissions
- **Organizational Policies:** Enforce standards across teams
- **Centralized Audit Logs:** Compliance-ready logging
- **Offboarding:** Instant access revocation when team members leave
- **Team Templates:** Pre-configured secret sets for common project types

### 15.3 Architecture

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

### 15.4 Offline-First Guarantee

- Local development works **100% without cloud**
- Cloud is additive, never mandatory
- Sync conflicts resolved gracefully
- Offline changes merge when reconnected

---

## 16. Business Model

### 16.1 Pricing Tiers

| Tier | Price | Features |
|------|-------|----------|
| **Free** | $0 | Local usage, unlimited projects, core SDKs |
| **Pro** | $X/month | Cloud sync, multiple machines, priority support |
| **Team** | $Y/user/month | Team features, shared secrets, audit logs |
| **Enterprise** | Custom | SSO, compliance, dedicated support, SLAs |

### 16.2 Open Source Strategy

**OSS Core + Paid Control Plane:**
- Daemon and SDKs: Open source (permissive license)
- CLI: Open source
- Cloud & Governance: Commercial

**Benefits:**
- Community trust and contributions
- Transparent security (auditable)
- Low barrier to adoption
- Clear upgrade path for teams

### 16.3 Target Customers

| Segment | Value Proposition |
|---------|-------------------|
| Freelancers | Organization without overhead |
| Agencies | Client isolation, easy offboarding |
| Startups | Scale without changing tools |
| Security-conscious orgs | Audit trails, compliance |

---

## 17. Strategic Value

### 17.1 Market Positioning

- **Not a vault replacement:** Complements, doesn't compete with HashiCorp Vault
- **Not enterprise-first:** Developer-first, enterprise-capable
- **Not cloud-dependent:** Local-first with cloud benefits

### 17.2 Competitive Advantages

1. **Developer Experience:** Faster than manual `.env` management
2. **Security:** Better than status quo without friction
3. **Flexibility:** Works for indie devs AND teams
4. **Transparency:** Open source core builds trust
5. **Modern Stack:** Built for today's multi-project, multi-environment reality

### 17.3 Growth Vectors

```
Indie Dev → Multiple Machines → Team → Organization
    │              │              │           │
    └──────────────┴──────────────┴───────────┘
         Natural expansion path, no tool change
```

---

## 18. Technical Constraints & Decisions

### 18.1 Platform

- **Initial:** macOS only
- **Future:** Linux, Windows (based on demand)

### 18.2 Not In Scope (v1)

- Detailed cryptographic specifications
- Exact IPC protocol design
- Provider-specific API automation
- Compliance certifications (SOC2, etc.)
- Mobile platform support

### 18.3 Open Questions

- [ ] Exact encryption algorithm selection
- [ ] IPC protocol (Unix sockets vs. gRPC vs. HTTP)
- [ ] SDK distribution strategy
- [ ] Pricing specifics
- [ ] Brand name finalization

---

## 19. Success Metrics

### 19.1 Adoption

- Daily active developers
- Projects connected
- Secrets managed

### 19.2 Engagement

- Access requests per day
- UI vs CLI usage ratio
- Feature utilization

### 19.3 Business

- Free to paid conversion
- Team tier adoption
- Churn rate

---

## 20. Next Steps

### Immediate (PID → PRD)

1. Technical architecture deep dive
2. Security model specification
3. UX/UI design exploration
4. SDK interface design
5. Pricing validation research

### Development Phases

| Phase | Focus | Deliverable |
|-------|-------|-------------|
| 1 | Core | Daemon + CLI + 2 SDKs |
| 2 | UX | Native macOS UI |
| 3 | Polish | Remaining SDKs, providers |
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

---

## Appendix B: User Stories

### Indie Developer
> "I start a new Flutter project. Instead of copying my OpenAI key from another project, the app requests it from my local secrets daemon. I approve once, and it just works."

### Team Lead
> "A contractor's engagement ends. I remove them from our team in the cloud dashboard. Their local daemon instantly loses access to all shared secrets."

### Security-Conscious Dev
> "I notice suspicious activity on my OpenAI account. I hit the kill switch, and within seconds, no app on my machine can access any API key until I re-authorize."

---

## Appendix C: Feature Priority Matrix

| Feature | Must Have | Should Have | Nice to Have |
|---------|-----------|-------------|--------------|
| Encrypted local storage | ✓ | | |
| Daemon + CLI | ✓ | | |
| Basic SDK (2 languages) | ✓ | | |
| macOS UI | | ✓ | |
| Provider onboarding | | ✓ | |
| Environment management | | ✓ | |
| Cloud sync | | | ✓ |
| Team features | | | ✓ |
| Ephemeral secrets | | | ✓ |

---

*Document Version: 2.0*
*Last Updated: December 2025*
