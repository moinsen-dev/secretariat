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
import '../services/logger_service.dart';
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
        await provider.loadEnvironments();
      }
    } catch (e) {
      Log.ui('Error checking vault status', error: e);
    }
  }

  /// Show panic confirmation dialog
  void _showPanicConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text(
              'Emergency Lockdown',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: const Text(
          'This will immediately:\n\n'
          '• Lock the vault\n'
          '• Revoke ALL application permissions\n'
          '• Log this emergency action\n\n'
          'Are you sure you want to proceed?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _executePanic();
            },
            child: const Text('PANIC'),
          ),
        ],
      ),
    );
  }

  /// Execute the panic command
  Future<void> _executePanic() async {
    final provider = Provider.of<VaultProvider>(context, listen: false);
    try {
      await provider.panic();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency lockdown executed. Vault locked and all access revoked.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Panic failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
  void _showUnlockDialog() async {
    if (_showingUnlockDialog) return;

    _showingUnlockDialog = true;

    // Check if biometric unlock is available
    final provider = Provider.of<VaultProvider>(context, listen: false);
    final biometricStatus = await provider.getBiometricStatus();
    final biometricAvailable = biometricStatus['available'] == true;
    final biometricEnabled = biometricStatus['enabled'] == true;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (dialogContext) => VaultUnlockDialog(
        onUnlock: (password) async {
          final vaultProvider =
              Provider.of<VaultProvider>(context, listen: false);
          // Capture navigator before async gap to avoid use_build_context_synchronously
          final navigator = Navigator.of(dialogContext);

          // Enable biometric on first successful unlock if available
          // This stores the master key in keychain for future Touch ID unlock
          await vaultProvider.unlockVault(
            password,
            enableBiometric: biometricAvailable,
          );

          // Load data after unlock
          await vaultProvider.loadSecrets();
          await vaultProvider.loadApplications();
          // Close dialog
          if (mounted && navigator.canPop()) {
            navigator.pop();
          }
          _showingUnlockDialog = false;
        },
        onTouchIdUnlock: biometricEnabled
            ? () async {
                final vaultProvider =
                    Provider.of<VaultProvider>(context, listen: false);
                // Capture navigator before async gap
                final navigator = Navigator.of(dialogContext);

                // Unlock using biometric - daemon will retrieve key from keychain
                await vaultProvider.unlockVaultBiometric();

                // Load data after unlock
                await vaultProvider.loadSecrets();
                await vaultProvider.loadApplications();

                // Close dialog
                if (mounted && navigator.canPop()) {
                  navigator.pop();
                }
                _showingUnlockDialog = false;
              }
            : null,
        touchIdEnabled: biometricAvailable,
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

  /// Get icon for environment
  IconData _getEnvironmentIcon(String env) {
    switch (env.toLowerCase()) {
      case 'prod':
      case 'production':
        return Icons.rocket_launch;
      case 'staging':
        return Icons.science;
      case 'dev':
      case 'development':
        return Icons.code;
      case 'test':
      case 'testing':
        return Icons.bug_report;
      default:
        return Icons.folder;
    }
  }

  /// Get color for environment
  Color _getEnvironmentColor(String env) {
    switch (env.toLowerCase()) {
      case 'prod':
      case 'production':
        return Colors.red;
      case 'staging':
        return Colors.orange;
      case 'dev':
      case 'development':
        return Colors.green;
      case 'test':
      case 'testing':
        return Colors.blue;
      default:
        return Colors.grey;
    }
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
          // Environment selector (visible on Home and Secrets tabs)
          if (_currentIndex == 0 || _currentIndex == 1)
            Consumer<VaultProvider>(
              builder: (context, provider, child) {
                if (provider.environments.isEmpty || provider.environments.length <= 1) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: DropdownButton<String>(
                    value: provider.selectedEnvironment,
                    dropdownColor: surfaceDark,
                    underline: const SizedBox.shrink(),
                    icon: Icon(Icons.arrow_drop_down, color: textSecondaryDark),
                    items: provider.environments.map((env) {
                      return DropdownMenuItem<String>(
                        value: env,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getEnvironmentIcon(env),
                              size: 16,
                              color: _getEnvironmentColor(env),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              env,
                              style: TextStyle(
                                color: textPrimaryDark,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        provider.setEnvironment(value);
                      }
                    },
                  ),
                );
              },
            ),
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
          // Panic button (always visible)
          IconButton(
            icon: const Icon(Icons.emergency, color: Colors.red),
            onPressed: _showPanicConfirmation,
            tooltip: 'Emergency Lockdown',
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
