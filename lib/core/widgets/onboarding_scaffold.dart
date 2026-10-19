import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';

/// Screen furniture shared by onboarding screens: a calm, top-aligned
/// column with consistent gutters that stays scrollable on small screens.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    this.bottom,
    this.trailing,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  final Widget? bottom;

  static const _appBarExtent = 48.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        toolbarHeight: _appBarExtent,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              // Keeps short content vertically composed while tall content
              // simply scrolls (no internal overflow).
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - _appBarExtent,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.slate500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    child,
                    if (trailing != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xl),
                        child: trailing!,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: bottom == null
          ? null
          : Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
              ),
              child: bottom,
            ),
    );
  }
}
