import 'dart:io';
import '../lib/services/native_crypto.dart';
import '../lib/services/local_vault.dart';

// Proof: the Dart/iOS path reads a vault the macOS DAEMON created.
// Usage: dart run tool/ios_vault_proof.dart <vault.json> <dylib>
void main(List<String> args) {
  final json = File(args[0]).readAsStringSync();
  final crypto = NativeCrypto.open(path: args[1]);
  final vault = LocalVault.fromJson(crypto, json);

  print('initialized: ${vault.isInitialized}');
  print('names (locked, no decryption): ${vault.listNames().map((n) => n.name).toList()}');

  // 1. Wrong password must be rejected.
  final wrong = vault.unlock('not-the-password');
  print('1) wrong password rejected: ${!wrong}');

  // 2. Right password unlocks (verified against password_verification).
  final ok = vault.unlock('mac-master-2026');
  print('2) correct password unlocks: $ok');

  // 3. Decrypt the daemon-encrypted secrets — including unicode/emoji.
  final openai = vault.getValue('OPENAI_KEY');
  final db = vault.getValue('DB_PASS');
  print('3) OPENAI_KEY -> "$openai"');
  print('   DB_PASS    -> "$db"');
  final dec = openai == 'sk-mac-created-üml-🔑-7788' && db == r'Tr0ub4dor&3';
  print('   decrypt matches daemon plaintext: $dec');

  // 4. iOS writes a new secret; re-decrypt to confirm round-trip.
  vault.setValue('NEW_FROM_IOS', 'ios-written-value-99');
  final back = vault.getValue('NEW_FROM_IOS');
  print('4) iOS-written secret round-trips: ${back == 'ios-written-value-99'}');

  final pass = !wrong && ok && dec && back == 'ios-written-value-99';
  print(pass ? '\n✅ iOS READS & WRITES A MAC-CREATED VAULT' : '\n❌ FAILED');
  if (!pass) exit(1);
}
