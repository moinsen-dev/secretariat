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

  /// Stream controller for incoming messages
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
      return; // Already connected
    }

    // Get socket path based on platform
    final socketPath = _getSocketPath();

    try {
      // F145: Connect to Unix socket
      final address = InternetAddress(socketPath, type: InternetAddressType.unix);
      _socket = await Socket.connect(address, 0);

      // Initialize message stream
      _messageController = StreamController<Map<String, dynamic>>();

      // Listen for incoming data
      _socketSubscription = _socket!.listen(
        _handleData,
        onError: _handleError,
        onDone: _handleDone,
      );
    } catch (e) {
      throw SocketException(
        'Failed to connect to daemon at $socketPath: $e',
      );
    }
  }

  /// Disconnect from the daemon
  Future<void> disconnect() async {
    await _socketSubscription?.cancel();
    await _socket?.close();
    await _messageController?.close();

    _socketSubscription = null;
    _socket = null;
    _messageController = null;
    _buffer = '';
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
      throw StateError('Not connected to daemon. Call connect() first.');
    }

    // Build JSON-RPC request
    final request = {
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
      'id': DateTime.now().millisecondsSinceEpoch,
    };

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
          completer.completeError(
            DaemonException(message['error']['message'] as String),
          );
        } else {
          completer.complete(message['result'] as Map<String, dynamic>);
        }
      }
    });

    // Clean up subscription after response
    final result = await completer.future;
    await subscription.cancel();
    return result;
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
    return await sendRequest('secret.get', {'name': name});
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
    return List<Map<String, dynamic>>.from(result['applications'] as List);
  }

  /// Revoke an application's access to a secret
  ///
  /// Example:
  /// ```dart
  /// await client.revokePermission('app-id-123', 'secret-id-456');
  /// ```
  Future<void> revokePermission(String appId, String secretId) async {
    await sendRequest('app.revoke', {
      'app_id': appId,
      'secret_id': secretId,
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
        _messageController?.add(message);
      } catch (e) {
        debugPrint('Failed to parse JSON message: $e');
      }
    }
  }

  /// Handle socket errors
  void _handleError(dynamic error) {
    debugPrint('Socket error: $error');
    disconnect();
  }

  /// Handle socket close
  void _handleDone() {
    debugPrint('Socket closed');
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
      // Windows: Named pipe (not implemented yet)
      throw UnsupportedError('Windows named pipes not yet implemented');
    } else {
      throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
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
