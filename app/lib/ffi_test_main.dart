// Minimal entrypoint to prove the FFI crypto resolves at runtime on iOS,
// without the daemon/desktop-plugin baggage of the real app.
//   flutter run -d <ios-sim> -t lib/ffi_test_main.dart
import 'package:flutter/material.dart';
import 'services/native_crypto.dart';

void main() {
  String result;
  try {
    final c = NativeCrypto.open(); // iOS → DynamicLibrary.process()
    final key = c.deriveKey('test-password', '8LgDtH/Nx0kobQOCuYhKaA');
    final blob = c.encrypt('sk-ios-runtime-🔑', key);
    final back = c.decrypt(blob, key);
    final ok = key.length == 32 && back == 'sk-ios-runtime-🔑';
    result = ok
        ? 'FFI OK on iOS — key=${key.length}B, unicode roundtrip ✓'
        : 'FFI WRONG RESULT';
  } catch (e) {
    result = 'FFI FAILED: $e';
  }
  debugPrint('[FFI-PROOF] $result');
  runApp(MaterialApp(
    home: Scaffold(body: Center(child: Text(result))),
  ));
}
