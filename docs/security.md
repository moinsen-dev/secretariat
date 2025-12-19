# Security Architecture

This document explains Secretariat's security design and implementation.

## Overview

Secretariat uses a defense-in-depth approach with multiple security layers:

1. **Encryption at Rest** - AES-256-GCM for all stored secrets
2. **Key Protection** - Master key stored in OS keychain
3. **Access Control** - Per-app, per-secret permissions
4. **Audit Logging** - Complete access history
5. **Memory Safety** - Automatic secret zeroing

## Encryption

### Algorithm: AES-256-GCM

Secretariat uses AES-256-GCM (Galois/Counter Mode), which provides:

- **256-bit key strength** - Resistant to brute force attacks
- **Authenticated encryption** - Detects tampering automatically
- **128-bit authentication tag** - Cryptographic integrity verification

### Implementation

```
┌─────────────────────────────────────────────────────┐
│                   Secret Storage                     │
├─────────────────────────────────────────────────────┤
│  plaintext ─────┐                                   │
│                 │                                   │
│                 ▼                                   │
│  ┌─────────────────────────────────────────────┐   │
│  │              AES-256-GCM                     │   │
│  │  ┌─────────┐  ┌──────────┐  ┌───────────┐   │   │
│  │  │ Master  │  │  Random  │  │ Plaintext │   │   │
│  │  │   Key   │  │  Nonce   │  │   Data    │   │   │
│  │  │(32 bytes)│  │(12 bytes)│  │(variable) │   │   │
│  │  └────┬────┘  └────┬─────┘  └─────┬─────┘   │   │
│  │       │            │              │         │   │
│  │       ▼            ▼              ▼         │   │
│  │  ┌─────────────────────────────────────┐   │   │
│  │  │           Encryption                │   │   │
│  │  └─────────────────────────────────────┘   │   │
│  │                    │                        │   │
│  │                    ▼                        │   │
│  │  ┌──────────────────────────────────────┐  │   │
│  │  │ Nonce │ Ciphertext │ Auth Tag (16B) │  │   │
│  │  └──────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────┘   │
│                       │                             │
│                       ▼                             │
│              ┌────────────────┐                    │
│              │  SQLite BLOB   │                    │
│              │  (encrypted)   │                    │
│              └────────────────┘                    │
└─────────────────────────────────────────────────────┘
```

### Key Properties

1. **Unique Nonce per Operation**
   - Every encryption generates a fresh 96-bit random nonce
   - Prevents nonce reuse attacks
   - Provides semantic security (same plaintext → different ciphertext)

2. **Authentication Tag**
   - 128-bit GCM authentication tag appended to ciphertext
   - Verified before decryption
   - Detects any modification to ciphertext

3. **Fail-Secure Decryption**
   - Wrong key → authentication failure
   - Modified ciphertext → authentication failure
   - Truncated data → authentication failure

## Master Key Management

### Key Derivation

The master key is derived from the user's password using Argon2id:

```
Password + Salt ─────► Argon2id ─────► 256-bit Master Key
                           │
                           ├── Memory: 64 MB
                           ├── Iterations: 3
                           └── Parallelism: 4
```

Argon2id parameters are tuned for:
- **Resistance to GPU attacks** - High memory requirement
- **Resistance to ASIC attacks** - Memory-hard function
- **Usable latency** - < 500ms on typical hardware

### Key Storage

The master key is stored in the OS secure keychain:

| Platform | Storage Mechanism |
|----------|------------------|
| macOS | Keychain Services (SecItemAdd) |
| Windows | Credential Manager |
| Linux | Secret Service API |

**Key properties:**
- Protected by OS-level security
- Requires biometric or password to access
- Never written to disk in plaintext
- Cleared from memory after use

### Keychain Entry

```
Service: com.secretariat.daemon
Account: master_key
Data: [32 bytes - encrypted by keychain]
Access: Requires user authentication (Touch ID/password)
```

## Access Control

### Application Registration

When an application first requests a secret, it's registered with:

