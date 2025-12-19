// F164-F170: Secrets List Screen for Secretariat app
//
// Features:
// - F164: Create lib/screens/secrets_list.dart file
// - F165: Fetch secrets from VaultProvider using Provider.of
// - F166: Build ListView.builder with secrets (style)
// - F167: Implement ListTile for each secret with name and provider
// - F168: Add search TextField with debounce (300ms) using Timer
// - F169: Add sort dropdown (by name, by created, by updated)
// - F170: Implement onTap to navigate to SecretDetail screen

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/secret.dart';
import '../providers/vault_provider.dart';
import '../widgets/empty_state.dart';

/// Sort order options for secrets list
enum SecretSortOrder {
  name,
  created,
  updated,
}

/// F164: Create lib/screens/secrets_list.dart file
///
/// Full list screen showing all secrets with search and sort capabilities.
///
/// Features:
/// - Search with debounce to avoid excessive API calls (F168)
/// - Sort by name, created date, or updated date (F169)
/// - Navigate to detail screen on tap (F170)
///
/// Example usage:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (context) => SecretsListScreen()),
/// )
/// ```
class SecretsListScreen extends StatefulWidget {
  const SecretsListScreen({super.key});

  @override
  State<SecretsListScreen> createState() => _SecretsListScreenState();
}

class _SecretsListScreenState extends State<SecretsListScreen> {
  /// F168: TextEditingController for search field with debounce
  late final TextEditingController _searchController;

  /// F168: Timer for debouncing search input (300ms)
  Timer? _debounceTimer;

  /// Current search query
  String _searchQuery = '';

  /// F169: Current sort order
  SecretSortOrder _sortOrder = SecretSortOrder.name;

  /// Filtered and sorted secrets
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
                backgroundColor: Colors.red,
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

  /// F168: Handle search changes with debounce (300ms)
  void _onSearchChanged() {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Start new timer for 300ms debounce
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  /// F169: Sort secrets based on selected sort order
  List<Secret> _sortSecrets(List<Secret> secrets) {
    final sorted = List<Secret>.from(secrets);

    switch (_sortOrder) {
      case SecretSortOrder.name:
        sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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

  /// Get provider icon based on provider name
  IconData _getProviderIcon(String? provider) {
    if (provider == null) return Icons.key;

    final lowerProvider = provider.toLowerCase();
    if (lowerProvider.contains('openai')) return Icons.smart_toy;
    if (lowerProvider.contains('anthropic')) return Icons.psychology;
    if (lowerProvider.contains('stripe')) return Icons.payment;
    if (lowerProvider.contains('github')) return Icons.code;
    if (lowerProvider.contains('aws')) return Icons.cloud;
    if (lowerProvider.contains('google')) return Icons.business;

    return Icons.vpn_key;
  }

  /// Get color for provider badge
  Color _getProviderColor(String? provider) {
    if (provider == null) return Colors.grey;

    final hash = provider.hashCode;
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
    ];

    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Secrets'),
        actions: [
          // F169: Sort dropdown
          PopupMenuButton<SecretSortOrder>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onSelected: (SecretSortOrder order) {
              setState(() {
                _sortOrder = order;
              });
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: SecretSortOrder.name,
                child: Row(
                  children: [
                    Icon(
                      Icons.sort_by_alpha,
                      color: _sortOrder == SecretSortOrder.name
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Sort by Name',
                      style: TextStyle(
                        color: _sortOrder == SecretSortOrder.name
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SecretSortOrder.created,
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: _sortOrder == SecretSortOrder.created
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Sort by Created',
                      style: TextStyle(
                        color: _sortOrder == SecretSortOrder.created
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SecretSortOrder.updated,
                child: Row(
                  children: [
                    Icon(
                      Icons.update,
                      color: _sortOrder == SecretSortOrder.updated
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Sort by Updated',
                      style: TextStyle(
                        color: _sortOrder == SecretSortOrder.updated
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<VaultProvider>(
        builder: (context, vaultProvider, child) {
          // F165: Fetch secrets from VaultProvider using Provider.of
          // Filter and sort secrets
          var secrets = vaultProvider.secrets;

          // Apply search filter
          if (_searchQuery.isNotEmpty) {
            secrets = vaultProvider.filterSecrets(_searchQuery);
          }

          // F169: Apply sort order
          _displaySecrets = _sortSecrets(secrets);

          return Column(
            children: [
              // F168: Add search TextField with debounce (300ms)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search secrets...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),

              // Loading indicator
              if (vaultProvider.isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),

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
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            vaultProvider.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              vaultProvider.loadSecrets();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // F166: Build ListView.builder with secrets (style)
              if (!vaultProvider.isLoading && vaultProvider.errorMessage == null)
                Expanded(
                  child: _displaySecrets.isEmpty
                      ? EmptyState(
                          icon: _searchQuery.isEmpty ? Icons.vpn_key_off : Icons.search_off,
                          title: _searchQuery.isEmpty
                              ? 'No secrets yet'
                              : 'No matching secrets',
                          message: _searchQuery.isEmpty
                              ? 'Add your first secret to get started'
                              : 'Try a different search term',
                        )
                      : ListView.builder(
                          itemCount: _displaySecrets.length,
                          itemBuilder: (context, index) {
                            final secret = _displaySecrets[index];
                            // F167: Implement ListTile for each secret with name and provider
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getProviderColor(secret.provider),
                                child: Icon(
                                  _getProviderIcon(secret.provider),
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                secret.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: secret.provider != null
                                  ? Text(
                                      secret.provider!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    )
                                  : null,
                              trailing: Icon(
                                Icons.chevron_right,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              // F170: Implement onTap to navigate to SecretDetail screen
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/secret-detail',
                                  arguments: secret,
                                );
                              },
                            );
                          },
                        ),
                ),

              // Status bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _searchQuery.isEmpty
                          ? 'Showing all secrets'
                          : 'Filtered results',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${_displaySecrets.length} secret${_displaySecrets.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
