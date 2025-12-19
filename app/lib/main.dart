// Main entry point for Secretariat Flutter app
// Updated for Wave 21: Added routing for secrets list and detail screens
// Updated for Wave 22: Added routing for add secret and applications screens
// Updated for Wave 23: Added theme (F204) and system tray initialization (F192-F199)
// Updated for Phase 1 completion: Added keyboard shortcuts, onboarding, import wizard
// Migrated from system_tray to tray_manager (actively maintained package)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'dart:io' show Platform, exit;
import 'providers/vault_provider.dart';
import 'screens/main_popup.dart';
import 'screens/secrets_list.dart';
import 'screens/secret_detail.dart';
import 'screens/add_secret.dart';
import 'screens/applications.dart';
import 'screens/audit_log.dart';
import 'screens/settings.dart';
import 'screens/import_wizard.dart';
import 'screens/onboarding.dart';
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
        // Set MainPopup as home screen with keyboard shortcuts
        home: const KeyboardShortcutHandler(child: MainPopup()),
        // Define routes for navigation
        routes: {
          '/home': (context) => const KeyboardShortcutHandler(child: MainPopup()),
          '/secrets-list': (context) => const SecretsListScreen(),
          '/secret-detail': (context) => const SecretDetailScreen(),
          '/add-secret': (context) => const AddSecretScreen(),
          '/applications': (context) => const ApplicationsScreen(),
          '/audit-log': (context) => const AuditLogScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/import': (context) => const ImportWizardScreen(),
          '/onboarding': (context) => const OnboardingScreen(),
        },
      ),
    );
  }
}

/// Keyboard shortcuts handler for the app
///
/// Implements keyboard shortcuts from app_spec.txt lines 123-128:
/// - Cmd+Shift+S: Open Secretariat popup (handled by OS for global hotkey)
/// - Cmd+F: Focus search
/// - Cmd+N: Add new secret
/// - Cmd+C: Copy selected secret (handled by widgets)
/// - Esc: Close popup/dialog
class KeyboardShortcutHandler extends StatelessWidget {
  final Widget child;

  const KeyboardShortcutHandler({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        // Cmd+N / Ctrl+N: Add new secret
        SingleActivator(
          LogicalKeyboardKey.keyN,
          meta: Platform.isMacOS,
          control: !Platform.isMacOS,
        ): const AddSecretIntent(),

        // Cmd+F / Ctrl+F: Focus search
        SingleActivator(
          LogicalKeyboardKey.keyF,
          meta: Platform.isMacOS,
          control: !Platform.isMacOS,
        ): const FocusSearchIntent(),

        // Cmd+, / Ctrl+,: Open settings
        SingleActivator(
          LogicalKeyboardKey.comma,
          meta: Platform.isMacOS,
          control: !Platform.isMacOS,
        ): const OpenSettingsIntent(),

        // Cmd+I / Ctrl+I: Open import wizard
        SingleActivator(
          LogicalKeyboardKey.keyI,
          meta: Platform.isMacOS,
          control: !Platform.isMacOS,
        ): const OpenImportIntent(),

        // Esc: Close popup/go back
        const SingleActivator(LogicalKeyboardKey.escape): const CloseIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          AddSecretIntent: AddSecretAction(),
          FocusSearchIntent: FocusSearchAction(),
          OpenSettingsIntent: OpenSettingsAction(),
          OpenImportIntent: OpenImportAction(),
          CloseIntent: CloseAction(),
        },
        child: child,
      ),
    );
  }
}

/// Intent for adding a new secret (Cmd+N)
class AddSecretIntent extends Intent {
  const AddSecretIntent();
}

/// Action for adding a new secret
class AddSecretAction extends Action<AddSecretIntent> {
  @override
  Object? invoke(AddSecretIntent intent) {
    final context = primaryFocus?.context;
    if (context != null) {
      Navigator.of(context).pushNamed('/add-secret');
    }
    return null;
  }
}

/// Intent for focusing search (Cmd+F)
class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

/// Action for focusing search field
class FocusSearchAction extends Action<FocusSearchIntent> {
  @override
  Object? invoke(FocusSearchIntent intent) {
    // This will be handled by the MainPopup widget which has the search field
    // We broadcast via a notification or use a global key
    debugPrint('[KeyboardShortcuts] Focus search requested');
    return null;
  }
}

/// Intent for opening settings (Cmd+,)
class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

/// Action for opening settings
class OpenSettingsAction extends Action<OpenSettingsIntent> {
  @override
  Object? invoke(OpenSettingsIntent intent) {
    final context = primaryFocus?.context;
    if (context != null) {
      Navigator.of(context).pushNamed('/settings');
    }
    return null;
  }
}

/// Intent for opening import wizard (Cmd+I)
class OpenImportIntent extends Intent {
  const OpenImportIntent();
}

/// Action for opening import wizard
class OpenImportAction extends Action<OpenImportIntent> {
  @override
  Object? invoke(OpenImportIntent intent) {
    final context = primaryFocus?.context;
    if (context != null) {
      Navigator.of(context).pushNamed('/import');
    }
    return null;
  }
}

/// Intent for closing popup/going back (Esc)
class CloseIntent extends Intent {
  const CloseIntent();
}

/// Action for closing popup
class CloseAction extends Action<CloseIntent> {
  @override
  Object? invoke(CloseIntent intent) {
    final context = primaryFocus?.context;
    if (context != null && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    return null;
  }
}
