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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/secret.dart';
import '../models/application.dart';
import '../models/audit_entry.dart';
import '../services/daemon_client.dart';
import '../services/daemon_manager.dart';
import '../services/local_vault.dart';
import '../services/native_crypto.dart';
import '../services/platform_paths.dart';

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

  /// List of audit log entries
  List<AuditEntry> _auditEntries = [];

  /// Daemon client for communication
  final DaemonClient _daemonClient = DaemonClient();

  /// Daemon manager for lifecycle control
  final DaemonManager _daemonManager = DaemonManager.instance;

  /// Whether the provider is currently loading data
  bool _isLoading = false;

  /// Error message if the last operation failed
  String? _errorMessage;

  /// Current daemon status
  DaemonStatus _daemonStatus = DaemonStatus.unknown;

  /// Re-entrant guard for connect()
  bool _connecting = false;

  // ---- iOS backend (no daemon) ----
  //
  // iOS has no `secd`, so the app operates directly on the E2E-encrypted vault
  // document via the shared Rust crypto (FFI). The same master password + salt
  // derive the same key as the daemon, so iOS reads/writes the very vault the
  // Macs sync. Storage is a local file in the app's Documents dir; iCloud sync
  // layers on top when available.
  bool get _useLocal => Platform.isIOS;
  LocalVault? _local;
  String? _localPath;

  /// F153: Getter for isLocked
  bool get isLocked => _isLocked;

  /// F154: Getter for secrets
  List<Secret> get secrets => List.unmodifiable(_secrets);

  /// F188: Getter for applications
  List<Application> get applications => List.unmodifiable(_applications);

  /// Getter for audit entries
  List<AuditEntry> get auditEntries => List.unmodifiable(_auditEntries);

  /// Getter for loading state
  bool get isLoading => _isLoading;

  /// Getter for error message
  String? get errorMessage => _errorMessage;

  /// Whether the daemon client is connected
  bool get isConnected => _daemonClient.isConnected;

  /// Current daemon status
  DaemonStatus get daemonStatus => _daemonStatus;

  /// Whether the daemon is running
  bool get isDaemonRunning => _daemonStatus == DaemonStatus.running;

  /// Connect to the daemon
  ///
  /// Must be called before any other operations.
  /// If autoStart is true (default), will attempt to start the daemon if not running.
  ///
  /// Example:
  /// ```dart
  /// final provider = VaultProvider();
  /// await provider.connect();
  /// ```
  Future<void> connect({bool autoStart = true}) async {
    if (_connecting) {
      debugPrint('[VaultProvider] Already connecting, skipping...');
      return;
    }
    _connecting = true;

    try {
      _errorMessage = null;

      // Check daemon status first
      _daemonStatus = await _daemonManager.checkStatus();
      notifyListeners();

      // Auto-start daemon if not running
      if (_daemonStatus != DaemonStatus.running && autoStart) {
        debugPrint(
          '[VaultProvider] Daemon not running, attempting auto-start...',
        );
        final started = await _daemonManager.ensureRunning();
        if (started) {
          _daemonStatus = DaemonStatus.running;
          debugPrint('[VaultProvider] Daemon started successfully');
        } else {
          _daemonStatus = DaemonStatus.stopped;
          _errorMessage = 'Failed to start daemon';
          notifyListeners();
          _connecting = false;
          throw StateError('Failed to start daemon. Please start it manually.');
        }
      }

      await _daemonClient.connect();
      // F156: Call notifyListeners() after state changes
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to connect to daemon: $e';
      debugPrint('[VaultProvider] Connect error: $e');
      notifyListeners();
      rethrow;
    } finally {
      _connecting = false;
    }
  }

  /// iOS only: open the FFI crypto and load the local vault document (pulling
  /// from iCloud first if a synced vault exists, else starting empty). Call
  /// this once at startup instead of [connect].
  Future<void> initLocal() async {
    if (!_useLocal) return;
    try {
      final crypto = NativeCrypto.open();
      final dir = await getApplicationDocumentsDirectory();
      _localPath = '${dir.path}/secretariat-vault.json';
      final f = File(_localPath!);
      if (await f.exists()) {
        _local = LocalVault.fromJson(crypto, await f.readAsString());
      } else {
        // First launch on this device: adopt an existing iCloud vault if one
        // is there (so we share the Macs' secrets), otherwise start fresh.
        String? remote;
        try {
          if (await PlatformPaths.icloudAvailable()) {
            remote = await PlatformPaths.icloudRead();
          }
        } catch (_) {}
        _local = (remote != null && remote.trim().isNotEmpty)
            ? LocalVault.fromJson(crypto, remote)
            : LocalVault.empty(crypto);
      }
      _isLocked = !_local!.isUnlocked;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to open local vault: $e';
      debugPrint('[VaultProvider] initLocal error: $e');
      notifyListeners();
    }
  }

  /// iOS only: persist the in-memory vault document to the local file and push
  /// to iCloud best-effort (no-op if iCloud is unavailable).
  Future<void> _persistLocal() async {
    final lv = _local;
    final p = _localPath;
    if (lv == null || p == null) return;
    final json = lv.toJson();
    await File(p).writeAsString(json);
    try {
      if (await PlatformPaths.icloudAvailable()) {
        await PlatformPaths.icloudWrite(json);
      }
    } catch (e) {
      debugPrint('[VaultProvider] iCloud push skipped: $e');
    }
  }

  /// Check daemon status
  ///
  /// Updates the internal daemon status and returns it.
  Future<DaemonStatus> checkDaemonStatus() async {
    _daemonStatus = await _daemonManager.checkStatus();
    notifyListeners();
    return _daemonStatus;
  }

  /// Start the daemon manually
  ///
  /// Returns true if daemon started successfully.
  Future<bool> startDaemon() async {
    _daemonStatus = DaemonStatus.starting;
    notifyListeners();

    final success = await _daemonManager.startDaemon();
    _daemonStatus = success ? DaemonStatus.running : DaemonStatus.stopped;
    notifyListeners();

    return success;
  }

  /// Stop the daemon
  ///
  /// Returns true if daemon stopped successfully.
  Future<bool> stopDaemon() async {
    final success = await _daemonManager.stopDaemon();
    if (success) {
      _daemonStatus = DaemonStatus.stopped;
      await disconnect();
    }
    return success;
  }

  /// Check if LaunchAgent is installed (macOS auto-start)
  bool get isAutoStartEnabled => _daemonManager.isLaunchAgentInstalled();

  /// Enable auto-start (installs LaunchAgent on macOS)
  Future<bool> enableAutoStart() async {
    return await _daemonManager.installLaunchAgent();
  }

  /// Disable auto-start (uninstalls LaunchAgent on macOS)
  Future<bool> disableAutoStart() async {
    return await _daemonManager.uninstallLaunchAgent();
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
    if (_useLocal) {
      final lv = _local;
      if (lv == null) return;
      _secrets = lv.listSecretsJson().map((j) => Secret.fromJson(j)).toList();
      _isLocked = !lv.isUnlocked;
      notifyListeners();
      return;
    }
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
      // Also log it: a caught error shown only in the UI is invisible to
      // the VM-service error stream and to log-based tooling otherwise.
      debugPrint('[VaultProvider] Failed to load secrets: $e');
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
    if (_useLocal) {
      try {
        final value = _local!.getValue(name);
        final meta = _local!.listSecretsJson().firstWhere(
          (j) => j['name'] == name,
          orElse: () => {'id': name, 'name': name},
        );
        final secret = Secret.fromJson({...meta, 'value': value});
        final index = _secrets.indexWhere((s) => s.name == name);
        if (index >= 0) {
          _secrets[index] = secret;
        } else {
          _secrets.add(secret);
        }
        notifyListeners();
        return secret;
      } catch (e) {
        _errorMessage = 'Failed to get secret: $e';
        debugPrint('[VaultProvider] Failed to get secret "$name": $e');
        notifyListeners();
        return null;
      }
    }
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
    } catch (e, st) {
      _errorMessage = 'Failed to get secret: $e';
      debugPrint('[VaultProvider] Failed to get secret "$name": $e\n$st');
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
    if (_useLocal) {
      try {
        _local!.setValue(name, value, provider: provider);
        await _persistLocal();
        await loadSecrets();
        return;
      } catch (e) {
        _errorMessage = 'Failed to set secret: $e';
        debugPrint('[VaultProvider] Failed to set secret "$name": $e');
        notifyListeners();
        rethrow;
      }
    }
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
      // Push the change to iCloud (fire-and-forget).
      unawaited(syncWithICloud());
    } catch (e, st) {
      _errorMessage = 'Failed to set secret: $e';
      debugPrint('[VaultProvider] Failed to set secret "$name": $e\n$st');
      notifyListeners();
      rethrow;
    }
  }

  // ---- E2E-encrypted iCloud sync ----

  Timer? _syncTimer;
  StreamSubscription<dynamic>? _syncEventSub;
  bool _syncing = false;

  /// Run one iCloud sync cycle: PULL (merge the cloud file into the local
  /// vault) then PUSH (write the full merged export back). After both, local
  /// and cloud converge by last-write-wins. Only ciphertext crosses iCloud.
  Future<void> syncWithICloud() async {
    if (_syncing) return;
    if (!await PlatformPaths.icloudAvailable()) {
      return;
    }
    _syncing = true;
    try {
      if (!_daemonClient.isConnected) {
        await _daemonClient.connect();
      }

      // PULL
      var applied = 0;
      final remote = await PlatformPaths.icloudRead();
      if (remote != null && remote.trim().isNotEmpty) {
        try {
          final payload = jsonDecode(remote) as Map<String, dynamic>;
          final res = await _daemonClient.syncImport(
            (payload['secrets'] as List?) ?? const [],
            (payload['tombstones'] as List?) ?? const [],
          );
          applied = ((res['applied_secrets'] as int?) ?? 0) +
              ((res['applied_tombstones'] as int?) ?? 0);
          debugPrint('[Sync] pull applied=$applied');
        } catch (e) {
          debugPrint('[Sync] pull failed: $e');
        }
      }

      // PUSH — only write if the merged export differs from what's already
      // in iCloud, so our own write doesn't re-trigger the file-change watcher.
      final exported = await _daemonClient.syncExport();
      final newContent = jsonEncode(exported);
      if (newContent != remote) {
        final ok = await PlatformPaths.icloudWrite(newContent);
        debugPrint('[Sync] push ${ok ? "ok" : "failed"}');
      } else {
        debugPrint('[Sync] push skipped (no change)');
      }

      // Refresh the UI if the pull changed local state.
      if (applied > 0 && !_isLocked) {
        await loadSecrets();
      }
    } catch (e) {
      debugPrint('[Sync] cycle error: $e');
    } finally {
      _syncing = false;
    }
  }

  /// Start periodic background sync (and run one cycle immediately).
  void startAutoSync({Duration interval = const Duration(seconds: 30)}) {
    // iOS persists + pushes to iCloud on each write (_persistLocal); there is
    // no daemon to drive a sync loop, so skip the periodic timer for now.
    if (_useLocal) return;
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) => syncWithICloud());
    // React instantly when another device pushes a change to the iCloud file.
    _syncEventSub ??= PlatformPaths.icloudChanges.listen((_) {
      debugPrint('[Sync] iCloud file changed, syncing now');
      syncWithICloud();
    }, onError: (_) {});
    unawaited(syncWithICloud());
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _syncEventSub?.cancel();
    _syncEventSub = null;
  }

  /// Delete a secret
  ///
  /// Example:
  /// ```dart
  /// await provider.deleteSecret('OPENAI_API_KEY');
  /// ```
  Future<void> deleteSecret(String name) async {
    if (_useLocal) {
      try {
        _local!.delete(name);
        _secrets.removeWhere((s) => s.name == name);
        notifyListeners();
        await _persistLocal();
        return;
      } catch (e) {
        _errorMessage = 'Failed to delete secret: $e';
        notifyListeners();
        rethrow;
      }
    }
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
      // Push the deletion (tombstone) to iCloud (fire-and-forget).
      unawaited(syncWithICloud());
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
    if (_useLocal) {
      _local?.lock();
      _secrets = [];
      _isLocked = true;
      notifyListeners();
      return;
    }
    _secrets = [];
    _isLocked = true;
    await disconnect();
    // F156: Call notifyListeners() after state changes
    notifyListeners();
  }

  /// Get vault status from daemon
  ///
  /// Returns a map with state, secret_count, and app_count.
  Future<Map<String, dynamic>> getVaultStatus() async {
    if (_useLocal) {
      final lv = _local;
      if (lv == null) {
        return {'state': 'uninitialized', 'secret_count': 0, 'app_count': 0};
      }
      _isLocked = !lv.isUnlocked;
      final state = !lv.isInitialized
          ? 'uninitialized'
          : (lv.isUnlocked ? 'unlocked' : 'locked');
      return {
        'state': state,
        'secret_count': lv.listNames().length,
        'app_count': 0,
      };
    }
    try {
      _errorMessage = null;

      if (!_daemonClient.isConnected) {
        await _daemonClient.connect();
      }

      final status = await _daemonClient.getVaultStatus();
      _isLocked = status['state'] == 'locked';
      return status;
    } catch (e) {
      _errorMessage = 'Failed to get vault status: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Unlock the vault with password
  ///
  /// Sends unlock command to daemon then loads secrets.
  Future<void> unlock() async {
    // unlock() requires the password — this is just a routing helper.
    // Use unlockVault(password) from the dialog instead.
    throw StateError(
      'unlock() requires a password. Use unlockVault(password) instead.',
    );
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
    if (_useLocal) {
      // iOS has no daemon and no app-permission registry (that's a host-agent
      // concept). Present an empty list rather than erroring.
      _applications = [];
      notifyListeners();
      return;
    }
    try {
      _errorMessage = null;

      // Ensure we're connected
      if (!_daemonClient.isConnected) {
        await _daemonClient.connect();
      }

      // Fetch applications from daemon
      final appsJson = await _daemonClient.listApplications();

      // Convert JSON to Application objects
      _applications = appsJson
          .map((json) => Application.fromJson(json))
          .toList();

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
  /// await provider.revokePermission('app-id', 'secret-name');
  /// ```
  Future<void> revokePermission(String appId, String secretName) async {
    try {
      _errorMessage = null;

      if (!_daemonClient.isConnected) {
        await _daemonClient.connect();
      }

      await _daemonClient.revokePermission(appId, secretName);

      // Reload applications to reflect the change
      await loadApplications();
    } catch (e) {
      _errorMessage = 'Failed to revoke permission: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Grant an application permission to access a secret
  ///
  /// Example:
  /// ```dart
  /// await provider.grantPermission('app-fingerprint', 'OPENAI_API_KEY');
  /// ```
  Future<void> grantPermission(String appId, String secretName) async {
    try {
      _errorMessage = null;

      if (!_daemonClient.isConnected) {
        await _daemonClient.connect();
      }

      await _daemonClient.grantPermission(appId, secretName);

      // Reload applications to reflect the change
      await loadApplications();
    } catch (e) {
      _errorMessage = 'Failed to grant permission: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Load audit log entries from daemon
  ///
  /// Example:
  /// ```dart
  /// await provider.loadAuditLog(limit: 50);
  /// ```
  Future<void> loadAuditLog({int limit = 100, String? appId}) async {
    if (_useLocal) {
      // No daemon-side audit log on iOS yet.
      _auditEntries = [];
      notifyListeners();
      return;
    }
    try {
      _errorMessage = null;

      if (!_daemonClient.isConnected) {
        await _daemonClient.connect();
      }

      final entriesJson = await _daemonClient.getAuditLog(
        limit: limit,
        appId: appId,
      );

      _auditEntries = entriesJson
          .map((json) => AuditEntry.fromJson(json))
          .toList();

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load audit log: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Lock the vault via daemon
  ///
  /// Sends lock command to daemon and clears local state.
  Future<void> lockVault() async {
    if (_useLocal) {
      _local?.lock();
      _secrets = [];
      _isLocked = true;
      notifyListeners();
      return;
    }
    try {
      _errorMessage = null;

      if (!_daemonClient.isConnected) {
        await _daemonClient.connect();
      }

      await _daemonClient.lockVault();

      // Clear local state
      _secrets = [];
      _isLocked = true;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to lock vault: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Unlock the vault with password
  ///
  /// Sends unlock command to daemon with password.
  Future<void> unlockVault(String password) async {
    if (_useLocal) {
      _errorMessage = null;
      final ok = _local?.unlock(password) ?? false;
      if (!ok) {
        _errorMessage = 'Incorrect master password';
        notifyListeners();
        throw StateError('Incorrect master password');
      }
      _isLocked = false;
      await loadSecrets();
      return;
    }
    try {
      _errorMessage = null;

      if (!_daemonClient.isConnected) {
        await _daemonClient.connect();
      }

      await _daemonClient.unlockVault(password);

      // Mark as unlocked and reload secrets
      _isLocked = false;
      await loadSecrets();
    } catch (e) {
      _errorMessage = 'Failed to unlock vault: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Rotate a secret's value
  ///
  /// Creates a new version of the secret while preserving the previous value.
  Future<Map<String, dynamic>> rotateSecret(
    String name,
    String newValue,
  ) async {
    if (_useLocal) {
      _local!.setValue(name, newValue);
      await _persistLocal();
      await loadSecrets();
      return {'name': name, 'version': 0};
    }
    try {
      _errorMessage = null;

      if (!_daemonClient.isConnected) {
        await _daemonClient.connect();
      }

      final result = await _daemonClient.rotateSecret(name, newValue);

      // Reload secrets to get updated version
      await loadSecrets();

      return result;
    } catch (e) {
      _errorMessage = 'Failed to rotate secret: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Initialize the vault with a master password
  ///
  /// This must be called on first run to set up the vault.
  /// Returns the vault path and number of migrated secrets.
  Future<Map<String, dynamic>> initializeVault(String password) async {
    if (_useLocal) {
      try {
        _local!.initialize(password);
        _isLocked = false;
        await _persistLocal();
        notifyListeners();
        return {'vault_path': _localPath ?? '', 'migrated_count': 0};
      } catch (e) {
        _errorMessage = 'Failed to initialize vault: $e';
        notifyListeners();
        rethrow;
      }
    }
    try {
      _errorMessage = null;

      if (!_daemonClient.isConnected) {
        await _daemonClient.connect();
      }

      final result = await _daemonClient.initVault(password);

      // Vault is now initialized and unlocked
      _isLocked = false;
      notifyListeners();

      return result;
    } catch (e) {
      _errorMessage = 'Failed to initialize vault: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Change the vault master password
  ///
  /// Re-encrypts all secrets with the new password.
  Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (_useLocal) {
      // Re-keying re-encrypts every secret under a new salt; do it on a Mac
      // (daemon) for now so all devices converge on the new key via sync.
      throw UnsupportedError(
        'Change the master password on a Mac for now — it re-keys the whole vault.',
      );
    }
    try {
      _errorMessage = null;

      if (!_daemonClient.isConnected) {
        await _daemonClient.connect();
      }

      final result = await _daemonClient.changePassword(
        currentPassword,
        newPassword,
      );
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = 'Failed to change password: $e';
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
