// F157-F160: Main popup screen for Secretariat app
//
// Features:
// - F157: Create lib/screens/main_popup.dart file
// - F158: Define MainPopup extends StatefulWidget
// - F159: Add TextEditingController for search field
// - F160: Add TextField with autofocus: true for search

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/secret.dart';
import '../providers/vault_provider.dart';

/// F158: Define MainPopup extends StatefulWidget
///
/// Main popup screen for the Secretariat menu bar app.
///
/// This is a compact popup suitable for quick access to secrets.
/// Features:
/// - Search field with autofocus (F160)
/// - Filtered list of secrets
/// - Quick actions (copy, view, etc.)
///
/// Example usage:
/// ```dart
/// MaterialApp(
///   home: ChangeNotifierProvider(
///     create: (_) => VaultProvider(),
///     child: MainPopup(),
///   ),
/// )
/// ```
class MainPopup extends StatefulWidget {
  const MainPopup({super.key});

  @override
  State<MainPopup> createState() => _MainPopupState();
}

class _MainPopupState extends State<MainPopup> {
  /// F159: Add TextEditingController for search field
  ///
  /// Controller for the search text field.
  /// Used to filter secrets by name, provider, or notes.
  late final TextEditingController _searchController;

  /// Filtered list of secrets based on search query
  List<Secret> _filteredSecrets = [];

  @override
  void initState() {
    super.initState();
    // F159: Initialize TextEditingController
    _searchController = TextEditingController();

    // Listen to search changes
    _searchController.addListener(_onSearchChanged);

    // Load secrets on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vaultProvider = Provider.of<VaultProvider>(context, listen: false);
      if (!vaultProvider.isConnected) {
        vaultProvider
            .connect()
            .then((_) {
              vaultProvider.loadSecrets();
            })
            .catchError((e) {
              _showError('Failed to connect: $e');
            });
      } else {
        vaultProvider.loadSecrets().catchError((e) {
          _showError('Failed to load secrets: $e');
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// F161: Handle search query changes with filtering
  void _onSearchChanged() {
    setState(() {
      final vaultProvider = Provider.of<VaultProvider>(context, listen: false);
      _filteredSecrets = vaultProvider.filterSecrets(_searchController.text);
    });
  }

  /// Get recent secrets (last 5)
  List<Secret> _getRecentSecrets(List<Secret> secrets) {
    // Sort by updated_at (or created_at if never updated), newest first
    final sorted = List<Secret>.from(secrets);
    sorted.sort((a, b) {
      final aTime = a.updatedAt ?? a.createdAt;
      final bTime = b.updatedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    // F162: Return last 5 secrets
    return sorted.take(5).toList();
  }

  /// Show error message
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// Copy secret value to clipboard with auto-clear after 30 seconds
  Future<void> _copySecret(Secret secret) async {
    try {
      // Get the full secret with value from the daemon
      final vaultProvider = Provider.of<VaultProvider>(context, listen: false);
      final fullSecret = await vaultProvider.getSecret(secret.name);

      if (fullSecret == null || fullSecret.value == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to retrieve secret value'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: fullSecret.value!));

      if (!mounted) return;

      // Show success message with countdown hint
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

      // Schedule auto-clear after 30 seconds
      Future.delayed(const Duration(seconds: 30), () async {
        // Clear clipboard by setting empty data
        // Note: We can't verify if the same data is still there,
        // so we just clear it. This is a security best practice.
        await Clipboard.setData(const ClipboardData(text: ''));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secretariat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final vaultProvider = Provider.of<VaultProvider>(
                context,
                listen: false,
              );
              vaultProvider.refreshSecrets();
            },
            tooltip: 'Refresh secrets',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/add-secret');
            },
            tooltip: 'Add secret',
          ),
        ],
      ),
      body: Consumer<VaultProvider>(
        builder: (context, vaultProvider, child) {
          // Update filtered secrets when provider changes
          if (_searchController.text.isEmpty) {
            _filteredSecrets = vaultProvider.secrets;
          } else {
            _filteredSecrets = vaultProvider.filterSecrets(
              _searchController.text,
            );
          }

          return Column(
            children: [
              // F160: Add TextField with autofocus: true for search
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  autofocus: true, // F160: autofocus enabled
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
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),

              // Loading indicator
              if (vaultProvider.isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),

              // Error message
              if (vaultProvider.errorMessage != null &&
                  !vaultProvider.isLoading)
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

              // F162: Display recent secrets (last 5) or filtered list
              if (!vaultProvider.isLoading &&
                  vaultProvider.errorMessage == null)
                Expanded(
                  child: _filteredSecrets.isEmpty
                      ? Center(
                          child: Text(
                            _searchController.text.isEmpty
                                ? 'No secrets yet.\nClick + to add one.'
                                : 'No secrets match "${_searchController.text}"',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // F162: Show "Recent Secrets" header when not searching
                            if (_searchController.text.isEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  8,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Recent Secrets',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/secrets-list',
                                        );
                                      },
                                      child: const Text('View All'),
                                    ),
                                  ],
                                ),
                              ),
                            // F162: ListView for recent secrets (last 5)
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

              // Status bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border(
                    top: BorderSide(color: Theme.of(context).dividerColor),
                  ),
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
                              ? Colors.red
                              : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          vaultProvider.isLocked ? 'Locked' : 'Unlocked',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_filteredSecrets.length} secret${_filteredSecrets.length != 1 ? 's' : ''}',
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
      // F163: Add "Add Secret" FloatingActionButton
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add-secret');
        },
        tooltip: 'Add Secret',
        child: const Icon(Icons.add),
      ),
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
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getProviderColor(secret.provider),
        child: Text(
          secret.name.substring(0, 1).toUpperCase(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(secret.name),
      subtitle: secret.provider != null
          ? Text(
              secret.provider!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.copy),
        onPressed: onCopy,
        tooltip: 'Copy to clipboard',
      ),
      onTap: () {
        Navigator.pushNamed(context, '/secret-detail', arguments: secret);
      },
    );
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
}
