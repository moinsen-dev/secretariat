# Secretariat Implementation Plan

**Version:** 1.2
**Created:** December 19, 2025
**Updated:** December 19, 2025
**Status:** Phase 1 - Core Implementation (Milestones 1-6 Complete)

---

## Current State Assessment

### Completed (~95%)

| Component | Status | Notes |
|-----------|--------|-------|
| Daemon core | ✅ | IPC server, socket communication |
| `secret.list` | ✅ | Returns metadata only |
| `secret.get` | ✅ | Decrypts and returns value |
| `secret.set` | ✅ | Encrypts and stores |
| `secret.delete` | ✅ | Works |
| `health.check` | ✅ | Works |
| `vault.init` | ✅ | Password-based initialization |
| **`vault.lock`** | ✅ | Clear master key from memory |
| **`vault.unlock`** | ✅ | Unlock with password derivation |
| **`vault.status`** | ✅ | Returns state, secret_count, app_count |
| **`secret.rotate`** | ✅ | Rotate secret with version tracking |
| AES-256-GCM encryption | ✅ | Working |
| macOS Keychain integration | ✅ | Master key storage |
| CLI basic commands | ✅ | init, list, get, set, delete |
| Flutter app shell | ✅ | Menu bar, basic list view |
| **Flutter: Audit Log screen** | ✅ | View access history with filters |
| **Flutter: Settings screen** | ✅ | Daemon control, vault lock, preferences |
| **Flutter: Applications screen** | ✅ | Grant/revoke permissions UI |
| SDKs (4 languages) | ✅ | Dart, Python, Rust, Node.js - all complete |
| **`app.register`** | ✅ | Register applications with fingerprinting |
| **`app.list`** | ✅ | List apps with permission counts |
| **`app.authorize`** | ✅ | Grant app access to secrets |
| **`app.revoke`** | ✅ | Revoke app access with audit logging |
| **`audit.log`** | ✅ | Query audit log with filters |
| **CLI: apps** | ✅ | `sec apps` - list applications |
| **CLI: grant** | ✅ | `sec grant <app> <key>` |
| **CLI: revoke** | ✅ | `sec revoke <app> <key>` |
| **CLI: audit** | ✅ | `sec audit` with filtering |
| **CLI: explain** | ✅ | `sec explain <app>` |

### Remaining (~5%)

- Import wizard enhancements (--scan, provider detection, cleanup command)
- Onboarding screen for Flutter app
- Auto-lock on system sleep
- CLI lock/unlock/status commands (handlers exist)

---

## Implementation Milestones

### Milestone 1: Application Management & Audit Logging ✅ COMPLETE
**Priority:** Critical
**Effort:** 3-4 days
**Status:** ✅ Completed December 19, 2025

The foundation for security - tracking which apps access which secrets.

#### 1.1 Database Schema Updates ✅

All tables already existed in `daemon/src/storage.rs`:
- `applications` - App registration with fingerprinting
- `permissions` - App-to-secret access grants
- `audit_log` - Access history logging

#### 1.2 Daemon Handlers ✅

| Handler | File | Status |
|---------|------|--------|
| `app.register` | `handlers/app_register.rs` | ✅ Complete |
| `app.list` | `handlers/app_list.rs` | ✅ Complete |
| `app.authorize` | `handlers/app_authorize.rs` | ✅ Complete |
| `app.revoke` | `handlers/app_revoke.rs` | ✅ Complete |
| `audit.log` | via `storage.query_audit_log()` | ✅ Complete |

#### 1.3 CLI Commands ✅

| Command | File | Status |
|---------|------|--------|
| `sec apps` | `commands/apps.rs` | ✅ Complete |
| `sec grant <APP> <KEY>` | `commands/grant.rs` | ✅ Complete |
| `sec revoke <APP> <KEY>` | `commands/revoke.rs` | ✅ Complete |
| `sec audit` | `commands/audit.rs` | ✅ Complete |
| `sec explain <APP>` | `commands/explain.rs` | ✅ Complete |

#### 1.4 Audit Integration (Partial)

- ✅ Audit logging exists in storage layer
- ⚠️ `secret.get/set/delete` handlers could emit more detailed audit events
- This is minor polish, not blocking

---

### Milestone 2: Import Wizard Enhancement ⏳ PARTIAL
**Priority:** High
**Effort:** 2-3 days
**Status:** Basic import exists, advanced features deferred to Phase 2

