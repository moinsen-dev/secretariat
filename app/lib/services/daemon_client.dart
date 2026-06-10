// F145-F149: DaemonClient for JSON-RPC communication with Secretariat daemon
//
// Features:
// - F145: Unix socket connection (macOS/Linux)
// - F146-F149: JSON-RPC request/response cycle
// - Persistent response dispatcher to avoid race conditions between requests
//
// The key design choice: a single persistent stream subscription routes
// responses by request ID, instead of creating/cancelling per-request
// subscriptions. This eliminates the race where a response arrives
// between subscribe and cancel of successive requests.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Custom exception for daemon errors
class DaemonException implements Exception {
  final String message;
  DaemonException(this.message);

  @override
  String toString() => 'DaemonException: $message';
}

/// Client for communicating with the Secretariat daemon via Unix socket
///
/// Uses JSON-RPC 2.0 protocol over newline-delimited Unix socket.
/// Maintains a persistent response dispatcher that routes incoming
/// responses to the correct pending request by ID.
class DaemonClient {
  Socket? _socket;
  StreamSubscription<Map<String, dynamic>>? _responseSubscription;
  StreamSubscription<dynamic>? _socketSubscription;
  StreamController<Map<String, dynamic>>? _messageController;
  String _buffer = '';

  /// Flag to prevent reconnect races while connect() is in flight
  bool _connecting = false;

  /// Flag to prevent operations on disposed client
  bool _isDisposed = false;

  /// Heartbeat timer to keep the socket connection alive
  Timer? _heartbeatTimer;

  /// Map of pending request IDs to their completers
  final Map<int, Completer<Map<String, dynamic>>> _pendingRequests = {};

  /// Next request ID (auto-incrementing, avoids millisecond collisions)
  int _nextRequestId = 1;

  /// Serializes socket write+flush so concurrent requests never overlap.
  /// IOSink.flush() briefly binds the sink; two overlapping flushes throw
  /// "Bad state: StreamSink is bound to a stream". Chaining writes prevents
  /// that when several requests fire at once (e.g. on app startup).
  Future<void> _writeQueue = Future<void>.value();

  /// Whether the client is connected
  bool get isConnected => _socket != null;

  /// Connect to the daemon Unix socket
  ///
  /// [socketPath] can be provided to override the default platform path.
  ///
  /// Example:
  /// ```dart
  /// final client = DaemonClient();
  /// await client.connect();
  /// ```
  Future<void> connect() async {
    if (_socket != null) {
      _log('Already connected to daemon');
      return;
    }
    if (_connecting) {
      _log('Already connecting...');
      return;
    }
    _connecting = true;
    _isDisposed = false;

    final socketPath = _getSocketPath();
    _log('Connecting to daemon at: $socketPath');

    // Check if socket file exists
    final socketFile = File(socketPath);
    if (!socketFile.existsSync()) {
      _log('ERROR: Socket file does not exist at $socketPath');
      _log('Make sure the Secretariat daemon is running (make service-start)');
      throw SocketException(
        'Daemon socket not found at $socketPath. Is the daemon running?',
      );
    }

    try {
      final address = InternetAddress(
        socketPath,
        type: InternetAddressType.unix,
      );
      _log('Attempting socket connection...');
      _socket = await Socket.connect(address, 0);
      _log('Socket connected successfully');

      // Create message stream and persistent dispatcher
      _messageController = StreamController<Map<String, dynamic>>.broadcast();

      // Persistent subscription: routes all responses by request ID
      _responseSubscription = _messageController!.stream.listen(_dispatchResponse);

      // Socket data listener
      _socketSubscription = _socket!.listen(
        _handleData,
        onError: _handleSocketError,
        onDone: _handleSocketDone,
      );
      _log('Daemon client ready');
      startHeartbeat();
    } catch (e) {
      _log('ERROR: Failed to connect to daemon: $e');
      cleanup();
      rethrow;
    } finally {
      _connecting = false;
    }
  }

