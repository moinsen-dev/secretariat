// F143-F145: DaemonClient for Flutter app
//
// Features:
// - F143: Create lib/services/daemon_client.dart file
// - F144: Define DaemonClient class with Socket? _socket field
// - F145: Implement connect() async method using Socket.connect to Unix socket

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// F144: Define DaemonClient class with Socket? _socket field
///
/// Client for communicating with the Secretariat daemon via Unix socket.
///
/// Example:
/// ```dart
/// final client = DaemonClient();
/// await client.connect();
/// final secrets = await client.listSecrets();
/// await client.disconnect();
/// ```
class DaemonClient {
  /// F144: Socket connection to the daemon
  Socket? _socket;

  /// Stream controller for incoming messages (broadcast to allow multiple listeners)
  StreamController<Map<String, dynamic>>? _messageController;

  /// Stream subscription for socket data
  StreamSubscription<List<int>>? _socketSubscription;

  /// Whether the client is currently connected
  bool get isConnected => _socket != null;

  /// Buffer for incomplete JSON messages
  String _buffer = '';

  /// F145: Implement connect() async method using Socket.connect to Unix socket
  ///
  /// Connects to the daemon Unix socket.
  ///
  /// The socket path is platform-specific:
  /// - macOS: ~/Library/Application Support/Secretariat/secretariat.sock
  /// - Linux: ~/.local/share/secretariat/secretariat.sock
  /// - Windows: Named pipe (not implemented yet)
  ///
  /// Throws [SocketException] if connection fails.
  ///
  /// Example:
  /// ```dart
  /// final client = DaemonClient();
  /// await client.connect();
  /// ```
  Future<void> connect() async {
    if (_socket != null) {
      _log('Already connected to daemon');
      return; // Already connected
    }

    // Get socket path based on platform
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
      // F145: Connect to Unix socket
      final address = InternetAddress(
        socketPath,
        type: InternetAddressType.unix,
      );
      _log('Attempting socket connection...');
      _socket = await Socket.connect(address, 0);
      _log('Socket connected successfully');

      // Initialize message stream as broadcast to allow multiple listeners
      _messageController = StreamController<Map<String, dynamic>>.broadcast();

      // Listen for incoming data
      _socketSubscription = _socket!.listen(
        _handleData,
        onError: _handleError,
        onDone: _handleDone,
      );
      _log('Daemon client ready');
    } catch (e) {
      _log('ERROR: Failed to connect to daemon: $e');
      throw SocketException('Failed to connect to daemon at $socketPath: $e');
    }
  }

  /// Log a message (uses debugPrint in debug mode)
  void _log(String message) {
    debugPrint('[DaemonClient] $message');
  }

  /// Disconnect from the daemon
  Future<void> disconnect() async {
    _log('Disconnecting from daemon...');
    await _socketSubscription?.cancel();
    await _socket?.close();
    await _messageController?.close();

    _socketSubscription = null;
    _socket = null;
    _messageController = null;
    _buffer = '';
    _log('Disconnected');
  }

  /// F146: Send a JSON-RPC request to the daemon
  ///
  /// Implements F146-F149:
  /// - F146: sendRequest(String method, Map params) async method
  /// - F147: Serialize request to JSON and write to socket
  /// - F148: Listen for response on socket stream
  /// - F149: Parse response JSON and extract result
  ///
  /// Example:
  /// ```dart
  /// final response = await client.sendRequest('secret.list', {});
  /// ```
  Future<Map<String, dynamic>> sendRequest(
    String method,
    Map<String, dynamic> params,
  ) async {
    if (_socket == null) {
      _log('ERROR: Not connected to daemon');
      throw StateError('Not connected to daemon. Call connect() first.');
    }

    // Build JSON-RPC request
    final request = {
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
      'id': DateTime.now().millisecondsSinceEpoch,
    };

    _log('Sending request: $method');

    // F147: Serialize request to JSON and write to socket
    final requestJson = json.encode(request);
    _socket!.write('$requestJson\n');
    await _socket!.flush();

    // F148: Listen for response on socket stream
    final completer = Completer<Map<String, dynamic>>();
    final subscription = _messageController!.stream.listen((message) {
      if (message['id'] == request['id']) {
        // F149: Parse response JSON and extract result
        if (message.containsKey('error')) {
          final errorMsg = message['error']['message'] as String;
          _log('ERROR: Request $method failed: $errorMsg');
          completer.completeError(DaemonException(errorMsg));
        } else {
          _log('Request $method succeeded');
          completer.complete(message['result'] as Map<String, dynamic>);
        }
      }
    });

    // Clean up subscription after response
    try {
      final result = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _log('ERROR: Request $method timed out');
          throw DaemonException('Request timed out');
        },
      );
      await subscription.cancel();
      return result;
    } catch (e) {
      await subscription.cancel();
      rethrow;
    }
  }

  /// Legacy alias for sendRequest
  ///
  /// Example:
  /// ```dart
  /// final response = await client.request('secret.list', {});
  /// ```
  @Deprecated('Use sendRequest instead')
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params,
  ) async {
    return sendRequest(method, params);
  }

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
  Future<void> revokePermission(String appId, String secretName) async {
    await sendRequest('app.revoke', {'app_id': appId, 'secret_name': secretName});
  }

  /// Grant an application access to a secret
  ///
  /// Example:
  /// ```dart
  /// await client.grantPermission('app-id-123', 'OPENAI_API_KEY');
  /// ```
  Future<void> grantPermission(String appId, String secretName) async {
    await sendRequest('app.authorize', {'app_id': appId, 'secret_name': secretName});
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

  /// Get audit log entries
  ///
  /// Example:
  /// ```dart
  /// final entries = await client.getAuditLog(limit: 50);
  /// ```
  Future<List<Map<String, dynamic>>> getAuditLog({int limit = 100, String? appId}) async {
    final params = <String, dynamic>{'limit': limit};
    if (appId != null) {
      params['app_id'] = appId;
    }
    final result = await sendRequest('audit.log', params);
    return List<Map<String, dynamic>>.from(result['entries'] as List);
  }

  /// Rotate a secret's value
  ///
  /// Example:
  /// ```dart
  /// final result = await client.rotateSecret('OPENAI_API_KEY', 'new-secret-value');
  /// // result = {'name': 'OPENAI_API_KEY', 'version': 2, 'status': 'rotated'}
  /// ```
  Future<Map<String, dynamic>> rotateSecret(String name, String newValue) async {
    return await sendRequest('secret.rotate', {'name': name, 'value': newValue});
  }

  /// Initialize the vault with a master password
  ///
  /// This must be called on first run to set up the vault.
  /// The password will be used to derive the master encryption key.
  ///
  /// Example:
  /// ```dart
  /// final result = await client.initVault('my-secure-password');
  /// // result = {'vault_path': '/path/to/vault.db', 'secrets_migrated': 0}
  /// ```
  Future<Map<String, dynamic>> initVault(String password) async {
    return await sendRequest('vault.init', {'password': password});
  }

  /// Change the vault master password
  ///
  /// Re-encrypts all secrets with the new password.
  ///
  /// Example:
  /// ```dart
  /// final result = await client.changePassword('old-password', 'new-password');
  /// // result = {'secrets_migrated': 5, 'status': 'password_changed'}
  /// ```
  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    return await sendRequest('vault.change_password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  /// Handle incoming socket data
  void _handleData(List<int> data) {
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
        _messageController?.add(message);
      } catch (e) {
        _log('ERROR: Failed to parse JSON message: $e');
        _log('Raw message: $line');
      }
    }
  }

  /// Handle socket errors
  void _handleError(dynamic error) {
    _log('ERROR: Socket error: $error');
    disconnect();
  }

  /// Handle socket close
  void _handleDone() {
    _log('Socket connection closed by daemon');
    disconnect();
  }

  /// Get platform-specific socket path
  String _getSocketPath() {
    if (Platform.isMacOS) {
      // macOS: ~/Library/Application Support/Secretariat/secretariat.sock
      final home = Platform.environment['HOME'];
      return '$home/Library/Application Support/Secretariat/secretariat.sock';
    } else if (Platform.isLinux) {
      // Linux: ~/.local/share/secretariat/secretariat.sock
      final home = Platform.environment['HOME'];
      return '$home/.local/share/secretariat/secretariat.sock';
    } else if (Platform.isWindows) {
      // Windows is not yet supported
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
}

/// Exception thrown when daemon returns an error
class DaemonException implements Exception {
  final String message;

  DaemonException(this.message);

  @override
  String toString() => 'DaemonException: $message';
}
