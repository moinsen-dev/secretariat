// F151-F156: VaultProvider for state management
// F188: Added loadApplications() method
//
// Features:
// - F151: Create lib/providers/vault_provider.dart file
// - F152: Define VaultProvider extends ChangeNotifier
// - F153: Add bool isLocked field with getter
// - F154: Add List<Secret> secrets field with getter
// - F155: Implement loadSecrets() async method that fetches from daemon
// - F156: Call notifyListeners() after state changes
// - F188: Fetch applications from daemon

import 'package:flutter/foundation.dart';
import '../models/secret.dart';
import '../models/application.dart';
import '../services/daemon_client.dart';

/// F152: Define VaultProvider extends ChangeNotifier
///
/// Provider for managing vault state including secrets and lock status.
///
/// This provider uses DaemonClient to communicate with the daemon
/// and exposes the vault state to the UI via ChangeNotifier.
///
/// Example usage:
/// ```dart
/// // In main.dart
/// ChangeNotifierProvider(
///   create: (_) => VaultProvider(),
///   child: MyApp(),
/// )
///
/// // In a widget
/// final vaultProvider = Provider.of&lt;VaultProvider&gt;(context);
/// await vaultProvider.loadSecrets();
/// ```
class VaultProvider extends ChangeNotifier {
  /// F153: Add bool isLocked field with getter
  ///
  /// Whether the vault is currently locked
  bool _isLocked = true;

  /// F154: Add `List<Secret>` secrets field with getter
  ///
  /// List of all secrets in the vault
  List<Secret> _secrets = [];

  /// F188: List of all registered applications
  List<Application> _applications = [];

  /// Daemon client for communication
  final DaemonClient _daemonClient = DaemonClient();

  /// Whether the provider is currently loading data
  bool _isLoading = false;

  /// Error message if the last operation failed
  String? _errorMessage;

  /// F153: Getter for isLocked
  bool get isLocked => _isLocked;

  /// F154: Getter for secrets
  List<Secret> get secrets => List.unmodifiable(_secrets);

  /// F188: Getter for applications
  List<Application> get applications => List.unmodifiable(_applications);

  /// Getter for loading state
  bool get isLoading => _isLoading;

  /// Getter for error message
  String? get errorMessage => _errorMessage;

  /// Whether the daemon client is connected
  bool get isConnected => _daemonClient.isConnected;

