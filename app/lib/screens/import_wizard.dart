// Import Wizard Screen for Secretariat app
//
// Implements the Import Wizard from app_spec.txt lines 119, 201-225:
// - Step-by-step wizard for .env file import
// - Drag & drop .env file support
// - Preview before import
// - Duplicate detection
// - Provider auto-detection

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../providers/vault_provider.dart';

/// Secret entry parsed from .env file
class EnvSecret {
  final String name;
  final String value;
  String? provider;
  bool selected;
  bool isDuplicate;

  EnvSecret({
    required this.name,
    required this.value,
    this.provider,
    this.selected = true,
    this.isDuplicate = false,
  });
}

/// Import Wizard Screen
///
/// Multi-step wizard for importing secrets from .env files:
/// 1. Select/drop file
/// 2. Review and configure secrets
/// 3. Import confirmation
class ImportWizardScreen extends StatefulWidget {
  const ImportWizardScreen({super.key});

  @override
  State<ImportWizardScreen> createState() => _ImportWizardScreenState();
}

class _ImportWizardScreenState extends State<ImportWizardScreen> {
  /// Current wizard step (0-2)
  int _currentStep = 0;

  /// Selected file path
  String? _filePath;

  /// Parsed secrets from file
  List<EnvSecret> _secrets = [];

  /// Whether file is being dragged over
  bool _isDragging = false;

  /// Whether import is in progress
  bool _isImporting = false;

  /// Import error message
  String? _errorMessage;

  /// Number of successfully imported secrets
  int _importedCount = 0;

  /// Provider detection patterns
  static const Map<String, String> _providerPatterns = {
    'OPENAI': 'openai',
    'ANTHROPIC': 'anthropic',
    'CLAUDE': 'anthropic',
    'STRIPE': 'stripe',
    'GITHUB': 'github',
    'AWS': 'aws',
    'GOOGLE': 'google',
    'GCP': 'google',
    'AZURE': 'azure',
    'FIREBASE': 'firebase',
    'SUPABASE': 'supabase',
    'VERCEL': 'vercel',
    'NETLIFY': 'netlify',
    'CLOUDFLARE': 'cloudflare',
    'SENDGRID': 'sendgrid',
    'TWILIO': 'twilio',
    'DATABASE': 'database',
    'POSTGRES': 'database',
    'MYSQL': 'database',
    'MONGODB': 'database',
    'REDIS': 'database',
  };

