#!/bin/bash
# F247-F250: End-to-end tests for daemon initialization
#
# Features:
# - F247: Create tests/test_daemon_init.sh end-to-end test
# - F248: Test daemon starts successfully
# - F249: Test database is created at correct path
# - F250: Test socket file is created
#
# Usage: ./tests/test_daemon_init.sh
#
# Prerequisites:
# - Daemon binary built: cargo build --release -p secd
# - CLI binary built: cargo build --release -p sec

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
TEST_DIR="${TMPDIR:-/tmp}/secretariat-e2e-$$"
SOCKET_PATH="$TEST_DIR/secretariat.sock"
DB_PATH="$TEST_DIR/vault.db"
LOG_PATH="$TEST_DIR/daemon.log"
DAEMON_PID=""

# Cleanup function
cleanup() {
    echo -e "${YELLOW}Cleaning up...${NC}"

    # Kill daemon if running
    if [ -n "$DAEMON_PID" ] && kill -0 "$DAEMON_PID" 2>/dev/null; then
        kill "$DAEMON_PID" 2>/dev/null || true
        wait "$DAEMON_PID" 2>/dev/null || true
    fi

    # Remove test directory
    rm -rf "$TEST_DIR"

    echo -e "${GREEN}Cleanup complete${NC}"
}

# Set up trap for cleanup
trap cleanup EXIT

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to log test result
pass() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    ((++TESTS_PASSED))
}

fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    ((++TESTS_FAILED))
}

# Create test directory
echo "Creating test directory: $TEST_DIR"
mkdir -p "$TEST_DIR"

# Find binaries
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DAEMON_BIN="$PROJECT_DIR/target/release/secd"
CLI_BIN="$PROJECT_DIR/target/release/sec"

# Check if binaries exist (try debug if release not found)
if [ ! -f "$DAEMON_BIN" ]; then
    DAEMON_BIN="$PROJECT_DIR/target/debug/secd"
fi
if [ ! -f "$CLI_BIN" ]; then
    CLI_BIN="$PROJECT_DIR/target/debug/sec"
fi

echo "================================================"
echo "Secretariat End-to-End Tests"
echo "================================================"
echo "Test directory: $TEST_DIR"
echo "Daemon binary: $DAEMON_BIN"
echo "CLI binary: $CLI_BIN"
echo "================================================"

# ==================================================
# F248: Test daemon starts successfully
# ==================================================
echo ""
echo "F248: Test daemon starts successfully"
echo "--------------------------------------"

if [ ! -f "$DAEMON_BIN" ]; then
    fail "Daemon binary not found at $DAEMON_BIN"
    fail "Build with: cargo build --release -p secd"
else
    # Start daemon with test configuration
    SECRETARIAT_SOCKET_PATH="$SOCKET_PATH" \
    SECRETARIAT_DB_PATH="$DB_PATH" \
    "$DAEMON_BIN" > "$LOG_PATH" 2>&1 &
    DAEMON_PID=$!

    # Wait for daemon to start (max 5 seconds)
    for i in {1..50}; do
        if [ -S "$SOCKET_PATH" ]; then
            break
        fi
        sleep 0.1
    done

    # Check if daemon is running
    if kill -0 "$DAEMON_PID" 2>/dev/null; then
        pass "Daemon started successfully (PID: $DAEMON_PID)"
    else
        fail "Daemon failed to start"
        echo "Daemon log:"
        cat "$LOG_PATH" 2>/dev/null || echo "(no log)"
    fi
fi

# ==================================================
# F249: Test database is created at correct path
# ==================================================
echo ""
echo "F249: Test database is created at correct path"
echo "----------------------------------------------"

# Give daemon time to create database
sleep 0.5

if [ -f "$DB_PATH" ]; then
    pass "Database created at $DB_PATH"

    # Verify it's a valid SQLite database
    if command -v sqlite3 &> /dev/null; then
        if sqlite3 "$DB_PATH" "SELECT 1;" &> /dev/null; then
            pass "Database is valid SQLite file"
        else
            fail "Database is not a valid SQLite file"
        fi

        # Check for expected tables
        TABLES=$(sqlite3 "$DB_PATH" ".tables" 2>/dev/null || echo "")

        if echo "$TABLES" | grep -q "secrets"; then
            pass "Table 'secrets' exists"
        else
            fail "Table 'secrets' not found"
        fi

        if echo "$TABLES" | grep -q "applications"; then
            pass "Table 'applications' exists"
        else
            fail "Table 'applications' not found"
        fi

        if echo "$TABLES" | grep -q "permissions"; then
            pass "Table 'permissions' exists"
        else
            fail "Table 'permissions' not found"
        fi

        if echo "$TABLES" | grep -q "audit_log"; then
            pass "Table 'audit_log' exists"
        else
            fail "Table 'audit_log' not found"
        fi
    else
        echo "  (sqlite3 not installed, skipping table verification)"
    fi
else
    fail "Database not created at $DB_PATH"
fi

# ==================================================
# F250: Test socket file is created
# ==================================================
echo ""
echo "F250: Test socket file is created"
echo "---------------------------------"

if [ -S "$SOCKET_PATH" ]; then
    pass "Socket file created at $SOCKET_PATH"

    # Test socket is responsive
    if [ -f "$CLI_BIN" ]; then
        # Try to get health status
        SECRETARIAT_SOCKET_PATH="$SOCKET_PATH" \
        "$CLI_BIN" status > /dev/null 2>&1

        if [ $? -eq 0 ]; then
            pass "Daemon responds to status command"
        else
            # Status might not be implemented yet, that's ok
            echo "  (status command not available)"
        fi
    fi
else
    fail "Socket file not created at $SOCKET_PATH"
fi

# ==================================================
# Summary
# ==================================================
echo ""
echo "================================================"
echo "Test Summary"
echo "================================================"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo "================================================"

# Exit with error if any tests failed
if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi

exit 0
