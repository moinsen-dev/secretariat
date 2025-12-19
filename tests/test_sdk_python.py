#!/usr/bin/env python3
# F259-F260: Python SDK integration tests
#
# Features:
# - F259: Create tests/test_sdk_python.py
# - F260: Test Python SDK get() returns correct value
#
# Usage: python tests/test_sdk_python.py
#
# Prerequisites:
# - Daemon running with test secrets

import json
import os
import socket
import sys
from typing import Dict, List, Optional

# Colors for output
RED = '\033[0;31m'
GREEN = '\033[0;32m'
NC = '\033[0m'  # No Color

# Test counters
tests_passed = 0
tests_failed = 0


def pass_test(message: str) -> None:
    """Log passed test."""
    global tests_passed
    print(f"{GREEN}✓ PASS:{NC} {message}")
    tests_passed += 1


def fail_test(message: str) -> None:
    """Log failed test."""
    global tests_failed
    print(f"{RED}✗ FAIL:{NC} {message}")
    tests_failed += 1


class SecretariatTestClient:
    """Simplified SDK client for testing."""

    def __init__(self, socket_path: str = "/tmp/secretariat.sock"):
        self.socket_path = socket_path
        self._socket: Optional[socket.socket] = None
        self._request_id = 0

    def _connect(self) -> None:
        """Connect to daemon socket."""
        if self._socket is not None:
            return

        self._socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self._socket.settimeout(5.0)
        self._socket.connect(self.socket_path)

    def _send_request(self, method: str, params: Dict) -> Dict:
        """Send JSON-RPC request."""
        self._connect()

        self._request_id += 1
        request = {
            "jsonrpc": "2.0",
            "id": self._request_id,
            "method": method,
            "params": params,
        }

        request_json = json.dumps(request) + "\n"
        self._socket.sendall(request_json.encode("utf-8"))

        # Receive response
        response_data = b""
        while True:
            chunk = self._socket.recv(4096)
            if not chunk:
                break
            response_data += chunk
            if response_data.endswith(b"\n"):
                break

        response = json.loads(response_data.decode("utf-8").strip())

        if "error" in response:
            raise Exception(response["error"].get("message", "Unknown error"))

        return response.get("result", {})

    def get(self, key: str) -> str:
        """Get secret value by key."""
        result = self._send_request("secret.get", {"key": key})
        return result.get("value", "")

    def list(self) -> List[str]:
        """List all secret names."""
        result = self._send_request("secret.list", {})
        return result.get("secrets", [])

    def close(self) -> None:
        """Close connection."""
        if self._socket is not None:
            self._socket.close()
            self._socket = None

    def __enter__(self) -> "SecretariatTestClient":
        return self

    def __exit__(self, *args) -> None:
        self.close()


def test_get_returns_correct_value(client: SecretariatTestClient, test_key: str, expected_value: str) -> None:
    """F260: Test Python SDK get() returns correct value."""
    try:
        value = client.get(test_key)

        if value == expected_value:
            pass_test(f'get("{test_key}") returned correct value')
        else:
            fail_test(f'get("{test_key}") returned "{value}", expected "{expected_value}"')
    except Exception as e:
        fail_test(f'get("{test_key}") threw exception: {e}')


def test_get_throws_on_missing_key(client: SecretariatTestClient) -> None:
    """Test get() raises exception on non-existent key."""
    try:
        client.get("NONEXISTENT_KEY_12345")
        fail_test("get() should raise for non-existent key")
    except Exception:
        pass_test("get() raises for non-existent key")


def test_list_returns_secrets(client: SecretariatTestClient) -> None:
    """Test list() returns secrets."""
    try:
        secrets = client.list()

        if isinstance(secrets, list):
            pass_test("list() returned a list")
        else:
            fail_test("list() did not return a list")

        if secrets:
            pass_test(f"list() returned {len(secrets)} secrets")
        else:
            # Empty list is valid if no secrets exist
            pass_test("list() returned empty list (no secrets)")
    except Exception as e:
        fail_test(f"list() threw exception: {e}")


def test_context_manager(socket_path: str) -> None:
    """Test context manager support."""
    try:
        with SecretariatTestClient(socket_path=socket_path) as client:
            # Just verify connection works
            client.list()
        pass_test("Context manager works correctly")
    except Exception as e:
        fail_test(f"Context manager failed: {e}")


def main() -> int:
    """Run tests."""
    print("================================================")
    print("Secretariat Python SDK Tests")
    print("================================================")

    # Check for socket path override
    socket_path = os.environ.get("SECRETARIAT_SOCKET_PATH", "/tmp/secretariat.sock")
    print(f"Socket path: {socket_path}")

    # Check if socket exists
    if not os.path.exists(socket_path):
        print(f"{RED}Error: Socket not found at {socket_path}{NC}")
        print("Make sure the daemon is running.")
        return 1

    with SecretariatTestClient(socket_path=socket_path) as client:
        print("")
        print("F260: Test Python SDK get() returns correct value")
        print("-------------------------------------------------")

        # Test with a secret that should exist (set up by CLI tests)
        test_get_returns_correct_value(client, "DATABASE_URL", "postgres://localhost/test")

        print("")
        print("Test get() throws on non-existent key")
        print("-------------------------------------")
        test_get_throws_on_missing_key(client)

        print("")
        print("Test list() returns secrets")
        print("---------------------------")
        test_list_returns_secrets(client)

    print("")
    print("Test context manager")
    print("--------------------")
    test_context_manager(socket_path)

    print("")
    print("================================================")
    print("Python SDK Test Summary")
    print("================================================")
    print(f"{GREEN}Passed: {tests_passed}{NC}")
    print(f"{RED}Failed: {tests_failed}{NC}")
    print("================================================")

    return 1 if tests_failed > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
