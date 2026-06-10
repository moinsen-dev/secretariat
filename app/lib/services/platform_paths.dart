// Resolves platform paths that a sandboxed macOS app cannot derive from
// $HOME (a sandboxed app's $HOME is its own container, not the real home).
//
// On macOS the daemon's Unix socket lives in the shared App Group container
// (group.dev.moinsen.secretariat); the native side resolves its real path via
// FileManager. The iCloud (ubiquity) container is resolved the same way.

import 'dart:io';
import 'package:flutter/services.dart';

class PlatformPaths {
  static const _channel = MethodChannel('dev.moinsen.secretariat/platform');
  static const _syncEvents =
      EventChannel('dev.moinsen.secretariat/sync_events');

  /// Fires when the iCloud vault file changes (another device pushed). Empty
  /// stream on unsupported platforms.
  static Stream<dynamic> get icloudChanges {
    if (!Platform.isMacOS && !Platform.isIOS) return const Stream.empty();
    return _syncEvents.receiveBroadcastStream();
  }

  static String? _socketPath;
  static String? _ubiquityPath;

  /// Path to the daemon Unix socket. On macOS this is the App Group container
  /// socket (resolved natively); cached after first resolution.
  static Future<String> socketPath() async {
    if (_socketPath != null) return _socketPath!;

    if (Platform.isMacOS) {
      try {
        final p = await _channel.invokeMethod<String>('getSocketPath');
        if (p != null && p.isNotEmpty) {
          _socketPath = p;
          return p;
        }
      } catch (_) {
        // Not sandboxed / channel unavailable — fall back to the real home.
      }
      final home = Platform.environment['HOME'];
      _socketPath =
          '$home/Library/Group Containers/group.dev.moinsen.secretariat/secretariat.sock';
      return _socketPath!;
    } else if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      _socketPath = '$home/.local/share/secretariat/secretariat.sock';
      return _socketPath!;
    }
    throw UnsupportedError('Unsupported platform for daemon socket');
  }

  /// Path to the iCloud Drive (ubiquity) container, or null if iCloud isn't
  /// available (not signed in / not yet provisioned). macOS/iOS only.
  static Future<String?> ubiquityContainerPath() async {
    if (_ubiquityPath != null) return _ubiquityPath;
    if (!Platform.isMacOS && !Platform.isIOS) return null;
    try {
      _ubiquityPath =
          await _channel.invokeMethod<String>('getUbiquityContainerPath');
    } catch (_) {
      _ubiquityPath = null;
    }
    return _ubiquityPath;
  }

  /// Whether iCloud is available (signed in + container provisioned).
  static Future<bool> icloudAvailable() async {
    return (await ubiquityContainerPath()) != null;
  }

  /// Read the encrypted vault sync file from iCloud. Returns the JSON string,
  /// or null if it doesn't exist yet / iCloud unavailable.
  static Future<String?> icloudRead() async {
    if (!Platform.isMacOS && !Platform.isIOS) return null;
    try {
      return await _channel.invokeMethod<String>('icloudRead');
    } catch (_) {
      return null;
    }
  }

  /// Write the encrypted vault sync file to iCloud. Returns true on success.
  static Future<bool> icloudWrite(String content) async {
    if (!Platform.isMacOS && !Platform.isIOS) return false;
    try {
      final ok =
          await _channel.invokeMethod<bool>('icloudWrite', {'content': content});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
