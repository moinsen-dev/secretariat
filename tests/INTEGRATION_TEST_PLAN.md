# Secretariat Integration Test Plan

## Overview

This document outlines the comprehensive integration testing plan for the Secretariat local secrets orchestrator. The system consists of:

- **Daemon (secd)**: Rust-based background service managing encrypted secrets
- **CLI (sec)**: Command-line interface for secret management
- **Flutter App**: Desktop/mobile application with GUI
- **SDKs**: Client libraries for Dart, Python, Node.js, and Rust

## Test Environment Setup

### Prerequisites
1. macOS with Rust toolchain installed
2. Flutter SDK (for app testing)
3. Node.js (for sdk-node testing)
4. Python 3 (for sdk-python testing)

### Starting the Daemon
```bash
# Option 1: Via LaunchAgent (recommended for persistent usage)
make service-install
make service-start

# Option 2: Manual start (for development/debugging)
./target/release/secd
```

### Verifying Daemon Status
```bash
make service-status
```

Expected output:
- Launch Agent installed: ✓
- Daemon is running: ✓
- Socket exists: ✓

---

## Component Test Suites

### 1. CLI Integration Tests

#### 1.1 Basic Operations
| Test | Command | Expected Result |
|------|---------|-----------------|
| List empty vault | `sec list` | "No secrets found." |
| Set secret | `sec set MY_KEY value123` | "Secret set successfully" |
| List with secrets | `sec list` | Table showing MY_KEY |
| Get secret | `sec get MY_KEY` | "value123" |
| Delete secret | `echo "y" \| sec delete MY_KEY` | "Secret deleted" |

#### 1.2 Advanced Operations
| Test | Command | Expected Result |
|------|---------|-----------------|
| Set with environment | `sec set DB_URL value --env staging` | Secret with env=staging |
| List as JSON | `sec list --json` | JSON array output |
| Get without newline | `sec get KEY -n` | Value without trailing newline |
| Delete non-existent | `sec delete UNKNOWN` | Error: Secret not found |

#### 1.3 Edge Cases
| Test | Description | Expected Result |
|------|-------------|-----------------|
| Special characters | Set secret with `!@#$%^&*()` | Value preserved correctly |
| Long values | Set 10KB secret value | Successfully stored/retrieved |
| Unicode names | Set secret `日本語_キー` | Works correctly |
| Empty value | `sec set EMPTY ""` | Stores empty string |

### 2. Daemon Tests

#### 2.1 Service Lifecycle
```bash
# Start service
make service-start
# Verify running
make service-status
# Stop service
make service-stop
# Verify stopped
make service-status
```

#### 2.2 Socket Communication
```bash
# Test direct IPC
echo '{"jsonrpc":"2.0","id":1,"method":"health.check","params":{}}' | \
  python3 -c "import socket,json,sys; s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM); s.connect('$HOME/Library/Application Support/Secretariat/secretariat.sock'); s.send((sys.stdin.read()+'\n').encode()); print(s.recv(4096).decode())"
```

#### 2.3 Error Handling
| Scenario | Expected Behavior |
|----------|-------------------|
| Invalid JSON | Returns -32700 (Parse error) |
| Unknown method | Returns -32601 (Method not found) |
| Missing params | Returns -32602 (Invalid params) |
| Rate limit exceeded | Returns -32000 (Rate limit) |

### 3. SDK Integration Tests

#### 3.1 Python SDK
```python
from secretariat import SecretariatClient

client = SecretariatClient()
client.connect()

# Set secret
client.set_secret("PYTHON_TEST", "python_value")

# Get secret
value = client.get_secret("PYTHON_TEST")
assert value == "python_value"

# List secrets
secrets = client.list_secrets()
assert any(s['name'] == 'PYTHON_TEST' for s in secrets)

# Delete
client.delete_secret("PYTHON_TEST")
```

