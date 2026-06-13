// End-to-end proof of the iOS vault backend on the real simulator: drives
// VaultProvider's iOS (LocalVault + FFI + path_provider) path through the full
// lifecycle — create, add, list, read, lock, unlock — and then proves the
// vault survives a "relaunch" by opening a SECOND provider over the persisted
// file.  Run:  flutter run -d <ios-sim> -t lib/ios_backend_proof.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'providers/vault_provider.dart';

const _pw = 'TestPass123';
const _name = 'OPENAI_API_KEY';
const _value = 'sk-ios-secret-🔑-äöü';

Future<String> _run() async {
  final steps = <String>[];
  void check(bool ok, String label) {
    steps.add('${ok ? "✓" : "✗"} $label');
    if (!ok) throw StateError('FAILED: $label');
  }

  // 1) Fresh vault
  final p = VaultProvider();
  await p.initLocal();
  var status = await p.getVaultStatus();
  check(status['state'] == 'uninitialized', 'fresh vault is uninitialized');

  // 2) Create master password (FFI salt-gen + verification)
  await p.initializeVault(_pw);
  status = await p.getVaultStatus();
  check(status['state'] == 'unlocked', 'initialize → unlocked');

  // 3) Add a secret (FFI encrypt + persist)
  await p.setSecret(_name, _value, provider: 'openai');
  await p.loadSecrets();
  check(p.secrets.any((s) => s.name == _name), 'secret appears in list');

  // 4) Read it back (FFI decrypt)
  final got = await p.getSecret(_name);
  check(got?.value == _value, 'decrypted value matches (incl. unicode)');

  // 5) Lock / unlock
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

  // 6) Persistence across a "relaunch": a brand-new provider loads the file.
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String result;
  try {
    final detail = await _run();
    result = 'IOS-BACKEND-PROOF OK\n$detail';
  } catch (e, st) {
    result = 'IOS-BACKEND-PROOF FAILED: $e\n$st';
  }
  // One-line marker for log scraping + full detail.
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
