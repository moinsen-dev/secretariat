// dart:ffi bridge to `secretariat-core` (Argon2id + AES-256-GCM).
//
// iOS has no daemon, so the iOS app runs the SAME Rust crypto as the macOS
// daemon — byte-identical — to derive the key from the master password + salt
// and decrypt the iCloud-synced secret blobs. The encrypted blob layout is
// `nonce(12) || ciphertext`, matching the vault's `value_encrypted`.

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// int sec_derive_key(u8* pw, usize pwLen, u8* salt, usize saltLen, u8* outKey)
typedef _DeriveKeyNative = Int32 Function(
    Pointer<Uint8>, Size, Pointer<Uint8>, Size, Pointer<Uint8>);
typedef _DeriveKey = int Function(
    Pointer<Uint8>, int, Pointer<Uint8>, int, Pointer<Uint8>);

// int sec_encrypt(u8* pt, usize ptLen, u8* key, u8** outPtr, usize* outLen)
typedef _CryptNative = Int32 Function(
    Pointer<Uint8>, Size, Pointer<Uint8>, Pointer<Pointer<Uint8>>, Pointer<Size>);
typedef _Crypt = int Function(
    Pointer<Uint8>, int, Pointer<Uint8>, Pointer<Pointer<Uint8>>, Pointer<Size>);

typedef _FreeNative = Void Function(Pointer<Uint8>, Size);
typedef _Free = void Function(Pointer<Uint8>, int);

typedef _KeySizeNative = Size Function();
typedef _KeySize = int Function();

// int sec_generate_salt(u8** outPtr, usize* outLen)
typedef _GenSaltNative = Int32 Function(Pointer<Pointer<Uint8>>, Pointer<Size>);
typedef _GenSalt = int Function(Pointer<Pointer<Uint8>>, Pointer<Size>);

class NativeCryptoException implements Exception {
  final String op;
  final int code;
  NativeCryptoException(this.op, this.code);
  @override
  String toString() => 'NativeCrypto.$op failed (code $code)';
}

class NativeCrypto {
  final _DeriveKey _deriveKey;
  final _Crypt _encrypt;
  final _Crypt _decrypt;
  final _Free _free;
  final _GenSalt _genSalt;
  final int keySize;

  NativeCrypto._(DynamicLibrary lib)
      : _deriveKey =
            lib.lookupFunction<_DeriveKeyNative, _DeriveKey>('sec_derive_key'),
        _encrypt = lib.lookupFunction<_CryptNative, _Crypt>('sec_encrypt'),
        _decrypt = lib.lookupFunction<_CryptNative, _Crypt>('sec_decrypt'),
        _free = lib.lookupFunction<_FreeNative, _Free>('sec_free'),
        _genSalt =
            lib.lookupFunction<_GenSaltNative, _GenSalt>('sec_generate_salt'),
        keySize =
            lib.lookupFunction<_KeySizeNative, _KeySize>('sec_key_size')();

  /// Open the native library. On iOS the static lib is linked into the app
  /// process; on macOS/dev pass [path] to a built `libsecretariat_core_ffi.dylib`.
  factory NativeCrypto.open({String? path}) {
    final DynamicLibrary lib;
    if (path != null) {
      lib = DynamicLibrary.open(path);
    } else if (Platform.isIOS) {
      lib = DynamicLibrary.process();
    } else {
      lib = DynamicLibrary.open('libsecretariat_core_ffi.dylib');
    }
    return NativeCrypto._(lib);
  }

  /// Argon2id-derive the 32-byte master key from the password + salt.
  Uint8List deriveKey(String password, String salt) {
    final pw = password.toNativeUtf8();
    final saltP = salt.toNativeUtf8();
    final outKey = malloc<Uint8>(keySize);
    try {
      final rc = _deriveKey(
          pw.cast(), pw.length, saltP.cast(), saltP.length, outKey);
      if (rc != 0) throw NativeCryptoException('deriveKey', rc);
      return Uint8List.fromList(outKey.asTypedList(keySize));
    } finally {
      malloc.free(pw);
      malloc.free(saltP);
      malloc.free(outKey);
    }
  }

  /// Generate a fresh PHC-base64 salt (same format the daemon's vault-init
  /// produces) so an iOS-created vault unlocks on a Mac and vice versa.
  String generateSalt() {
    final outPtr = malloc<Pointer<Uint8>>();
    final outLen = malloc<Size>();
    try {
      final rc = _genSalt(outPtr, outLen);
      if (rc != 0) throw NativeCryptoException('generateSalt', rc);
      final len = outLen.value;
      final bytes = Uint8List.fromList(outPtr.value.asTypedList(len));
      _free(outPtr.value, len);
      return utf8.decode(bytes);
    } finally {
      malloc.free(outPtr);
      malloc.free(outLen);
    }
  }

  /// Encrypt [plaintext] → `nonce(12) || ciphertext` blob.
  Uint8List encrypt(String plaintext, Uint8List key) =>
      _crypt(_encrypt, 'encrypt', Uint8List.fromList(utf8.encode(plaintext)), key);

  /// Decrypt a `nonce(12) || ciphertext` blob → UTF-8 plaintext.
  String decrypt(Uint8List blob, Uint8List key) =>
      utf8.decode(_crypt(_decrypt, 'decrypt', blob, key));

  Uint8List _crypt(_Crypt fn, String op, Uint8List input, Uint8List key) {
    final inP = malloc<Uint8>(input.length);
    inP.asTypedList(input.length).setAll(0, input);
    final keyP = malloc<Uint8>(key.length);
    keyP.asTypedList(key.length).setAll(0, key);
    final outPtr = malloc<Pointer<Uint8>>();
    final outLen = malloc<Size>();
    try {
      final rc = fn(inP, input.length, keyP, outPtr, outLen);
      if (rc != 0) throw NativeCryptoException(op, rc);
      final len = outLen.value;
      final result = Uint8List.fromList(outPtr.value.asTypedList(len));
      _free(outPtr.value, len);
      return result;
    } finally {
      malloc.free(inP);
      malloc.free(keyP);
      malloc.free(outPtr);
      malloc.free(outLen);
    }
  }
}