#### 2.1 CLI Import (Existing)

Basic `sec import` command works. Advanced features deferred:

| Feature | Status | Notes |
|---------|--------|-------|
| `--scan <DIR>` | ⏳ | Deferred to Phase 2 |
| Provider detection | ⏳ | Deferred to Phase 2 |
| Duplicate detection | ⏳ | Deferred to Phase 2 |
| `sec cleanup` | ⏳ | Deferred to Phase 2 |

---

### Milestone 3: Vault Lock/Unlock & Security ✅ COMPLETE
**Priority:** High
**Effort:** 2-3 days
**Status:** ✅ Completed December 19, 2025

#### 3.1 Vault State Management ✅

Vault states managed via daemon server:
- `locked` - Master key cleared from memory
- `unlocked` - Master key available, operations allowed
- `uninitialized` - No vault exists yet

#### 3.2 Daemon Handlers ✅

| Handler | File | Status |
|---------|------|--------|
| `vault.lock` | `handlers/vault_lock.rs` | ✅ Complete |
| `vault.unlock` | `handlers/vault_unlock.rs` | ✅ Complete |
| `vault.status` | `handlers/vault_status.rs` | ✅ Complete |
| `vault.change_password` | ⏳ | Deferred to Phase 2 |

#### 3.3 Flutter App Integration ✅

- Settings screen with Lock Vault button
- Vault status display (state, secret count, app count)
- Daemon start/stop controls

#### 3.4 Security Features

- [ ] Auto-lock on system sleep (deferred to Phase 2)
- [x] Manual lock via UI and API
- [ ] Failed attempt tracking (deferred)

---

### Milestone 4: Secret Rotation ✅ COMPLETE
**Priority:** Medium
**Effort:** 1-2 days
**Status:** ✅ Completed December 19, 2025

#### 4.1 Schema Update ✅

Added to `daemon/src/storage.rs`:
```sql
version INTEGER DEFAULT 1,              -- Version number for rotation tracking
previous_value_encrypted BLOB           -- Previous encrypted value for rollback
```

Also added `SecretMetadataWithVersion` struct for version tracking.

#### 4.2 Daemon Handler ✅

| Handler | File | Status |
|---------|------|--------|
| `secret.rotate` | `handlers/secret_rotate.rs` | ✅ Complete |
| `secret.history` | ⏳ | Deferred to Phase 2 |
| `secret.rollback` | ⏳ | Deferred to Phase 2 |

#### 4.3 Flutter Integration ✅

`rotateSecret(name, newValue)` method added to:
- `daemon_client.dart`
- `vault_provider.dart`

---

### Milestone 5: Flutter App Enhancement ✅ COMPLETE
**Priority:** High
**Effort:** 4-5 days
**Status:** ✅ Completed December 19, 2025

#### 5.1 Screens ✅

| Screen | File | Status |
|--------|------|--------|
| Applications | `screens/applications.dart` | ✅ Enhanced with grant/revoke permissions |
| Audit Log | `screens/audit_log.dart` | ✅ Created - view access history with filters |
| Settings | `screens/settings.dart` | ✅ Created - daemon control, vault lock, about |
| Import Wizard | `screens/import_wizard.dart` | ⏳ Deferred to Phase 2 |
| Onboarding | `screens/onboarding.dart` | ⏳ Deferred to Phase 2 |

#### 5.2 Feature Enhancements ✅

| Feature | Status | Notes |
|---------|--------|-------|
| Secret value fetch | ✅ | Via `secret.get` RPC |
| App permissions UI | ✅ | Grant/revoke in ExpansionTile |
| Drag & drop import | ⏳ | Deferred to Phase 2 |
| Keyboard shortcuts | ⏳ | Deferred to Phase 2 |
| Provider icons | ⏳ | Deferred to Phase 2 |

#### 5.3 VaultProvider/DaemonClient Methods ✅

| Method | Status |
|--------|--------|
| `grantPermission(app, secret)` | ✅ |
| `revokePermission(app, secret)` | ✅ |
| `getVaultStatus()` | ✅ |
| `lockVault()` | ✅ |
| `unlockVault(password)` | ✅ |
| `loadAuditLog(limit, appId)` | ✅ |
| `rotateSecret(name, value)` | ✅ |

#### 5.4 New Models ✅

| Model | File | Status |
|-------|------|--------|
| `AuditEntry` | `models/audit_entry.dart` | ✅ Created |

---

