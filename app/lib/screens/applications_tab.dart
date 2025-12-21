// Applications Tab - Permission management for bottom navigation
//
// Embedded version of ApplicationsScreen for use in MainShell.
// Shows all registered applications and their permissions.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/application.dart';
import '../models/secret.dart';
import '../providers/vault_provider.dart';
import '../theme/colors.dart';

/// Applications tab content showing app permissions
///
/// This is the body content for the Apps tab in MainShell.
/// Does not include Scaffold or AppBar (provided by shell).
class ApplicationsTab extends StatefulWidget {
  const ApplicationsTab({super.key});

  @override
  State<ApplicationsTab> createState() => _ApplicationsTabState();
}

class _ApplicationsTabState extends State<ApplicationsTab> {
  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    final vaultProvider = Provider.of<VaultProvider>(context, listen: false);
    try {
      await vaultProvider.loadApplications();
      await vaultProvider.loadSecrets();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load applications: $e'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

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

  Future<void> _handleGrantPermission(String appId, String appName) async {
    final vaultProvider = Provider.of<VaultProvider>(context, listen: false);
    final secrets = vaultProvider.secrets;
    final app = vaultProvider.applications.firstWhere((a) => a.id == appId);

    final availableSecrets = secrets.where(
      (s) => !app.permissions.contains(s.id) && !app.permissions.contains(s.name),
    ).toList();

    if (availableSecrets.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All secrets already granted to this app')),
        );
      }
      return;
    }

    final selectedSecret = await showDialog<Secret>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceDark,
        title: Text(
          'Grant Permission to $appName',
          style: TextStyle(color: textPrimaryDark),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableSecrets.length,
            itemBuilder: (context, index) {
              final secret = availableSecrets[index];
              return ListTile(
                leading: Icon(Icons.vpn_key, color: accentColor),
                title: Text(
                  secret.name,
                  style: TextStyle(color: textPrimaryDark),
                ),
                subtitle: secret.provider != null
                    ? Text(
                        secret.provider!,
                        style: TextStyle(color: textSecondaryDark),
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(secret),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: textSecondaryDark)),
          ),
        ],
      ),
    );

    if (selectedSecret != null && mounted) {
      try {
        await vaultProvider.grantPermission(appId, selectedSecret.name);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Granted access to "${selectedSecret.name}"'),
              backgroundColor: successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to grant permission: $e'),
              backgroundColor: errorColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleRevokePermission(
    String appId,
    String secretId,
    String secretName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceDark,
        title: Text(
          'Revoke Permission',
          style: TextStyle(color: textPrimaryDark),
        ),
        content: Text(
          'Are you sure you want to revoke access to "$secretName"?',
          style: TextStyle(color: textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: textSecondaryDark)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Revoke', style: TextStyle(color: errorColor)),
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
              backgroundColor: successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to revoke permission: $e'),
              backgroundColor: errorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VaultProvider>(
      builder: (context, vaultProvider, child) {
        if (vaultProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (vaultProvider.errorMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: errorColor),
                  const SizedBox(height: 16),
                  Text(
                    vaultProvider.errorMessage!,
                    style: TextStyle(color: textPrimaryDark),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadApplications,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final applications = vaultProvider.applications;
        final secrets = vaultProvider.secrets;

        if (applications.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.apps,
                    size: 64,
                    color: applicationColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Applications Registered',
                    style: TextStyle(
                      color: textPrimaryDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Applications will appear here when they\nrequest access to your secrets',
                    style: TextStyle(color: textSecondaryDark),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

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
              onGrantPermission: _handleGrantPermission,
            );
          },
        );
      },
    );
  }
}

/// Application tile with expandable permissions
class _ApplicationTile extends StatelessWidget {
  final Application application;
  final List<Secret> secrets;
  final String Function(DateTime) formatTimestamp;
  final String Function(String, List<Secret>) getSecretName;
  final Future<void> Function(String appId, String secretId, String secretName)
      onRevokePermission;
  final Future<void> Function(String appId, String appName) onGrantPermission;

  const _ApplicationTile({
    required this.application,
    required this.secrets,
    required this.formatTimestamp,
    required this.getSecretName,
    required this.onRevokePermission,
    required this.onGrantPermission,
  });

  @override
  Widget build(BuildContext context) {
    final permissionCount = application.permissions.length;
    final hasPermissions = permissionCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderDark),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: applicationColor.withValues(alpha: 0.2),
            child: Icon(Icons.apps, color: applicationColor),
          ),
          title: Text(
            application.name,
            style: TextStyle(
              color: textPrimaryDark,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (application.path != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.folder_outlined, size: 14, color: textSecondaryDark),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        application.path!,
                        style: TextStyle(fontSize: 12, color: textSecondaryDark),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: hasPermissions
                          ? successColor.withValues(alpha: 0.2)
                          : surfaceVariantDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.key,
                          size: 12,
                          color: hasPermissions ? successColor : textSecondaryDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$permissionCount permission${permissionCount != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: hasPermissions ? successColor : textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Last access
                  Flexible(
                    child: Text(
                      application.lastAccess != null
                          ? 'Last: ${formatTimestamp(application.lastAccess!)}'
                          : 'Never accessed',
                      style: TextStyle(fontSize: 11, color: textSecondaryDark),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
          iconColor: textSecondaryDark,
          collapsedIconColor: textSecondaryDark,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: borderDark),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Granted Permissions',
                        style: TextStyle(
                          color: textPrimaryDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => onGrantPermission(
                          application.id,
                          application.name,
                        ),
                        icon: Icon(Icons.add, size: 18, color: accentColor),
                        label: Text('Grant', style: TextStyle(color: accentColor)),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (hasPermissions)
                    ...application.permissions.map((secretId) {
                      final secretName = getSecretName(secretId, secrets);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.vpn_key, size: 16, color: secretColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                secretName,
                                style: TextStyle(
                                  color: textPrimaryDark,
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, size: 18, color: errorColor),
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
                    })
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No permissions granted yet',
                          style: TextStyle(
                            color: textSecondaryDark,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
