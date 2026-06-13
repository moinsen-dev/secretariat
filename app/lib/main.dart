// Main entry point for Secretariat Flutter app
// Updated for Wave 21: Added routing for secrets list and detail screens
// Updated for Wave 22: Added routing for add secret and applications screens
// Updated for Wave 23: Added theme (F204) and system tray initialization (F192-F199)
// Updated for Phase 1 completion: Added keyboard shortcuts, onboarding, import wizard
// Migrated from system_tray to tray_manager (actively maintained package)
// Updated for Wireframes: Added window_manager, complete shortcuts, unlock dialog

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io' show Platform, exit;
import 'providers/vault_provider.dart';
import 'screens/main_shell.dart';
import 'screens/secrets_list.dart';
import 'screens/secret_detail.dart';
import 'screens/add_secret.dart';
import 'screens/applications.dart';
import 'screens/audit_log.dart';
import 'screens/settings.dart';
import 'screens/import_wizard.dart';
import 'screens/onboarding.dart';
import 'theme/theme.dart';

/// Key for storing onboarding completion status
const String _onboardingCompleteKey = 'onboarding_complete';

void main() async {
  // Ensure Flutter is initialized before platform plugins
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for desktop platforms
  await _initWindowManager();

  // F192: Initialize system tray on app start
  await _initSystemTray();

  // Check if onboarding has been completed
  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool(_onboardingCompleteKey) ?? false;

  // Initialize VaultProvider. iOS has no daemon — it opens a local vault via
  // the shared FFI crypto; desktop ensures the daemon is running.
  final vaultProvider = VaultProvider();
  if (Platform.isIOS) {
    await vaultProvider.initLocal();
  } else {
    await _ensureDaemonRunning(vaultProvider);
  }

  // Decide whether to show the create-master-password onboarding.
  // The persisted flag is only a fallback — the authoritative signal is the
  // daemon's vault state. A vault may already exist (e.g. created via the
  // `sec` CLI) even when this app has never run. In that case we must NOT
  // show "Create Master Password" (re-init would fail/clobber); we go to the
  // app shell, which shows the unlock dialog for the existing vault.
  bool showOnboarding = !onboardingComplete;
  try {
    final status = await vaultProvider.getVaultStatus();
    showOnboarding = status['state'] == 'uninitialized';
  } catch (e) {
    debugPrint('[Main] Could not read vault status, using onboarding flag: $e');
  }

  // Start E2E-encrypted iCloud background sync (no-op if iCloud unavailable).
  vaultProvider.startAutoSync();

  runApp(
    SecretariatApp(
      vaultProvider: vaultProvider,
      showOnboarding: showOnboarding,
    ),
  );
}

/// Initialize window manager with minimum size constraints
Future<void> _initWindowManager() async {
  // Only initialize on desktop platforms
  if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
    return;
  }

  try {
    await windowManager.ensureInitialized();

    // Set minimum window size (800x600 per wireframe spec)
    await windowManager.setMinimumSize(const Size(800, 600));

    // Set initial size if needed
    await windowManager.setSize(const Size(900, 700));

    // Center window on screen
    await windowManager.center();

    // Make window visible
    await windowManager.show();
    await windowManager.focus();

    debugPrint('[WindowManager] Initialized with minimum size 800x600');
  } catch (e) {
    debugPrint('[WindowManager] Failed to initialize: $e');
  }
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
  final bool showOnboarding;

  const SecretariatApp({
    super.key,
    required this.vaultProvider,
    this.showOnboarding = false,
  });

  @override
  State<SecretariatApp> createState() => _SecretariatAppState();
}