  /// Connect to the daemon
  ///
  /// Must be called before any other operations.
  ///
  /// Example:
  /// ```dart
  /// final provider = VaultProvider();
  /// await provider.connect();
  /// ```
  Future<void> connect() async {
    try {
      _errorMessage = null;
      await _daemonClient.connect();
      // F156: Call notifyListeners() after state changes
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to connect to daemon: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Disconnect from the daemon
  Future<void> disconnect() async {
    await _daemonClient.disconnect();
    _secrets = [];
    _isLocked = true;
    // F156: Call notifyListeners() after state changes
    notifyListeners();
  }

  /// F155: Implement loadSecrets() async method that fetches from daemon
  ///
  /// Loads all secrets from the daemon.
  ///
  /// This method:
  /// 1. Connects to the daemon if not already connected
  /// 2. Fetches the list of secrets
  /// 3. Updates the internal state
  /// 4. Notifies listeners (F156)
  ///
  /// Example:
  /// ```dart
  /// final provider = Provider.of<VaultProvider>(context);
  /// await provider.loadSecrets();
  /// ```
  Future<void> loadSecrets() async {
    if (_isLoading) return; // Prevent concurrent loads

    _isLoading = true;
    _errorMessage = null;
    // F156: Call notifyListeners() after state changes
    notifyListeners();

    try {
      // Ensure we're connected
      if (!_daemonClient.isConnected) {
        await _daemonClient.connect();
      }

      // F155: Fetch secrets from daemon
      final secretsJson = await _daemonClient.listSecrets();

      // Convert JSON to Secret objects
      _secrets = secretsJson.map((json) => Secret.fromJson(json)).toList();

      // Vault is unlocked if we can successfully load secrets
      _isLocked = false;

      _isLoading = false;
      // F156: Call notifyListeners() after state changes
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load secrets: $e';
      // F156: Call notifyListeners() after state changes
      notifyListeners();
      rethrow;
    }
  }

  /// Refresh secrets from the daemon
  ///
  /// Same as loadSecrets but explicitly named for clarity.
  Future<void> refreshSecrets() async {
    await loadSecrets();
  }

  /// Get a specific secret by name
  ///
  /// Example:
  /// ```dart
  /// final secret = await provider.getSecret('OPENAI_API_KEY');
  /// ```
  Future<Secret?> getSecret(String name) async {
    try {
      _errorMessage = null;

      if (!_daemonClient.isConnected) {
        await _daemonClient.connect();
      }

      final secretJson = await _daemonClient.getSecret(name);
      final secret = Secret.fromJson(secretJson);

      // Update the secret in the list if it exists
      final index = _secrets.indexWhere((s) => s.name == name);
      if (index >= 0) {
        _secrets[index] = secret;
      } else {
        _secrets.add(secret);
      }

      // F156: Call notifyListeners() after state changes
      notifyListeners();

      return secret;
    } catch (e) {
      _errorMessage = 'Failed to get secret: $e';
      notifyListeners();
      return null;
    }
  }

  /// Add or update a secret
  ///
  /// Example:
  /// ```dart
  /// await provider.setSecret('OPENAI_API_KEY', 'sk-abc123...', provider: 'openai');
  /// ```
  Future<void> setSecret(
    String name,
    String value, {
    String? provider,
    String? environment,
    String? notes,
  }) async {
    try {
      _errorMessage = null;

      if (!_daemonClient.isConnected) {
        await _daemonClient.connect();
      }

      await _daemonClient.setSecret(
        name,
        value,
        provider: provider,
        environment: environment,
        notes: notes,
      );

      // Reload secrets to get updated list
      await loadSecrets();
    } catch (e) {
      _errorMessage = 'Failed to set secret: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Delete a secret
  ///
  /// Example:
  /// ```dart
  /// await provider.deleteSecret('OPENAI_API_KEY');
  /// ```
  Future<void> deleteSecret(String name) async {
    try {
      _errorMessage = null;

      if (!_daemonClient.isConnected) {
        await _daemonClient.connect();
      }

      await _daemonClient.deleteSecret(name);

      // Remove from local list
      _secrets.removeWhere((s) => s.name == name);

      // F156: Call notifyListeners() after state changes
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to delete secret: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Lock the vault
  ///
  /// Clears secrets from memory and marks vault as locked.
  Future<void> lock() async {
    _secrets = [];
    _isLocked = true;
    await disconnect();
    // F156: Call notifyListeners() after state changes
    notifyListeners();
  }

  /// Unlock the vault
  ///
  /// Attempts to load secrets, which will unlock the vault if successful.
  Future<void> unlock() async {
    await loadSecrets();
  }

  /// Filter secrets by search query
  ///
  /// Returns a list of secrets matching the query (by name, provider, or notes).
  ///
  /// Example:
  /// ```dart
  /// final filtered = provider.filterSecrets('openai');
  /// ```
  List<Secret> filterSecrets(String query) {
    if (query.isEmpty) {
      return secrets;
    }

    final lowerQuery = query.toLowerCase();
    return _secrets.where((secret) {
      return secret.name.toLowerCase().contains(lowerQuery) ||
          (secret.provider?.toLowerCase().contains(lowerQuery) ?? false) ||
          (secret.notes?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// F188: Load applications from daemon
  ///
  /// Fetches all registered applications and their permissions.
  ///
  /// Example:
  /// ```dart
  /// final provider = Provider.of<VaultProvider>(context);
  /// await provider.loadApplications();
  /// ```
  Future<void> loadApplications() async {
    try {
      _errorMessage = null;

      // Ensure we're connected
      if (!_daemonClient.isConnected) {
        await _daemonClient.connect();
      }

      // Fetch applications from daemon
      final appsJson = await _daemonClient.listApplications();

      // Convert JSON to Application objects
      _applications = appsJson.map((json) => Application.fromJson(json)).toList();

      // Notify listeners
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load applications: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Revoke an application's permission to a secret
  ///
  /// Example:
  /// ```dart
  /// await provider.revokePermission('app-id', 'secret-id');
  /// ```
  Future<void> revokePermission(String appId, String secretId) async {
    try {
      _errorMessage = null;

      if (!_daemonClient.isConnected) {
        await _daemonClient.connect();
      }

      await _daemonClient.revokePermission(appId, secretId);

      // Reload applications to reflect the change
      await loadApplications();
    } catch (e) {
      _errorMessage = 'Failed to revoke permission: $e';
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _daemonClient.disconnect();
    super.dispose();
  }
}
