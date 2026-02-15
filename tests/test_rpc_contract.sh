#!/bin/bash
# JSON-RPC contract tests for daemon + adapter-facing surface
#
# Usage: ./tests/test_rpc_contract.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TEST_DIR="${TMPDIR:-/tmp}/secretariat-rpc-contract-$$"
SOCKET_PATH="$TEST_DIR/secretariat.sock"
DB_PATH="$TEST_DIR/vault.db"
LOG_PATH="$TEST_DIR/daemon.log"
DAEMON_PID=""

TESTS_PASSED=0
TESTS_FAILED=0

pass() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    ((++TESTS_PASSED))
}

fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    ((++TESTS_FAILED))
}

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

rpc_call() {
    local method="$1"
    local params_json="$2"
    local request_id="${3:-1}"

    python3 - "$SOCKET_PATH" "$request_id" "$method" "$params_json" <<'PY'
import json
import socket
import sys

socket_path, request_id, method, params_raw = sys.argv[1:5]
params = json.loads(params_raw)

client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
client.settimeout(5.0)
client.connect(socket_path)
request = {
    "jsonrpc": "2.0",
    "id": int(request_id),
    "method": method,
    "params": params,
}
client.sendall((json.dumps(request) + "\n").encode("utf-8"))

response_data = b""
while True:
    chunk = client.recv(4096)
    if not chunk:
        break
    response_data += chunk
    if response_data.endswith(b"\n"):
        break

client.close()
print(response_data.decode("utf-8").strip())
PY
}

mkdir -p "$TEST_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DAEMON_BIN="$PROJECT_DIR/target/release/secd"
CLI_BIN="$PROJECT_DIR/target/release/sec"

[ ! -f "$DAEMON_BIN" ] && DAEMON_BIN="$PROJECT_DIR/target/debug/secd"
[ ! -f "$CLI_BIN" ] && CLI_BIN="$PROJECT_DIR/target/debug/sec"

echo "================================================"
echo "Secretariat JSON-RPC Contract Tests"
echo "================================================"
echo "Test directory: $TEST_DIR"
echo "Socket path: $SOCKET_PATH"
echo "================================================"

if [ ! -f "$DAEMON_BIN" ] || [ ! -f "$CLI_BIN" ]; then
    fail "Binaries not found. Build with: cargo build --workspace"
    exit 1
fi

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
    fail "Daemon failed to start"
    cat "$LOG_PATH" 2>/dev/null || true
    exit 1
fi

if "$CLI_BIN" init --password-env SECRETARIAT_TEST_MASTER_PASSWORD >/dev/null 2>&1; then
    pass "Vault initialized"
else
    fail "Vault initialization failed"
    exit 1
fi

"$CLI_BIN" set CONTRACT_TEST_KEY "contract-value-123" --provider openai --environment prod >/dev/null
"$CLI_BIN" agent register contract-agent >/dev/null
"$CLI_BIN" agent grant contract-agent CONTRACT_TEST_KEY --environment prod >/dev/null

echo ""
echo "Contract: secret.get requires app_id"
echo "-------------------------------------"

RESP=$(rpc_call "secret.get" '{"name":"CONTRACT_TEST_KEY"}' 1)
if python3 - "$RESP" <<'PY'
import json
import sys
r = json.loads(sys.argv[1])
assert "error" in r
assert r["error"]["code"] == -32602
assert "app_id" in r["error"]["message"]
PY
then
    pass "secret.get without app_id returns -32602"
else
    fail "secret.get without app_id contract mismatch"
fi

RESP=$(rpc_call "secret.get" '{"name":"CONTRACT_TEST_KEY","agent":"contract-agent"}' 2)
if python3 - "$RESP" <<'PY'
import json
import sys
r = json.loads(sys.argv[1])
assert "error" in r
assert r["error"]["code"] == -32602
assert "app_id" in r["error"]["message"]
PY
then
    pass "legacy agent param is rejected for secret.get"
else
    fail "legacy agent param behavior changed unexpectedly"
fi

RESP=$(rpc_call "secret.get" '{"name":"CONTRACT_TEST_KEY","app_id":"cli"}' 3)
if python3 - "$RESP" <<'PY'
import json
import sys
r = json.loads(sys.argv[1])
assert "result" in r
assert r["result"]["name"] == "CONTRACT_TEST_KEY"
assert r["result"]["value"] == "contract-value-123"
PY
then
    pass "secret.get with app_id returns {name,value}"
else
    fail "secret.get success contract mismatch"
fi

echo ""
echo "Contract: secret.list metadata shape"
echo "------------------------------------"

RESP=$(rpc_call "secret.list" '{}' 4)
if python3 - "$RESP" <<'PY'
import json
import sys
r = json.loads(sys.argv[1])
secrets = r["result"]["secrets"]
assert isinstance(secrets, list)
assert len(secrets) >= 1
target = next((s for s in secrets if s.get("name") == "CONTRACT_TEST_KEY"), None)
assert target is not None
for key in ("id", "name", "provider", "environment", "created_at"):
    assert key in target
assert target["environment"] == "prod"
PY
then
    pass "secret.list returns metadata objects"
else
    fail "secret.list metadata contract mismatch"
fi

RESP=$(rpc_call "vault.status" '{}' 5)
if python3 - "$RESP" <<'PY'
import json
import sys
r = json.loads(sys.argv[1])
result = r["result"]
state = result.get("state", result.get("status"))
assert state in ("locked", "unlocked", "uninitialized")
assert isinstance(result["secret_count"], int)
assert isinstance(result.get("app_count", 0), int)
PY
then
    pass "vault.status contract is stable"
else
    fail "vault.status contract mismatch"
fi

RESP=$(rpc_call "agent.explain" '{"agent_id":"contract-agent"}' 6)
if python3 - "$RESP" <<'PY'
import json
import sys
r = json.loads(sys.argv[1])
perms = r["result"]["permissions"]
assert isinstance(perms, list)
assert any(
    p.get("secret") == "CONTRACT_TEST_KEY" and p.get("environment") == "prod"
    for p in perms
)
PY
then
    pass "agent.explain returns secret/environment permissions"
else
    fail "agent.explain contract mismatch"
fi

echo ""
echo "Contract: lock-state behavior"
echo "-----------------------------"

"$CLI_BIN" lock >/dev/null

RESP=$(rpc_call "secret.get" '{"name":"CONTRACT_TEST_KEY","app_id":"cli"}' 7)
if python3 - "$RESP" <<'PY'
import json
import sys
r = json.loads(sys.argv[1])
assert "error" in r
assert r["error"]["code"] == -32002
PY
then
    pass "secret.get returns -32002 when vault is locked"
else
    fail "locked vault behavior changed for secret.get"
fi

RESP=$(rpc_call "secret.list" '{}' 8)
if python3 - "$RESP" <<'PY'
import json
import sys
r = json.loads(sys.argv[1])
assert "result" in r
assert isinstance(r["result"]["secrets"], list)
PY
then
    pass "secret.list remains available while locked"
else
    fail "secret.list should be available while locked"
fi

echo ""
echo "================================================"
echo "Contract Test Summary"
echo "================================================"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo "================================================"

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi

exit 0
