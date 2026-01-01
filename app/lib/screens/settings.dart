import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vault_provider.dart';
import '../services/daemon_manager.dart';
import '../theme/colors.dart';

/// Settings screen for Secretariat app preferences and daemon management
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  String? _statusMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        backgroundColor: surfaceDark,
        title: Text(
          'Settings',
          style: TextStyle(
            color: textPrimaryDark,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimaryDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<VaultProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Daemon Status Section
              _buildSectionHeader('Daemon'),
              _buildDaemonStatusTile(provider),
              _buildAutoStartTile(provider),
              const SizedBox(height: 24),

              // Vault Section
              _buildSectionHeader('Vault'),
              _buildVaultStatusTile(provider),
              _buildLockVaultTile(provider),
              const SizedBox(height: 24),

              // Security & Access Section
              _buildSectionHeader('Security & Access'),
              _buildNavigationTile(
                icon: Icons.apps,
                iconColor: primaryColor,
                title: 'Applications',
                subtitle: 'Manage app permissions and access',
                onTap: () => Navigator.pushNamed(context, '/applications'),
              ),
              _buildNavigationTile(
                icon: Icons.smart_toy,
                iconColor: accentColor,
                title: 'AI Agents',
                subtitle: 'Manage AI assistant access to secrets',
                onTap: () => Navigator.pushNamed(context, '/agents'),
              ),
              _buildNavigationTile(
                icon: Icons.history,
                iconColor: warningColor,
                title: 'Audit Log',
                subtitle: 'View secret access history',
                onTap: () => Navigator.pushNamed(context, '/audit-log'),
              ),
              _buildNavigationTile(
                icon: Icons.file_download,
                iconColor: successColor,
                title: 'Import Secrets',
                subtitle: 'Import from .env files',
                onTap: () => Navigator.pushNamed(context, '/import'),
              ),
              const SizedBox(height: 24),

              // Secret Health Section
              _buildSectionHeader('Secret Health'),
              _buildRotationRemindersTile(provider),
              _buildExpiringSecretsTile(provider),
              const SizedBox(height: 24),

              // About Section
              _buildSectionHeader('About'),
              _buildAboutTile(),
              _buildVersionTile(),

              if (_statusMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: surfaceVariantDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(color: textSecondaryDark, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: textSecondaryDark,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildDaemonStatusTile(VaultProvider provider) {
    final status = provider.daemonStatus;
    final isRunning = status == DaemonStatus.running;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderDark),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (isRunning ? successColor : errorColor).withValues(
              alpha: 0.15,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isRunning ? Icons.check_circle : Icons.error,
            color: isRunning ? successColor : errorColor,
            size: 20,
          ),
        ),
        title: Text(
          'Daemon Status',
          style: TextStyle(
            color: textPrimaryDark,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          _getDaemonStatusText(status),
          style: TextStyle(
            color: isRunning ? successColor : textSecondaryDark,
            fontSize: 12,
          ),
        ),
        trailing: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: accentColor,
                ),
              )
            : TextButton(
                onPressed: () async {
                  setState(() => _isLoading = true);
                  try {
                    if (isRunning) {
                      await provider.stopDaemon();
                      _showStatus('Daemon stopped');
                    } else {
                      await provider.startDaemon();
                      await provider.connect();
                      _showStatus('Daemon started');
                    }
                  } catch (e) {
                    _showStatus('Error: $e');
                  } finally {
                    setState(() => _isLoading = false);
                  }
                },
                child: Text(
                  isRunning ? 'Stop' : 'Start',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildAutoStartTile(VaultProvider provider) {
    final isEnabled = provider.isAutoStartEnabled;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderDark),
      ),
      child: SwitchListTile(
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.play_arrow, color: primaryColor, size: 20),
        ),
        title: Text(
          'Start on Login',
          style: TextStyle(
            color: textPrimaryDark,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          isEnabled ? 'Daemon starts automatically' : 'Start daemon manually',
          style: TextStyle(color: textSecondaryDark, fontSize: 12),
        ),
        value: isEnabled,
        activeThumbColor: accentColor,
        onChanged: (value) async {
          setState(() => _isLoading = true);
          try {
            if (value) {
              final success = await provider.enableAutoStart();
              _showStatus(
                success ? 'Auto-start enabled' : 'Failed to enable auto-start',
              );
            } else {
              final success = await provider.disableAutoStart();
              _showStatus(
                success
                    ? 'Auto-start disabled'
                    : 'Failed to disable auto-start',
              );
            }
          } catch (e) {
            _showStatus('Error: $e');
          } finally {
            setState(() => _isLoading = false);
          }
        },
      ),
    );
  }

  Widget _buildVaultStatusTile(VaultProvider provider) {
    return FutureBuilder<Map<String, dynamic>>(
      future: provider.isConnected ? provider.getVaultStatus() : null,
      builder: (context, snapshot) {
        String stateText = 'Unknown';
        int secretCount = 0;
        int appCount = 0;

        if (snapshot.hasData) {
          stateText = snapshot.data!['state'] as String? ?? 'unknown';
          secretCount = snapshot.data!['secret_count'] as int? ?? 0;
          appCount = snapshot.data!['app_count'] as int? ?? 0;
        } else if (snapshot.hasError) {
          stateText = 'Error';
        } else if (!provider.isConnected) {
          stateText = 'Disconnected';
        }

        final isUnlocked = stateText == 'unlocked';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: surfaceDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderDark),
          ),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (isUnlocked ? unlockedColor : lockedColor).withValues(
                  alpha: 0.15,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isUnlocked ? Icons.lock_open : Icons.lock,
                color: isUnlocked ? unlockedColor : lockedColor,
                size: 20,
              ),
            ),
            title: Text(
              'Vault Status',
              style: TextStyle(
                color: textPrimaryDark,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              '$stateText - $secretCount secrets, $appCount apps',
              style: TextStyle(color: textSecondaryDark, fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLockVaultTile(VaultProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderDark),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: errorColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.lock_outline, color: errorColor, size: 20),
        ),
        title: Text(
          'Lock Vault',
          style: TextStyle(
            color: textPrimaryDark,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Clear master key from memory',
          style: TextStyle(color: textSecondaryDark, fontSize: 12),
        ),
        trailing: TextButton(
          onPressed: () async {
            // Capture navigator before async gap to avoid use_build_context_synchronously
            final navigator = Navigator.of(context);
            final confirm = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                backgroundColor: surfaceDark,
                title: Text(
                  'Lock Vault?',
                  style: TextStyle(color: textPrimaryDark),
                ),
                content: Text(
                  'This will clear the master key from memory. You will need to enter your password to unlock again.',
                  style: TextStyle(color: textSecondaryDark),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: textSecondaryDark),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text('Lock', style: TextStyle(color: errorColor)),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              try {
                await provider.lockVault();
                if (context.mounted) {
                  navigator.pop();
                }
              } catch (e) {
                _showStatus('Failed to lock: $e');
              }
            }
          },
          child: Text(
            'Lock Now',
            style: TextStyle(color: errorColor, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderDark),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: textPrimaryDark,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: textSecondaryDark, fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right, color: textSecondaryDark),
        onTap: onTap,
      ),
    );
  }

  Widget _buildAboutTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderDark),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: secretColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.security, color: secretColor, size: 20),
        ),
        title: Text(
          'Secretariat',
          style: TextStyle(
            color: textPrimaryDark,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Local-first secrets management',
          style: TextStyle(color: textSecondaryDark, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildVersionTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderDark),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: infoColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.info_outline, color: infoColor, size: 20),
        ),
        title: Text(
          'Version',
          style: TextStyle(
            color: textPrimaryDark,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '0.1.0 (Phase 1)',
          style: TextStyle(color: textSecondaryDark, fontSize: 12),
        ),
      ),
    );
  }

  String _getDaemonStatusText(DaemonStatus status) {
    switch (status) {
      case DaemonStatus.running:
        return 'Running';
      case DaemonStatus.stopped:
        return 'Stopped';
      case DaemonStatus.starting:
        return 'Starting...';
      case DaemonStatus.unknown:
        return 'Unknown';
    }
  }

  Widget _buildRotationRemindersTile(VaultProvider provider) {
    final secretsNeedingRotation = provider.secretsNeedingRotation;
    final count = secretsNeedingRotation.length;
    final hasWarnings = count > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasWarnings ? warningColor.withValues(alpha: 0.5) : borderDark,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (hasWarnings ? warningColor : successColor).withValues(
              alpha: 0.15,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.rotate_right,
                color: hasWarnings ? warningColor : successColor,
                size: 20,
              ),
              if (hasWarnings)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: warningColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        count > 9 ? '9+' : count.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        title: Text(
          'Rotation Reminders',
          style: TextStyle(
            color: textPrimaryDark,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          hasWarnings
              ? '$count secret${count == 1 ? '' : 's'} need${count == 1 ? 's' : ''} rotation (90+ days old)'
              : 'All secrets are recently rotated',
          style: TextStyle(
            color: hasWarnings ? warningColor : textSecondaryDark,
            fontSize: 12,
          ),
        ),
        trailing: hasWarnings
            ? Icon(Icons.chevron_right, color: textSecondaryDark)
            : Icon(Icons.check, color: successColor),
        onTap: hasWarnings
            ? () {
                _showRotationRemindersDialog(secretsNeedingRotation);
              }
            : null,
      ),
    );
  }

  void _showRotationRemindersDialog(List secrets) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surfaceDark,
        title: Row(
          children: [
            Icon(Icons.rotate_right, color: warningColor),
            const SizedBox(width: 12),
            Text(
              'Secrets Needing Rotation',
              style: TextStyle(color: textPrimaryDark, fontSize: 16),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'These secrets have not been rotated in over 90 days:',
                style: TextStyle(color: textSecondaryDark, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...secrets.take(10).map((secret) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.key, size: 16, color: warningColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            secret.name,
                            style: TextStyle(
                              color: textPrimaryDark,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          _formatDaysAgo(secret.rotatedAt ?? secret.createdAt),
                          style: TextStyle(
                            color: textSecondaryDark,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )),
              if (secrets.length > 10)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '...and ${secrets.length - 10} more',
                    style: TextStyle(
                      color: textSecondaryDark,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiringSecretsTile(VaultProvider provider) {
    final expiringSecrets = provider.secretsExpiringSoon;
    final count = expiringSecrets.length;
    final hasExpiring = count > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasExpiring ? errorColor.withValues(alpha: 0.5) : borderDark,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (hasExpiring ? errorColor : successColor).withValues(
              alpha: 0.15,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.timer,
                color: hasExpiring ? errorColor : successColor,
                size: 20,
              ),
              if (hasExpiring)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: errorColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        count > 9 ? '9+' : count.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        title: Text(
          'Expiring Secrets',
          style: TextStyle(
            color: textPrimaryDark,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          hasExpiring
              ? '$count ephemeral secret${count == 1 ? '' : 's'} expiring within 1 hour'
              : 'No ephemeral secrets expiring soon',
          style: TextStyle(
            color: hasExpiring ? errorColor : textSecondaryDark,
            fontSize: 12,
          ),
        ),
        trailing: hasExpiring
            ? Icon(Icons.chevron_right, color: textSecondaryDark)
            : Icon(Icons.check, color: successColor),
        onTap: hasExpiring
            ? () {
                _showExpiringSecretsDialog(expiringSecrets);
              }
            : null,
      ),
    );
  }

  void _showExpiringSecretsDialog(List secrets) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surfaceDark,
        title: Row(
          children: [
            Icon(Icons.timer, color: errorColor),
            const SizedBox(width: 12),
            Text(
              'Expiring Soon',
              style: TextStyle(color: textPrimaryDark, fontSize: 16),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'These ephemeral secrets are expiring soon:',
                style: TextStyle(color: textSecondaryDark, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...secrets.take(10).map((secret) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.key, size: 16, color: errorColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            secret.name,
                            style: TextStyle(
                              color: textPrimaryDark,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          _formatTimeRemaining(secret.timeRemaining),
                          style: TextStyle(
                            color: errorColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )),
              if (secrets.length > 10)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '...and ${secrets.length - 10} more',
                    style: TextStyle(
                      color: textSecondaryDark,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDaysAgo(DateTime date) {
    final days = DateTime.now().difference(date).inDays;
    if (days == 0) return 'today';
    if (days == 1) return '1 day ago';
    return '$days days ago';
  }

  String _formatTimeRemaining(Duration? duration) {
    if (duration == null) return 'Unknown';
    if (duration.isNegative || duration == Duration.zero) return 'Expired';

    final minutes = duration.inMinutes;
    if (minutes < 60) {
      return '${minutes}m left';
    }
    final hours = duration.inHours;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m left';
  }

  void _showStatus(String message) {
    setState(() => _statusMessage = message);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _statusMessage = null);
      }
    });
  }
}
