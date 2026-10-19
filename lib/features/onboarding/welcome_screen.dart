import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import 'domain/user_role.dart';

/// First real screen: product identity + two role paths. Role intent is
/// onboarding context only — authorization always lives on the server.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Welcome',
      subtitle:
          'Attendance your team can rely on — set up in minutes, check '
          'in with one tap.',
      bottom: TextButton.icon(
        onPressed: () => _toSignIn(context),
        icon: const Icon(Icons.login_rounded, size: AppIconSize.md),
        label: const Text('I already have an account'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RoleCard(
            icon: Icons.storefront_rounded,
            title: "I own a business",
            body:
                'Create an organisation, invite your team and track '
                'attendance from one place.',
            onTap: () => _toSignUp(context, UserRole.owner),
          ),
          const SizedBox(height: AppSpacing.lg),
          _RoleCard(
            icon: Icons.badge_outlined,
            title: 'I am an employee',
            body:
                'Join your organisation with a staff code and punch in or '
                'out in a couple of taps.',
            onTap: () => _toSignIn(context),
          ),
        ],
      ),
    );
  }

  void _toSignUp(BuildContext context, UserRole role) =>
      context.push('/sign-up', extra: role);

  void _toSignIn(BuildContext context) => context.push('/sign-in');
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // The whole card presents as one labelled button for screen readers.
    return Semantics(
      container: true,
      button: true,
      label: title,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.emerald50,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: AppIconSize.md,
                    color: AppColors.emerald700,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        body,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.md),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: AppIconSize.md,
                    color: AppColors.slate400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
