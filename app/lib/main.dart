// Main entry point for Secretariat Flutter app
// Updated for Wave 21: Added routing for secrets list and detail screens
// Updated for Wave 22: Added routing for add secret and applications screens
// Updated for Wave 23: Added theme (F204) and system tray initialization (F192-F199)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:system_tray/system_tray.dart';
import 'dart:io' show Platform, exit;
import 'providers/vault_provider.dart';
import 'screens/main_popup.dart';
import 'screens/secrets_list.dart';
import 'screens/secret_detail.dart';
import 'screens/add_secret.dart';
import 'screens/applications.dart';
import 'theme/theme.dart';

// F192: Global system tray instance
final SystemTray _systemTray = SystemTray();

void main() async {
  // F192: Ensure Flutter is initialized before system tray setup
  WidgetsFlutterBinding.ensureInitialized();

  // F192: Initialize system tray on app start
  await _initSystemTray();

  runApp(const SecretariatApp());
}

/// F192-F199: Initialize system tray with icons and menu
Future<void> _initSystemTray() async {
  // Skip system tray on unsupported platforms
  if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
    return;
  }

  try {
    // F193: Set initial icon to locked state
    await _systemTray.initSystemTray(
      iconPath: 'assets/tray_locked.png',
    );

    // F194: Create menu with items: "Open", "Lock", "Quit"
    final Menu menu = Menu();
    await menu.buildFrom([
      // F195: "Open" menu item to show main window
      MenuItemLabel(
        label: 'Open',
        onClicked: (menuItem) => _handleOpenWindow(),
      ),
      MenuSeparator(),
      // F196: "Lock" menu item to lock vault via daemon
      MenuItemLabel(
        label: 'Lock',
        onClicked: (menuItem) => _handleLockVault(),
      ),
      MenuSeparator(),
      // F197: "Quit" menu item to exit app
      MenuItemLabel(
        label: 'Quit',
        onClicked: (menuItem) => _handleQuit(),
      ),
    ]);

    await _systemTray.setContextMenu(menu);
  } catch (e) {
    debugPrint('Failed to initialize system tray: $e');
  }
}

/// F195: Handle "Open" menu item - show main window
void _handleOpenWindow() {
  // This will be implemented when we have proper window management
  debugPrint('Open window requested');
}

/// F196: Handle "Lock" menu item - lock vault via daemon
void _handleLockVault() {
  // This will be implemented with VaultProvider access
  debugPrint('Lock vault requested');
}

/// F197: Handle "Quit" menu item - exit app
void _handleQuit() {
  exit(0);
}

/// F198-F199: Update tray icon based on vault lock state
Future<void> updateTrayIcon(bool isLocked) async {
  try {
    // F199: Update tray icon when vault is unlocked
    final iconPath = isLocked ? 'assets/tray_locked.png' : 'assets/tray_unlocked.png';
    await _systemTray.setImage(iconPath);
  } catch (e) {
    debugPrint('Failed to update tray icon: $e');
  }
}

class SecretariatApp extends StatelessWidget {
  const SecretariatApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap the app with ChangeNotifierProvider to provide VaultProvider
    return ChangeNotifierProvider(
      create: (_) => VaultProvider(),
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
