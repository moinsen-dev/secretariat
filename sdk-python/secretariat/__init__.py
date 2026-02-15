# F223-F230: Python SDK for Secretariat
#
# Features:
# - F223: Create sdk-python/secretariat/__init__.py file
# - F224: Define Secretariat class
# - F225: Import socket module
# - F226: Implement get(self, key: str) -> str method
# - F227: Connect to Unix socket using socket.socket(AF_UNIX)
# - F228: Send JSON request as bytes
# - F229: Receive response and parse JSON
# - F230: Implement __enter__ and __exit__ for context manager support

"""
Secretariat Python SDK

A lightweight Python client for the Secretariat secrets manager daemon.

Example usage:
    from secretariat import Secretariat

    client = Secretariat()
    api_key = client.get('OPENAI_API_KEY')
    print(f'API Key: {api_key}')

With context manager:
    with Secretariat() as client:
        api_key = client.get('OPENAI_API_KEY')
        secrets = client.get_many(['OPENAI_API_KEY', 'DATABASE_URL'])
"""

from __future__ import annotations

import json
import os
import platform
# F225: Import socket module
import socket
from typing import Dict, List, Optional


class SecretariatError(Exception):
    """Exception raised by Secretariat SDK."""

    def __init__(self, message: str, code: Optional[int] = None):
        super().__init__(message)
        self.message = message
        self.code = code

    def __str__(self) -> str:
        if self.code is not None:
            return f"SecretariatError({self.code}): {self.message}"
        return f"SecretariatError: {self.message}"


