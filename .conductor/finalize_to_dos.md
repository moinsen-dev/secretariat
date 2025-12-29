# Placeholder Hunt Report

> Generated on 2025-12-29 (Updated scan)
> Previous scan: 2025-12-28
> Scanned ~55 source files (Rust + Dart/Flutter)
> Scope: Full project scan
> Project: Secretariat - Local Secrets Orchestrator

---

## Executive Summary

| Category | Total | Critical (P0) | High (P1) | Medium (P2) | Low (P3) |
|----------|-------|---------------|-----------|-------------|----------|
| Platform Not Implemented | 4 | 0 | 4 | 0 | 0 |
| Placeholder Code | 3 | 0 | 2 | 1 | 0 |
| Debug Logging | 25+ | 0 | 0 | 25+ | 0 |
| Android Build TODOs | 2 | 0 | 0 | 2 | 0 |
| Documentation TODOs | 4 | 0 | 0 | 4 | 0 |
| Dead Code (intentional) | 12 | 0 | 0 | 0 | 12 |
| **Total** | **50+** | **0** | **6** | **32+** | **12** |

**Status**: MEDIUM RISK - No critical security issues, but platform support gaps exist
**Estimated Effort:** ~8-12 hours (for High priority items)

### What's Good (Not Found)

- No hardcoded credentials in production code
- No NotImplementedError/unimplemented!() macros in active code paths
- No disabled tests (#[ignore] or skip: true)
- No empty catch blocks - all have proper error handling
- No fake data (lorem ipsum, example.com, John Doe) in production code
- No todo!() macros
- No magic numbers in business logic

---

## Critical (P0) - Must Fix Before Production

**No critical issues found in this scan.**

Previous critical issues (from 2025-12-28) have been addressed:
- [x] Hardcoded development encryption key - FIXED
- [x] Development master key fallback - FIXED
- [x] Windows Named Pipes crash - FIXED (graceful error)
- [x] TODO in security-critical path - FIXED

---

## High (P1) - Fix Before Release

### 1. Platform Support Not Implemented - Linux/Windows Keychain

**Files affected:**
- `/Users/udi/work/moinsen/ideas/local_secrets_orchestrator/daemon/src/keychain.rs`
- `/Users/udi/work/moinsen/ideas/local_secrets_orchestrator/daemon/src/system_events.rs`
- `/Users/udi/work/moinsen/ideas/local_secrets_orchestrator/daemon/src/handlers/app_register.rs`

**Pattern:** "Not yet implemented" for Linux/Windows platforms

**daemon/src/keychain.rs:33-34**
```rust
/// - **Linux**: Not yet implemented (TODO: use Secret Service API)
/// - **Windows**: Not yet implemented (TODO: use Credential Manager)
```

**daemon/src/keychain.rs:153-154**
```rust
/// - **Linux**: Not yet implemented (returns Ok(true) as placeholder)
/// - **Windows**: Not yet implemented (returns Ok(true) as placeholder)
```

**Risk:** Linux and Windows users will not have native keychain integration. Error messages are now user-friendly (from previous fix), but functionality is limited.

**Suggested Fix:**
- Linux: Implement using `secret-service` crate or `libsecret` bindings
- Windows: Implement using `windows-credentials` crate

**Effort:** 4-8 hours per platform

---

### 2. Touch ID Unlock Placeholder in Flutter App

**File:** `/Users/udi/work/moinsen/ideas/local_secrets_orchestrator/app/lib/screens/main_shell.dart:142-143`

```dart
// For now, this is a placeholder - full implementation would need
// keychain integration to retrieve the password
```

**Context:**
```dart
onTouchIdUnlock: () async {
  // Touch ID authentication is handled by the dialog
  // After successful auth, we still need to unlock with stored password
  // For now, this is a placeholder - full implementation would need
  // keychain integration to retrieve the password
  final provider = Provider.of<VaultProvider>(context, listen: false);
  // In a full implementation, retrieve password from keychain here
  await provider.loadSecrets();
  await provider.loadApplications();
```

**Risk:** Touch ID unlock appears to work but doesn't actually unlock the vault securely - it bypasses the password requirement by loading data without proper decryption.

**Suggested Fix:** Integrate with iOS/macOS keychain to store and retrieve the master password after biometric authentication.

**Effort:** 2-4 hours

---

### 3. System Events Not Implemented - Linux/Windows

**File:** `/Users/udi/work/moinsen/ideas/local_secrets_orchestrator/daemon/src/system_events.rs:9-10`

```rust
//! - **Linux**: Uses systemd-logind or UPower (not yet implemented)
//! - **Windows**: Uses SetSuspendState/WM_POWERBROADCAST (not yet implemented)
```

**Line 135:**
```rust
/// On Linux/Windows, sleep monitoring is not yet implemented.
```

**Risk:** On Linux/Windows, the daemon won't auto-lock on system sleep, potentially leaving secrets accessible.

**Suggested Fix:** Implement using D-Bus for Linux, Win32 API for Windows.

**Effort:** 2-4 hours per platform

---

### 4. Unreachable Code in Client

**File:** `/Users/udi/work/moinsen/ideas/local_secrets_orchestrator/cli/src/client.rs:198`

```rust
unreachable!()
```

**Context:** Located in retry loop for daemon startup. After exhausting retries, this `unreachable!()` is hit.

**Risk:** If daemon startup fails after max retries, this will panic instead of returning a proper error.

**Suggested Fix:** Return a proper `Err(anyhow!("Failed to start daemon after N attempts"))` instead of `unreachable!()`.

**Effort:** 15 minutes

---

## Medium (P2) - Should Address

### 1. Debug Logging Statements (debugPrint) - 25+ occurrences

**Files affected:**
- `/Users/udi/work/moinsen/ideas/local_secrets_orchestrator/app/lib/main.dart` (18 occurrences)
- `/Users/udi/work/moinsen/ideas/local_secrets_orchestrator/app/lib/services/daemon_client.dart` (1 occurrence)
- `/Users/udi/work/moinsen/ideas/local_secrets_orchestrator/app/lib/services/daemon_manager.dart` (1 occurrence)
- `/Users/udi/work/moinsen/ideas/local_secrets_orchestrator/app/lib/providers/vault_provider.dart` (2 occurrences)
- `/Users/udi/work/moinsen/ideas/local_secrets_orchestrator/app/lib/widgets/vault_unlock_dialog.dart` (2 occurrences)
- `/Users/udi/work/moinsen/ideas/local_secrets_orchestrator/app/lib/screens/main_shell.dart` (1 occurrence)
- `/Users/udi/work/moinsen/ideas/local_secrets_orchestrator/app/lib/screens/import_wizard.dart` (1 occurrence)
- `/Users/udi/work/moinsen/ideas/local_secrets_orchestrator/app/test/daemon_client_integration_test.dart` (6 occurrences - test file, OK)

**Example from app/lib/main.dart:**
```dart
debugPrint('[WindowManager] Initialized with minimum size 800x600');
debugPrint('[WindowManager] Failed to initialize: $e');
debugPrint('[Main] Checking daemon status...');
debugPrint('[Main] Daemon status: $status');
debugPrint('[SystemTray] Initialized successfully');
```

**Note:** Flutter's `debugPrint` only appears in debug builds, so this is less critical than raw `print()`.

**Risk:** Potential information disclosure in debug builds, performance impact.

**Suggested Fix:**
- Replace with proper logging framework (e.g., `logger` package)
- Or wrap in `kDebugMode` check for explicit control
- Consider structured logging for production telemetry

**Effort:** 1-2 hours

---

### 2. Android Build Configuration TODOs

**File:** `/Users/udi/work/moinsen/ideas/local_secrets_orchestrator/app/android/app/build.gradle.kts`

**Line 23:**
```kotlin
// TODO: Specify your own unique Application ID
applicationId = "dev.moinsen.secretariat"
```
**Note:** The application ID is already set correctly. TODO comment is stale.

**Line 35:**
```kotlin
// TODO: Add your own signing config for the release build.
// Signing with the debug keys for now, so `flutter run --release` works.
signingConfig = signingConfigs.getByName("debug")
```
**Note:** Release builds will use debug signing, not suitable for Play Store.

**Suggested Fix:**
- Remove first TODO (application ID is already correct)
- Create proper release signing configuration before Play Store submission

**Effort:** 30 minutes to remove TODO, 1 hour for signing config

---

### 3. Outdated Server Documentation

**File:** `/Users/udi/work/moinsen/ideas/local_secrets_orchestrator/daemon/src/server.rs:408`

```rust
/// Currently returns placeholder responses for all methods.
```

**Risk:** This documentation is outdated - methods are actually implemented.

**Suggested Fix:** Update documentation to reflect current implementation state.

**Effort:** 10 minutes

---

### 4. SDK Documentation Examples Using unwrap()

**File:** `/Users/udi/work/moinsen/ideas/local_secrets_orchestrator/sdk-rust/src/lib.rs` (multiple locations)

Examples use `.unwrap()` extensively:
```rust
/// let client = Secretariat::new().unwrap();
/// let api_key = client.get("OPENAI_API_KEY").unwrap();
```

**Risk:** Users copying examples may not handle errors properly in their applications.

**Suggested Fix:** Show proper error handling with `?` operator or `expect()` with descriptive messages.

**Effort:** 30 minutes

---

## Low (P3) - Nice to Have

### 1. Dead Code Annotations (#[allow(dead_code)]) - 12 occurrences

These are intentionally marked with explanatory comments and are acceptable:

| File | Function/Field | Reason |
|------|----------------|--------|
| daemon/src/crypto.rs:62 | `generate_master_key()` | "Kept for API completeness" |
| daemon/src/handlers/vault_unlock.rs:15 | `status` field | Part of result struct |
| daemon/src/handlers/vault_lock.rs:13,19 | `VaultLockResult` | Handler coordination |
| daemon/src/keychain.rs:116 | `delete_master_key()` | "Used for vault reset" |
| daemon/src/keychain.rs:156,213 | biometric functions | "Phase 2 features" |
| daemon/src/storage.rs:60,141,327,379,397,943 | Various methods | Future use documented |
| daemon/src/server.rs:102,255 | Server methods | "Testing/compatibility" |
| cli/src/commands/import.rs:49 | `SetResponse` | Deserialization validation |
| cli/src/commands/explain.rs:36 | `app_id` field | API response structure |
| cli/src/commands/unlock.rs:16 | `password` field | Reserved for future feature |

**Assessment:** All are properly documented and intentional. No action needed.

---

### 2. Console Print Statements in CLI (Intentional)

The CLI uses `println!()` and `eprintln!()` extensively for user-facing output. This is intentional and correct for command-line tools.

**Files:** `cli/src/commands/*.rs`, `daemon/src/main.rs`

---

### 3. Unsafe Block in Daemon

**File:** `/Users/udi/work/moinsen/ideas/local_secrets_orchestrator/daemon/src/main.rs:134`

```rust
let result = unsafe { libc::kill(pid as i32, 0) };
```

**Assessment:** This is a standard POSIX pattern for checking if a process exists (sending signal 0). The unsafe block is minimal and well-understood.

**Risk:** Low - idiomatic Rust for POSIX operations.

---

## Quick Wins (< 15 minutes each)

1. [ ] **cli/src/client.rs:198** - Replace `unreachable!()` with proper error return (~5 min)
2. [ ] **daemon/src/server.rs:408** - Update outdated documentation (~5 min)
3. [ ] **app/android/app/build.gradle.kts:23** - Remove resolved TODO comment (~2 min)

**Total Quick Win Effort:** ~15 minutes

---

## Needs Implementation (> 1 hour each)

| Task | Effort | Priority |
|------|--------|----------|
| Linux Keychain Support (Secret Service API) | 4-8 hours | HIGH |
| Windows Keychain Support (Credential Manager) | 4-8 hours | HIGH |
| Touch ID Unlock (keychain password storage) | 2-4 hours | HIGH |
| Debug Logging Cleanup (proper logging framework) | 1-2 hours | MEDIUM |
| Linux System Events (D-Bus integration) | 2-4 hours | MEDIUM |
| Windows System Events (Win32 API) | 2-4 hours | MEDIUM |
| Android Release Signing | 1 hour | MEDIUM |

---

## Needs Discussion

1. **Platform Support Priority** - Should Linux or Windows be implemented first?
2. **Debug Logging Strategy** - Use a logging framework, or just wrap in kDebugMode?
3. **Touch ID Implementation** - Is the current placeholder behavior acceptable for initial macOS release?

---

## By File (for focused cleanup)

### High Priority Files

| File | Issues | Priority |
|------|--------|----------|
| daemon/src/keychain.rs | 3 platform TODOs | HIGH |
| app/lib/screens/main_shell.dart | 1 Touch ID placeholder | HIGH |
| cli/src/client.rs | 1 unreachable!() | HIGH |
| daemon/src/system_events.rs | 2 platform TODOs | HIGH |

### Medium Priority Files

| File | Issues | Priority |
|------|--------|----------|
| app/lib/main.dart | 18 debugPrint calls | MEDIUM |
| app/lib/services/*.dart | 2 debugPrint calls | MEDIUM |
| app/android/app/build.gradle.kts | 2 stale TODOs | MEDIUM |
| daemon/src/server.rs | 1 outdated doc | MEDIUM |

---

## Pattern Distribution

```
Platform Support Gaps:  ||||       4 issues (HIGH)
Placeholder Code:       |||        3 issues (HIGH/MEDIUM)
Debug Logging:          ||||||||||||||||||||||||| 25+ (MEDIUM)
Build Config TODOs:     ||         2 issues (MEDIUM)
Documentation TODOs:    ||||       4 issues (LOW)
Dead Code (OK):         ||||||||||||  12 issues (intentional, LOW)
```

---

## Recommendations

### Immediate Actions (Before Next Release)
1. **Replace unreachable!()** - Prevents potential panic in production
2. **Review Touch ID behavior** - Decide if placeholder is acceptable
3. **Update outdated docs** - Quick wins with high clarity impact

### Short-Term (Next Sprint)
1. **Implement logging framework** - Replace all debugPrint with proper logging
2. **Android release signing** - Prepare for app store submission

### Long-Term (Roadmap)
1. **Linux platform support** - Keychain + system events
2. **Windows platform support** - Keychain + system events

### Process Improvements
1. **Pre-commit hook** - Warn on `debugPrint` in non-test files
2. **CI pipeline** - Flag `unreachable!()` or `panic!()` in non-test code
3. **Platform tracking** - Create GitHub issues for Linux/Windows support

---

## Comparison with Previous Scan (2025-12-28)

| Category | Previous | Current | Change |
|----------|----------|---------|--------|
| Critical (P0) | 4 (all fixed) | 0 | Maintained |
| High (P1) | 8 (all fixed) | 6 new found | +6 edge cases |
| Medium (P2) | 17 | 32+ | More thorough scan |
| Low (P3) | 0 | 12 | Documented dead_code |

**Notes:**
- Previous critical/high fixes remain in place
- This scan identified additional platform support gaps
- debugPrint count increased due to more thorough scanning
- #[allow(dead_code)] patterns now documented as intentional

---

**Generated**: 2025-12-29
**Analysis Type**: placeholder-hunt
**Report Path**: `.conductor/finalize_to_dos.md`
