# Secretariat Performance Benchmarks

This document describes performance benchmarks for Secretariat components.

## F270: Secret Retrieval Latency (target: < 10ms)

### Benchmark Setup

```bash
# Install criterion for Rust benchmarks
cargo add --dev criterion

# Run benchmarks
cargo bench --bench secret_get
```

### Benchmark Code

```rust
// benches/secret_get.rs
use criterion::{black_box, criterion_group, criterion_main, Criterion};

fn bench_secret_get(c: &mut Criterion) {
    // Setup: Connect to daemon and ensure test secret exists
    let client = secretariat::Client::new().unwrap();

    c.bench_function("secret.get", |b| {
        b.iter(|| {
            black_box(client.get("BENCH_SECRET").unwrap())
        })
    });
}

criterion_group!(benches, bench_secret_get);
criterion_main!(benches);
```

### Expected Results

| Operation | Target | Typical |
|-----------|--------|---------|
| secret.get (cold) | < 10ms | ~5ms |
| secret.get (warm) | < 5ms | ~2ms |
| secret.set | < 20ms | ~10ms |
| secret.list | < 10ms | ~3ms |

---

## F271: Daemon Memory Usage (target: < 50MB)

### Profiling with Valgrind (Linux)

```bash
valgrind --tool=massif ./target/release/secd &
DAEMON_PID=$!

# Run some operations
sec list
sec get SOME_KEY

# Generate report
ms_print massif.out.$DAEMON_PID
```

### Profiling with Instruments (macOS)

```bash
# Using Xcode Instruments
xcrun xctrace record --template 'Allocations' \
  --launch ./target/release/secd
```

### Memory Breakdown

| Component | Expected |
|-----------|----------|
| Base daemon | ~10MB |
| SQLite connection | ~5MB |
| Crypto buffers | ~2MB |
| IPC handlers | ~3MB |
| **Total idle** | **< 25MB** |
| Peak (100 concurrent) | < 50MB |

---

## F272: CLI Startup Time (target: < 100ms)

### Benchmark with hyperfine

```bash
# Install hyperfine
brew install hyperfine

# Benchmark CLI startup
hyperfine --warmup 3 --runs 50 \
  './target/release/sec version' \
  --export-markdown cli-startup.md
```

### Expected Results

| Command | Target | Typical |
|---------|--------|---------|
| sec version | < 50ms | ~20ms |
| sec list | < 100ms | ~50ms |
| sec get KEY | < 100ms | ~60ms |

---

## F273: Flutter App Launch Time (target: < 500ms)

### Profiling with DevTools

```bash
# Run app with timeline
flutter run --profile --trace-startup

# Analyze in DevTools
flutter pub global run devtools
```

### Key Metrics

| Phase | Target |
|-------|--------|
| Engine init | < 100ms |
| Framework init | < 150ms |
| First frame | < 250ms |
| **Total to interactive** | **< 500ms** |

### Optimization Strategies

1. Lazy-load non-critical widgets
2. Use `WidgetsBinding.ensureInitialized()` early
3. Minimize work in `main()`
4. Defer daemon connection until needed

---

## F274: Concurrent Request Load Test

### Test Setup

```bash
# Using wrk for load testing
wrk -t12 -c100 -d30s \
  --script=tests/load_test.lua \
  http://localhost:8080/secret.get
```

### Load Test Script

```lua
-- tests/load_test.lua
wrk.method = "POST"
wrk.body = '{"jsonrpc":"2.0","id":1,"method":"secret.get","params":{"key":"LOAD_TEST"}}'
wrk.headers["Content-Type"] = "application/json"
```

### Alternative: Unix Socket Load Test

```python
#!/usr/bin/env python3
# tests/load_test.py
import asyncio
import socket
import json
import time

async def make_request(sock_path, request_id):
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(sock_path)

    request = {
        "jsonrpc": "2.0",
        "id": request_id,
        "method": "secret.get",
        "params": {"key": "LOAD_TEST"}
    }

    sock.sendall((json.dumps(request) + "\n").encode())
    response = sock.recv(4096)
    sock.close()

    return json.loads(response)

async def load_test(concurrent=100, total=1000):
    sock_path = "/tmp/secretariat.sock"
    start = time.time()

    tasks = []
    for i in range(total):
        tasks.append(make_request(sock_path, i))
        if len(tasks) >= concurrent:
            await asyncio.gather(*tasks)
            tasks = []

    if tasks:
        await asyncio.gather(*tasks)

    elapsed = time.time() - start
    print(f"Completed {total} requests in {elapsed:.2f}s")
    print(f"Rate: {total/elapsed:.0f} req/s")

asyncio.run(load_test())
```

### Expected Results

| Metric | Target |
|--------|--------|
| Concurrent connections | 100+ |
| Requests/second | 1000+ |
| P99 latency | < 50ms |
| Error rate | 0% |
| Memory growth | < 10MB |

---

## Continuous Benchmarking

### GitHub Actions Integration

```yaml
# .github/workflows/bench.yml
name: Benchmarks

on:
  push:
    branches: [main]

jobs:
  bench:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run benchmarks
        run: cargo bench --bench secret_get -- --noplot

      - name: Check CLI startup
        run: |
          cargo build --release
          hyperfine --export-json bench.json \
            './target/release/sec version'

      - name: Verify targets
        run: python scripts/verify_benchmarks.py
```

---

## Summary

All performance targets are achievable with the current architecture:

- **< 10ms secret retrieval**: Achieved through efficient IPC and minimal crypto overhead
- **< 50MB memory**: SQLite in-process, no ORM, minimal allocations
- **< 100ms CLI**: Static binary, no runtime, lazy daemon connection
- **< 500ms app launch**: Flutter's AOT compilation, lazy initialization
- **1000+ req/s**: Tokio async runtime, connection pooling
