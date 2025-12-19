// F215-F220: Dart SDK for Secretariat
//
// Features:
// - F215: Create sdk-dart/lib/secretariat.dart file
// - F216: Define Secretariat class
// - F217: Add Socket? _socket private field
// - F218: Implement Future<String> get(String key) async method
// - F219: Connect to Unix socket at fixed path
// - F220: Send JSON-RPC request for secret.get

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// F216: Secretariat client class
///
/// Lightweight Dart SDK for communicating with the Secretariat daemon.
///
/// This SDK provides a simple async interface for retrieving secrets from
/// the local Secretariat daemon via Unix domain socket (macOS/Linux) or
/// named pipe (Windows).
///
/// Example usage:
/// ```dart
/// import 'package:secretariat/secretariat.dart';
///
/// final client = Secretariat();
/// final apiKey = await client.get('OPENAI_API_KEY');
/// print('API Key: $apiKey');
/// ```
class Secretariat {
  /// F217: Socket connection to daemon
  Socket? _socket;

  /// Path to Unix domain socket (macOS/Linux)
  static const String _defaultSocketPath = '/tmp/secretariat.sock';

  /// Named pipe path (Windows)
  static const String _defaultPipePath = r'\\.\pipe\secretariat';

  /// Custom socket/pipe path (optional)
  final String? socketPath;

  /// Request timeout duration
  final Duration timeout;

  /// Request ID counter for JSON-RPC
  int _requestId = 0;

  /// Create a new Secretariat client
  ///
  /// [socketPath] - Optional custom path to Unix socket or named pipe
  /// [timeout] - Request timeout (default: 5 seconds)
  Secretariat({
    this.socketPath,
    this.timeout = const Duration(seconds: 5),
  });

  /// F219: Get the socket path based on platform
  String get _socketPath {
    if (socketPath != null) return socketPath!;

    // Use platform-specific default path
    if (Platform.isWindows) {
      return _defaultPipePath;
    } else {
      return _defaultSocketPath;
    }
  }

  /// F219: Connect to the daemon Unix socket
  Future<void> _connect() async {
    if (_socket != null) return;

    try {
      // Connect to Unix domain socket or named pipe
      _socket = await Socket.connect(
        InternetAddress(_socketPath, type: InternetAddressType.unix),
        0,
        timeout: timeout,
      );
    } catch (e) {
      throw SecretariatException(
        'Failed to connect to Secretariat daemon at $_socketPath: $e',
      );
    }
  }

  /// F220: Send JSON-RPC request to daemon
  Future<Map<String, dynamic>> _sendRequest(
    String method,
    Map<String, dynamic> params,
  ) async {
    await _connect();

    final requestId = ++_requestId;

    // F220: Build JSON-RPC 2.0 request
    final request = {
      'jsonrpc': '2.0',
      'id': requestId,
      'method': method,
      'params': params,
    };

    final requestJson = jsonEncode(request);

    // Send request
    _socket!.write('$requestJson\n');
    await _socket!.flush();

    // Read response
    final completer = Completer<Map<String, dynamic>>();
    final responseBuffer = StringBuffer();

    _socket!.listen(
      (data) {
        responseBuffer.write(utf8.decode(data));
        final responseStr = responseBuffer.toString();

        // Check if we have a complete JSON response (ends with newline)
        if (responseStr.endsWith('\n')) {
          try {
            final response = jsonDecode(responseStr.trim()) as Map<String, dynamic>;

            // Validate response
            if (response['id'] != requestId) {
              completer.completeError(
                SecretariatException('Response ID mismatch'),
              );
              return;
            }

            if (response.containsKey('error')) {
              final error = response['error'] as Map<String, dynamic>;
              completer.completeError(
                SecretariatException(
                  error['message'] as String? ?? 'Unknown error',
                  code: error['code'] as int?,
                ),
              );
              return;
            }

            completer.complete(response);
          } catch (e) {
            completer.completeError(
              SecretariatException('Failed to parse response: $e'),
            );
          }
        }
      },
      onError: (error) {
        completer.completeError(
          SecretariatException('Socket error: $error'),
        );
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(
            SecretariatException('Connection closed unexpectedly'),
          );
        }
      },
    );

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        throw SecretariatException('Request timed out');
      },
    );
  }

  /// F218: Get secret value by key
  ///
  /// Retrieves the decrypted value of a secret from the daemon.
  ///
  /// [key] - Secret name/key (e.g., 'OPENAI_API_KEY')
  ///
  /// Returns the secret value as a String.
  ///
  /// Throws [SecretariatException] if:
  /// - Cannot connect to daemon
  /// - Secret not found
  /// - Permission denied
  /// - Network/communication error
  ///
  /// Example:
  /// ```dart
  /// final client = Secretariat();
  /// try {
  ///   final apiKey = await client.get('OPENAI_API_KEY');
  ///   print('Retrieved: $apiKey');
  /// } catch (e) {
  ///   print('Error: $e');
  /// }
  /// ```
  Future<String> get(String key) async {
    // F220: Send secret.get JSON-RPC request
    final response = await _sendRequest('secret.get', {'key': key});

    // Extract result from response
    if (!response.containsKey('result')) {
      throw SecretariatException('Invalid response: missing result');
    }

    final result = response['result'] as Map<String, dynamic>;

    if (!result.containsKey('value')) {
      throw SecretariatException('Invalid response: missing value');
    }

    return result['value'] as String;
  }

  /// Get multiple secrets at once
  ///
  /// [keys] - List of secret names to retrieve
  ///
  /// Returns a Map of key -> value pairs.
  ///
  /// Example:
  /// ```dart
  /// final secrets = await client.getMany([
  ///   'OPENAI_API_KEY',
  ///   'DATABASE_URL',
  /// ]);
  /// print(secrets['OPENAI_API_KEY']);
  /// ```
  Future<Map<String, String>> getMany(List<String> keys) async {
    final results = <String, String>{};

    for (final key in keys) {
      try {
        results[key] = await get(key);
      } catch (e) {
        // Continue on error, return partial results
        rethrow;
      }
    }

    return results;
  }

  /// List all available secret names
  ///
  /// Returns a list of secret names (not values).
  ///
  /// Example:
  /// ```dart
  /// final names = await client.list();
  /// print('Available secrets: $names');
  /// ```
  Future<List<String>> list() async {
    final response = await _sendRequest('secret.list', {});

    if (!response.containsKey('result')) {
      throw SecretariatException('Invalid response: missing result');
    }

    final result = response['result'] as Map<String, dynamic>;

    if (!result.containsKey('secrets')) {
      throw SecretariatException('Invalid response: missing secrets');
    }

    final secrets = result['secrets'] as List<dynamic>;
    return secrets.map((s) => s as String).toList();
  }

  /// Close the connection to the daemon
  ///
  /// Call this when you're done using the client to free resources.
  Future<void> close() async {
    await _socket?.close();
    _socket = null;
  }
}

/// Exception thrown by Secretariat SDK
class SecretariatException implements Exception {
  /// Error message
  final String message;

  /// Optional error code
  final int? code;

  SecretariatException(this.message, {this.code});

  @override
  String toString() {
    if (code != null) {
      return 'SecretariatException($code): $message';
    }
    return 'SecretariatException: $message';
  }
}
