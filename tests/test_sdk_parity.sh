#!/bin/bash
# Cross-SDK parity test (Node, Python, Go, Rust, Dart)
#
# Usage: ./tests/test_sdk_parity.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

pass() {
  echo -e "${GREEN}✓ PASS:${NC} $1"
  ((++TESTS_PASSED))
}

fail() {
  echo -e "${RED}✗ FAIL:${NC} $1"
  ((++TESTS_FAILED))
}

skip() {
  echo -e "${YELLOW}○ SKIP:${NC} $1"
  ((++TESTS_SKIPPED))
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
export PROJECT_DIR

DAEMON_BIN=""
CLI_BIN=""

for profile in debug release; do
  cli_candidate="$PROJECT_DIR/target/$profile/sec"
  daemon_candidate="$PROJECT_DIR/target/$profile/secd"

  if [ -f "$cli_candidate" ] && [ -f "$daemon_candidate" ]; then
    if "$cli_candidate" init --help 2>&1 | grep -q "password-env"; then
      CLI_BIN="$cli_candidate"
      DAEMON_BIN="$daemon_candidate"
      break
    fi
  fi
done

TEST_DIR="${TMPDIR:-/tmp}/secretariat-sdk-parity-$$"
SOCKET_PATH="$TEST_DIR/secretariat.sock"
DB_PATH="$TEST_DIR/vault.db"
LOG_PATH="$TEST_DIR/daemon.log"
DAEMON_PID=""

cleanup() {
  echo -e "${YELLOW}Cleaning up...${NC}"
  if [ -n "$DAEMON_PID" ] && kill -0 "$DAEMON_PID" 2>/dev/null; then
    kill "$DAEMON_PID" 2>/dev/null || true
    wait "$DAEMON_PID" 2>/dev/null || true
  fi
  rm -rf "$TEST_DIR"
  echo -e "${GREEN}Cleanup complete${NC}"
}

trap cleanup EXIT

echo "================================================"
echo "Secretariat SDK Parity Tests"
echo "================================================"
echo "Test directory: $TEST_DIR"
echo "Socket path: $SOCKET_PATH"
echo "================================================"

if [ ! -f "$DAEMON_BIN" ] || [ ! -f "$CLI_BIN" ]; then
  echo -e "${RED}Binaries not found. Build with: cargo build --workspace${NC}"
  exit 1
fi

mkdir -p "$TEST_DIR"

export SECRETARIAT_SOCKET_PATH="$SOCKET_PATH"
export SECRETARIAT_DB_PATH="$DB_PATH"
export SECRETARIAT_TEST_MASTER_PASSWORD="testpassword123"

"$DAEMON_BIN" > "$LOG_PATH" 2>&1 &
DAEMON_PID=$!

for i in {1..50}; do
  [ -S "$SOCKET_PATH" ] && break
  sleep 0.1
done

if ! kill -0 "$DAEMON_PID" 2>/dev/null; then
  echo -e "${RED}Daemon failed to start${NC}"
  cat "$LOG_PATH" 2>/dev/null || true
  exit 1
fi

"$CLI_BIN" init --password-env SECRETARIAT_TEST_MASTER_PASSWORD >/dev/null
"$CLI_BIN" set SDK_PARITY_KEY "sdk-parity-value" >/dev/null
pass "Test fixture initialized (vault + SDK_PARITY_KEY)"

echo ""
echo "Node SDK"
echo "--------"
if command -v npm >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
  if (cd "$PROJECT_DIR/sdk-node" && npm run build >/dev/null); then
    if node -e "const {Secretariat}=require('$PROJECT_DIR/sdk-node/dist/index.js'); (async()=>{const c=new Secretariat({socketPath:process.env.SECRETARIAT_SOCKET_PATH}); const names=await c.list(); if(!names.includes('SDK_PARITY_KEY')) throw new Error('SDK_PARITY_KEY missing in list'); const value=await c.get('SDK_PARITY_KEY'); if(value!=='sdk-parity-value') throw new Error('wrong value'); c.close();})().catch(e=>{console.error(e); process.exit(1);});"; then
      pass "Node SDK get/list contract"
    else
      fail "Node SDK get/list contract"
    fi
  else
    fail "Node SDK build failed"
  fi
else
  skip "Node/npm unavailable"
fi

echo ""
echo "Python SDK"
echo "----------"
if command -v python3 >/dev/null 2>&1; then
  if python3 - <<'PY'
import os
import sys

project = os.environ["PROJECT_DIR"]
sys.path.insert(0, os.path.join(project, "sdk-python"))

from secretariat import Secretariat

client = Secretariat(socket_path=os.environ["SECRETARIAT_SOCKET_PATH"])
names = client.list()
if "SDK_PARITY_KEY" not in names:
    raise RuntimeError("SDK_PARITY_KEY missing in list")
value = client.get("SDK_PARITY_KEY")
if value != "sdk-parity-value":
    raise RuntimeError("wrong value")
client.close()
PY
  then
    pass "Python SDK get/list contract"
  else
    fail "Python SDK get/list contract"
  fi
else
  skip "python3 unavailable"
fi

echo ""
echo "Go SDK"
echo "------"
if command -v go >/dev/null 2>&1; then
  GO_TMP="$TEST_DIR/go-sdk"
  mkdir -p "$GO_TMP"
  cat > "$GO_TMP/go.mod" <<EOF
module sdkparity

go 1.21

require github.com/secretariat-team/secretariat-go v0.0.0

replace github.com/secretariat-team/secretariat-go => $PROJECT_DIR/sdk-go
EOF
  cat > "$GO_TMP/main.go" <<'EOF'
package main

import (
	"fmt"
	"os"

	secretariat "github.com/secretariat-team/secretariat-go"
)

func main() {
	socketPath := os.Getenv("SECRETARIAT_SOCKET_PATH")
	client, err := secretariat.New(secretariat.WithSocketPath(socketPath))
	if err != nil {
		panic(err)
	}
	defer client.Close()

	names, err := client.ListNames()
	if err != nil {
		panic(err)
	}
	found := false
	for _, n := range names {
		if n == "SDK_PARITY_KEY" {
			found = true
			break
		}
	}
	if !found {
		panic("SDK_PARITY_KEY missing in list")
	}

	value, err := client.Get("SDK_PARITY_KEY")
	if err != nil {
		panic(err)
	}
	if value != "sdk-parity-value" {
		panic(fmt.Sprintf("wrong value: %s", value))
	}
}
EOF
  if (cd "$GO_TMP" && go run . >/dev/null); then
    pass "Go SDK get/list contract"
  else
    fail "Go SDK get/list contract"
  fi
else
  skip "go unavailable"
fi

echo ""
echo "Rust SDK"
echo "--------"
if command -v cargo >/dev/null 2>&1; then
  RUST_TMP="$TEST_DIR/rust-sdk"
  mkdir -p "$RUST_TMP/src"
  cat > "$RUST_TMP/Cargo.toml" <<EOF
[package]
name = "sdk-parity-rust"
version = "0.1.0"
edition = "2021"

[dependencies]
secretariat = { path = "$PROJECT_DIR/sdk-rust" }
EOF
  cat > "$RUST_TMP/src/main.rs" <<'EOF'
use secretariat::Secretariat;

fn main() {
    let socket_path = std::env::var("SECRETARIAT_SOCKET_PATH")
        .expect("SECRETARIAT_SOCKET_PATH not set");
    let client = Secretariat::with_socket_path(socket_path).expect("client creation failed");

    let names = client.list().expect("list failed");
    if !names.contains(&"SDK_PARITY_KEY".to_string()) {
        panic!("SDK_PARITY_KEY missing in list");
    }

    let value = client.get("SDK_PARITY_KEY").expect("get failed");
    if value != "sdk-parity-value" {
        panic!("wrong value");
    }
}
EOF
  if (cd "$RUST_TMP" && cargo run --quiet >/dev/null); then
    pass "Rust SDK get/list contract"
  else
    fail "Rust SDK get/list contract"
  fi
else
  skip "cargo unavailable"
fi

echo ""
echo "Dart SDK"
echo "--------"
if command -v dart >/dev/null 2>&1; then
  DART_TMP="$TEST_DIR/dart_parity.dart"
  DART_IMPORT_URI="file://$PROJECT_DIR/sdk-dart/lib/secretariat.dart"
  cat > "$DART_TMP" <<EOF
import '$DART_IMPORT_URI';

Future<void> main() async {
  final client = Secretariat();

  final names = await client.list();
  if (!names.contains('SDK_PARITY_KEY')) {
    throw Exception('SDK_PARITY_KEY missing in list');
  }

  final value = await client.get('SDK_PARITY_KEY');
  if (value != 'sdk-parity-value') {
    throw Exception('wrong value: \$value');
  }
}
EOF
  if dart "$DART_TMP" >/dev/null; then
    pass "Dart SDK get/list contract"
  else
    fail "Dart SDK get/list contract"
  fi
else
  skip "dart unavailable"
fi

echo ""
echo "================================================"
echo "SDK Parity Summary"
echo "================================================"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo -e "${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
echo "================================================"

if [ $TESTS_FAILED -gt 0 ]; then
  exit 1
fi

exit 0
