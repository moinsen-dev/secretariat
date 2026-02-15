#!/usr/bin/env bash
#
# Secretariat Release Gate
#
# Runs the cross-component validation path used as the release quality gate.
# This is intended to be deterministic and CI-friendly.
#
# Usage:
#   ./scripts/release-gate.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

step() {
  local label="$1"
  echo ""
  echo -e "${BLUE}==>${NC} ${label}"
}

run() {
  "$@"
}

run_in() {
  local dir="$1"
  shift
  (
    cd "$dir"
    "$@"
  )
}

step "Rust workspace check + tests"
run_in "$ROOT_DIR" cargo check --workspace
run_in "$ROOT_DIR" cargo test --workspace

step "Rust/CLI integration shell tests"
run_in "$ROOT_DIR" ./tests/test_daemon_init.sh
run_in "$ROOT_DIR" ./tests/test_cli_commands.sh
run_in "$ROOT_DIR" ./tests/test_permissions.sh

step "JSON-RPC contract + cross-SDK parity suites"
run_in "$ROOT_DIR" ./tests/test_rpc_contract.sh
run_in "$ROOT_DIR" ./tests/test_sdk_parity.sh

step "MCP server build + tests"
run_in "$ROOT_DIR/mcp-server" npm run build
run_in "$ROOT_DIR/mcp-server" npm test -- --run

step "SDK validation"
run_in "$ROOT_DIR/sdk-node" npm run build
run_in "$ROOT_DIR/sdk-go" go test ./...
run_in "$ROOT_DIR/sdk-rust" cargo test
run_in "$ROOT_DIR/sdk-dart" dart analyze

step "Flutter app tests"
run_in "$ROOT_DIR/app" flutter test

echo ""
echo -e "${GREEN}Release gate passed.${NC}"
echo "Validated command path: ./scripts/release-gate.sh"
