// F179-F186: Add Secret Screen for Secretariat app
//
// Features:
// - F179: Create lib/screens/add_secret.dart file
// - F180: Add form with GlobalKey<FormState>
// - F181: Add TextFormField for secret name with validation
// - F182: Add TextFormField for secret value with obscureText: true
// - F183: Add DropdownButton for provider selection
// - F184: Implement auto-detection of provider from key name
// - F185: Add TextFormField for notes
// - F186: Implement onPressed for "Add Secret" button

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vault_provider.dart';

/// F179: Create lib/screens/add_secret.dart file
///
/// Screen for adding a new secret to the vault.
///
/// Features:
/// - Form with validation
/// - Provider selection with auto-detection
/// - Notes field
/// - Save functionality
class AddSecretScreen extends StatefulWidget {
  const AddSecretScreen({super.key});

  @override
  State<AddSecretScreen> createState() => _AddSecretScreenState();
}

class _AddSecretScreenState extends State<AddSecretScreen> {
  /// F180: Add form with GlobalKey for FormState
  final _formKey = GlobalKey<FormState>();

  /// Controllers for form fields
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _notesController = TextEditingController();

  /// Selected provider
  String? _selectedProvider;

  /// Whether the secret value is visible
  bool _isValueVisible = false;

  /// Whether form is being submitted
  bool _isSubmitting = false;

  /// List of common providers for dropdown
  final List<String> _providers = [
    'openai',
    'anthropic',
    'stripe',
    'github',
    'aws',
    'google',
    'azure',
    'firebase',
    'supabase',
    'vercel',
    'netlify',
    'cloudflare',
    'sendgrid',
    'twilio',
    'custom',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// F184: Implement auto-detection of provider from key name
  ///
  /// Detects provider based on common key name patterns:
  /// - OPENAI_* -> openai
  /// - ANTHROPIC_* -> anthropic
  /// - STRIPE_* -> stripe
  /// - GITHUB_* -> github
  /// - AWS_* -> aws
  /// - etc.
  void _detectProvider(String keyName) {
    final upperName = keyName.toUpperCase();

    // Common provider prefixes
    final providerPrefixes = {
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
    };

    for (final entry in providerPrefixes.entries) {
      if (upperName.startsWith(entry.key)) {
        setState(() {
          _selectedProvider = entry.value;
        });
        return;
      }
    }

    // If no match, set to custom
    setState(() {
      _selectedProvider = 'custom';
    });
  }

  /// F186: Implement onPressed for "Add Secret" button
  ///
  /// Validates form and saves the secret via VaultProvider.
  Future<void> _submitForm() async {
    // F181: Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final vaultProvider = Provider.of<VaultProvider>(context, listen: false);

      // F186: Call daemon client to add secret
      await vaultProvider.setSecret(
        _nameController.text.trim(),
        _valueController.text,
        provider: _selectedProvider == 'custom' ? null : _selectedProvider,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Secret added successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add secret: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Secret')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // F181: Add TextFormField for secret name with validation
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Secret Name',
                hintText: 'e.g., OPENAI_API_KEY',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Secret name is required';
                }
                // Check for valid environment variable name format
                if (!RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(value.trim())) {
                  return 'Use uppercase letters, numbers, and underscores only';
                }
                return null;
              },
              onChanged: (value) {
                // F184: Auto-detect provider from key name
                if (value.isNotEmpty) {
                  _detectProvider(value);
                }
              },
            ),

            const SizedBox(height: 16),

            // F182: Add TextFormField for secret value with obscureText: true
            TextFormField(
              controller: _valueController,
              decoration: InputDecoration(
                labelText: 'Secret Value',
                hintText: 'Enter the secret value',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isValueVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _isValueVisible = !_isValueVisible;
                    });
                  },
                ),
              ),
              obscureText: !_isValueVisible,
              maxLines: 1,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Secret value is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // F183: Add DropdownButton for provider selection
            DropdownButtonFormField<String>(
              initialValue: _selectedProvider,
              decoration: const InputDecoration(
                labelText: 'Provider',
                hintText: 'Select provider',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              items: _providers.map((provider) {
                return DropdownMenuItem(
                  value: provider,
                  child: Row(
                    children: [
                      Icon(
                        _getProviderIcon(provider),
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        provider == 'custom'
                            ? 'Custom / Other'
                            : provider.toUpperCase(),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProvider = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // F185: Add TextFormField for notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Add notes about this secret',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // F186: Implement onPressed for "Add Secret" button
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitForm,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_isSubmitting ? 'Adding...' : 'Add Secret'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
            ),
          ],
        ),
      ),
    );
  }

  /// Get provider icon based on provider name
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
      default:
        return Icons.vpn_key;
    }
  }
}
