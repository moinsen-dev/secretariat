// F213-F214: Empty State Widget for Secretariat app
//
// Features:
// - F213: Create lib/widgets/empty_state.dart widget
// - F214: Display illustration and "No secrets yet" text when vault is empty

import 'package:flutter/material.dart';

/// F213: Empty State Widget
///
/// Displays a visually appealing message when there are no secrets in the vault.
///
/// Features:
/// - Large icon/illustration
/// - Clear message text
/// - Optional call-to-action button
/// - Customizable icon and message
///
/// Example usage:
/// ```dart
/// if (secrets.isEmpty) {
///   return EmptyState(
///     icon: Icons.vpn_key_off,
///     title: 'No secrets yet',
///     message: 'Add your first secret to get started',
///     actionLabel: 'Add Secret',
///     onAction: () => Navigator.pushNamed(context, '/add-secret'),
///   );
/// }
/// ```
class EmptyState extends StatelessWidget {
  /// Icon to display
  final IconData icon;

  /// Main title text
  final String title;

  /// Optional descriptive message
  final String? message;

  /// Optional action button label
  final String? actionLabel;

  /// Optional action button callback
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    this.icon = Icons.vpn_key_off,
    this.title = 'No secrets yet',
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // F214: Illustration (large icon)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),

            const SizedBox(height: 24),

            // F214: "No secrets yet" title
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            // Optional message
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // Optional action button
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
