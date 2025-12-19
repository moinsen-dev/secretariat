// F187-F190: Applications Screen for Secretariat app
//
// Features:
// - F187: Create lib/screens/applications.dart file
// - F188: Fetch applications from daemon (via VaultProvider)
// - F189: Build ListView of apps with permissions count (style)
// - F190: Add ExpansionTile to show permissions for each app

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/application.dart';
import '../models/secret.dart';
import '../providers/vault_provider.dart';

/// F187: Create lib/screens/applications.dart file
///
/// Screen showing all registered applications and their permissions.
///
/// Features:
/// - List of applications with permission counts (F189)
/// - Expandable tiles to show detailed permissions (F190)
/// - Fetch data from daemon via VaultProvider (F188)
class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  @override
  void initState() {
    super.initState();
    // F188: Fetch applications from daemon
    _loadApplications();
  }

  /// Load applications from daemon
  Future<void> _loadApplications() async {
    final vaultProvider = Provider.of<VaultProvider>(context, listen: false);
    try {
      await vaultProvider.loadApplications();
      // Also load secrets to resolve permission names
      await vaultProvider.loadSecrets();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load applications: $e')),
        );
      }
    }
  }

  /// Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years != 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months != 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays != 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours != 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes != 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  /// Get secret name by ID
  String _getSecretName(String secretId, List<Secret> secrets) {
    final secret = secrets.firstWhere(
      (s) => s.id == secretId,
      orElse: () => Secret(
        id: secretId,
        name: 'Unknown Secret',
        value: '',
        createdAt: DateTime.now(),
      ),
    );
    return secret.name;
  }

  /// F191: Handle revoke permission action
  Future<void> _handleRevokePermission(
    String appId,
    String secretId,
    String secretName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Permission'),
        content: Text(
          'Are you sure you want to revoke access to "$secretName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final vaultProvider = Provider.of<VaultProvider>(context, listen: false);
      try {
        await vaultProvider.revokePermission(appId, secretId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Revoked access to "$secretName"'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to revoke permission: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Applications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApplications,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<VaultProvider>(
        builder: (context, vaultProvider, child) {
          if (vaultProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vaultProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    vaultProvider.errorMessage!,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loadApplications,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final applications = vaultProvider.applications;
          final secrets = vaultProvider.secrets;

          if (applications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.apps,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Applications Registered',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Applications will appear here when they\nrequest access to your secrets',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // F189: Build ListView of apps with permissions count (style)
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: applications.length,
            itemBuilder: (context, index) {
              final app = applications[index];
              return _ApplicationTile(
                application: app,
                secrets: secrets,
                formatTimestamp: _formatTimestamp,
                getSecretName: _getSecretName,
                onRevokePermission: _handleRevokePermission,
              );
            },
          );
        },
      ),
    );
  }
}

/// F190: Add ExpansionTile to show permissions for each app
///
/// Widget displaying a single application with expandable permissions.
class _ApplicationTile extends StatelessWidget {
  final Application application;
  final List<Secret> secrets;
  final String Function(DateTime) formatTimestamp;
  final String Function(String, List<Secret>) getSecretName;
  final Future<void> Function(String appId, String secretId, String secretName)
  onRevokePermission;

  const _ApplicationTile({
    required this.application,
    required this.secrets,
    required this.formatTimestamp,
    required this.getSecretName,
    required this.onRevokePermission,
  });

  @override
  Widget build(BuildContext context) {
    final permissionCount = application.permissions.length;
    final hasPermissions = permissionCount > 0;

    // F189: Build ListView of apps with permissions count (style)
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.apps,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          application.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (application.path != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      application.path!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                // Permissions count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: hasPermissions
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.key,
                        size: 12,
                        color: hasPermissions
                            ? Theme.of(context).colorScheme.onSecondaryContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$permissionCount permission${permissionCount != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: hasPermissions
                              ? Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Last access
                if (application.lastAccess != null)
                  Flexible(
                    child: Text(
                      'Last access: ${formatTimestamp(application.lastAccess!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  Flexible(
                    child: Text(
                      'Never accessed',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        // F190: Show permissions for each app when expanded
        children: [
          if (hasPermissions)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Granted Permissions',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // List of permissions
                  ...application.permissions.map((secretId) {
                    final secretName = getSecretName(secretId, secrets);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.vpn_key,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              secretName,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => onRevokePermission(
                              application.id,
                              secretId,
                              secretName,
                            ),
                            tooltip: 'Revoke permission',
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No permissions granted yet',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
