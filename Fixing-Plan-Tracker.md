# Secretariat Fixing Plan Tracker

Last updated: 2026-02-15
Owner: Core Platform
Current focus: Block D Complete (Release Candidate Prep)

## Goal
Build a stable base layer first (daemon runtime + IPC contract + CLI smoke), then move upward to MCP, SDKs, and App.

## Autonomous Blocks (Large Work Packages)

### Block A: Runtime Core Stabilization
Scope:
- Daemon startup reliability, socket/database path consistency, recovery for incompatible local state.
- CLI daemon-bootstrap reliability.
- End-to-end runtime smoke in isolated and default environments.

Deliverables:
- Stable daemon lifecycle (`start/status/stop`) under clean and dirty local state.
- No destructive behavior on incompatible DB (backup + fresh boot path).
- Runnable smoke scripts for startup and health.

Definition of Done:
- `sec status` reliably bootstraps daemon.
- Daemon survives stale socket/legacy DB conditions with clear logs.
- Startup smoke tests pass reproducibly.

### Block B: Contract and Integration Surface
Scope:
- Freeze JSON-RPC request/response contract (required params, error codes, lock-state behavior).
- Align CLI, MCP, and all SDK adapters to this contract.
- Add contract-level test coverage (not product-UI tests).

Deliverables:
- Contract spec document in repo.
- Validation tests that fail on parameter drift.
- MCP and SDK clients updated to contract.

Definition of Done:
- One contract test suite passes for daemon + adapters.
- No adapter uses deprecated/mismatched parameter names.
- Error semantics are consistent across surfaces.

### Block C: Product Surfaces Hardening
Scope:
- App robustness and test strategy (separate integration from unit path).
- MCP operational quality (tests, failure messages, permission behavior).
- SDK quality parity (Node/Python/Dart/Rust/Go behavior and docs).

Deliverables:
- App tests that are CI-stable without implicit local daemon assumptions.
- MCP test suite and reliable troubleshooting surface.
- SDK parity matrix (feature and error behavior alignment).

Definition of Done:
- App + MCP + SDK checks pass in controlled CI-like setup.
- Critical flows (locked/uninitialized/permission denied/not found) behave uniformly.
- Surface-specific docs match actual behavior.

### Block D: Release and CI Convergence
Scope:
- Consolidate build/test pipeline across Rust, App, MCP, SDKs.
- Remove documentation/status drift.
- Introduce release gate criteria and checklists.

Deliverables:
- Single green release gate.
- Updated docs/runbooks aligned to current implementation.
- Explicit rollback/recovery instructions for local state migration issues.

Definition of Done:
- One command path for full validation is green.
- Release checklist is executable and repeatable.
- No conflicting status docs.

## Phase Board

| Phase | Name | Status | Exit Criteria |
|---|---|---|---|
| 0 | Runtime Stabilization | COMPLETE | Daemon starts reliably; `sec status/set/get/list/delete` works in isolated test env and default env |
| 1 | RPC Contract Hardening | COMPLETE | JSON-RPC method/params documented and validated by contract tests |
| 2 | MCP Alignment | COMPLETE | MCP params/errors aligned with daemon contract; MCP tests green |
| 3 | SDK Consistency | COMPLETE | Node/Python/Dart/Rust/Go pass shared contract fixture suite |
| 4 | App Reliability | COMPLETE | App tests no longer depend on ad-hoc local daemon state |
| 5 | CI + Docs Convergence | COMPLETE | One green pipeline and no doc/status contradictions |

## Phase 0 Plan

### 0.1 Config + Path Overrides
- [x] Add explicit runtime overrides:
- `SECRETARIAT_DB_PATH`
- `SECRETARIAT_SOCKET_PATH` (and compatibility alias `SECRETARIAT_SOCKET`)
- `SECRETARIAT_DATA_DIR`
- [x] Ensure daemon runtime and server socket binding resolve the same path logic.
- [x] Ensure CLI client can use socket override env var.

### 0.2 Startup Recovery
- [x] Handle incompatible existing `vault.db` gracefully.
- [x] On `file is not a database`, move DB to a timestamped backup (non-destructive) and initialize fresh DB.
- [x] Keep clear log output with backup path.

### 0.3 Runtime Smoke Validation
- [x] Validate daemon start/stop/status in isolated temp paths.
- [x] Validate CLI CRUD against isolated daemon.
- [x] Re-run relevant scripts/tests that depend on env overrides.

