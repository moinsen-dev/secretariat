// Main entry point for Secretariat Flutter app
// Updated for Wave 21: Added routing for secrets list and detail screens
// Updated for Wave 22: Added routing for add secret and applications screens
// Updated for Wave 23: Added theme (F204) and system tray initialization (F192-F199)
// Migrated from system_tray to tray_manager (actively maintained package)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'dart:io' show Platform, exit;
import 'providers/vault_provider.dart';
import 'screens/main_popup.dart';
import 'screens/secrets_list.dart';
import 'screens/secret_detail.dart';
import 'screens/add_secret.dart';
import 'screens/applications.dart';
import 'theme/theme.dart';

void main() async {
  // F192: Ensure Flutter is initialized before system tray setup
  WidgetsFlutterBinding.ensureInitialized();

  // F192: Initialize system tray on app start
  await _initSystemTray();

  // Initialize VaultProvider and ensure daemon is running
  final vaultProvider = VaultProvider();
  await _ensureDaemonRunning(vaultProvider);

  runApp(SecretariatApp(vaultProvider: vaultProvider));
}

/// Ensure daemon is running at app startup
Future<void> _ensureDaemonRunning(VaultProvider vaultProvider) async {
  try {
    debugPrint('[Main] Checking daemon status...');
    final status = await vaultProvider.checkDaemonStatus();
    debugPrint('[Main] Daemon status: $status');

    if (!vaultProvider.isDaemonRunning) {
      debugPrint('[Main] Daemon not running, attempting to start...');
      final started = await vaultProvider.startDaemon();
      if (started) {
        debugPrint('[Main] Daemon started successfully');
      } else {
        debugPrint('[Main] WARNING: Failed to start daemon');
      }
    }
  } catch (e) {
    debugPrint('[Main] Error checking/starting daemon: $e');
  }
}

/// F192-F199: Initialize system tray with icons and menu
Future<void> _initSystemTray() async {
  // Skip system tray on unsupported platforms
  if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
    return;
  }

  try {
    // F193: Set initial icon to locked state
    await TrayManager.instance.setIcon(
      Platform.isWindows ? 'assets/tray_locked.ico' : 'assets/tray_locked.png',
    );

    // Set tooltip
    await TrayManager.instance.setToolTip('Secretariat - Locked');

    // F194: Create menu with items: "Open", "Lock", "Quit"
    final Menu menu = Menu(
      items: [
        // F195: "Open" menu item to show main window
        MenuItem(key: 'open', label: 'Open'),
        MenuItem.separator(),
        // F196: "Lock" menu item to lock vault via daemon
        MenuItem(key: 'lock', label: 'Lock'),
        MenuItem.separator(),
        // F197: "Quit" menu item to exit app
        MenuItem(key: 'quit', label: 'Quit'),
      ],
    );

    await TrayManager.instance.setContextMenu(menu);
    debugPrint('[SystemTray] Initialized successfully');
  } catch (e) {
    debugPrint('[SystemTray] Failed to initialize: $e');
  }
}

/// F198-F199: Update tray icon based on vault lock state
Future<void> updateTrayIcon(bool isLocked) async {
  try {
    final iconPath = isLocked
        ? (Platform.isWindows
              ? 'assets/tray_locked.ico'
              : 'assets/tray_locked.png')
        : (Platform.isWindows
              ? 'assets/tray_unlocked.ico'
              : 'assets/tray_unlocked.png');
    await TrayManager.instance.setIcon(iconPath);
    await TrayManager.instance.setToolTip(
      isLocked ? 'Secretariat - Locked' : 'Secretariat - Unlocked',
    );
  } catch (e) {
    debugPrint('[SystemTray] Failed to update icon: $e');
  }
}

class SecretariatApp extends StatefulWidget {
  final VaultProvider vaultProvider;

  const SecretariatApp({super.key, required this.vaultProvider});

  @override
  State<SecretariatApp> createState() => _SecretariatAppState();
}

class _SecretariatAppState extends State<SecretariatApp> with TrayListener {
  @override
  void initState() {
    super.initState();
    // Register tray listener for menu clicks
    TrayManager.instance.addListener(this);
  }

  @override
  void dispose() {
    TrayManager.instance.removeListener(this);
    super.dispose();
  }

  /// Handle tray icon click - show context menu
  @override
  void onTrayIconMouseDown() {
    TrayManager.instance.popUpContextMenu();
  }

  /// Handle tray icon right click - show context menu
  @override
  void onTrayIconRightMouseDown() {
    TrayManager.instance.popUpContextMenu();
  }

  /// Handle menu item clicks
  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    debugPrint('[SystemTray] Menu item clicked: ${menuItem.key}');
    switch (menuItem.key) {
      case 'open':
        _handleOpenWindow();
        break;
      case 'lock':
        _handleLockVault();
        break;
      case 'quit':
        _handleQuit();
        break;
    }
  }

  /// F195: Handle "Open" menu item - show main window
  void _handleOpenWindow() {
    // This will be implemented when we have proper window management
    debugPrint('[SystemTray] Open window requested');
  }

  /// F196: Handle "Lock" menu item - lock vault via daemon
  void _handleLockVault() {
    // This will be implemented with VaultProvider access
    debugPrint('[SystemTray] Lock vault requested');
  }

  /// F197: Handle "Quit" menu item - exit app
  void _handleQuit() {
    debugPrint('[SystemTray] Quit requested');
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    // Wrap the app with ChangeNotifierProvider to provide VaultProvider
    return ChangeNotifierProvider.value(
      value: widget.vaultProvider,
      child: MaterialApp(
        title: 'Secretariat',
        // F204: Apply theme to MaterialApp
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.system,
        // Set MainPopup as home screen
        home: const MainPopup(),
        // Define routes for navigation
        routes: {
          '/secrets-list': (context) => const SecretsListScreen(),
          '/secret-detail': (context) => const SecretDetailScreen(),
          '/add-secret': (context) => const AddSecretScreen(),
          '/applications': (context) => const ApplicationsScreen(),
        },
      ),
    );
  }
}