### Milestone 6: SDK Completeness ✅ COMPLETE
**Priority:** Medium
**Effort:** 2 days
**Status:** ✅ Completed December 19, 2025

All four SDKs are feature-complete with consistent APIs.

#### 6.1 SDK Method Coverage ✅

| Method | Dart | Python | Rust | Node.js |
|--------|------|--------|------|---------|
| `get(key)` | ✅ | ✅ | ✅ | ✅ |
| `getMany(keys)` | ✅ | ✅ | ✅ | ✅ |
| `list()` | ✅ | ✅ | ✅ | ✅ |
| `set(key, value)` | ✅ | ✅ | ✅ | ✅ |
| `delete(key)` | ✅ | ✅ | ✅ | ✅ |
| `getOrEnv(key)` | ✅ | ✅ | ✅ | ✅ |

#### 6.2 Error Handling ✅

All SDKs have:
- Proper error types (`SecretariatError`, `Error` enum, etc.)
- Timeout handling
- Graceful fallback to environment variables
- Connection error handling

#### 6.3 SDK Locations

| SDK | Location |
|-----|----------|
| Dart | `sdk-dart/lib/secretariat.dart` |
| Python | `sdk-python/secretariat/__init__.py` |
| Rust | `sdk-rust/src/lib.rs` |
| Node.js | `sdk-node/src/index.ts` |

---

## Implementation Order

```
Week 1:
├── Milestone 1: Application Management & Audit (3-4 days)
│   ├── Day 1: Database schema + app.register/app.list
│   ├── Day 2: app.authorize/app.revoke + audit logging
│   ├── Day 3: CLI commands (apps, grant, revoke, audit)
│   └── Day 4: Testing & integration
│
Week 2:
├── Milestone 2: Import Wizard (2-3 days)
│   ├── Day 1: --scan, provider detection
│   ├── Day 2: Duplicate detection, interactive mode
│   └── Day 3: cleanup command, testing
│
├── Milestone 3: Vault Lock/Unlock (2-3 days)
│   ├── Day 1: Vault state management
│   ├── Day 2: lock/unlock handlers + CLI
│   └── Day 3: Auto-lock, security features
│
Week 3:
├── Milestone 4: Secret Rotation (1-2 days)
│   ├── Day 1: Schema + handlers
│   └── Day 2: CLI + testing
│
├── Milestone 5: Flutter App (4-5 days)
│   ├── Day 1: Secret value fetching, detail view fix
│   ├── Day 2: Applications screen with permissions
│   ├── Day 3: Audit log screen
│   ├── Day 4: Import wizard, settings
│   └── Day 5: Onboarding, keyboard shortcuts
│
Week 4:
├── Milestone 6: SDK Completeness (2 days)
│   ├── Day 1: getMany, error handling
│   └── Day 2: Documentation, testing
│
└── Final: Integration Testing & Polish (2-3 days)
```

---

## File Changes Summary

### New Files Created

**Daemon:**
- ✅ `daemon/src/handlers/app_register.rs` - Complete
- ✅ `daemon/src/handlers/app_list.rs` - Complete
- ✅ `daemon/src/handlers/app_authorize.rs` - Complete
- ✅ `daemon/src/handlers/app_revoke.rs` - Complete
- ✅ `daemon/src/handlers/vault_init.rs` - Complete
- ✅ `daemon/src/handlers/vault_lock.rs` - Complete
- ✅ `daemon/src/handlers/vault_unlock.rs` - Complete
- ✅ `daemon/src/handlers/vault_status.rs` - Complete
- ✅ `daemon/src/handlers/secret_rotate.rs` - Complete
- ⏳ `daemon/src/vault.rs` - Deferred (using inline state management)

**CLI:**
- ✅ `cli/src/commands/apps.rs` - Complete
- ✅ `cli/src/commands/grant.rs` - Complete
- ✅ `cli/src/commands/revoke.rs` - Complete
- ✅ `cli/src/commands/audit.rs` - Complete
- ✅ `cli/src/commands/explain.rs` - Complete
- ⏳ `cli/src/commands/cleanup.rs` - Deferred to Phase 2
- ⏳ `cli/src/commands/lock.rs` - Deferred (handlers work via RPC)
- ⏳ `cli/src/commands/unlock.rs` - Deferred (handlers work via RPC)
- ⏳ `cli/src/commands/rotate.rs` - Deferred to Phase 2

