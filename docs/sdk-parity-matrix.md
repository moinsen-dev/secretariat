# SDK Parity Matrix (Block C)

Last updated: 2026-02-15
Validation command: `./tests/test_sdk_parity.sh`

## Contract Target

- `secret.get` must always send `app_id`
- `secret.list` must handle metadata-object entries
- SDKs should support explicit socket override for isolated test runs

## Matrix

| SDK | `secret.get` app_id | `secret.list` metadata | Socket override | Status |
|---|---|---|---|---|
| Node (`sdk-node`) | ✅ (`node-sdk`) | ✅ object + string fallback | ✅ constructor option | ✅ |
| Python (`sdk-python`) | ✅ (`python-sdk`) | ✅ object + string fallback | ✅ constructor option | ✅ |
| Go (`sdk-go`) | ✅ (`go-sdk` default) | ✅ object + string fallback | ✅ `WithSocketPath` | ✅ |
| Rust (`sdk-rust`) | ✅ (`rust-sdk`) | ✅ object + string fallback | ✅ `with_socket_path` / env | ✅ |
| Dart (`sdk-dart`) | ✅ (`dart-sdk`) | ✅ object + string fallback | ✅ constructor + env | ✅ |

## Notes

- The parity script runs all SDKs against one isolated daemon instance and one shared fixture secret.
- If a toolchain is unavailable on a machine, the script reports `SKIP` for that SDK.
