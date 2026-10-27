import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_dimensions.dart';
import '../../core/widgets/app_choice_card.dart';
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
          'Simple attendance for small teams — set up in minutes, check in '
          'with one tap.',
      bottom: TextButton.icon(
        onPressed: () => _toSignIn(context),
        icon: const Icon(Icons.login_rounded, size: AppIconSize.md),
        label: const Text('I already have an account'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppChoiceCard(
            icon: Icons.storefront_rounded,
            title: "I own a business",
            body:
                'Create an organisation, invite your team and track '
                'attendance from one place.',
            onTap: () => _toSignUp(context, UserRole.owner),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppChoiceCard(
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
