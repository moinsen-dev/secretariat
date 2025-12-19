// F205: Create lib/widgets/secret_list_tile.dart custom widget
//
// Reusable widget for displaying secret items in list views across the app.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/secret.dart';
import '../theme/colors.dart';

/// F205: Custom widget for displaying a secret in a list
/// F206-F212: Enhanced with provider icons, last accessed, clipboard integration
///
/// This widget provides a consistent appearance for secrets across all list screens.
///
/// Features:
/// - Displays secret name with provider badge
/// - Shows last updated timestamp
/// - Copy to clipboard action
/// - Tap to view details
/// - Optional trailing actions
///
/// Example usage:
/// ```dart
/// SecretListTile(
///   secret: mySecret,
///   onTap: () => Navigator.push(...),
///   onCopy: () => showSnackBar('Copied!'),
/// )
/// ```
class SecretListTile extends StatefulWidget {
  /// The secret to display
  final Secret secret;

  /// Callback when the tile is tapped
  final VoidCallback? onTap;

  /// Callback when the copy button is pressed
  final VoidCallback? onCopy;

  /// Optional trailing widget (e.g., delete button)
  final Widget? trailing;

  /// Whether to show the copy button (default: true)
  final bool showCopyButton;

  /// Whether to show the provider badge (default: true)
  final bool showProvider;

  /// Whether to show the last updated time (default: true)
  final bool showLastUpdated;

  const SecretListTile({
    super.key,
    required this.secret,
    this.onTap,
    this.onCopy,
    this.trailing,
    this.showCopyButton = true,
    this.showProvider = true,
    this.showLastUpdated = true,
  });

  @override
  State<SecretListTile> createState() => _SecretListTileState();
}

class _SecretListTileState extends State<SecretListTile> {
  /// F210-F211: Timer for auto-clearing clipboard after 30 seconds
  Timer? _clipboardTimer;

  @override
  void dispose() {
    _clipboardTimer?.cancel();
    super.dispose();
  }

  /// F208-F212: Handle clipboard copy with auto-clear timer
  void _handleCopy(BuildContext context) {
    // F209: Copy to clipboard
    Clipboard.setData(ClipboardData(text: widget.secret.value));

    // F212: Show SnackBar confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${widget.secret.name}'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // F210-F211: Start 30-second timer and clear clipboard after expiry
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer(const Duration(seconds: 30), () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
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

  /// F206: Get provider icon based on provider name
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
        return Icons.business;
      default:
        return Icons.vpn_key;
    }
  }

  /// Get provider badge color
  Color _getProviderColor(String? provider) {
    if (provider == null) return Colors.grey;

    switch (provider.toLowerCase()) {
      case 'openai':
        return const Color(0xFF10A37F);
      case 'anthropic':
        return const Color(0xFFD97757);
      case 'stripe':
        return const Color(0xFF635BFF);
      case 'github':
        return const Color(0xFF181717);
      case 'aws':
        return const Color(0xFFFF9900);
      case 'google':
        return const Color(0xFF4285F4);
      default:
        return secretColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // F206: Provider icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getProviderColor(widget.secret.provider).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getProviderIcon(widget.secret.provider),
                  color: _getProviderColor(widget.secret.provider),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Secret name
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.secret.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Provider badge
                        if (widget.showProvider && widget.secret.provider != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getProviderColor(widget.secret.provider),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.secret.provider!.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Metadata
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Environment badge
                        if (widget.secret.environment != null &&
                            widget.secret.environment != 'default') ...[
                          Icon(
                            Icons.circle,
                            size: 8,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.secret.environment!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],

                        // F207: Last accessed/updated with relative time
                        if (widget.showLastUpdated) ...[
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _formatTimestamp(widget.secret.updatedAt ?? widget.secret.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Notes preview
                    if (widget.secret.notes != null && widget.secret.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.secret.notes!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // F208: Copy IconButton
                  if (widget.showCopyButton)
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: widget.onCopy ?? () => _handleCopy(context),
                      tooltip: 'Copy to clipboard',
                      visualDensity: VisualDensity.compact,
                      color: Theme.of(context).colorScheme.primary,
                    ),

                  // Custom trailing widget
                  if (widget.trailing != null) widget.trailing!,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
