# Release Gate

This project uses one command path as the release validation gate:

```bash
./scripts/release-gate.sh
```

Equivalent Make target:

```bash
make release-gate
```

## What The Gate Verifies

1. Rust workspace compilation and tests.
2. CLI/daemon end-to-end shell suites.
3. JSON-RPC contract suite.
4. Cross-SDK parity suite (Node, Python, Go, Rust, Dart).
5. MCP server build and tests.
6. SDK-specific checks (Node build, Go tests, Rust tests, Dart analyze).
7. Flutter app tests.

## Release Checklist

1. Run `make release-gate` from repository root.
2. Confirm all suites pass with exit code `0`.
3. Confirm no unexpected local state migration during the run.
4. Review `Fixing-Plan-Tracker.md` phase status for current release scope.
5. Tag/release only after the gate is green on the intended commit.

## Failure Handling

If the gate fails:

1. Fix the failing surface first.
2. Re-run the full gate (not only the failed step).
3. If failure indicates local state problems, follow `docs/local-state-recovery.md`.
