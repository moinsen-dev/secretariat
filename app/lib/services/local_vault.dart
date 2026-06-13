// iOS vault backend — no daemon.
//
// On iOS there is no `secd`. The app operates directly on the E2E-encrypted
// iCloud sync document (`secretariat-vault.json`), doing Argon2id + AES-256-GCM
// via the shared Rust core (NativeCrypto / FFI). It can read EXACTLY the same
// vault the macOS daemon writes — same key derivation, same blob layout
// (`nonce(12) || ciphertext`, base64 in the JSON).
//
// The on-disk JSON is the sync payload produced by the daemon's `sync.export`:
//   { "salt": ..., "password_verification": ...,
//     "secrets": [ { "name", "value_encrypted"(b64), "provider", ... } ],
//     "tombstones": [...] }

import 'dart:convert';
import 'dart:typed_data';

import 'native_crypto.dart';

/// Decrypted-on-demand view over the iCloud vault document.
class LocalVault {
  final NativeCrypto _crypto;
  Map<String, dynamic> _doc;
  Uint8List? _key;

  LocalVault(this._crypto, this._doc);

  /// Parse a vault document (the iCloud sync JSON).
  factory LocalVault.fromJson(NativeCrypto crypto, String json) =>
      LocalVault(crypto, (jsonDecode(json) as Map).cast<String, dynamic>());

  /// Start from an empty, uninitialized document.
  factory LocalVault.empty(NativeCrypto crypto) =>
      LocalVault(crypto, {'secrets': [], 'tombstones': []});

  bool get isInitialized => _doc['salt'] != null;
  bool get isUnlocked => _key != null;

  List<Map<String, dynamic>> get _secrets =>
      ((_doc['secrets'] as List?) ?? const [])
          .cast<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();

  /// Secret names + metadata (no decryption — works while locked).
  List<({String name, String? provider})> listNames() =>
      _secrets.map((s) => (name: s['name'] as String, provider: s['provider'] as String?)).toList();

  /// Secret metadata maps (no values) in the daemon's `secret.list` shape, so
  /// the UI can build `Secret.fromJson` objects via the exact same path as on
  /// macOS. Decryption happens lazily in [getValue].
  List<Map<String, dynamic>> listSecretsJson() => _secrets
      .map((s) => {
            'id': s['name'],
            'name': s['name'],
            'provider': s['provider'],
            'environment': s['environment'],
            'created_at': s['created_at'],
            'updated_at': s['updated_at'],
            'rotated_at': s['rotated_at'],
            'notes': s['notes'],
          })
      .toList();

  /// Create a brand-new vault: generate a salt (daemon-compatible), derive the
  /// key, and store the encrypted verification value. Leaves the vault unlocked.
  void initialize(String password) {
    if (isInitialized) throw StateError('Vault already initialized');
    final salt = _crypto.generateSalt();
    final key = _crypto.deriveKey(password, salt);
    final verBlob = _crypto.encrypt('SECRETARIAT_VAULT_VERIFICATION_V1', key);
    _doc['salt'] = salt;
    _doc['password_verification'] = base64.encode(verBlob);
    _doc['secrets'] ??= [];
    _doc['tombstones'] ??= [];
    _key = key;
  }

  /// Derive the key from the master password and verify it against the stored
  /// verification value. Returns true on success (vault then unlocked).
  bool unlock(String password) {
    final salt = _doc['salt'] as String?;
    if (salt == null) return false;
    final key = _crypto.deriveKey(password, salt);

    final verB64 = _doc['password_verification'] as String?;
    if (verB64 != null && verB64.isNotEmpty) {
      try {
        final plain = _crypto.decrypt(Uint8List.fromList(base64.decode(verB64)), key);
        if (plain != 'SECRETARIAT_VAULT_VERIFICATION_V1') return false;
      } catch (_) {
        return false; // wrong password (auth-tag failure)
      }
    }
    _key = key;
    return true;
  }

  void lock() => _key = null;

  /// Decrypt and return a secret value (vault must be unlocked).
  String getValue(String name) {
    final key = _requireKey();
    final s = _secrets.firstWhere(
      (s) => s['name'] == name,
      orElse: () => throw StateError("Secret '$name' not found"),
    );
    final blob = base64.decode(s['value_encrypted'] as String);
    return _crypto.decrypt(Uint8List.fromList(blob), key);
  }

