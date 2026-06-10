// Home Tab - Recent secrets view for bottom navigation
//
// Embedded version of main_popup content for use in MainShell.
// Shows recent secrets (last 5) with search functionality.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/secret.dart';
import '../providers/vault_provider.dart';
import '../theme/colors.dart';
import '../utils/error_clipboard.dart';

/// Home tab content showing recent secrets and search
///
/// This is the body content for the Home tab in MainShell.
/// Does not include Scaffold, AppBar, or FAB (provided by shell).
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late final TextEditingController _searchController;
  List<Secret> _filteredSecrets = [];
  Timer? _clipboardClearTimer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);

    // Load secrets on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vaultProvider = Provider.of<VaultProvider>(context, listen: false);
      if (!vaultProvider.isConnected) {
        vaultProvider
            .connect()
            .then((_) => vaultProvider.loadSecrets())
            .catchError((e) => _showError('Failed to connect: $e'));
      } else {
        vaultProvider.loadSecrets().catchError(
          (e) => _showError('Failed to load secrets: $e'),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _clipboardClearTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      final vaultProvider = Provider.of<VaultProvider>(context, listen: false);
      _filteredSecrets = vaultProvider.filterSecrets(_searchController.text);
    });
  }

  List<Secret> _getRecentSecrets(List<Secret> secrets) {
    final sorted = List<Secret>.from(secrets);
    sorted.sort((a, b) {
      final aTime = a.updatedAt ?? a.createdAt;
      final bTime = b.updatedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    return sorted.take(5).toList();
  }

  void _showError(String message) {
    if (!mounted) return;
    copyErrorToClipboard(context, message);
  }

  Future<void> _copySecret(Secret secret) async {
    try {
      final vaultProvider = Provider.of<VaultProvider>(context, listen: false);
      final fullSecret = await vaultProvider.getSecret(secret.name);

      if (fullSecret == null || fullSecret.value == null) {
        if (mounted) {
          copyErrorToClipboard(context, 'Failed to retrieve secret value');
        }
        return;
      }

      await Clipboard.setData(ClipboardData(text: fullSecret.value!));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied ${secret.name} to clipboard (clears in 30s)'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Clear Now',
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: ''));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Clipboard cleared'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ),
      );

      // Auto-clear after 30 seconds
      _clipboardClearTimer?.cancel();
      _clipboardClearTimer = Timer(const Duration(seconds: 30), () async {
        await Clipboard.setData(const ClipboardData(text: ''));
      });
    } catch (e) {
      if (mounted) {
        copyErrorToClipboard(context, 'Failed to copy: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VaultProvider>(
      builder: (context, vaultProvider, child) {
        if (_searchController.text.isEmpty) {
          _filteredSecrets = vaultProvider.secrets;
        } else {
          _filteredSecrets = vaultProvider.filterSecrets(
            _searchController.text,
          );
        }

        return Column(
          children: [
            // Search field
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textPrimaryDark),
                decoration: InputDecoration(
                  hintText: 'Search secrets...',
                  hintStyle: TextStyle(color: textHintDark),
                  prefixIcon: Icon(Icons.search, color: textSecondaryDark),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: textSecondaryDark),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: accentColor),
                  ),
                  filled: true,
                  fillColor: surfaceVariantDark,
                ),
              ),
            ),

            // Loading indicator
            if (vaultProvider.isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator())),

            // Error message
            if (vaultProvider.errorMessage != null && !vaultProvider.isLoading)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: errorColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          vaultProvider.errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: errorColor),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            vaultProvider.connect().then((_) {
                              vaultProvider.loadSecrets();
                            });
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Secrets list
            if (!vaultProvider.isLoading && vaultProvider.errorMessage == null)
              Expanded(
                child: _filteredSecrets.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'No secrets yet.\nTap + to add one.'
                              : 'No secrets match "${_searchController.text}"',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textSecondaryDark),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          if (_searchController.text.isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: Text(
                                'Recent Secrets',
                                style: TextStyle(
                                  color: textSecondaryDark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          // List
                          Expanded(
                            child: ListView.builder(
                              itemCount: _searchController.text.isEmpty
                                  ? _getRecentSecrets(_filteredSecrets).length
                                  : _filteredSecrets.length,
                              itemBuilder: (context, index) {
                                final displaySecrets =
                                    _searchController.text.isEmpty
                                    ? _getRecentSecrets(_filteredSecrets)
                                    : _filteredSecrets;
                                final secret = displaySecrets[index];
                                return _SecretListItem(
                                  secret: secret,
                                  onCopy: () => _copySecret(secret),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),

            // Status bar with lock state
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: surfaceDark,
                border: Border(top: BorderSide(color: borderDark)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        vaultProvider.isLocked ? Icons.lock : Icons.lock_open,
                        size: 16,
                        color: vaultProvider.isLocked
                            ? lockedColor
                            : unlockedColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        vaultProvider.isLocked ? 'Locked' : 'Unlocked',
                        style: TextStyle(
                          fontSize: 12,
                          color: vaultProvider.isLocked
                              ? lockedColor
                              : unlockedColor,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${vaultProvider.secrets.length} secret${vaultProvider.secrets.length != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, color: textSecondaryDark),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Secret list item widget
class _SecretListItem extends StatelessWidget {
  final Secret secret;
  final VoidCallback onCopy;

  const _SecretListItem({required this.secret, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderDark),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getProviderColor(secret.provider),
          child: Text(
            secret.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          secret.name,
          style: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.w500),
        ),
        subtitle: secret.provider != null
            ? Text(
                secret.provider!,
                style: TextStyle(fontSize: 12, color: textSecondaryDark),
              )
            : null,
        trailing: IconButton(
          icon: Icon(Icons.copy, color: textSecondaryDark),
          onPressed: onCopy,
          tooltip: 'Copy to clipboard',
        ),
        onTap: () {
          Navigator.pushNamed(context, '/secret-detail', arguments: secret);
        },
      ),
    );
  }

  Color _getProviderColor(String? provider) {
    if (provider == null) return Colors.grey;
    final hash = provider.hashCode;
    final colors = [
      primaryColor,
      successColor,
      warningColor,
      secretColor,
      accentColor,
      applicationColor,
      infoColor,
      errorColor,
    ];
    return colors[hash.abs() % colors.length];
  }
}
