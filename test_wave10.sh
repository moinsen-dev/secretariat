#!/bin/bash
# Test script for Wave 10 features (F046-F050)

set -e

SOCKET_PATH="$HOME/Library/Application Support/Secretariat/secretariat.sock"

echo "=== Wave 10 Feature Tests ==="
echo ""

# Test F048: Request/Response Logging
echo "Test F048: Send a valid health check request (should be logged)"
echo '{"id":"test-1","method":"health.check","params":{}}' | nc -U "$SOCKET_PATH"
echo ""

# Test F049: Malformed JSON Handling
echo "Test F049: Send malformed JSON (missing closing brace)"
echo '{"id":"test-2","method":"health.check","params":{}' | nc -U "$SOCKET_PATH"
echo ""

# Test F049: Invalid UTF-8 (not easily testable with echo)
# Skipping as it requires binary data

# Test F050: Rate Limiting
echo "Test F050: Send multiple requests rapidly (should hit rate limit)"
for i in {1..105}; do
    echo "{\"id\":\"test-rate-$i\",\"method\":\"health.check\",\"params\":{}}" | nc -U "$SOCKET_PATH" &
done
wait
echo ""

# Test F046: Connection Idle Timeout
echo "Test F046: Open connection and wait 35 seconds (should timeout at 30s)"
echo "Opening connection and waiting for timeout..."
(sleep 35 | nc -U "$SOCKET_PATH") &
PID=$!
echo "Connection PID: $PID"
echo "Check daemon logs to see timeout message after 30 seconds"
echo ""

echo "=== Tests Complete ==="
echo "Check daemon logs for:"
echo "  - F048: Debug-level request logs and trace-level response logs"
echo "  - F049: Error responses for malformed JSON"
echo "  - F050: Rate limit exceeded errors"
echo "  - F046: Idle timeout warning after 30 seconds"
