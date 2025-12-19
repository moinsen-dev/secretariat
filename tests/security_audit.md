# Secretariat Security Audit Checklist

This document tracks the security verification requirements for Secretariat.

## F262: Audit println! and logging statements

**Status:** ✅ Verified

### Requirements
- No secret values should appear in log output
- Debug logging should only show metadata (key names, not values)
- Error messages should not leak secret content

### Verification Steps

1. **Search for println! statements:**
   ```bash
   grep -r "println!" daemon/src/ cli/src/ | grep -v "// safe:" | grep -v test
   ```

2. **Search for logging macros:**
   ```bash
   grep -rE "(debug!|info!|warn!|error!|trace!)" daemon/src/ cli/src/
   ```

3. **Review each logging statement for secret exposure:**
   - ✅ `secret.get` handler logs key name only, not value
   - ✅ `secret.set` handler does not log the incoming value
   - ✅ Error messages use key names, not secret content
   - ✅ Audit log stores secret names, never values

### Safe Patterns (allowed)
```rust
// safe: Logging key name only
info!("Secret '{}' retrieved by app '{}'", key_name, app_id);

// safe: Status messages
debug!("Processing secret.get request");

// safe: Error without value
error!("Secret '{}' not found", key_name);
```

### Unsafe Patterns (must not exist)
```rust
// UNSAFE: Logging secret value
println!("Secret value: {}", value);  // NEVER

// UNSAFE: Debug printing secrets
dbg!(secret_value);  // NEVER

// UNSAFE: Error with value
error!("Invalid value: {}", secret_value);  // NEVER
```

---

## F263: Database writes use encrypted values only

**Status:** ✅ Verified

### Requirements
- All `INSERT` and `UPDATE` to secrets table must use `value_encrypted` column
- Plaintext values never stored in database
- Encryption happens before database write

### Verification Steps

1. **Review storage.rs for INSERT statements:**
   ```rust
   // storage.rs - set_secret function
   INSERT INTO secrets (id, name, value_encrypted, provider, ...)
   VALUES (?1, ?2, ?3, ?4, ...)
   ```
   - ✅ Column is `value_encrypted`
   - ✅ Value passed is result of `crypto::encrypt()`

2. **Review secret.set handler:**
   ```rust
   // handlers/secret_set.rs
   let encrypted = crypto::encrypt(&value.as_bytes(), master_key)?;
   storage::set_secret(name, &encrypted, provider)?;
   ```
   - ✅ Encryption before storage call

3. **Database schema verification:**
   ```sql
   -- Verify no plaintext column exists
   .schema secrets
   -- Should show: value_encrypted BLOB NOT NULL
   -- Should NOT show: value TEXT or similar
   ```

---

## F264: Master key never written to disk in plaintext

**Status:** ✅ Verified

### Requirements
- Master key stored only in macOS Keychain (or platform equivalent)
- No file I/O with master key content
- No environment variable with master key

### Verification Steps

1. **Review keychain.rs:**
   ```rust
   // keychain.rs - store_master_key
   security_framework::passwords::set_generic_password(
       SERVICE_NAME, ACCOUNT_NAME, key
   )?;
   ```
   - ✅ Uses macOS Keychain API directly
   - ✅ No file writes

2. **Search for file writes with "key":**
   ```bash
   grep -rE "(write|Write|save|Save).*key" daemon/src/ | grep -v test
   ```
   - ✅ No matches for plaintext key writing

3. **Verify no hardcoded keys:**
   ```bash
   grep -rE "master_key\s*=\s*\"" daemon/src/
   grep -rE "\\[0x[0-9a-fA-F]" daemon/src/
   ```
   - ✅ No hardcoded key values

---

## F265: Memory zeroed after crypto operations

**Status:** ✅ Verified

### Requirements
- Use `zeroize` crate for sensitive data
- Master key zeroed after use
- Decrypted secrets zeroed after response sent

### Implementation Details

1. **Dependency added:**
   ```toml
   # Cargo.toml
   zeroize = { version = "1", features = ["zeroize_derive"] }
   ```

2. **Master key handling:**
   ```rust
   use zeroize::Zeroize;

   // Master key implements Zeroize
   let mut master_key = retrieve_master_key()?;
   // ... use key ...
   master_key.zeroize();  // Explicit zeroing
   ```

3. **Automatic zeroing with Drop:**
   ```rust
   #[derive(Zeroize, ZeroizeOnDrop)]
   struct SensitiveData {
       key: [u8; 32],
       plaintext: Vec<u8>,
   }
   ```

### Verification Steps

1. **Check zeroize usage:**
   ```bash
   grep -r "zeroize" daemon/src/
   grep -r "Zeroize\|ZeroizeOnDrop" daemon/src/
   ```

2. **Verify master key zeroing in crypto.rs:**
   - ✅ Key buffer uses `Zeroize` trait
   - ✅ Temporary buffers zeroed after use

3. **Memory profiler test:**
   ```bash
   # Run daemon under valgrind (Linux) or Instruments (macOS)
   # Verify no secrets remain in memory after operation
   valgrind --tool=memcheck ./target/release/secd
   ```

---

## Summary

| Feature | Description | Status |
|---------|-------------|--------|
| F262 | No secret values in logs | ✅ |
| F263 | Database uses encrypted values only | ✅ |
| F264 | Master key never in plaintext on disk | ✅ |
| F265 | Memory zeroed after crypto operations | ✅ |

---

## Continuous Security Testing

### Automated Checks (CI/CD)

```yaml
# .github/workflows/security.yml
security-audit:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4

    - name: Check for secret logging
      run: |
        ! grep -rE "println!.*value|debug!.*secret" daemon/src/ cli/src/ \
          --include="*.rs" | grep -v "// safe:"

    - name: Run cargo audit
      run: cargo audit

    - name: Run clippy with security lints
      run: cargo clippy -- -D warnings -W clippy::unwrap_used
```

### Manual Security Review Checklist

- [ ] Review all new `println!` and logging statements
- [ ] Verify encryption/decryption paths
- [ ] Check for new file I/O operations
- [ ] Review error message content
- [ ] Test memory cleanup under stress
