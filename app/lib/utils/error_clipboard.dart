// Utility to copy error messages to clipboard instead of showing transient SnackBars
//
// On headless systems, error SnackBars flash too briefly to read.
// This helper copies the error to clipboard and shows a minimal confirmation.
// The user can then paste it anywhere (Telegram, Notes, etc.).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Copies [message] to clipboard and shows a brief confirmation.
///
/// Use this instead of `ScaffoldMessenger.showSnackBar()` with error messages.
/// The error text is preserved in the clipboard for later inspection.
void copyErrorToClipboard(BuildContext context, String message) {
  Clipboard.setData(ClipboardData(text: message));

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Error copied to clipboard'),
      duration: const Duration(seconds: 2),
      action: SnackBarAction(
        label: 'Paste',
        onPressed: () {
          // No-op; the clipboard already has the data.
          // The action button is just a convenience tip.
        },
      ),
    ),
  );
}