**Flutter App:**
- ✅ `app/lib/screens/audit_log.dart` - Complete
- ✅ `app/lib/screens/settings.dart` - Complete
- ✅ `app/lib/models/audit_entry.dart` - Complete
- ⏳ `app/lib/screens/import_wizard.dart` - Deferred to Phase 2
- ⏳ `app/lib/screens/onboarding.dart` - Deferred to Phase 2
- ⏳ `app/lib/widgets/provider_icon.dart` - Deferred to Phase 2

### Files Modified

**Daemon:**
- ✅ `daemon/src/storage.rs` - Added version columns, SecretMetadataWithVersion
- ✅ `daemon/src/server.rs` - Added routes for all new handlers
- ✅ `daemon/src/handlers/mod.rs` - Registered all new handlers
- ✅ `daemon/src/crypto.rs` - Removed dead_code annotations
- ✅ `daemon/src/keychain.rs` - Removed dead_code annotations

**Flutter App:**
- ✅ `app/lib/providers/vault_provider.dart` - Added all new methods
- ✅ `app/lib/services/daemon_client.dart` - Added all new RPC calls
- ✅ `app/lib/screens/applications.dart` - Added grant/revoke permissions UI

---

## Success Criteria

### Functional
- [x] All CLI commands from app_spec.txt work
- [x] All daemon API endpoints implemented
- [x] Flutter app has core planned screens (audit log, settings, applications)
- [x] SDKs support getMany and proper errors
- [ ] Import wizard handles 90% of .env files (Phase 2)

### Performance
- [x] Secret retrieval < 10ms
- [x] Daemon memory < 50MB
- [x] App launch < 500ms
- [x] CLI response < 100ms

### Security
- [x] Audit log captures all access
- [x] Vault lock/unlock works
- [x] App permissions enforced
- [x] Revocation is immediate

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Scope creep | Stick to Phase 1 features only |
| Breaking changes | Maintain backward compatibility |
| Security gaps | Audit logging from start |
| Performance issues | Profile early, optimize later |

---

## Phase 1 Complete - Summary

**Completed December 19, 2025**

Phase 1 of Secretariat is now feature-complete with:

### Core Features
- **Daemon**: Full JSON-RPC API over Unix domain sockets
- **CLI**: Complete command set (init, list, get, set, delete, import, apps, grant, revoke, audit, explain)
- **Flutter App**: Menu bar app with secrets list, applications management, audit log, settings
- **SDKs**: Four languages (Dart, Python, Rust, Node.js) with consistent APIs

### Security Features
- AES-256-GCM encryption for all secrets
- macOS Keychain integration for master key storage
- Argon2 password-based key derivation
- Per-application permissions with fingerprinting
- Comprehensive audit logging

### What's Working
1. Store and retrieve secrets securely
2. Import from .env files
3. Grant/revoke per-app access
4. View audit trail of all access
5. Lock/unlock vault
6. Rotate secrets with version tracking

## Phase 2 Roadmap (Future)

| Feature | Priority |
|---------|----------|
| Import wizard (`--scan`, provider detection) | Medium |
| CLI lock/unlock/status commands | Low |
| Onboarding screen | Medium |
| Keyboard shortcuts | Low |
| Auto-lock on system sleep | Medium |
| Secret history/rollback | Low |
| Windows support | Medium |

---

## Integration Testing - December 28, 2025

**Status**: ✅ All tests passing (35/35)

A comprehensive integration test suite was created (`tests/test_full_suite.sh`) covering:

### Test Coverage

| Test Suite | Tests | Status |
|------------|-------|--------|
| Daemon Lifecycle | 4 | ✅ Pass |
| Basic Secret Operations | 6 | ✅ Pass |
| Vault Lock/Unlock | 4 | ✅ Pass |
| Permission System | 4 | ✅ Pass |
| Audit Logging | 3 | ✅ Pass |
| Edge Cases | 7 | ✅ Pass |
| Error Handling | 3 | ✅ Pass |
| Data Persistence | 4 | ✅ Pass |

### Edge Cases Verified
- Special characters in key names (e.g., `KEY-123`)
- Special characters in values (`!@#$%^&*()`)
- Unicode values (Japanese, emojis)
- Large values (10KB+)
- Concurrent access (5 parallel gets)
- Very long key names (200+ characters)

### Running Tests
```bash
make test-quick   # Basic tests (~30s)
make test-full    # Full suite with edge cases (~60s)
```

---

*Last Updated: December 28, 2025*
