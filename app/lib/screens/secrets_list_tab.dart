// Secrets List Tab - Full secrets inventory for bottom navigation
//
// Embedded version of SecretsListScreen for use in MainShell.
// Shows all secrets with search and sort functionality.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/secret.dart';
import '../providers/vault_provider.dart';
import '../theme/colors.dart';

/// Sort order options for secrets list
enum SecretSortOrder { name, created, updated }

/// Secrets list tab content showing all secrets with search and sort
///
/// This is the body content for the Secrets tab in MainShell.
/// Does not include Scaffold or AppBar (provided by shell).
class SecretsListTab extends StatefulWidget {
  const SecretsListTab({super.key});

  @override
  State<SecretsListTab> createState() => _SecretsListTabState();
}

class _SecretsListTabState extends State<SecretsListTab> {
  late final TextEditingController _searchController;
  Timer? _debounceTimer;
  String _searchQuery = '';
  SecretSortOrder _sortOrder = SecretSortOrder.name;
  List<Secret> _displaySecrets = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);

    // Load secrets on init if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vaultProvider = Provider.of<VaultProvider>(context, listen: false);
      if (vaultProvider.secrets.isEmpty && !vaultProvider.isLoading) {
        vaultProvider.loadSecrets().catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load secrets: $e'),
                backgroundColor: errorColor,
              ),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  List<Secret> _sortSecrets(List<Secret> secrets) {
    final sorted = List<Secret>.from(secrets);
    switch (_sortOrder) {
      case SecretSortOrder.name:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case SecretSortOrder.created:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SecretSortOrder.updated:
        sorted.sort((a, b) {
          final aTime = a.updatedAt ?? a.createdAt;
          final bTime = b.updatedAt ?? b.createdAt;
          return bTime.compareTo(aTime);
        });
        break;
    }
    return sorted;
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

  Future<void> _copySecret(Secret secret) async {
    try {
      final vaultProvider = Provider.of<VaultProvider>(context, listen: false);
      final fullSecret = await vaultProvider.getSecret(secret.name);

      if (fullSecret == null || fullSecret.value == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to retrieve secret value'),
              backgroundColor: errorColor,
            ),
          );
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
      Future.delayed(const Duration(seconds: 30), () async {
        await Clipboard.setData(const ClipboardData(text: ''));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy: $e'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VaultProvider>(
      builder: (context, vaultProvider, child) {
        var secrets = vaultProvider.secrets;

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          secrets = vaultProvider.filterSecrets(_searchQuery);
        }

        // Apply sort order
        _displaySecrets = _sortSecrets(secrets);

        return Column(
          children: [
            // Search and sort row
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Search field
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: textPrimaryDark),
                      decoration: InputDecoration(
                        hintText: 'Search secrets...',
                        hintStyle: TextStyle(color: textHintDark),
                        prefixIcon: Icon(
                          Icons.search,
                          color: textSecondaryDark,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: textSecondaryDark,
                                ),
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sort dropdown
                  PopupMenuButton<SecretSortOrder>(
                    icon: Icon(Icons.sort, color: textSecondaryDark),
                    tooltip: 'Sort',
                    color: surfaceDark,
                    onSelected: (SecretSortOrder order) {
                      setState(() {
                        _sortOrder = order;
                      });
                    },
                    itemBuilder: (context) => [
                      _buildSortMenuItem(
                        SecretSortOrder.name,
                        Icons.sort_by_alpha,
                        'Name',
                      ),
                      _buildSortMenuItem(
                        SecretSortOrder.created,
                        Icons.schedule,
                        'Created',
                      ),
                      _buildSortMenuItem(
                        SecretSortOrder.updated,
                        Icons.update,
                        'Updated',
                      ),
                    ],
                  ),
                ],
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
                          onPressed: () => vaultProvider.loadSecrets(),
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
                child: _displaySecrets.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No secrets yet.\nTap + to add one.'
                              : 'No secrets match "$_searchQuery"',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textSecondaryDark),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _displaySecrets.length,
                        itemBuilder: (context, index) {
                          final secret = _displaySecrets[index];
                          return _SecretListItem(
                            secret: secret,
                            providerColor: _getProviderColor(secret.provider),
                            onCopy: () => _copySecret(secret),
                          );
                        },
                      ),
              ),

            // Status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: surfaceDark,
                border: Border(top: BorderSide(color: borderDark)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _searchQuery.isEmpty ? 'All secrets' : 'Filtered results',
                    style: TextStyle(fontSize: 12, color: textSecondaryDark),
                  ),
                  Row(
                    children: [
                      Icon(_getSortIcon(), size: 14, color: textSecondaryDark),
                      const SizedBox(width: 4),
                      Text(
                        '${_displaySecrets.length} secret${_displaySecrets.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  PopupMenuItem<SecretSortOrder> _buildSortMenuItem(
    SecretSortOrder order,
    IconData icon,
    String label,
  ) {
    final isSelected = _sortOrder == order;
    return PopupMenuItem(
      value: order,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? accentColor : textSecondaryDark,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            'Sort by $label',
            style: TextStyle(color: isSelected ? accentColor : textPrimaryDark),
          ),
        ],
      ),
    );
  }

  IconData _getSortIcon() {
    switch (_sortOrder) {
      case SecretSortOrder.name:
        return Icons.sort_by_alpha;
      case SecretSortOrder.created:
        return Icons.schedule;
      case SecretSortOrder.updated:
        return Icons.update;
    }
  }
}

/// Secret list item widget with accessibility support
class _SecretListItem extends StatelessWidget {
  final Secret secret;
  final Color providerColor;
  final VoidCallback onCopy;

  const _SecretListItem({
    required this.secret,
    required this.providerColor,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final providerLabel = secret.provider ?? 'unknown';

    return Semantics(
      label: '${secret.name} secret from $providerLabel provider',
      button: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderDark),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: providerColor,
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
            style: TextStyle(
              color: textPrimaryDark,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: secret.provider != null
              ? Text(
                  secret.provider!,
                  style: TextStyle(fontSize: 12, color: textSecondaryDark),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: 'Copy ${secret.name} to clipboard',
                button: true,
                child: IconButton(
                  icon: Icon(Icons.copy, color: textSecondaryDark, size: 20),
                  onPressed: onCopy,
                  tooltip: 'Copy to clipboard',
                ),
              ),
              Icon(Icons.chevron_right, color: textSecondaryDark),
            ],
          ),
          onTap: () {
            Navigator.pushNamed(context, '/secret-detail', arguments: secret);
          },
        ),
      ),
    );
  }
}
