// F143-F145: DaemonClient for Flutter app
//
// Features:
// - F143: Create lib/services/daemon_client.dart file
// - F144: Define DaemonClient class with Socket? _socket field
// - F145: Implement connect() async method using Socket.connect to Unix socket

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'logger_service.dart';

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

  /// Log a message using centralized logging
  void _log(String message) {
    Log.daemon(message);
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
    await sendRequest('app.revoke', {
      'app_id': appId,
      'secret_name': secretName,
    });
  }

  /// Grant an application access to a secret
  ///
  /// Example:
  /// ```dart
  /// await client.grantPermission('app-id-123', 'OPENAI_API_KEY');
  /// ```
  Future<void> grantPermission(String appId, String secretName) async {
    await sendRequest('app.authorize', {
      'app_id': appId,
      'secret_name': secretName,
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
  /// If [storeForBiometric] is true, the master key will be stored in the
  /// system keychain for future Touch ID unlock.
  ///
  /// Example:
  /// ```dart
  /// await client.unlockVault('my-password', storeForBiometric: true);
  /// ```
  Future<Map<String, dynamic>> unlockVault(
    String password, {
    bool storeForBiometric = false,
  }) async {
    return await sendRequest('vault.unlock', {
      'password': password,
      'store_for_biometric': storeForBiometric,
    });
  }

  /// Unlock the vault using biometric authentication (Touch ID)
  ///
  /// Requires that biometric unlock was previously enabled by calling
  /// [unlockVault] with [storeForBiometric] set to true.
  ///
  /// Example:
  /// ```dart
  /// await client.unlockVaultBiometric();
  /// ```
  Future<Map<String, dynamic>> unlockVaultBiometric() async {
    return await sendRequest('vault.unlock_biometric', {});
  }

  /// Check if biometric unlock is available and enabled
  ///
  /// Returns status with:
  /// - available: true if Touch ID hardware is present
  /// - enabled: true if a master key is stored in keychain
  ///
  /// Example:
  /// ```dart
  /// final status = await client.getBiometricStatus();
  /// if (status['available'] && status['enabled']) {
  ///   await client.unlockVaultBiometric();
  /// }
  /// ```
  Future<Map<String, dynamic>> getBiometricStatus() async {
    return await sendRequest('vault.biometric_status', {});
  }

  /// Disable biometric unlock by removing the stored master key
  ///
  /// Example:
  /// ```dart
  /// await client.disableBiometric();
  /// ```
  Future<void> disableBiometric() async {
    await sendRequest('vault.biometric_disable', {});
  }

  /// Get audit log entries
  ///
  /// Example:
  /// ```dart
  /// final entries = await client.getAuditLog(limit: 50);
  /// ```
  Future<List<Map<String, dynamic>>> getAuditLog({
    int limit = 100,
    String? appId,
  }) async {
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
  Future<Map<String, dynamic>> rotateSecret(
    String name,
    String newValue,
  ) async {
    return await sendRequest('secret.rotate', {
      'name': name,
      'value': newValue,
    });
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
  Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    return await sendRequest('vault.change_password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  // ============================================================
  // Ephemeral Secrets
  // ============================================================

  /// Set a secret with a time-to-live (ephemeral secret)
  ///
  /// The secret will be automatically deleted after [ttlSeconds].
  ///
  /// Example:
  /// ```dart
  /// await client.setSecretWithTtl('SESSION_TOKEN', 'abc123', ttlSeconds: 3600);
  /// ```
  Future<void> setSecretWithTtl(
    String name,
    String value, {
    required int ttlSeconds,
    String? provider,
    String? environment,
    String? notes,
  }) async {
    final params = {
      'name': name,
      'value': value,
      'ttl': ttlSeconds,
      if (provider != null) 'provider': provider,
      if (environment != null) 'environment': environment,
      if (notes != null) 'notes': notes,
    };

    await sendRequest('secret.set', params);
  }

  /// Get secrets that are expiring soon
  ///
  /// Returns secrets expiring within [withinMinutes] minutes.
  ///
  /// Example:
  /// ```dart
  /// final expiring = await client.getExpiringSecrets(withinMinutes: 60);
  /// ```
  Future<List<Map<String, dynamic>>> getExpiringSecrets({
    int withinMinutes = 60,
  }) async {
    final result = await sendRequest('secret.expiring', {
      'within_minutes': withinMinutes,
    });
    return List<Map<String, dynamic>>.from(result['secrets'] as List);
  }

  /// Clean up expired ephemeral secrets
  ///
  /// Returns the count of cleaned up secrets.
  ///
  /// Example:
  /// ```dart
  /// final result = await client.cleanupExpiredSecrets();
  /// // result = {'cleaned': 3}
  /// ```
  Future<Map<String, dynamic>> cleanupExpiredSecrets() async {
    return await sendRequest('secret.cleanup', {});
  }

  // ============================================================
  // Secret Version History & Rollback
  // ============================================================

  /// Get version history for a secret
  ///
  /// Returns version number, whether a previous version exists,
  /// and the last rotation timestamp.
  ///
  /// Example:
  /// ```dart
  /// final history = await client.getSecretHistory('OPENAI_API_KEY');
  /// // history = {'name': 'OPENAI_API_KEY', 'version': 3, 'has_previous': true, 'rotated_at': '...'}
  /// ```
  Future<Map<String, dynamic>> getSecretHistory(String name) async {
    return await sendRequest('secret.history', {'name': name});
  }

  /// Rollback a secret to its previous version
  ///
  /// Returns the new (rolled back) version number.
  ///
  /// Example:
  /// ```dart
  /// final result = await client.rollbackSecret('OPENAI_API_KEY');
  /// // result = {'name': 'OPENAI_API_KEY', 'version': 2, 'status': 'rolled_back'}
  /// ```
  Future<Map<String, dynamic>> rollbackSecret(String name) async {
    return await sendRequest('secret.rollback', {'name': name});
  }

  // ============================================================
  // Rotation Reminders
  // ============================================================

  /// Get secrets that need rotation
  ///
  /// Returns secrets that haven't been rotated within [daysSinceRotation] days.
  ///
  /// Example:
  /// ```dart
  /// final stale = await client.getRotationReminders(daysSinceRotation: 90);
  /// ```
  Future<List<String>> getRotationReminders({int daysSinceRotation = 90}) async {
    final result = await sendRequest('secret.rotation_reminders', {
      'days': daysSinceRotation,
    });
    return List<String>.from(result['secrets'] as List);
  }

  // ============================================================
  // Emergency Controls
  // ============================================================

  /// Emergency panic button - locks vault and revokes all access
  ///
  /// This is a security kill-switch that:
  /// 1. Locks the vault immediately
  /// 2. Revokes all application permissions
  /// 3. Logs the emergency action
  ///
  /// Example:
  /// ```dart
  /// await client.panic();
  /// ```
  Future<Map<String, dynamic>> panic() async {
    return await sendRequest('vault.panic', {});
  }

  // ============================================================
  // AI Agent Access Control
  // ============================================================

  /// List all registered AI agents
  ///
  /// Example:
  /// ```dart
  /// final agents = await client.listAgents();
  /// ```
  Future<List<Map<String, dynamic>>> listAgents() async {
    final result = await sendRequest('agent.list', {});
    return List<Map<String, dynamic>>.from(result['agents'] as List);
  }

  /// Register a new AI agent
  ///
  /// Example:
  /// ```dart
  /// final result = await client.registerAgent('claude-code', description: 'Claude AI coding assistant');
  /// ```
  Future<Map<String, dynamic>> registerAgent(
    String agentId, {
    String? description,
  }) async {
    return await sendRequest('agent.register', {
      'agent_id': agentId,
      if (description != null) 'description': description,
    });
  }

  /// Grant an AI agent access to a secret
  ///
  /// Example:
  /// ```dart
  /// await client.grantAgentAccess('claude-code', 'OPENAI_API_KEY');
  /// ```
  Future<void> grantAgentAccess(String agentId, String secretName) async {
    await sendRequest('agent.grant', {
      'agent_id': agentId,
      'secret_name': secretName,
    });
  }

  /// Revoke an AI agent's access to a secret
  ///
  /// Example:
  /// ```dart
  /// await client.revokeAgentAccess('claude-code', 'OPENAI_API_KEY');
  /// ```
  Future<void> revokeAgentAccess(String agentId, String secretName) async {
    await sendRequest('agent.revoke', {
      'agent_id': agentId,
      'secret_name': secretName,
    });
  }

  /// Revoke all access for an AI agent
  ///
  /// Example:
  /// ```dart
  /// await client.revokeAllAgentAccess('claude-code');
  /// ```
  Future<void> revokeAllAgentAccess(String agentId) async {
    await sendRequest('agent.revoke_all', {'agent_id': agentId});
  }

  /// Get permissions for an AI agent
  ///
  /// Example:
  /// ```dart
  /// final permissions = await client.getAgentPermissions('claude-code');
  /// ```
  Future<List<String>> getAgentPermissions(String agentId) async {
    final result = await sendRequest('agent.permissions', {
      'agent_id': agentId,
    });
    return List<String>.from(result['secrets'] as List);
  }

  // ============================================================
  // Environment Management
  // ============================================================

  /// List all environments
  ///
  /// Example:
  /// ```dart
  /// final environments = await client.listEnvironments();
  /// // environments = ['default', 'dev', 'staging', 'prod']
  /// ```
  Future<List<String>> listEnvironments() async {
    final result = await sendRequest('environment.list', {});
    return List<String>.from(result['environments'] as List);
  }

  /// List secrets for a specific environment
  ///
  /// Example:
  /// ```dart
  /// final secrets = await client.listSecretsForEnvironment('prod');
  /// ```
  Future<List<Map<String, dynamic>>> listSecretsForEnvironment(
    String environment,
  ) async {
    final result = await sendRequest('secret.list', {
      'environment': environment,
    });
    return List<Map<String, dynamic>>.from(result['secrets'] as List);
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
