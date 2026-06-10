// Daemon Manager Service
//
// Manages the Secretariat daemon lifecycle:
// - Check if daemon is running
// - Start daemon if not running
// - Auto-start daemon on app launch
// - Install/manage LaunchAgent (macOS)

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// Status of the Secretariat daemon
enum DaemonStatus {
  /// Daemon is running and responsive
  running,

  /// Daemon is not running
  stopped,

  /// Daemon status is unknown (checking failed)
  unknown,

  /// Daemon is starting up
  starting,
}

/// Manages the Secretariat daemon lifecycle
class DaemonManager {
  /// Singleton instance
  static final DaemonManager instance = DaemonManager._();

  DaemonManager._();

  /// Current daemon status
  DaemonStatus _status = DaemonStatus.unknown;
  DaemonStatus get status => _status;

  /// Get the socket path based on platform
  String get socketPath {
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '/tmp';
      return '$home/Library/Application Support/Secretariat/secretariat.sock';
    } else if (Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '/tmp';
      return '$home/.local/share/secretariat/secretariat.sock';
    } else if (Platform.isWindows) {
      return r'\\.\pipe\secretariat';
    }
    return '/tmp/secretariat.sock';
  }

  /// Get the daemon binary path
  String get _daemonPath {
    if (Platform.isMacOS) {
      // Check common locations
      final locations = [
        '/usr/local/bin/secd',
        '${Platform.environment['HOME']}/bin/secd',
        // Development location (relative to app)
        _findDevelopmentDaemon(),
      ].whereType<String>().toList();

      for (final loc in locations) {
        if (File(loc).existsSync()) {
          return loc;
        }
      }
    }
    return 'secd'; // Fall back to PATH
  }

  /// Find daemon in development workspace
  ///
  /// Looks for the daemon binary in development locations relative to the app bundle.
  /// This is only used during development - production installations should place
  /// the daemon in /usr/local/bin/secd or ~/bin/secd.
  String? _findDevelopmentDaemon() {
    // In development mode, check if SECRETARIAT_DEV_PATH is set
    final devPath = Platform.environment['SECRETARIAT_DEV_PATH'];
    if (devPath != null) {
      final releasePath = '$devPath/target/release/secd';
      final debugPath = '$devPath/target/debug/secd';
      if (File(releasePath).existsSync()) return releasePath;
      if (File(debugPath).existsSync()) return debugPath;
    }

    // Check relative to app bundle (for development builds)
    // This allows the app to find the daemon when run from the same workspace
    final executable = Platform.resolvedExecutable;
    final appDir = File(executable).parent;

    // Try going up from app bundle to find workspace root
    var current = appDir;
    for (var i = 0; i < 5; i++) {
      final cargoToml = File('${current.path}/Cargo.toml');
      if (cargoToml.existsSync()) {
        // Found workspace root
        final releasePath = '${current.path}/target/release/secd';
        final debugPath = '${current.path}/target/debug/secd';
        if (File(releasePath).existsSync()) return releasePath;
        if (File(debugPath).existsSync()) return debugPath;
        break;
      }
      current = current.parent;
    }

    return null;
  }

  /// Get LaunchAgent plist path (macOS)
  String get _launchAgentPath {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return '$home/Library/LaunchAgents/dev.moinsen.secretariat.plist';
  }

  /// Log a message
  void _log(String message) {
    debugPrint('[DaemonManager] $message');
  }

  /// Check if daemon is running by checking socket existence and connectivity
  Future<DaemonStatus> checkStatus() async {
    _log('Checking daemon status...');

    // First check if socket file exists
    final socketFile = File(socketPath);
    if (!socketFile.existsSync()) {
      _log('Socket file does not exist at $socketPath');
      _status = DaemonStatus.stopped;
      return _status;
    }

    // Try to connect to verify daemon is responsive
    try {
      final address = InternetAddress(
        socketPath,
        type: InternetAddressType.unix,
      );
      final socket = await Socket.connect(address, 0).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          throw SocketException('Connection timeout');
        },
      );

      try {
        // Send a health check request
        socket.write(
          '{"jsonrpc":"2.0","id":0,"method":"health.check","params":{}}\n',
        );
        await socket.flush();

        // Wait briefly for response
        await Future.delayed(const Duration(milliseconds: 100));
      } finally {
        await socket.close();
      }

      _log('Daemon is running and responsive');
      _status = DaemonStatus.running;
      return _status;
    } catch (e) {
      _log('Failed to connect to daemon: $e');
      // Socket exists but daemon not responding - might be stale socket
      _status = DaemonStatus.stopped;
      return _status;
    }
  }

  /// Check if daemon is running (quick check)
  Future<bool> isRunning() async {
    final status = await checkStatus();
    return status == DaemonStatus.running;
  }

  /// Start the daemon
  ///
  /// On macOS, uses launchctl to start via LaunchAgent if installed,
  /// otherwise starts directly.
  Future<bool> startDaemon() async {
    _log('Starting daemon...');
    _status = DaemonStatus.starting;

    try {
      if (Platform.isMacOS) {
        return await _startDaemonMacOS();
      } else if (Platform.isLinux) {
        return await _startDaemonLinux();
      } else {
        _log('Platform not supported for daemon management');
        return false;
      }
    } catch (e) {
      _log('ERROR: Failed to start daemon: $e');
      _status = DaemonStatus.stopped;
      return false;
    }
  }

  /// Start daemon on macOS
  Future<bool> _startDaemonMacOS() async {
    // Check if LaunchAgent is installed
    final launchAgentFile = File(_launchAgentPath);
    if (launchAgentFile.existsSync()) {
      _log('Using LaunchAgent to start daemon');

      // Try to load and start via launchctl
      final result = await Process.run('launchctl', [
        'load',
        '-w',
        _launchAgentPath,
      ]);

      if (result.exitCode != 0) {
        // Might already be loaded, try kickstart
        _log('LaunchAgent load returned ${result.exitCode}, trying kickstart');
        final kickResult = await Process.run('launchctl', [
          'kickstart',
          '-k',
          'gui/${Platform.environment['UID'] ?? '501'}/dev.moinsen.secretariat.daemon',
        ]);

        if (kickResult.exitCode != 0) {
          _log('Kickstart failed: ${kickResult.stderr}');
          // Fall back to direct start
          return await _startDaemonDirect();
        }
      }

      // Wait for daemon to start
      await Future.delayed(const Duration(seconds: 1));

      // Verify it's running
      final status = await checkStatus();
      return status == DaemonStatus.running;
    } else {
      _log('LaunchAgent not installed, starting directly');
      return await _startDaemonDirect();
    }
  }

  /// Start daemon directly (not via LaunchAgent)
  Future<bool> _startDaemonDirect() async {
    final daemonPath = _daemonPath;
    _log('Starting daemon directly: $daemonPath');

    if (!File(daemonPath).existsSync() && daemonPath != 'secd') {
      _log('ERROR: Daemon binary not found at $daemonPath');
      _status = DaemonStatus.stopped;
      return false;
    }

    // Start daemon in background
    final process = await Process.start(
      daemonPath,
      [],
      mode: ProcessStartMode.detached,
    );

    _log('Daemon process started with PID: ${process.pid}');

    // Wait for daemon to initialize
    await Future.delayed(const Duration(seconds: 2));

    // Verify it's running
    final status = await checkStatus();
    return status == DaemonStatus.running;
  }

  /// Start daemon on Linux
  Future<bool> _startDaemonLinux() async {
    // Check for systemd user service
    final result = await Process.run('systemctl', [
      '--user',
      'start',
      'secretariat',
    ]);

    if (result.exitCode == 0) {
      _log('Started via systemd');
      await Future.delayed(const Duration(seconds: 1));
      final status = await checkStatus();
      return status == DaemonStatus.running;
    }

    // Fall back to direct start
    _log('Systemd service not available, starting directly');
    return await _startDaemonDirect();
  }

  /// Stop the daemon
  Future<bool> stopDaemon() async {
    _log('Stopping daemon...');

    try {
      if (Platform.isMacOS) {
        final result = await Process.run('launchctl', [
          'unload',
          _launchAgentPath,
        ]);

        if (result.exitCode != 0) {
          _log('launchctl unload failed, trying pkill');
          await Process.run('pkill', ['-f', 'secd']);
        }
      } else if (Platform.isLinux) {
        await Process.run('systemctl', ['--user', 'stop', 'secretariat']);
      }

      await Future.delayed(const Duration(milliseconds: 500));
      _status = DaemonStatus.stopped;
      return true;
    } catch (e) {
      _log('ERROR: Failed to stop daemon: $e');
      return false;
    }
  }

  /// Install LaunchAgent for auto-start (macOS)
  Future<bool> installLaunchAgent() async {
    if (!Platform.isMacOS) {
      _log('LaunchAgent is only supported on macOS');
      return false;
    }

    _log('Installing LaunchAgent...');

    final daemonPath = _daemonPath;
    if (!File(daemonPath).existsSync() && daemonPath != 'secd') {
      _log('ERROR: Daemon binary not found at $daemonPath');
      return false;
    }

    final home = Platform.environment['HOME'] ?? '/tmp';
    final dataDir = '$home/Library/Application Support/Secretariat';
    final logPath = '$dataDir/daemon.log';

    // Ensure LaunchAgents directory exists
    final launchAgentsDir = Directory(path.dirname(_launchAgentPath));
    if (!launchAgentsDir.existsSync()) {
      launchAgentsDir.createSync(recursive: true);
    }

    // Create plist content
    final plistContent =
        '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>dev.moinsen.secretariat.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>$daemonPath</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$logPath</string>
    <key>StandardErrorPath</key>
    <string>$logPath</string>
    <key>WorkingDirectory</key>
    <string>$dataDir</string>
</dict>
</plist>
''';

    try {
      // Write plist file
      final plistFile = File(_launchAgentPath);
      await plistFile.writeAsString(plistContent);
      _log('LaunchAgent installed at $_launchAgentPath');

      // Load the agent
      await Process.run('launchctl', ['load', '-w', _launchAgentPath]);
      _log('LaunchAgent loaded');

      return true;
    } catch (e) {
      _log('ERROR: Failed to install LaunchAgent: $e');
      return false;
    }
  }

  /// Uninstall LaunchAgent (macOS)
  Future<bool> uninstallLaunchAgent() async {
    if (!Platform.isMacOS) {
      return false;
    }

    _log('Uninstalling LaunchAgent...');

    try {
      // Unload the agent
      await Process.run('launchctl', ['unload', _launchAgentPath]);

      // Remove plist file
      final plistFile = File(_launchAgentPath);
      if (plistFile.existsSync()) {
        await plistFile.delete();
      }

      _log('LaunchAgent uninstalled');
      return true;
    } catch (e) {
      _log('ERROR: Failed to uninstall LaunchAgent: $e');
      return false;
    }
  }

  /// Check if LaunchAgent is installed (macOS)
  bool isLaunchAgentInstalled() {
    if (!Platform.isMacOS) {
      return false;
    }
    return File(_launchAgentPath).existsSync();
  }

  /// Ensure daemon is running, starting it if necessary
  ///
  /// Returns true if daemon is running (was already running or was started successfully)
  Future<bool> ensureRunning() async {
    final status = await checkStatus();

    if (status == DaemonStatus.running) {
      _log('Daemon is already running');
      return true;
    }

    _log('Daemon is not running, attempting to start...');
    return await startDaemon();
  }
}

/// Global instance for convenience
final daemonManager = DaemonManager.instance;
