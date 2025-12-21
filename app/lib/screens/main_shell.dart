// Main Shell - Bottom navigation container for Secretariat app
//
// Provides tabbed navigation between:
// - Home (recent secrets + search)
// - Secrets (full list with sort/filter)
// - Apps (application permissions)
// - Settings (configuration, lock, import, audit)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vault_provider.dart';
import '../theme/colors.dart';
import 'home_tab.dart';
import 'secrets_list_tab.dart';
import 'applications_tab.dart';
import 'settings_tab.dart';

/// Main shell widget with bottom navigation
///
/// This is the primary container for the app after onboarding.
/// Uses IndexedStack to preserve state across tab switches.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // Tab titles for app bar
  static const List<String> _tabTitles = [
    'Secretariat',
    'All Secrets',
    'Applications',
    'Settings',
  ];

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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.key_outlined),
            activeIcon: Icon(Icons.key),
            label: 'Secrets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apps_outlined),
            activeIcon: Icon(Icons.apps),
            label: 'Apps',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