  /// Create or update a secret (encrypts locally; updates the in-memory doc
  /// and bumps updated_at so the daemon's last-write-wins merge picks it up).
  void setValue(String name, String value, {String? provider}) {
    final key = _requireKey();
    final blob = _crypto.encrypt(value, key);
    final b64 = base64.encode(blob);
    final now = _sqliteNow();

    final secrets = (_doc['secrets'] as List).cast<Map>();
    final idx = secrets.indexWhere((s) => s['name'] == name);
    if (idx >= 0) {
      secrets[idx]['value_encrypted'] = b64;
      secrets[idx]['updated_at'] = now;
      if (provider != null) secrets[idx]['provider'] = provider;
    } else {
      secrets.add({
        'name': name,
        'value_encrypted': b64,
        'provider': provider,
        'environment': 'default',
        'notes': null,
        'created_at': now,
        'updated_at': now,
        'version': 1,
        'rotated_at': null,
      });
    }
    // A re-created secret cancels a prior tombstone.
    final tombs = (_doc['tombstones'] as List?)?.cast<Map>() ?? [];
    tombs.removeWhere((t) => t['name'] == name);
    _doc['tombstones'] = tombs;
  }

  /// Delete a secret, leaving a tombstone (for cross-device sync).
  void delete(String name) {
    final secrets = (_doc['secrets'] as List).cast<Map>();
    secrets.removeWhere((s) => s['name'] == name);
    final tombs = (_doc['tombstones'] as List?)?.cast<Map>() ?? [];
    tombs.removeWhere((t) => t['name'] == name);
    tombs.add({'name': name, 'deleted_at': _sqliteNow()});
    _doc['tombstones'] = tombs;
  }

  /// Merge a remote sync document into this one using the daemon's exact
  /// last-write-wins rules, so iOS converges identically to the Macs. Operates
  /// on ciphertext only — no unlock required. Returns true if anything changed.
  ///
  /// Rules (mirroring `storage.rs` import_sync_secret / import_sync_tombstone):
  /// - a remote secret applies unless a local tombstone is `>=` its updated_at
  ///   (deletion wins) or a local secret is `>=` it (local newer/equal wins);
  ///   applying it clears any local tombstone (resurrection).
  /// - a remote tombstone applies unless the local secret is strictly newer
  ///   (`>` deleted_at) — i.e. it was re-created after the delete.
  bool merge(String remoteJson) {
    final remote = (jsonDecode(remoteJson) as Map).cast<String, dynamic>();
    var changed = false;

    // Adopt salt + verification on first sync into an empty vault.
    if (_doc['salt'] == null && remote['salt'] != null) {
      _doc['salt'] = remote['salt'];
      _doc['password_verification'] = remote['password_verification'];
      changed = true;
    }

    final secrets = (_doc['secrets'] as List).cast<Map>();
    final tombs = ((_doc['tombstones'] as List?) ?? []).cast<Map>();

    String? localUpdatedAt(String name) {
      final i = secrets.indexWhere((s) => s['name'] == name);
      return i >= 0 ? secrets[i]['updated_at'] as String? : null;
    }

    String? localTombAt(String name) {
      final i = tombs.indexWhere((t) => t['name'] == name);
      return i >= 0 ? tombs[i]['deleted_at'] as String? : null;
    }

    // Remote secrets.
    for (final rsRaw in (remote['secrets'] as List?) ?? const []) {
      final rs = (rsRaw as Map).cast<String, dynamic>();
      final name = rs['name'] as String;
      final ru = (rs['updated_at'] as String?) ?? '';
      final td = localTombAt(name);
      if (td != null && td.compareTo(ru) >= 0) continue; // deletion wins
      final lu = localUpdatedAt(name);
      if (lu != null && lu.compareTo(ru) >= 0) continue; // local newer/equal
      secrets.removeWhere((s) => s['name'] == name);
      secrets.add(rs);
      tombs.removeWhere((t) => t['name'] == name); // resurrection
      changed = true;
    }

    // Remote tombstones.
    for (final rtRaw in (remote['tombstones'] as List?) ?? const []) {
      final rt = (rtRaw as Map).cast<String, dynamic>();
      final name = rt['name'] as String;
      final dd = (rt['deleted_at'] as String?) ?? '';
      final lu = localUpdatedAt(name);
      if (lu != null && lu.compareTo(dd) > 0) continue; // resurrected — keep
      if (lu == null && localTombAt(name) == dd) continue; // already have it
      secrets.removeWhere((s) => s['name'] == name);
      tombs.removeWhere((t) => t['name'] == name);
      tombs.add({'name': name, 'deleted_at': dd});
      changed = true;
    }

    _doc['secrets'] = secrets;
    _doc['tombstones'] = tombs;
    return changed;
  }

  /// Serialize back to the iCloud sync JSON.
  String toJson() => jsonEncode(_doc);

  Uint8List _requireKey() {
    final k = _key;
    if (k == null) throw StateError('Vault is locked');
    return k;
  }

  /// UTC timestamp in SQLite's `YYYY-MM-DD HH:MM:SS` format — same lexically
  /// ordered shape the daemon uses, so last-write-wins compares correctly.
  static String _sqliteNow() {
    final n = DateTime.now().toUtc();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${p(n.month)}-${p(n.day)} ${p(n.hour)}:${p(n.minute)}:${p(n.second)}';
  }
}
