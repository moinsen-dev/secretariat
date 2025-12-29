// Main Shell - Bottom navigation container for Secretariat app
//
// Provides tabbed navigation between:
// - Home (recent secrets + search)
// - Secrets (full list with sort/filter)
// - Apps (application permissions)
// - Settings (configuration, lock, import, audit)
//
// Also handles vault lock state and displays unlock dialog when needed.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vault_provider.dart';
import '../theme/colors.dart';
import '../widgets/vault_unlock_dialog.dart';
import 'home_tab.dart';
import 'secrets_list_tab.dart';
import 'applications_tab.dart';
import 'settings_tab.dart';

/// Global key to access MainShell state for keyboard navigation
final GlobalKey<MainShellState> mainShellKey = GlobalKey<MainShellState>();

/// Main shell widget with bottom navigation
///
/// This is the primary container for the app after onboarding.
/// Uses IndexedStack to preserve state across tab switches.
/// Shows unlock dialog when vault is locked.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _showingUnlockDialog = false;
  VaultProvider? _vaultProvider;

  // Tab titles for app bar
  static const List<String> _tabTitles = [
    'Secretariat',
    'All Secrets',
    'Applications',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    // Schedule vault status check after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVaultStatus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to vault provider changes
    final provider = Provider.of<VaultProvider>(context, listen: false);
    if (_vaultProvider != provider) {
      _vaultProvider?.removeListener(_onVaultStateChanged);
      _vaultProvider = provider;
      _vaultProvider?.addListener(_onVaultStateChanged);
    }
  }

  @override
  void dispose() {
    _vaultProvider?.removeListener(_onVaultStateChanged);
    super.dispose();
  }

  /// Check vault status and show unlock dialog if locked
  Future<void> _checkVaultStatus() async {
    if (!mounted) return;

    final provider = Provider.of<VaultProvider>(context, listen: false);

    try {
      // Try to connect and get vault status
      if (!provider.isConnected) {
        await provider.connect();
      }

      final status = await provider.getVaultStatus();
      final state = status['state'] as String?;

      if (state == 'locked' && !_showingUnlockDialog) {
        _showUnlockDialog();
      } else if (state == 'unlocked') {
        // Load secrets if vault is unlocked
        await provider.loadSecrets();
        await provider.loadApplications();
      }
    } catch (e) {
      debugPrint('[MainShell] Error checking vault status: $e');
    }
  }

  /// Called when vault state changes
  void _onVaultStateChanged() {
    if (!mounted) return;

    final provider = _vaultProvider;
    if (provider == null) return;

    // Show unlock dialog if vault becomes locked
    if (provider.isLocked && !_showingUnlockDialog) {
      _showUnlockDialog();
    }
  }

  /// Show the vault unlock dialog
  void _showUnlockDialog() {
    if (_showingUnlockDialog) return;

    _showingUnlockDialog = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (dialogContext) => VaultUnlockDialog(
        onUnlock: (password) async {
          final provider = Provider.of<VaultProvider>(context, listen: false);
          await provider.unlockVault(password);
          // Load data after unlock
          await provider.loadSecrets();
          await provider.loadApplications();
          // Close dialog
          if (mounted && Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
          _showingUnlockDialog = false;
        },
        onTouchIdUnlock: () async {
          // Touch ID authentication is handled by the dialog
          // After successful auth, we still need to unlock with stored password
          // For now, this is a placeholder - full implementation would need
          // keychain integration to retrieve the password
          final provider = Provider.of<VaultProvider>(context, listen: false);
          // In a full implementation, retrieve password from keychain here
          await provider.loadSecrets();
          await provider.loadApplications();
          if (mounted && Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
          _showingUnlockDialog = false;
        },
        touchIdEnabled: true,
      ),
    ).then((_) {
      _showingUnlockDialog = false;
    });
  }

  /// Navigate to a specific tab (used by keyboard shortcuts)
  void navigateToTab(int index) {
    if (index >= 0 && index < 4) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        backgroundColor: surfaceDark,
        title: Text(
          _tabTitles[_currentIndex],
          style: TextStyle(
            color: textPrimaryDark,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Refresh button (visible on Home and Secrets tabs)
          if (_currentIndex == 0 || _currentIndex == 1)
            IconButton(
              icon: Icon(Icons.refresh, color: textPrimaryDark),
              onPressed: () {
                final vaultProvider = Provider.of<VaultProvider>(
                  context,
                  listen: false,
                );
                vaultProvider.refreshSecrets();
              },
              tooltip: 'Refresh',
            ),
          // Add button (visible on Home and Secrets tabs)
          if (_currentIndex == 0 || _currentIndex == 1)
            IconButton(
              icon: Icon(Icons.add, color: textPrimaryDark),
              onPressed: () {
                Navigator.pushNamed(context, '/add-secret');
              },
              tooltip: 'Add Secret',
            ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          // Tab 0: Home (recent secrets + search)
          HomeTab(),
          // Tab 1: All Secrets (full list with sort)
          SecretsListTab(),
          // Tab 2: Applications
          ApplicationsTab(),
          // Tab 3: Settings
          SettingsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: surfaceDark,
        selectedItemColor: accentColor,
        unselectedItemColor: textSecondaryDark,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: [
          BottomNavigationBarItem(
            icon: Semantics(
              label: 'Home, tab 1 of 4',
              child: const Icon(Icons.home_outlined),
            ),
            activeIcon: Semantics(
              label: 'Home, tab 1 of 4, selected',
              child: const Icon(Icons.home),
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Semantics(
              label: 'Secrets, tab 2 of 4',
              child: const Icon(Icons.key_outlined),
            ),
            activeIcon: Semantics(
              label: 'Secrets, tab 2 of 4, selected',
              child: const Icon(Icons.key),
            ),
            label: 'Secrets',
          ),
          BottomNavigationBarItem(
            icon: Semantics(
              label: 'Applications, tab 3 of 4',
              child: const Icon(Icons.apps_outlined),
            ),
            activeIcon: Semantics(
              label: 'Applications, tab 3 of 4, selected',
              child: const Icon(Icons.apps),
            ),
            label: 'Apps',
          ),
          BottomNavigationBarItem(
            icon: Semantics(
              label: 'Settings, tab 4 of 4',
              child: const Icon(Icons.settings_outlined),
            ),
            activeIcon: Semantics(
              label: 'Settings, tab 4 of 4, selected',
              child: const Icon(Icons.settings),
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
