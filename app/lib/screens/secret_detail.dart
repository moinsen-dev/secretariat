// F171-F178: Secret Detail Screen for Secretariat app
//
// Features:
// - F171: Create lib/screens/secret_detail.dart file
// - F172: Display secret name in AppBar title
// - F173: Show provider with icon
// - F174: Display created_at and updated_at timestamps
// - F175: Add "Edit" IconButton to enable edit mode
// - F176: Add "Delete" IconButton with confirmation dialog
// - F177: Show TextFormField in edit mode
// - F178: Implement Save button to call daemon client

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/application.dart';
import '../models/secret.dart';
import '../providers/vault_provider.dart';
import '../theme/colors.dart';
import '../utils/error_clipboard.dart';

/// F171: Create lib/screens/secret_detail.dart file
///
/// Detail screen showing all metadata for a specific secret.
///
/// Features:
/// - Display secret name in AppBar (F172)
/// - Show provider with icon (F173)
/// - Display created_at and updated_at timestamps (F174)
/// - Edit mode toggle button (F175)
///
/// Example usage:
/// ```dart
/// Navigator.pushNamed(
///   context,
///   '/secret-detail',
///   arguments: secret,
/// )
/// ```
class SecretDetailScreen extends StatefulWidget {
  const SecretDetailScreen({super.key});

  @override
  State<SecretDetailScreen> createState() => _SecretDetailScreenState();
}

class _SecretDetailScreenState extends State<SecretDetailScreen> {
  /// Whether edit mode is enabled
  bool _isEditMode = false;

  /// Whether the secret value is visible
  bool _isValueVisible = false;

  /// F177: Text editing controllers for edit mode
  late final TextEditingController _valueController;
  late final TextEditingController _notesController;
  late String _editingProvider;

  /// Guard against didChangeDependencies re-entry
  bool _controllersInitialized = false;

