// End-to-end proof of the iOS vault backend on the real simulator. Two parts:
//  1) VaultProvider lifecycle (LocalVault + FFI + path_provider persistence).
//  2) LocalVault.merge() last-write-wins convergence, mirroring the daemon's
//     sync.import rules — the substance of cross-device iCloud sync (the iCloud
//     transport itself needs a signed-in account + 2 devices to exercise live).
//   flutter run -d <ios-sim> -t lib/ios_backend_proof.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'providers/vault_provider.dart';
import 'services/local_vault.dart';
import 'services/native_crypto.dart';

const _pw = 'TestPass123';
const _name = 'OPENAI_API_KEY';
const _value = 'sk-ios-secret-🔑-äöü';

Future<String> _runLifecycle() async {
  final steps = <String>[];
  void check(bool ok, String label) {
    steps.add('${ok ? "✓" : "✗"} $label');
    if (!ok) throw StateError('FAILED: $label');
  }

  final p = VaultProvider();
  await p.initLocal();
  var status = await p.getVaultStatus();
  check(status['state'] == 'uninitialized', 'fresh vault is uninitialized');

  await p.initializeVault(_pw);
  status = await p.getVaultStatus();
  check(status['state'] == 'unlocked', 'initialize → unlocked');

  await p.setSecret(_name, _value, provider: 'openai');
  await p.loadSecrets();
  check(p.secrets.any((s) => s.name == _name), 'secret appears in list');

  final got = await p.getSecret(_name);
  check(got?.value == _value, 'decrypted value matches (incl. unicode)');

  await p.lockVault();
  check(p.isLocked, 'lockVault → locked');
  final bad = await () async {
    try {
      await p.unlockVault('wrong-pw');
      return false;
    } catch (_) {
      return true;
    }
  }();
  check(bad, 'wrong password rejected');
  await p.unlockVault(_pw);
  check(!p.isLocked, 'correct password unlocks');
  final got2 = await p.getSecret(_name);
  check(got2?.value == _value, 'value still readable after unlock');

  // Persistence across a "relaunch": a brand-new provider loads the file.
  final p2 = VaultProvider();
  await p2.initLocal();
  final status2 = await p2.getVaultStatus();
  check(status2['state'] == 'locked', 'relaunch: persisted vault is locked');
  check(status2['secret_count'] == 1, 'relaunch: 1 secret persisted');
  await p2.unlockVault(_pw);
  final got3 = await p2.getSecret(_name);
  check(got3?.value == _value, 'relaunch: value survives + decrypts');

  return steps.join('\n');
}

String _runMerge() {
  final steps = <String>[];
  void check(bool ok, String label) {
    steps.add('${ok ? "✓" : "✗"} merge: $label');
    if (!ok) throw StateError('FAILED merge: $label');
  }

  final crypto = NativeCrypto.open();
  Map<String, dynamic> sec(String n, String t, [String v = 'x']) => {
        'name': n, 'value_encrypted': v, 'provider': null,
        'environment': 'default', 'notes': null,
        'created_at': t, 'updated_at': t, 'version': 1, 'rotated_at': null,
      };
  String doc(List<Map<String, dynamic>> secrets,
          [List<Map<String, dynamic>> tombs = const []]) =>
      jsonEncode({
        'salt': 's', 'password_verification': '',
        'secrets': secrets, 'tombstones': tombs,
      });
  LocalVault withA() =>
      LocalVault.fromJson(crypto, doc([sec('A', '2026-06-13 10:00:00', 'localA')]));
  Set<String> names(LocalVault lv) => lv.listNames().map((e) => e.name).toSet();

  // 1) Remote adds B (new) + has an OLDER A → gain B, keep local A.
  var lv = withA();
  lv.merge(doc([
    sec('A', '2026-06-13 09:00:00', 'remoteOld'),
    sec('B', '2026-06-13 11:00:00'),
  ]));
  check(names(lv).containsAll({'A', 'B'}), 'adds new secret, keeps newer-local');
  check(lv.toJson().contains('localA'), 'older remote did NOT overwrite A');

  // 2) Remote has a NEWER A → take it.
  lv = withA();
  lv.merge(doc([sec('A', '2026-06-13 12:00:00', 'remoteNew')]));
  check(lv.toJson().contains('remoteNew'), 'newer remote overwrites A');

  // 3) Remote tombstone NEWER than local A → delete A.
  lv = withA();
  lv.merge(doc([], [{'name': 'A', 'deleted_at': '2026-06-13 12:00:00'}]));
  check(!names(lv).contains('A'), 'newer tombstone deletes A');

  // 4) Remote tombstone OLDER than local A → keep A (resurrected/newer).
  lv = withA();
  lv.merge(doc([], [{'name': 'A', 'deleted_at': '2026-06-13 09:00:00'}]));
  check(names(lv).contains('A'), 'older tombstone does NOT delete A');

  // 5) Remote secret resurrects a locally-tombstoned name.
  lv = LocalVault.fromJson(
      crypto, doc([], [{'name': 'A', 'deleted_at': '2026-06-13 10:00:00'}]));
  lv.merge(doc([sec('A', '2026-06-13 12:00:00', 'resurrected')]));
  check(names(lv).contains('A') && lv.toJson().contains('resurrected'),
      'newer remote secret resurrects tombstoned name');

  // 6) Idempotent: merging the same doc twice changes nothing the 2nd time.
  lv = withA();
  final r = doc([sec('A', '2026-06-13 12:00:00', 'v2'), sec('C', '2026-06-13 12:00:00')]);
  lv.merge(r);
  final secondChanged = lv.merge(r);
  check(!secondChanged, 're-merging identical remote is a no-op');

  return steps.join('\n');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String result;
  try {
    // Start each run from a clean slate so the lifecycle assertions hold.
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/secretariat-vault.json');
    if (await f.exists()) await f.delete();

    final life = await _runLifecycle();
    final merge = _runMerge();
    result = 'IOS-BACKEND-PROOF OK\n$life\n$merge';
  } catch (e, st) {
    result = 'IOS-BACKEND-PROOF FAILED: $e\n$st';
  }
  for (final line in result.split('\n')) {
    debugPrint('[IOS-PROOF] $line');
  }
  stderr.writeln('[IOS-PROOF-RESULT] ${result.split('\n').first}');
  runApp(MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(result)),
      ),
    ),
  ));
}