## Current Execution Mode
- We execute in **autonomous blocks** (A -> B -> C -> D), not in micro-steps.
- Inside each block, changes can span multiple components as long as they close the block's DoD.
- Reporting happens per block milestone, not per tiny fix.

## Risks
- Legacy encrypted DB data may need manual migration if old key format is unavailable.
- Existing scripts assume behavior that diverges from current binaries; fix incrementally after Phase 0 base is green.

## Progress Log

### 2026-02-15
- Created tracker and started Phase 0 implementation.
- Implemented daemon/CLI path overrides for socket and database.
- Implemented incompatible-DB backup-and-recover startup behavior.
- Switched daemon startup default to locked mode (non-blocking keychain restore).
- Added non-interactive `sec init --password-env <ENV_VAR>` flow for automation.
- `sec init` now unlocks the vault immediately after successful initialization.
- Fixed E2E shell test counters that exited early under `set -e`.
- Hardened permission test script flow to avoid `set -e` aborts on expected non-critical failures.
- Validation:
  - `target/debug/sec status` starts daemon successfully.
  - `tests/test_daemon_init.sh` passes.
  - `tests/test_cli_commands.sh` passes.
  - `tests/test_permissions.sh` passes.
- Planning model updated: moved to large autonomous blocks (A-D).
- Block A marked complete; moving to Block B.
- Block B delivered:
  - Added contract reference document: `docs/json-rpc-contract.md`.
  - Added contract validation test suite: `tests/test_rpc_contract.sh`.
  - Fixed MCP adapter contract drift:
    - `secret.get` now uses `app_id` contract.
    - `vault.status` now handles daemon `state` shape.
    - `secret.list` now filters by agent permissions using `agent.explain`.
    - Added MCP unit tests: `mcp-server/src/tools.test.ts`.
  - Fixed SDK contract drift:
    - Node SDK `list()` now handles metadata-object responses.
    - Python SDK `list()` now handles metadata-object responses.
  - Fixed CLI list behavior to apply provider/environment filters client-side against canonical `secret.list` response.
  - Validation:
    - `cargo check --workspace` passes.
    - `npm run build && npm test -- --run` in `mcp-server` passes.
    - `npm run build` in `sdk-node` passes.
    - `tests/test_rpc_contract.sh` passes.
    - SDK smoke check (Node + Python get/list) passes.
- Block B marked complete; moving to Block C.
- Block C delivered:
  - App hardening:
    - Added contract-focused daemon client tests with local mock JSON-RPC server: `app/test/daemon_client_contract_test.dart`.
    - Split integration behavior into opt-in mode via `SECRETARIAT_RUN_INTEGRATION_TESTS=1`.
    - Standardized socket override handling (`SECRETARIAT_SOCKET_PATH` / `SECRETARIAT_SOCKET`) in app client/manager.
  - MCP hardening:
    - Expanded MCP unit coverage for lock-state, registration errors, permission filtering, and `vault.status` state mapping.
  - SDK parity hardening:
    - Added cross-SDK parity suite: `tests/test_sdk_parity.sh`.
    - Added parity reference doc: `docs/sdk-parity-matrix.md`.
    - Aligned Go/Rust/Dart socket override and `list` parsing behavior to contract expectations.
  - Validation:
    - `cargo check --workspace` passes.
    - `tests/test_rpc_contract.sh` passes.
    - `tests/test_sdk_parity.sh` passes.
    - `npm run build && npm test -- --run` in `mcp-server` passes (6 tests).
    - `flutter test` in `app` passes.
- Block C marked complete; moving to Block D.
- Block D delivered:
  - Added single release gate command path:
    - Script: `scripts/release-gate.sh`
    - Make target: `make release-gate`
  - Consolidated release gate documentation:
    - `docs/release-gate.md` (scope + checklist)
    - `docs/local-state-recovery.md` (rollback/recovery runbook)
  - Reduced documentation drift:
    - Updated root `README.md` to current architecture and validation flow.
    - Marked `StateTracker.md` as historical snapshot and pointed to canonical tracker.
  - Validation:
    - `make release-gate` passes end-to-end.
      - Includes Rust workspace checks/tests, CLI/daemon shell suites, JSON-RPC contract suite, SDK parity suite, MCP build/tests, SDK checks, and Flutter tests.
- Block D marked complete.