  /// Detect provider from secret name
  String? _detectProvider(String name) {
    final upperName = name.toUpperCase();
    for (final entry in _providerPatterns.entries) {
      if (upperName.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Parse .env file content
  Future<void> _parseEnvFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        setState(() {
          _errorMessage = 'File not found: $path';
        });
        return;
      }

      final content = await file.readAsString();
      final lines = content.split('\n');
      final secrets = <EnvSecret>[];

      for (final line in lines) {
        final trimmed = line.trim();

        // Skip empty lines and comments
        if (trimmed.isEmpty || trimmed.startsWith('#')) {
          continue;
        }

        // Parse KEY=VALUE format
        final equalsIndex = trimmed.indexOf('=');
        if (equalsIndex <= 0) {
          continue;
        }

        final name = trimmed.substring(0, equalsIndex).trim();
        var value = trimmed.substring(equalsIndex + 1).trim();

        // Remove surrounding quotes if present
        if ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'"))) {
          value = value.substring(1, value.length - 1);
        }

        // Skip empty values
        if (value.isEmpty) {
          continue;
        }

        secrets.add(EnvSecret(
          name: name,
          value: value,
          provider: _detectProvider(name),
        ));
      }

      // Check for duplicates against existing secrets
      if (!mounted) return;
      final vaultProvider = Provider.of<VaultProvider>(context, listen: false);
      final existingNames = vaultProvider.secrets.map((s) => s.name).toSet();

      for (final secret in secrets) {
        if (existingNames.contains(secret.name)) {
          secret.isDuplicate = true;
          secret.selected = false; // Deselect duplicates by default
        }
      }

      setState(() {
        _secrets = secrets;
        _filePath = path;
        _errorMessage = null;
        _currentStep = 1; // Move to review step
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to parse file: $e';
      });
    }
  }

  /// Import selected secrets
  Future<void> _importSecrets() async {
    final selectedSecrets = _secrets.where((s) => s.selected).toList();
    if (selectedSecrets.isEmpty) {
      setState(() {
        _errorMessage = 'No secrets selected for import';
      });
      return;
    }

    setState(() {
      _isImporting = true;
      _errorMessage = null;
      _importedCount = 0;
    });

    final vaultProvider = Provider.of<VaultProvider>(context, listen: false);

    for (final secret in selectedSecrets) {
      try {
        await vaultProvider.setSecret(
          secret.name,
          secret.value,
          provider: secret.provider,
        );
        _importedCount++;
      } catch (e) {
        debugPrint('Failed to import ${secret.name}: $e');
      }
    }

    setState(() {
      _isImporting = false;
      _currentStep = 2; // Move to completion step
    });
  }

  /// Build step 1: File selection
  Widget _buildFileSelectionStep() {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) {
        setState(() => _isDragging = false);
        if (details.files.isNotEmpty) {
          final file = details.files.first;
          if (file.path.endsWith('.env') ||
              file.name.contains('.env') ||
              !file.name.contains('.')) {
            _parseEnvFile(file.path);
          } else {
            setState(() {
              _errorMessage = 'Please drop a .env file';
            });
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _isDragging
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isDragging
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
            width: _isDragging ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isDragging ? Icons.file_download : Icons.upload_file,
              size: 64,
              color: _isDragging
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _isDragging
                  ? 'Drop your .env file here'
                  : 'Drag & drop your .env file here',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'or',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                // For simplicity, prompt user to enter path
                // In production, use file_picker package
                final controller = TextEditingController();
                final path = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Enter .env file path'),
                    content: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: '/path/to/your/.env',
                        border: OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, controller.text),
                        child: const Text('Open'),
                      ),
                    ],
                  ),
                );
                if (path != null && path.isNotEmpty) {
                  _parseEnvFile(path);
                }
              },
              icon: const Icon(Icons.folder_open),
              label: const Text('Browse Files'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build step 2: Review secrets
  Widget _buildReviewStep() {
    final selectedCount = _secrets.where((s) => s.selected).length;
    final duplicateCount = _secrets.where((s) => s.isDuplicate).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.description),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _filePath?.split('/').last ?? 'Unknown file',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${_secrets.length} secrets found • $selectedCount selected',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = 0;
                      _secrets = [];
                      _filePath = null;
                    });
                  },
                  child: const Text('Change File'),
                ),
              ],
            ),
          ),
        ),

        if (duplicateCount > 0) ...[
          const SizedBox(height: 8),
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$duplicateCount secret(s) already exist and are deselected by default.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Select all / none
        Row(
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  for (final secret in _secrets) {
                    secret.selected = true;
                  }
                });
              },
              child: const Text('Select All'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  for (final secret in _secrets) {
                    secret.selected = false;
                  }
                });
              },
              child: const Text('Select None'),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Secrets list
        Expanded(
          child: ListView.builder(
            itemCount: _secrets.length,
            itemBuilder: (context, index) {
              final secret = _secrets[index];
              return Card(
                color: secret.isDuplicate
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : null,
                child: CheckboxListTile(
                  value: secret.selected,
                  onChanged: (value) {
                    setState(() {
                      secret.selected = value ?? false;
                    });
                  },
                  title: Row(
                    children: [
                      Text(secret.name),
                      if (secret.isDuplicate) ...[
                        const SizedBox(width: 8),
                        Chip(
                          label: const Text('Exists'),
                          labelStyle: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                          ),
                          backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                  subtitle: Row(
                    children: [
                      if (secret.provider != null) ...[
                        Icon(
                          _getProviderIcon(secret.provider),
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          secret.provider!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        '${secret.value.length} characters',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  secondary: secret.provider != null
                      ? null
                      : DropdownButton<String>(
                          value: secret.provider,
                          hint: const Text('Provider'),
                          underline: const SizedBox(),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Auto-detect'),
                            ),
                            ..._providerPatterns.values.toSet().map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p),
                                  ),
                                ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              secret.provider = value;
                            });
                          },
                        ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _currentStep = 0;
                  _secrets = [];
                  _filePath = null;
                });
              },
              child: const Text('Back'),
            ),
            FilledButton.icon(
              onPressed: selectedCount > 0 && !_isImporting
                  ? _importSecrets
                  : null,
              icon: _isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload),
              label: Text(
                _isImporting
                    ? 'Importing...'
                    : 'Import $selectedCount Secret${selectedCount == 1 ? '' : 's'}',
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build step 3: Completion
  Widget _buildCompletionStep() {
    final total = _secrets.where((s) => s.selected).length;
    final success = _importedCount == total;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            success ? Icons.check_circle : Icons.warning,
            size: 80,
            color: success
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 24),
          Text(
            success
                ? 'Import Complete!'
                : 'Import Partially Complete',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '$_importedCount of $total secrets imported successfully',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep = 0;
                    _secrets = [];
                    _filePath = null;
                    _importedCount = 0;
                  });
                },
                child: const Text('Import Another'),
              ),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Get icon for provider
  IconData _getProviderIcon(String? provider) {
    if (provider == null) return Icons.vpn_key;

    switch (provider.toLowerCase()) {
      case 'openai':
        return Icons.smart_toy;
      case 'anthropic':
        return Icons.psychology;
      case 'stripe':
        return Icons.payment;
      case 'github':
        return Icons.code;
      case 'aws':
        return Icons.cloud;
      case 'google':
      case 'gcp':
        return Icons.business;
      case 'azure':
        return Icons.cloud_circle;
      case 'firebase':
        return Icons.whatshot;
      case 'supabase':
        return Icons.storage;
      case 'vercel':
      case 'netlify':
        return Icons.dns;
      case 'cloudflare':
        return Icons.security;
      case 'sendgrid':
      case 'twilio':
        return Icons.email;
      case 'database':
        return Icons.storage;
      default:
        return Icons.vpn_key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Secrets'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildStepIndicator(0, 'Select File'),
                Expanded(child: _buildStepConnector(0)),
                _buildStepIndicator(1, 'Review'),
                Expanded(child: _buildStepConnector(1)),
                _buildStepIndicator(2, 'Complete'),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _currentStep == 0
            ? _buildFileSelectionStep()
            : _currentStep == 1
                ? _buildReviewStep()
                : _buildCompletionStep(),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Center(
            child: _currentStep > step
                ? Icon(
                    Icons.check,
                    size: 18,
                    color: Theme.of(context).colorScheme.onPrimary,
                  )
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isCurrent
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(int afterStep) {
    final isActive = _currentStep > afterStep;

    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: isActive
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}