# F224: Define Secretariat class
class Secretariat:
    """
    Secretariat client for retrieving secrets from the daemon.

    This client communicates with the local Secretariat daemon via Unix
    domain socket (macOS/Linux) or named pipe (Windows).

    Attributes:
        socket_path: Path to Unix socket or named pipe (optional)
        timeout: Socket timeout in seconds (default: 5.0)

    Example:
        >>> client = Secretariat()
        >>> api_key = client.get('OPENAI_API_KEY')
        >>> print(f'API Key: {api_key}')

    Context manager example:
        >>> with Secretariat() as client:
        ...     api_key = client.get('OPENAI_API_KEY')
    """

    # Default socket paths by platform
    # macOS: ~/Library/Application Support/Secretariat/secretariat.sock
    # Linux: ~/.local/share/secretariat/secretariat.sock
    # Windows: \\.\pipe\secretariat
    _DEFAULT_PIPE_PATH = r"\\.\pipe\secretariat"

    def __init__(
        self,
        socket_path: Optional[str] = None,
        timeout: float = 5.0,
    ):
        """
        Initialize Secretariat client.

        Args:
            socket_path: Custom path to Unix socket or named pipe.
                         If None, uses platform-specific default.
            timeout: Socket timeout in seconds (default: 5.0)
        """
        self._socket_path = socket_path
        self._timeout = timeout
        self._socket: Optional[socket.socket] = None
        self._request_id = 0

    @property
    def socket_path(self) -> str:
        """Get the socket/pipe path based on platform."""
        if self._socket_path:
            return self._socket_path

        system = platform.system()
        if system == "Windows":
            return self._DEFAULT_PIPE_PATH
        elif system == "Darwin":  # macOS
            home = os.path.expanduser("~")
            return os.path.join(home, "Library", "Application Support", "Secretariat", "secretariat.sock")
        else:  # Linux and other Unix-like systems
            home = os.path.expanduser("~")
            return os.path.join(home, ".local", "share", "secretariat", "secretariat.sock")

    # F227: Connect to Unix socket using socket.socket(AF_UNIX)
    def _connect(self) -> None:
        """Connect to the daemon socket."""
        if self._socket is not None:
            return

        try:
            # F227: Create Unix domain socket
            self._socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self._socket.settimeout(self._timeout)
            self._socket.connect(self.socket_path)
        except socket.error as e:
            self._socket = None
            raise SecretariatError(
                f"Failed to connect to Secretariat daemon at {self.socket_path}: {e}"
            ) from e

    # F228: Send JSON request as bytes
    def _send_request(
        self,
        method: str,
        params: Dict[str, object],
    ) -> Dict[str, object]:
        """
        Send JSON-RPC request to daemon.

        Args:
            method: RPC method name (e.g., 'secret.get')
            params: Method parameters

        Returns:
            Response result dict

        Raises:
            SecretariatError: On communication or RPC errors
        """
        self._connect()

        self._request_id += 1
        request_id = self._request_id

        # Build JSON-RPC 2.0 request
        request = {
            "jsonrpc": "2.0",
            "id": request_id,
            "method": method,
            "params": params,
        }

        # F228: Send JSON request as bytes
        request_json = json.dumps(request) + "\n"
        try:
            self._socket.sendall(request_json.encode("utf-8"))
        except socket.error as e:
            self._socket = None
            raise SecretariatError(f"Failed to send request: {e}") from e

        # F229: Receive response and parse JSON
        return self._receive_response(request_id)

    # F229: Receive response and parse JSON
    def _receive_response(self, expected_id: int) -> Dict[str, object]:
        """
        Receive and parse JSON-RPC response.

        Args:
            expected_id: Expected request ID

        Returns:
            Response result dict

        Raises:
            SecretariatError: On communication or parsing errors
        """
        response_data = b""

        try:
            while True:
                chunk = self._socket.recv(4096)
                if not chunk:
                    break
                response_data += chunk
                # Check for complete response (ends with newline)
                if response_data.endswith(b"\n"):
                    break
        except socket.timeout:
            raise SecretariatError("Request timed out")
        except socket.error as e:
            self._socket = None
            raise SecretariatError(f"Failed to receive response: {e}") from e

        if not response_data:
            raise SecretariatError("Empty response from daemon")

        # Parse JSON response
        try:
            response = json.loads(response_data.decode("utf-8").strip())
        except json.JSONDecodeError as e:
            raise SecretariatError(f"Failed to parse response: {e}") from e

        # Validate response
        if response.get("id") != expected_id:
            raise SecretariatError("Response ID mismatch")

        # Check for errors
        if "error" in response:
            error = response["error"]
            raise SecretariatError(
                error.get("message", "Unknown error"),
                code=error.get("code"),
            )

        return response.get("result", {})

    # F226: Implement get(self, key: str) -> str method
    def get(self, key: str, app_id: str = "python-sdk") -> str:
        """
        Get secret value by key.

        Args:
            key: Secret name/key (e.g., 'OPENAI_API_KEY')
            app_id: Application identifier for permission checks (default: 'python-sdk')

        Returns:
            Decrypted secret value

        Raises:
            SecretariatError: If secret not found, permission denied,
                             or communication error

        Example:
            >>> client = Secretariat()
            >>> api_key = client.get('OPENAI_API_KEY')
        """
        result = self._send_request("secret.get", {"name": key, "app_id": app_id})

        if "value" not in result:
            raise SecretariatError("Invalid response: missing value")

        return result["value"]

    def get_many(self, keys: List[str]) -> Dict[str, str]:
        """
        Get multiple secrets at once.

        Args:
            keys: List of secret names to retrieve

        Returns:
            Dict mapping key to value

        Raises:
            SecretariatError: On first error (does not return partial results)

        Example:
            >>> secrets = client.get_many(['OPENAI_API_KEY', 'DATABASE_URL'])
            >>> print(secrets['OPENAI_API_KEY'])
        """
        results = {}
        for key in keys:
            results[key] = self.get(key)
        return results

    def list(self) -> List[str]:
        """
        List all available secret names.

        Returns:
            List of secret names (not values)

        Example:
            >>> names = client.list()
            >>> print(f'Available secrets: {names}')
        """
        result = self._send_request("secret.list", {})

        if "secrets" not in result:
            raise SecretariatError("Invalid response: missing secrets")

        secrets_raw = result["secrets"]
        if not isinstance(secrets_raw, list):
            raise SecretariatError("Invalid response: secrets must be a list")

        names: List[str] = []
        for entry in secrets_raw:
            if isinstance(entry, str):
                names.append(entry)
            elif isinstance(entry, dict):
                name = entry.get("name")
                if isinstance(name, str):
                    names.append(name)
                else:
                    raise SecretariatError("Invalid response: secret entry missing name")
            else:
                raise SecretariatError("Invalid response: unsupported secret entry format")

        return names

    def set(self, key: str, value: str) -> None:
        """
        Set/create a secret.

        Args:
            key: Secret name/key (e.g., 'OPENAI_API_KEY')
            value: Secret value to store (will be encrypted)

        Raises:
            SecretariatError: On communication or storage error

        Example:
            >>> client.set('API_KEY', 'sk-123456789')
        """
        self._send_request("secret.set", {"name": key, "value": value})

    def delete(self, key: str) -> None:
        """
        Delete a secret.

        Args:
            key: Secret name/key to delete

        Raises:
            SecretariatError: If secret not found or communication error

        Example:
            >>> client.delete('OLD_API_KEY')
        """
        self._send_request("secret.delete", {"name": key})

    def close(self) -> None:
        """
        Close the connection to the daemon.

        Call this when done to free resources.
        """
        if self._socket is not None:
            try:
                self._socket.close()
            except socket.error:
                pass
            self._socket = None

    # F230: Implement __enter__ and __exit__ for context manager support
    def __enter__(self) -> "Secretariat":
        """Enter context manager."""
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> None:
        """Exit context manager, closing connection."""
        self.close()


# Convenience function for quick access
def get(key: str, socket_path: Optional[str] = None) -> str:
    """
    Quick function to get a single secret.

    Args:
        key: Secret name/key
        socket_path: Optional custom socket path

    Returns:
        Secret value

    Example:
        >>> from secretariat import get
        >>> api_key = get('OPENAI_API_KEY')
    """
    with Secretariat(socket_path=socket_path) as client:
        return client.get(key)


# Environment variable fallback support
def get_or_env(key: str, env_var: Optional[str] = None) -> str:
    """
    Get secret with environment variable fallback.

    Tries to get secret from daemon first. If daemon is unavailable
    or secret not found, falls back to environment variable.

    Args:
        key: Secret name/key
        env_var: Environment variable name (defaults to key)

    Returns:
        Secret value from daemon or environment

    Raises:
        SecretariatError: If neither daemon nor environment has value

    Example:
        >>> api_key = get_or_env('OPENAI_API_KEY')
    """
    env_name = env_var or key

    try:
        with Secretariat() as client:
            return client.get(key)
    except SecretariatError:
        # Fall back to environment variable
        value = os.environ.get(env_name)
        if value is not None:
            return value
        raise SecretariatError(
            f"Secret '{key}' not found in daemon or environment variable '{env_name}'"
        )


__all__ = [
    "Secretariat",
    "SecretariatError",
    "get",
    "get_or_env",
]

__version__ = "0.1.0"