  /// Disconnect from the daemon
  Future<void> disconnect() async {
    _log('Disconnecting from daemon...');

    // Fail all pending requests
    for (final entry in _pendingRequests.entries) {
      if (!entry.value.isCompleted) {
        entry.value.completeError(DaemonException('Connection closed'));
      }
    }
    _pendingRequests.clear();

    cleanup();
    _log('Disconnected');
  }

  /// Internal cleanup without failing pending requests
  @visibleForTesting
  void cleanup() {
    _isDisposed = true;
    stopHeartbeat();
    _responseSubscription?.cancel();
    _responseSubscription = null;
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.close();
    _socket = null;
    _messageController?.close();
    _messageController = null;
    _buffer = '';
  }

  /// Whether the heartbeat timer should remain active (socket open, not disposed)
  @visibleForTesting
  bool get heartbeatShouldRemainActive => _socket != null && !_isDisposed;

  /// Start periodic heartbeat to keep the socket connection alive
  @visibleForTesting
  void startHeartbeat() {
    stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!heartbeatShouldRemainActive) {
        stopHeartbeat();
        return;
      }
      try {
        await healthCheck();
      } catch (_) {
        // Socket likely closed — stop heartbeat, reconnect happens on next request
        stopHeartbeat();
      }
    });
  }

  /// Stop the heartbeat timer
  @visibleForTesting
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  @visibleForTesting
  Timer? get heartbeatTimer => _heartbeatTimer;

  @visibleForTesting
  Socket? get socket => _socket;

  @visibleForTesting
  set socket(Socket? value) {
    _socket = value;
  }

  @visibleForTesting
  bool get isDisposed => _isDisposed;

  /// Ensure we are connected, reconnecting if the socket was closed
  @visibleForTesting
  Future<void> ensureConnected() async {
    if (_socket != null && !_isDisposed) return;
    // If another connect is in progress, wait for it
    if (_connecting) {
      _log('Already connecting, waiting...');
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (_socket != null && !_isDisposed) return;
        if (!_connecting) break;
      }
    }
    _log('Socket disconnected, reconnecting...');
    // Just null the socket without disposing — connect() handles the rest
    _socket = null;
    _isDisposed = false;
    await connect();
  }

  /// F146-F149: Send a JSON-RPC request and wait for response
  ///
  /// Uses a persistent response dispatcher to route the response.
  /// Automatically reconnects if the socket connection was lost.
  /// Returns the `result` field of the JSON-RPC response.
  ///
  /// Example:
  /// ```dart
  /// final response = await client.sendRequest('secret.list', {});
  /// ```
  Future<Map<String, dynamic>> sendRequest(
    String method,
    Map<String, dynamic> params,
  ) async {
    // Auto-reconnect if socket was closed
    try {
      await ensureConnected();
    } catch (e) {
      _log('ERROR: Auto-reconnect failed: $e');
      throw DaemonException('Not connected to daemon and reconnect failed: $e');
    }

    // Build JSON-RPC request with auto-incrementing ID
    final requestId = _nextRequestId++;
    final request = {
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
      'id': requestId,
    };

    _log('Sending request #$requestId: $method');

    // F147: Serialize request to JSON and write to socket.
    // Chain through _writeQueue so concurrent requests don't overlap their
    // flush() calls (which would throw "StreamSink is bound to a stream").
    final requestJson = json.encode(request);
    await _serializedWrite('$requestJson\n');

    // F148-F149: Create completer and wait for dispatcher to route response
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[requestId] = completer;

    try {
      final result = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _log('ERROR: Request #$requestId ($method) timed out');
          _pendingRequests.remove(requestId);
          throw DaemonException('Request timed out');
        },
      );
      _log('Request #$requestId ($method) succeeded');
      return result;
    } catch (e) {
      _pendingRequests.remove(requestId);
      rethrow;
    }
  }

  /// Write to the socket through a serialized queue so write+flush of
  /// concurrent requests never overlap. The queue swallows errors so one
  /// failed write doesn't poison every subsequent request.
  Future<void> _serializedWrite(String data) {
    final result = _writeQueue.then((_) async {
      _socket!.write(data);
      await _socket!.flush();
    });
    _writeQueue = result.catchError((_) {});
    return result;
  }

  /// Dispatch a response message to the correct pending request
  void _dispatchResponse(Map<String, dynamic> message) {
    final id = message['id'] as int?;
    if (id == null) {
      _log('WARNING: Received response without ID');
      return;
    }

    final completer = _pendingRequests.remove(id);
    if (completer == null) {
      _log('WARNING: No pending request for ID $id (already timed out or completed)');
      return;
    }

    if (completer.isCompleted) {
      _log('WARNING: Completer for ID $id already completed');
      return;
    }

    if (message.containsKey('error')) {
      final errorMsg = message['error']['message'] as String;
      _log('ERROR: Request #$id failed: $errorMsg');
      completer.completeError(DaemonException(errorMsg));
    } else {
      _log('Response #$id received successfully');
      completer.complete(message['result'] as Map<String, dynamic>);
    }
  }

  /// Handle incoming socket data
  void _handleData(List<int> data) {
    if (_isDisposed) {
      _log('WARNING: _handleData called after disposal, ignoring');
      return;
    }

    _buffer += utf8.decode(data);

    // Process complete JSON messages (newline-delimited)
    final lines = _buffer.split('\n');
    _buffer = lines.last; // Keep incomplete line in buffer

    for (var i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      try {
        final message = json.decode(line) as Map<String, dynamic>;
        _log('Received response for request ${message['id']}');
        if (_messageController != null && !_messageController!.isClosed) {
          _messageController!.add(message);
        } else {
          _log('WARNING: messageController is closed, dropping response');
        }
      } catch (e) {
        _log('ERROR: Failed to process message: $e');
        _log('Raw message: $line');
      }
    }
  }

  /// Handle socket errors
  void _handleSocketError(dynamic error) {
    _log('ERROR: Socket error: $error');
    disconnect();
  }

  /// Handle socket close
  void _handleSocketDone() {
    _log('Socket connection closed by daemon');
    disconnect();
  }

  /// F145: Get platform-specific socket path
  String _getSocketPath() {
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      return '$home/Library/Application Support/Secretariat/secretariat.sock';
    } else if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      return '$home/.local/share/secretariat/secretariat.sock';
    } else if (Platform.isWindows) {
      throw UnsupportedError(
        'Secretariat is not yet available for Windows.\n'
        'Currently supported platforms: macOS, Linux.\n'
        'Windows support is planned for a future release.',
      );
    } else {
      throw UnsupportedError(
        'Unsupported platform: ${Platform.operatingSystem}.\n'
        'Secretariat currently supports macOS and Linux only.',
      );
    }
  }

  /// Log a debug message
  void _log(String message) {
    debugPrint('[DaemonClient] $message');
  }

  // =========================================================================
  // Convenience methods (all use sendRequest internally)
  // =========================================================================

  /// List all secrets
  ///
  /// Example:
  /// ```dart
  /// final secrets = await client.listSecrets();
  /// ```
  Future<List<Map<String, dynamic>>> listSecrets() async {
    final result = await sendRequest('secret.list', {});
    return List<Map<String, dynamic>>.from(result['secrets'] as List);
  }

  /// Get a secret by name
  ///
  /// Example:
  /// ```dart
  /// final secret = await client.getSecret('OPENAI_API_KEY');
  /// ```
  Future<Map<String, dynamic>> getSecret(String name) async {
    return await sendRequest('secret.get', {
      'name': name,
      'app_id': 'flutter-app',
    });
  }

  /// Set a secret
  ///
  /// Example:
  /// ```dart
  /// await client.setSecret('OPENAI_API_KEY', 'sk-abc123...');
  /// ```
  Future<void> setSecret(
    String name,
    String value, {
    String? provider,
    String? environment,
    String? notes,
  }) async {
    final params = {
      'name': name,
      'value': value,
      if (provider != null) 'provider': provider,
      if (environment != null) 'environment': environment,
      if (notes != null) 'notes': notes,
    };
    await sendRequest('secret.set', params);
  }

  /// Delete a secret
  ///
  /// Example:
  /// ```dart
  /// await client.deleteSecret('OPENAI_API_KEY');
  /// ```
  Future<void> deleteSecret(String name) async {
    await sendRequest('secret.delete', {'name': name});
  }

  /// Get daemon health status
  ///
  /// Example:
  /// ```dart
  /// final status = await client.healthCheck();
  /// ```
  Future<Map<String, dynamic>> healthCheck() async {
    return await sendRequest('health.check', {});
  }

  /// Rotate a secret (create new version)
  ///
  /// Example:
  /// ```dart
  /// final result = await client.rotateSecret('API_KEY', 'new-value');
  /// ```
  Future<Map<String, dynamic>> rotateSecret(String name, String newValue) async {
    return await sendRequest('secret.rotate', {
      'name': name,
      'new_value': newValue,
    });
  }

  /// List all registered applications
  ///
  /// Example:
  /// ```dart
  /// final apps = await client.listApplications();
  /// ```
  Future<List<Map<String, dynamic>>> listApplications() async {
    final result = await sendRequest('app.list', {});
    return List<Map<String, dynamic>>.from(result['apps'] as List);
  }

  /// Revoke an application's access to a secret
  ///
  /// Example:
  /// ```dart
  /// await client.revokePermission('app-id-123', 'secret-name');
  /// ```
  Future<void> revokePermission(String appId, String secretId) async {
    await sendRequest('app.revoke', {
      'app_id': appId,
      'secret_id': secretId,
    });
  }

  /// Grant an application access to a secret
  ///
  /// Example:
  /// ```dart
  /// await client.grantPermission('app-id-123', 'secret-name');
  /// ```
  Future<void> grantPermission(String appId, String secretName) async {
    await sendRequest('app.authorize', {
      'app_id': appId,
      'secret_name': secretName,
    });
  }

  /// Get audit log
  ///
  /// Example:
  /// ```dart
  /// final entries = await client.getAuditLog();
  /// ```
  Future<List<Map<String, dynamic>>> getAuditLog({
    String? appId,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (appId != null) {
      params['app_id'] = appId;
    }
    final result = await sendRequest('audit.log', params);
    return List<Map<String, dynamic>>.from(result['entries'] as List);
  }

  /// Export the full encrypted sync payload (secrets + tombstones + salt +
  /// verification). Moves only ciphertext — no unlock required.
  Future<Map<String, dynamic>> syncExport() async {
    return await sendRequest('sync.export', {});
  }

  /// Merge an incoming encrypted sync payload from another device into the
  /// local vault (last-write-wins). Returns applied/received counts.
  Future<Map<String, dynamic>> syncImport(
    List<dynamic> secrets,
    List<dynamic> tombstones,
  ) async {
    return await sendRequest('sync.import', {
      'secrets': secrets,
      'tombstones': tombstones,
    });
  }

  /// Get vault status
  ///
  /// Example:
  /// ```dart
  /// final status = await client.getVaultStatus();
  /// // status = {'state': 'unlocked', 'secret_count': 5, 'app_count': 2}
  /// ```
  Future<Map<String, dynamic>> getVaultStatus() async {
    return await sendRequest('vault.status', {});
  }

  /// Lock the vault
  ///
  /// Example:
  /// ```dart
  /// await client.lockVault();
  /// ```
  Future<void> lockVault() async {
    await sendRequest('vault.lock', {});
  }

  /// Unlock the vault with password
  ///
  /// Example:
  /// ```dart
  /// await client.unlockVault('my-password');
  /// ```
  Future<void> unlockVault(String password) async {
    await sendRequest('vault.unlock', {'password': password});
  }

  /// Initialize the vault with a password
  ///
  /// Example:
  /// ```dart
  /// final result = await client.initVault('my-secure-password');
  /// ```
  Future<Map<String, dynamic>> initVault(String password) async {
    return await sendRequest('vault.init', {'password': password});
  }

  /// Change the vault master password
  ///
  /// Example:
  /// ```dart
  /// final result = await client.changePassword('old-password', 'new-password');
  /// ```
  Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    return await sendRequest('vault.change_password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }
}
