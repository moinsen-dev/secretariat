// VaultUnlockDialog - Modal dialog for unlocking the vault
//
// Displays when the vault is locked and requires password or Touch ID
// to unlock before accessing secrets.
//
// Features:
// - Password input with visibility toggle
// - Touch ID biometric authentication (macOS)
// - Loading state during unlock
// - Error display for failed attempts
// - Quit App button for users who forgot password

import 'dart:io' show Platform, exit;
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../theme/colors.dart';

/// Modal dialog that blocks app access until vault is unlocked
///
/// Usage:
/// ```dart
/// showDialog(
///   context: context,
///   barrierDismissible: false,
///   builder: (context) => VaultUnlockDialog(
///     onUnlock: (password) async {
///       await vaultProvider.unlockVault(password);
///     },
///   ),
/// );
/// ```
class VaultUnlockDialog extends StatefulWidget {
  /// Callback when unlock is attempted with password
  final Future<void> Function(String password) onUnlock;

  /// Callback when Touch ID unlock is successful
  final Future<void> Function()? onTouchIdUnlock;

  /// Whether Touch ID is enabled for this vault
  final bool touchIdEnabled;

  const VaultUnlockDialog({
    super.key,
    required this.onUnlock,
    this.onTouchIdUnlock,
    this.touchIdEnabled = true,
  });

  @override
  State<VaultUnlockDialog> createState() => _VaultUnlockDialogState();
}

class _VaultUnlockDialogState extends State<VaultUnlockDialog> {
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _localAuth = LocalAuthentication();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    // Auto-focus password field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _passwordFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  /// Check if biometrics are available on this device
  Future<void> _checkBiometrics() async {
    if (!Platform.isMacOS) {
      // Currently only supporting Touch ID on macOS
      return;
    }

    try {
      final canAuth = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (canAuth && isDeviceSupported) {
        final availableBiometrics = await _localAuth.getAvailableBiometrics();
        setState(() {
          _canUseBiometrics = availableBiometrics.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('[VaultUnlockDialog] Error checking biometrics: $e');
    }
  }

  /// Attempt to unlock vault with password
  Future<void> _unlockWithPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your master password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onUnlock(password);
      // If successful, dialog will be dismissed by parent
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Incorrect password. Please try again.';
      });
      _passwordController.clear();
      _passwordFocusNode.requestFocus();
    }
  }

  /// Attempt to unlock vault with Touch ID
  Future<void> _unlockWithTouchId() async {
    if (widget.onTouchIdUnlock == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock your Secretariat vault',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (didAuthenticate) {
        await widget.onTouchIdUnlock!();
        // If successful, dialog will be dismissed by parent
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Touch ID authentication failed';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Touch ID error: ${e.toString()}';
      });
    }
  }

  /// Handle quit app button
  void _quitApp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceDark,
        title: const Text('Quit Secretariat?'),
        content: const Text(
          'If you forgot your master password, your secrets cannot be recovered. '
          'Are you sure you want to quit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => exit(0),
            style: TextButton.styleFrom(foregroundColor: errorColor),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showTouchId =
        widget.touchIdEnabled &&
        _canUseBiometrics &&
        widget.onTouchIdUnlock != null;

    return Dialog(
      backgroundColor: surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lock icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: lockedColor.withAlpha(26), // 10% opacity
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(Icons.lock, size: 40, color: lockedColor),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Vault is Locked',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: textPrimaryDark,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              'Enter your master password to unlock',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: textSecondaryDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Password field
            Semantics(
              label: 'Master password, required, secure input',
              child: TextField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                obscureText: _obscurePassword,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Master Password',
                  filled: true,
                  fillColor: surfaceVariantDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: accentColor, width: 2),
                  ),
                  suffixIcon: Semantics(
                    label: _obscurePassword ? 'Show password' : 'Hide password',
                    button: true,
                    child: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: textSecondaryDark,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                onSubmitted: (_) => _unlockWithPassword(),
              ),
            ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: errorColor.withAlpha(26), // 10% opacity
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: errorColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: errorColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Unlock button
            SizedBox(
              width: double.infinity,
              child: Semantics(
                label: 'Unlock vault with password',
                button: true,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _unlockWithPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Unlock'),
                ),
              ),
            ),

            // Touch ID option
            if (showTouchId) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Divider(color: borderDark)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: textSecondaryDark),
                    ),
                  ),
                  Expanded(child: Divider(color: borderDark)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Semantics(
                  label: 'Unlock vault with Touch ID',
                  button: true,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _unlockWithTouchId,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Unlock with Touch ID'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentColor,
                      side: const BorderSide(color: accentColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // Quit button
            const SizedBox(height: 24),
            Semantics(
              label: 'Quit Secretariat application',
              button: true,
              child: TextButton(
                onPressed: _isLoading ? null : _quitApp,
                child: Text(
                  'Quit Secretariat',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: textSecondaryDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
