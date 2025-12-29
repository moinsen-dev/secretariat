import 'package:flutter/foundation.dart';
import 'package:talker/talker.dart';

/// Centralized logging service using Talker.
///
/// Provides structured logging with different log levels and
/// automatic filtering in release builds for security.
class LoggerService {
  LoggerService._();

  static final Talker _talker = Talker(
    settings: TalkerSettings(
      // Only enable logging in debug mode
      enabled: kDebugMode,
      // Use colors for better readability in console
      useConsoleLogs: true,
      // Max history for in-memory log storage
      maxHistoryItems: 100,
    ),
    logger: TalkerLogger(
      // Customize output format
      settings: TalkerLoggerSettings(
        enableColors: true,
        maxLineWidth: 120,
      ),
    ),
  );

  /// Get the Talker instance for direct access if needed.
  static Talker get instance => _talker;

  // ---------------------------------------------------------------------------
  // Logging methods by component
  // ---------------------------------------------------------------------------

  /// Log messages from the main app initialization.
  static void main(String message, {Object? error, StackTrace? stackTrace}) {
    _log('[Main]', message, error: error, stackTrace: stackTrace);
  }

  /// Log messages from window manager operations.
  static void window(String message, {Object? error, StackTrace? stackTrace}) {
    _log('[Window]', message, error: error, stackTrace: stackTrace);
  }

  /// Log messages from system tray operations.
  static void tray(String message, {Object? error, StackTrace? stackTrace}) {
    _log('[Tray]', message, error: error, stackTrace: stackTrace);
  }

  /// Log messages from daemon client operations.
  static void daemon(String message, {Object? error, StackTrace? stackTrace}) {
    _log('[Daemon]', message, error: error, stackTrace: stackTrace);
  }

  /// Log messages from vault operations.
  static void vault(String message, {Object? error, StackTrace? stackTrace}) {
    _log('[Vault]', message, error: error, stackTrace: stackTrace);
  }

  /// Log messages from UI components.
  static void ui(String message, {Object? error, StackTrace? stackTrace}) {
    _log('[UI]', message, error: error, stackTrace: stackTrace);
  }

  /// Log messages from import operations.
  static void import_(String message, {Object? error, StackTrace? stackTrace}) {
    _log('[Import]', message, error: error, stackTrace: stackTrace);
  }

  // ---------------------------------------------------------------------------
  // Generic logging methods
  // ---------------------------------------------------------------------------

  /// Log a debug message.
  static void debug(String message) {
    _talker.debug(message);
  }

  /// Log an info message.
  static void info(String message) {
    _talker.info(message);
  }

  /// Log a warning message.
  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _talker.warning(message, error, stackTrace);
  }

  /// Log an error message.
  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _talker.error(message, error, stackTrace);
  }

  /// Log a critical/severe message.
  static void critical(String message,
      {Object? error, StackTrace? stackTrace}) {
    _talker.critical(message, error, stackTrace);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static void _log(
    String prefix,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (error != null) {
      _talker.error('$prefix $message', error, stackTrace);
    } else {
      _talker.debug('$prefix $message');
    }
  }
}

/// Shorthand for LoggerService to keep call sites concise.
typedef Log = LoggerService;
