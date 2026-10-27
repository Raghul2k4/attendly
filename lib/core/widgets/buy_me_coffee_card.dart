import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import 'surface_card.dart';

const buyMeACoffeeUrl = 'https://buymeacoffee.com/raghul';

/// Opens the developer support page in an external browser. If launching fails
/// (e.g. device without browser intent handler), it copies the link to the
/// clipboard and notifies the user with a snackbar.
Future<void> openBuyMeACoffee(BuildContext context) async {
  final uri = Uri.parse(buyMeACoffeeUrl);
  try {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      await _copyFallback(context);
    }
  } catch (_) {
    if (context.mounted) {
      await _copyFallback(context);
    }
  }
}

Future<void> _copyFallback(BuildContext context) async {
  await Clipboard.setData(const ClipboardData(text: buyMeACoffeeUrl));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard: buymeacoffee.com/raghul'),
      ),
    );
  }
}

/// A friendly, dignified support card for the Attendly developer.
class BuyMeCoffeeCard extends StatelessWidget {
  const BuyMeCoffeeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDD00).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.local_cafe_rounded,
                  color: Color(0xFFD97706),
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Support the developer', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'If Attendly makes managing attendance easier for your team, consider buying Raghul a coffee.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.darkSlate500 : AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('buy_me_coffee_button'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFDD00),
              foregroundColor: const Color(0xFF000000),
              minimumSize: const Size.fromHeight(TouchTarget.minInteractive),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              elevation: 0,
            ),
            onPressed: () => openBuyMeACoffee(context),
            icon: const Icon(
              Icons.coffee_rounded,
              size: 20,
              color: Color(0xFF000000),
            ),
            label: const Text(
              'Buy me a coffee',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
                color: Color(0xFF000000),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