```
┌───────────────────────────────────────────┐
│           Application Identity            │
├───────────────────────────────────────────┤
│  app_id:      UUID                        │
│  name:        my-python-app               │
│  path:        /usr/bin/python3            │
│  bundle_id:   com.python.python3          │
│  fingerprint: SHA-256 of executable       │
│  pid:         1234 (current process)      │
└───────────────────────────────────────────┘
```

### Permission Model

Permissions are stored per-app, per-secret:

```sql
permissions (
    app_id    → applications.id
    secret_id → secrets.id
    granted_at
    granted_by  -- 'user' or 'auto'
)
```

**Permission flow:**

```
App requests secret.get("OPENAI_API_KEY")
           │
           ▼
┌─────────────────────────┐
│  Check permissions      │
│  table for (app, key)   │
└───────────┬─────────────┘
            │
    ┌───────┴───────┐
    │               │
    ▼               ▼
 Granted         Denied
    │               │
    ▼               ▼
 Decrypt       Return error
 & return      Log attempt
```

### Revocation

Permission revocation is **immediate**:
- Delete from permissions table
- No caching of permissions
- Next request will fail

## Audit Logging

### What's Logged

| Event | Fields |
|-------|--------|
| Secret read | timestamp, app_id, secret_name, success |
| Secret write | timestamp, app_id, secret_name, success |
| Secret delete | timestamp, app_id, secret_name, success |
| Permission grant | timestamp, app_id, secret_name, granted_by |
| Permission revoke | timestamp, app_id, secret_name |
| Failed access | timestamp, app_id, secret_name, reason |

### What's NOT Logged

- Secret values (never!)
- Master key material
- Decrypted content

### Retention

- Default: 30 days
- Configurable per deployment
- Automatic cleanup of old entries

## Memory Safety

### Zeroization

All sensitive data is zeroed from memory after use:

```rust
use zeroize::{Zeroize, ZeroizeOnDrop};

#[derive(ZeroizeOnDrop)]
struct SensitiveBuffer {
    key: [u8; 32],
    plaintext: Vec<u8>,
}

// Automatically zeroed when dropped
```

### Memory Protections

1. **No secret logging** - Values never printed
2. **Short lifetime** - Secrets decrypted only when needed
3. **Explicit zeroing** - Using zeroize crate
4. **Stack allocation** - Fixed-size keys on stack when possible

## Threat Model

### Protected Against

| Threat | Mitigation |
|--------|------------|
| Disk theft | AES-256-GCM encryption |
| Memory dump | Zeroization after use |
| Network sniffing | Local Unix socket only |
| Unauthorized app | Permission system |
| Tampering | GCM authentication |
| Brute force | Argon2id key derivation |

### Not Protected Against

| Threat | Reason |
|--------|--------|
| Kernel-level malware | Requires OS compromise |
| Physical keylogger | Beyond software scope |
| User coercion | Social engineering |
| Memory freezing | Requires physical access |

## Security Recommendations

### For Users

1. **Use a strong master password** - 16+ characters, unique
2. **Enable Touch ID** - Faster and more secure than typing
3. **Review audit logs** - Check for unexpected access
4. **Revoke unused apps** - Minimize attack surface
5. **Keep software updated** - Security patches

### For Developers

1. **Minimize secret lifetime** - Fetch, use, forget
2. **Don't log secrets** - Ever, even in debug mode
3. **Use SDKs** - Don't reimplement the protocol
4. **Handle errors** - Don't expose secret names in UI
5. **Request minimally** - Only request needed secrets

## Compliance

Secretariat's security design supports compliance with:

- **SOC 2** - Encryption, access control, audit logging
- **GDPR** - Data protection, access controls
- **PCI DSS** - Encryption of sensitive data
- **HIPAA** - Access controls, audit trails

*Note: Compliance depends on overall deployment and usage patterns.*

## Security Contacts

- **Security issues**: security@secretariat.dev
- **Bug bounty**: https://secretariat.dev/security
- **PGP key**: Available on our website

## References

- [AES-GCM (NIST SP 800-38D)](https://csrc.nist.gov/publications/detail/sp/800-38d/final)
- [Argon2 (RFC 9106)](https://www.rfc-editor.org/rfc/rfc9106.html)
- [macOS Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
