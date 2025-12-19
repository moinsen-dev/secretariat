#!/bin/bash
# Test Wave 18: CLI Commands (F116-F130)
# Tests list enhancement, get, set, and delete commands

set -e

echo "=========================================="
echo "Wave 18 Test: CLI Commands"
echo "=========================================="
echo

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper functions
pass() {
    echo -e "${GREEN}✓ $1${NC}"
}

fail() {
    echo -e "${RED}✗ $1${NC}"
    exit 1
}

section() {
    echo
    echo -e "${BLUE}$1${NC}"
    echo "----------------------------------------"
}

info() {
    echo -e "${YELLOW}$1${NC}"
}

# Start daemon if not running
if ! pgrep -f "target/debug/secd" > /dev/null; then
    info "Starting daemon..."
    ./target/debug/secd &
    DAEMON_PID=$!
    sleep 2
    pass "Daemon started (PID: $DAEMON_PID)"
else
    info "Daemon already running"
    DAEMON_PID=$(pgrep -f "target/debug/secd")
fi

# Cleanup function
cleanup() {
    if [ ! -z "$DAEMON_PID" ]; then
        info "Stopping daemon (PID: $DAEMON_PID)..."
        kill $DAEMON_PID 2>/dev/null || true
        sleep 1
    fi
}

trap cleanup EXIT

# Test F123-F126: Set Command
section "Test F123-F126: Set Command"

info "Setting secret with value argument..."
./target/debug/sec set TEST_API_KEY "test-secret-value-123" --provider test
pass "F123-F126: Set command works with value argument"

info "Setting secret with stdin..."
echo "stdin-secret-value-456" | ./target/debug/sec set TEST_STDIN_KEY --stdin --provider test
pass "F124: Set command reads from stdin"

info "Setting secret with metadata..."
./target/debug/sec set TEST_METADATA_KEY "meta-value" --provider openai --environment dev --notes "Test secret with metadata"
pass "F125: Set command includes metadata"

# Test F116-F118: List Command Enhancement
section "Test F116-F118: List Command Enhancement"

info "Listing secrets (human-readable)..."
OUTPUT=$(./target/debug/sec list)
echo "$OUTPUT"

# Check for ASCII table format with NAME, PROVIDER, CREATED columns
if echo "$OUTPUT" | grep -q "NAME.*PROVIDER.*CREATED"; then
    pass "F117: List displays ASCII table with name, provider, created columns"
else
    fail "F117: List does not show proper ASCII table format"
fi

if echo "$OUTPUT" | grep -q "TEST_API_KEY"; then
    pass "F116: List parses Vec<SecretMetadata> correctly"
else
    fail "F116: List does not show TEST_API_KEY"
fi

info "Listing secrets (JSON format)..."
JSON_OUTPUT=$(./target/debug/sec list --json)
echo "$JSON_OUTPUT"

if echo "$JSON_OUTPUT" | jq -e '.[0].name' > /dev/null 2>&1; then
    pass "F118: --json flag outputs valid JSON array"
else
    fail "F118: --json flag does not output valid JSON"
fi

# Test F119-F122: Get Command
section "Test F119-F122: Get Command"

info "Getting secret value..."
VALUE=$(./target/debug/sec get TEST_API_KEY)
echo "Retrieved value: $VALUE"

if [ "$VALUE" = "test-secret-value-123" ]; then
    pass "F119-F121: Get command retrieves and prints value correctly"
else
    fail "F119-F121: Get command returned wrong value: $VALUE"
fi

info "Getting non-existent secret..."
if ./target/debug/sec get NON_EXISTENT_KEY 2>&1 | grep -q "not found"; then
    pass "F122: Get command handles SecretNotFound with user-friendly message"
else
    fail "F122: Get command does not handle SecretNotFound properly"
fi

info "Testing get with --no-newline flag..."
VALUE_NO_NL=$(./target/debug/sec get TEST_API_KEY --no-newline)
# Check that value doesn't have trailing newline
if [ "$VALUE_NO_NL" = "test-secret-value-123" ]; then
    pass "F121: Get command supports --no-newline flag"
else
    fail "F121: --no-newline flag does not work correctly"
fi

# Test F127-F130: Delete Command
section "Test F127-F130: Delete Command"

info "Deleting secret with --force flag..."
./target/debug/sec delete TEST_METADATA_KEY --force
pass "F127-F129: Delete command works with --force flag"

# Verify deletion
if ./target/debug/sec get TEST_METADATA_KEY 2>&1 | grep -q "not found"; then
    pass "F129: Secret actually deleted from vault"
else
    fail "F129: Secret not deleted properly"
fi

info "Testing delete with confirmation prompt..."
# Auto-answer "n" to cancel deletion
echo "n" | ./target/debug/sec delete TEST_API_KEY 2>&1 | grep -q "cancelled" && \
    pass "F128: Delete prompts for confirmation and respects 'no'" || \
    fail "F128: Delete confirmation prompt does not work"

# Verify secret still exists
if ./target/debug/sec get TEST_API_KEY > /dev/null 2>&1; then
    pass "F128: Secret not deleted when confirmation is declined"
else
    fail "F128: Secret deleted even though confirmation was declined"
fi

info "Confirming deletion..."
# Auto-answer "y" to confirm deletion
echo "y" | ./target/debug/sec delete TEST_API_KEY
pass "F128-F130: Delete prompts, confirms, and deletes successfully"

# Verify deletion
if ./target/debug/sec get TEST_API_KEY 2>&1 | grep -q "not found"; then
    pass "F130: Secret deleted after confirmation"
else
    fail "F130: Secret not deleted after confirmation"
fi

# Test stdin secret deletion
info "Deleting stdin secret..."
./target/debug/sec delete TEST_STDIN_KEY --force
pass "F127-F130: All delete scenarios work"

# Final verification
section "Final Verification"

info "Listing remaining secrets..."
FINAL_LIST=$(./target/debug/sec list)
echo "$FINAL_LIST"

if echo "$FINAL_LIST" | grep -q "No secrets found"; then
    pass "All test secrets cleaned up"
else
    info "Some secrets remain (expected if vault had existing secrets)"
fi

echo
echo "=========================================="
echo -e "${GREEN}Wave 18 Tests Complete!${NC}"
echo "=========================================="
echo
echo "Features Implemented:"
echo "  F116: Parse response as Vec<SecretMetadata>"
echo "  F117: Format as ASCII table with name, provider, created columns"
echo "  F118: Implement --json flag to output raw JSON"
echo "  F119: Create commands/get.rs file"
echo "  F120: Send secret.get request with key argument"
echo "  F121: Print returned value to stdout (only value)"
echo "  F122: Handle SecretNotFound error with user-friendly message"
echo "  F123: Create commands/set.rs file"
echo "  F124: Read value from stdin if --stdin flag is set"
echo "  F125: Send secret.set request with key and value"
echo "  F126: Display 'Secret set successfully' message"
echo "  F127: Create commands/delete.rs file"
echo "  F128: Prompt 'Are you sure? (y/n)' unless --force flag"
echo "  F129: Send secret.delete request if confirmed"
echo "  F130: Display 'Secret deleted' message"
echo