class _SecretariatAppState extends State<SecretariatApp> with TrayListener {
  /// The system tray + window manager only exist on desktop. On iOS these
  /// calls would throw MissingPluginException, so gate them out entirely.
  bool get _isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    // Register tray listener for menu clicks (desktop only)
    if (_isDesktop) TrayManager.instance.addListener(this);
    // Listen to vault state changes
    widget.vaultProvider.addListener(_onVaultStateChanged);
    // Initial tray menu setup
    if (_isDesktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateTrayMenu(isLocked: widget.vaultProvider.isLocked);
        updateTrayIcon(widget.vaultProvider.isLocked);
      });
    }
  }

  @override
  void dispose() {
    if (_isDesktop) TrayManager.instance.removeListener(this);
    widget.vaultProvider.removeListener(_onVaultStateChanged);
    super.dispose();
  }

  /// Called when vault state changes - update tray icon and menu
  void _onVaultStateChanged() {
    if (!_isDesktop) return;
    final isLocked = widget.vaultProvider.isLocked;
    updateTrayIcon(isLocked);
    _updateTrayMenu(isLocked: isLocked);
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
      case 'unlock':
        // Open window and trigger unlock dialog via MainShell
        _handleOpenWindow();
        break;
      case 'quit':
        _handleQuit();
        break;
    }
  }

  /// F195: Handle "Open" menu item - show main window
  void _handleOpenWindow() async {
    debugPrint('[SystemTray] Open window requested');
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('[SystemTray] Failed to show window: $e');
    }
  }

  /// F196: Handle "Lock" menu item - lock vault via daemon
  void _handleLockVault() async {
    debugPrint('[SystemTray] Lock vault requested');
    try {
      await widget.vaultProvider.lockVault();
      await updateTrayIcon(true);
      await _updateTrayMenu(isLocked: true);
    } catch (e) {
      debugPrint('[SystemTray] Failed to lock vault: $e');
    }
  }

  /// F197: Handle "Quit" menu item - exit app
  void _handleQuit() {
    debugPrint('[SystemTray] Quit requested');
    exit(0);
  }

  /// Update tray menu based on vault state
  Future<void> _updateTrayMenu({required bool isLocked}) async {
    try {
      final secretCount = widget.vaultProvider.secrets.length;
      final Menu menu = Menu(
        items: [
          // Status header
          MenuItem(
            key: 'status',
            label: isLocked ? 'Status: Locked' : 'Status: Unlocked',
            disabled: true,
          ),
          if (!isLocked)
            MenuItem(
              key: 'secrets',
              label: 'Secrets: $secretCount',
              disabled: true,
            ),
          MenuItem.separator(),
          // F195: "Open" menu item to show main window
          MenuItem(key: 'open', label: 'Open Window'),
          MenuItem.separator(),
          // F196: Lock/Unlock menu item
          isLocked
              ? MenuItem(key: 'unlock', label: 'Unlock Vault...')
              : MenuItem(key: 'lock', label: 'Lock Vault'),
          MenuItem.separator(),
          // F197: "Quit" menu item to exit app
          MenuItem(key: 'quit', label: 'Quit'),
        ],
      );

      await TrayManager.instance.setContextMenu(menu);
    } catch (e) {
      debugPrint('[SystemTray] Failed to update menu: $e');
    }
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
        // Show onboarding on first run, otherwise show main shell with tabs
        home: widget.showOnboarding
            ? const OnboardingScreen()
            : KeyboardShortcutHandler(child: MainShell(key: mainShellKey)),
        // Define routes for navigation
        routes: {
          '/home': (context) =>
              KeyboardShortcutHandler(child: MainShell(key: mainShellKey)),
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
/// Implements keyboard shortcuts from wireframe section 6.1:
/// - Cmd+K: Quick search (focus)
/// - Cmd+L: Lock vault
/// - Cmd+N: Add new secret
/// - Cmd+F: Focus search (same as Cmd+K)
/// - Cmd+Q: Quit application
/// - Cmd+W: Close/minimize window
/// - Cmd+1-4: Navigate to tabs
/// - Cmd+,: Open settings
/// - Cmd+I: Open import wizard
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

        // Cmd+K / Ctrl+K: Quick search (same as Cmd+F)
        SingleActivator(
          LogicalKeyboardKey.keyK,
          meta: Platform.isMacOS,
          control: !Platform.isMacOS,
        ): const FocusSearchIntent(),

        // Cmd+L / Ctrl+L: Lock vault
        SingleActivator(
          LogicalKeyboardKey.keyL,
          meta: Platform.isMacOS,
          control: !Platform.isMacOS,
        ): const LockVaultIntent(),

        // Cmd+Q / Ctrl+Q: Quit application
        SingleActivator(
          LogicalKeyboardKey.keyQ,
          meta: Platform.isMacOS,
          control: !Platform.isMacOS,
        ): const QuitAppIntent(),

        // Cmd+W / Ctrl+W: Close/minimize window
        SingleActivator(
          LogicalKeyboardKey.keyW,
          meta: Platform.isMacOS,
          control: !Platform.isMacOS,
        ): const MinimizeWindowIntent(),

        // Cmd+1 / Ctrl+1: Go to Home tab
        SingleActivator(
          LogicalKeyboardKey.digit1,
          meta: Platform.isMacOS,
          control: !Platform.isMacOS,
        ): const NavigateToTabIntent(
          0,
        ),

        // Cmd+2 / Ctrl+2: Go to Secrets tab
        SingleActivator(
          LogicalKeyboardKey.digit2,
          meta: Platform.isMacOS,
          control: !Platform.isMacOS,
        ): const NavigateToTabIntent(
          1,
        ),

        // Cmd+3 / Ctrl+3: Go to Apps tab
        SingleActivator(
          LogicalKeyboardKey.digit3,
          meta: Platform.isMacOS,
          control: !Platform.isMacOS,
        ): const NavigateToTabIntent(
          2,
        ),

        // Cmd+4 / Ctrl+4: Go to Settings tab
        SingleActivator(
          LogicalKeyboardKey.digit4,
          meta: Platform.isMacOS,
          control: !Platform.isMacOS,
        ): const NavigateToTabIntent(
          3,
        ),

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
          LockVaultIntent: LockVaultAction(),
          QuitAppIntent: QuitAppAction(),
          MinimizeWindowIntent: MinimizeWindowAction(),
          NavigateToTabIntent: NavigateToTabAction(),
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

/// Intent for locking vault (Cmd+L)
class LockVaultIntent extends Intent {
  const LockVaultIntent();
}

/// Action for locking vault
class LockVaultAction extends Action<LockVaultIntent> {
  @override
  Object? invoke(LockVaultIntent intent) {
    final context = primaryFocus?.context;
    if (context != null) {
      final provider = Provider.of<VaultProvider>(context, listen: false);
      provider.lockVault();
    }
    return null;
  }
}

/// Intent for quitting app (Cmd+Q)
class QuitAppIntent extends Intent {
  const QuitAppIntent();
}

/// Action for quitting app
class QuitAppAction extends Action<QuitAppIntent> {
  @override
  Object? invoke(QuitAppIntent intent) {
    debugPrint('[KeyboardShortcuts] Quit app requested');
    exit(0);
  }
}

/// Intent for minimizing window (Cmd+W)
class MinimizeWindowIntent extends Intent {
  const MinimizeWindowIntent();
}

/// Action for minimizing window
class MinimizeWindowAction extends Action<MinimizeWindowIntent> {
  @override
  Object? invoke(MinimizeWindowIntent intent) {
    debugPrint('[KeyboardShortcuts] Minimize window requested');
    windowManager.minimize();
    return null;
  }
}

/// Intent for navigating to a specific tab (Cmd+1-4)
class NavigateToTabIntent extends Intent {
  final int tabIndex;
  const NavigateToTabIntent(this.tabIndex);
}

/// Action for navigating to a specific tab
class NavigateToTabAction extends Action<NavigateToTabIntent> {
  @override
  Object? invoke(NavigateToTabIntent intent) {
    debugPrint('[KeyboardShortcuts] Navigate to tab ${intent.tabIndex}');
    // Use the global key to access MainShell state
    mainShellKey.currentState?.navigateToTab(intent.tabIndex);
    return null;
  }
}
