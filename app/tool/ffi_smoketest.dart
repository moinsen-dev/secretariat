import 'dart:typed_data';
import '../lib/services/native_crypto.dart';

// Host smoke test for the secretariat-core FFI bridge.
// Usage: dart run tool/ffi_smoketest.dart [path/to/libsecretariat_core_ffi.dylib]
void main(List<String> args) {
  final dylib = args.isNotEmpty
      ? args[0]
      : '../target/debug/libsecretariat_core_ffi.dylib';
  final c = NativeCrypto.open(path: dylib);

  // 1. Deterministic key derivation (same password+salt → same key).
  const salt = '8LgDtH/Nx0kobQOCuYhKaA';
  final k1 = c.deriveKey('correct horse battery staple', salt);
  final k2 = c.deriveKey('correct horse battery staple', salt);
  assert(k1.length == 32, 'key must be 32 bytes');
  print('1) deriveKey: 32 bytes, deterministic=${_eq(k1, k2)}');

  // 2. Wrong password → different key.
  final kBad = c.deriveKey('wrong password', salt);
  print('2) wrong pw → different key: ${!_eq(k1, kBad)}');

  // 3. Roundtrip with a unicode secret.
  const secret = 'sk-proj-aB3xK9_ümlaut_🔐';
  final blob = c.encrypt(secret, k1);
  print('3) encrypt → blob ${blob.length} bytes (nonce12+ct), '
      'ciphertext≠plaintext=${!String.fromCharCodes(blob).contains(secret)}');
  final back = c.decrypt(blob, k1);
  print('4) decrypt → "$back"  matches=${back == secret}');

  // 5. Wrong key fails to decrypt (auth tag).
  var rejected = false;
  try {
    c.decrypt(blob, kBad);
  } catch (_) {
    rejected = true;
  }
  print('5) decrypt with wrong key rejected: $rejected');

  final ok = _eq(k1, k2) && !_eq(k1, kBad) && back == secret && rejected;
  print(ok ? '\n✅ ALL FFI CHECKS PASSED' : '\n❌ FAILED');
  if (!ok) throw 'ffi smoketest failed';
}

bool _eq(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