  /// The actual secret value, loaded from the daemon
  String? _secretValue;
  bool _isValueLoading = false;
  String? _valueLoadError;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controllersInitialized) {
      _controllersInitialized = true;
      _valueController = TextEditingController(text: '');
      _notesController = TextEditingController(text: '');
      _editingProvider = '';
      _initFromRouteArgs();
    }
  }

  void _initFromRouteArgs() {
    final secret = ModalRoute.of(context)!.settings.arguments as Secret;
    _valueController.text = secret.value ?? '';
    _notesController.text = secret.notes ?? '';
    _editingProvider = secret.provider ?? '';
    // Load full secret value from daemon (listSecrets only returns metadata)
    _loadSecretValue(secret.name);
  }

  Future<void> _loadSecretValue(String secretName) async {
    setState(() {
      _isValueLoading = true;
      _valueLoadError = null;
    });
    try {
      final vaultProvider = Provider.of<VaultProvider>(context, listen: false);
      final fullSecret = await vaultProvider.getSecret(secretName);
      if (mounted) {
        setState(() {
          _secretValue = fullSecret?.value;
          _isValueLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _valueLoadError = e.toString();
          _isValueLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
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

  /// Copy secret value to clipboard
  void _copyToClipboard(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// F176: Delete secret with confirmation dialog
  Future<void> _deleteSecret(BuildContext context, Secret secret) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Secret'),
        content: Text('Are you sure you want to delete "${secret.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final vaultProvider = Provider.of<VaultProvider>(
          context,
          listen: false,
        );
        await vaultProvider.deleteSecret(secret.name);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Secret deleted successfully')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete secret: $e')),
          );
        }
      }
    }
  }

  /// F178: Save secret changes
  Future<void> _saveSecret(BuildContext context, Secret secret) async {
    try {
      final vaultProvider = Provider.of<VaultProvider>(context, listen: false);

      await vaultProvider.setSecret(
        secret.name,
        _valueController.text,
        provider: _editingProvider.isEmpty ? null : _editingProvider,
        environment: secret.environment,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      setState(() {
        _isEditMode = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Secret saved successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save secret: $e')));
      }
    }
  }

  /// Rotate secret - prompts for new value and creates a new version
  Future<void> _rotateSecret(BuildContext context, Secret secret) async {
    final newValueController = TextEditingController();
    bool isValueVisible = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rotate Secret'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter a new value for "${secret.name}". '
                'The previous value will be preserved in case you need to rollback.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newValueController,
                obscureText: !isValueVisible,
                decoration: InputDecoration(
                  labelText: 'New Secret Value',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isValueVisible ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        isValueVisible = !isValueVisible;
                      });
                    },
                  ),
                ),
                maxLines: 1,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (newValueController.text.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Please enter a new value')),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Rotate'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final vaultProvider = Provider.of<VaultProvider>(
          context,
          listen: false,
        );

        final result = await vaultProvider.rotateSecret(
          secret.name,
          newValueController.text,
        );

        if (context.mounted) {
          final newVersion = result['version'] ?? 'new';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Secret rotated successfully to version $newVersion',
              ),
            ),
          );

          // Update the value controller with new value
          _valueController.text = newValueController.text;

          // Go back to refresh the list
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (context.mounted) {
          copyErrorToClipboard(context, 'Failed to rotate secret: $e');
        }
      }
    }

    newValueController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get secret from arguments
    final secret = ModalRoute.of(context)!.settings.arguments as Secret;

    return Scaffold(
      // F172: Display secret name in AppBar title
      appBar: AppBar(
        title: Text(secret.name),
        actions: [
          // F176: Add "Delete" IconButton with confirmation dialog
          if (!_isEditMode)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteSecret(context, secret),
              tooltip: 'Delete',
            ),
          // F175: Add "Edit" IconButton to enable edit mode
          // F178: Implement Save button to call daemon client
          IconButton(
            icon: Icon(_isEditMode ? Icons.check : Icons.edit),
            onPressed: () {
              if (_isEditMode) {
                // F178: Save changes
                _saveSecret(context, secret);
              } else {
                setState(() {
                  _isEditMode = true;
                });
              }
            },
            tooltip: _isEditMode ? 'Save' : 'Edit',
          ),
        ],
      ),
      body: Consumer<VaultProvider>(
        builder: (context, vaultProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // F173: Show provider with icon
                if (secret.provider != null)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getProviderColor(secret.provider),
                        child: Icon(
                          _getProviderIcon(secret.provider),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      title: const Text('Provider'),
                      subtitle: Text(secret.provider!),
                    ),
                  ),

                const SizedBox(height: 16),

                // Secret Value
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Secret Value',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (!_isEditMode)
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _isValueVisible
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isValueVisible = !_isValueVisible;
                                      });
                                    },
                                    tooltip: _isValueVisible ? 'Hide' : 'Show',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy),
                                    onPressed: _secretValue != null
                                        ? () {
                                            _copyToClipboard(_secretValue!);
                                          }
                                        : null,
                                    tooltip: 'Copy to clipboard',
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // F177: Show TextFormField in edit mode
                        if (_isEditMode)
                          TextFormField(
                            controller: _valueController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Secret Value',
                              hintText: 'Enter secret value',
                            ),
                            obscureText: !_isValueVisible,
                            // Flutter forbids obscureText + multiline.
                            // Single line while hidden, up to 3 when revealed.
                            maxLines: _isValueVisible ? 3 : 1,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _isValueLoading
                                  ? 'Loading...'
                                  : (_isValueVisible
                                      ? (_valueLoadError != null
                                          ? 'Error: $_valueLoadError'
                                          : (_secretValue ?? 'Value not loaded'))
                                      : '•' * 24),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Environment
                if (secret.environment != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.computer),
                      title: const Text('Environment'),
                      subtitle: Text(secret.environment!),
                    ),
                  ),

                const SizedBox(height: 16),

                // F174: Display created_at and updated_at timestamps
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Timestamps',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        _TimestampRow(
                          icon: Icons.add_circle_outline,
                          label: 'Created',
                          timestamp: secret.createdAt,
                          formatTimestamp: _formatTimestamp,
                        ),
                        if (secret.updatedAt != null) ...[
                          const Divider(height: 24),
                          _TimestampRow(
                            icon: Icons.update,
                            label: 'Last Updated',
                            timestamp: secret.updatedAt!,
                            formatTimestamp: _formatTimestamp,
                          ),
                        ],
                        if (secret.rotatedAt != null) ...[
                          const Divider(height: 24),
                          _TimestampRow(
                            icon: Icons.refresh,
                            label: 'Last Rotated',
                            timestamp: secret.rotatedAt!,
                            formatTimestamp: _formatTimestamp,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Notes
                if (_isEditMode ||
                    (secret.notes != null && secret.notes!.isNotEmpty))
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notes',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (_isEditMode)
                            TextFormField(
                              controller: _notesController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Notes (optional)',
                                hintText: 'Add notes about this secret',
                              ),
                              maxLines: 3,
                            )
                          else
                            Text(
                              secret.notes!,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                // Applications with Access section (per wireframe 3.9)
                if (!_isEditMode) ...[
                  const SizedBox(height: 16),
                  _ApplicationsWithAccessSection(secretName: secret.name),
                ],

                if (!_isEditMode) ...[
                  const SizedBox(height: 24),
                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Rotate Secret'),
                      onPressed: () => _rotateSecret(context, secret),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Widget for displaying a timestamp row
class _TimestampRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final DateTime timestamp;
  final String Function(DateTime) formatTimestamp;

  const _TimestampRow({
    required this.icon,
    required this.label,
    required this.timestamp,
    required this.formatTimestamp,
  });

  /// Format date for full display
  String _formatFullDate(DateTime timestamp) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[timestamp.month - 1]} ${timestamp.day}, ${timestamp.year} at ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatTimestamp(timestamp),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                _formatFullDate(timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Widget showing applications that have access to this secret (wireframe 3.9)
class _ApplicationsWithAccessSection extends StatelessWidget {
  final String secretName;

  const _ApplicationsWithAccessSection({required this.secretName});

  @override
  Widget build(BuildContext context) {
    return Consumer<VaultProvider>(
      builder: (context, vaultProvider, child) {
        // Find applications that have permission to access this secret
        final appsWithAccess = vaultProvider.applications
            .where((app) => app.permissions.contains(secretName))
            .toList();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.apps, size: 20, color: applicationColor),
                    const SizedBox(width: 8),
                    Text(
                      'Applications with Access',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (appsWithAccess.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No applications have been granted access to this secret yet.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...appsWithAccess.map((app) => _AppAccessTile(app: app)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Individual application tile showing access info
class _AppAccessTile extends StatelessWidget {
  final Application app;

  const _AppAccessTile({required this.app});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: applicationColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.apps, size: 18, color: applicationColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                if (app.lastAccess != null)
                  Text(
                    'Last access: ${_formatRelativeTime(app.lastAccess!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Icon(Icons.check_circle, size: 18, color: successColor),
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