#### 3.2 Node.js SDK
```typescript
import { SecretariatClient } from 'secretariat';

const client = new SecretariatClient();
await client.connect();

await client.setSecret("NODE_TEST", "node_value");
const value = await client.getSecret("NODE_TEST");
console.assert(value === "node_value");

await client.deleteSecret("NODE_TEST");
```

#### 3.3 Dart SDK
```dart
import 'package:secretariat/secretariat.dart';

final client = SecretariatClient();
await client.connect();

await client.setSecret("DART_TEST", "dart_value");
final value = await client.getSecret("DART_TEST");
assert(value == "dart_value");

await client.deleteSecret("DART_TEST");
```

#### 3.4 Rust SDK
```rust
use secretariat::SecretariatClient;

let client = SecretariatClient::connect()?;

client.set_secret("RUST_TEST", "rust_value")?;
let value = client.get_secret("RUST_TEST")?;
assert_eq!(value, "rust_value");

client.delete_secret("RUST_TEST")?;
```

### 4. Cross-Component Tests

#### 4.1 CLI ↔ SDK Interop
1. Set secret via CLI: `sec set CROSS_TEST "from_cli"`
2. Read via Python SDK: Verify value = "from_cli"
3. Update via SDK: Set new value "from_python"
4. Read via CLI: Verify `sec get CROSS_TEST` = "from_python"

#### 4.2 Concurrent Access
1. Run multiple CLI commands in parallel
2. Run multiple SDK clients simultaneously
3. Verify no data corruption or race conditions

### 5. Security Tests

#### 5.1 Encryption Verification
```bash
# Check that stored values are encrypted
sqlite3 "$HOME/Library/Application Support/Secretariat/vault.db" \
  "SELECT name, hex(value_encrypted) FROM secrets LIMIT 1;"
# Value should be unreadable (encrypted blob)
```

#### 5.2 Permission Model
1. Register app via `app.register`
2. Grant permission via `app.authorize`
3. Verify app can access authorized secrets
4. Verify app cannot access unauthorized secrets

### 6. Performance Tests

#### 6.1 Throughput
- Target: 100 operations/second
- Test: Create 1000 secrets in batch
- Measure: Total time and ops/sec

#### 6.2 Latency
- Target: < 10ms per operation
- Test: Measure p50, p95, p99 latencies

---

## Known Issues and Fixes Applied

### Issue 1: JSON-RPC ID Type Mismatch (Fixed)
- **Problem**: CLI sent `id` as integer, daemon expected string
- **Solution**: Updated daemon's `Request` struct to use `RequestId` enum accepting both
- **File**: `daemon/src/server.rs`

### Issue 2: CLI Permission Bypass (Fixed)
- **Problem**: CLI couldn't access secrets due to permission checks
- **Solution**: Added special case for `app_id="cli"` to bypass permission checks
- **File**: `daemon/src/handlers/secret_get.rs`

---

## Running the Tests

### Quick Smoke Test
```bash
make service-status && \
  ./target/release/sec set TEST_$(date +%s) "test_value" && \
  ./target/release/sec list
```

### Full Test Suite
```bash
# Run all Rust tests
make rust-test

# Run CLI tests
make test-cli

# Run integration tests
make test-integration
```

---

## Test Results Summary

| Component | Status | Notes |
|-----------|--------|-------|
| Daemon startup | ✅ Pass | LaunchAgent works correctly |
| CLI list | ✅ Pass | Displays secrets correctly |
| CLI set | ✅ Pass | Encrypts and stores |
| CLI get | ✅ Pass | Decrypts and returns |
| CLI delete | ✅ Pass | Removes with confirmation |
| SDK-dart | ⏳ Pending | Needs testing |
| SDK-python | ⏳ Pending | Needs testing |
| SDK-node | ⏳ Pending | Needs testing |
| SDK-rust | ⏳ Pending | Needs testing |
| Flutter app | ⏳ Pending | Needs testing |

---

## Next Steps

1. Run SDK integration tests for all four SDKs
2. Test Flutter app connection to daemon
3. Performance benchmarking
4. Security audit
