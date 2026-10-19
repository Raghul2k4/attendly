import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Copies [value] to the system clipboard and confirms with a calm snackbar.
/// Used for staff codes and one-time invite tokens.
Future<void> copyToClipboard(
  BuildContext context,
  String value, {
  required String label,
}) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('$label copied')));
}
