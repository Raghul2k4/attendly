import 'package:flutter/material.dart';

/// Primary (emerald) action button. Used for the single most important
/// action on a screen — never twice on the same screen. The label stays
/// visible while in-flight so assistive tech keeps the button's meaning.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.inProgress = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool inProgress;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: inProgress ? null : onPressed,
      style: inProgress
          ? ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary
                  .withValues(alpha: .55),
              foregroundColor: Colors.white,
            )
          : null,
      child: inProgress
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Text(label),
              ],
            )
          : Text(label),
    );
  }
}
