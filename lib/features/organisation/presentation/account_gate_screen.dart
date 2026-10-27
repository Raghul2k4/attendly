import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_choice_card.dart';
import '../../../core/widgets/app_error_panel.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../attendance/presentation/employee_home_view.dart';
import '../domain/organisation_models.dart';
import 'organisation_providers.dart';
import 'owner_home_view.dart';

/// Single post-auth destination. Resolves the signed-in user's membership and
/// renders setup, the owner dashboard, the employee home, or an honest
/// "access paused" state — every branch is driven by server data.
class AccountGateScreen extends ConsumerWidget {
  const AccountGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(myAccountProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Attendly'),
          actions: [
            IconButton(
            tooltip: 'Account',
            onPressed: () => context.push('/account'),
            icon: const Icon(Icons.person_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: account.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: AppErrorPanel(
              message: error is AppException
                  ? error.message
                  : 'We couldn’t load your account. Try again.',
              kind: error is AppException ? error.kind : AppErrorKind.unknown,
              onRetry: () => ref.invalidate(myAccountProvider),
            ),
          ),
          data: (account) {
            if (account == null) return const _SetupChoice();
            if (!account.membership.isActive) {
              return _PausedAccess(account: account);
            }
            if (account.membership.isOwner) {
              return OwnerHomeView(account: account);
            }
            return EmployeeHomeView(account: account);
          },
        ),
      ),
    );
  }
}

/// Signed in but not attached to an organisation yet: pick owner setup or
/// employee join. Role choice here is onboarding only; the server grants
/// permissions from the membership row.
class _SetupChoice extends ConsumerWidget {
  const _SetupChoice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final name =
        user?.userMetadata?['full_name'] as String? ?? user?.email ?? 'there';
    final trimmed = name.trim();
    final firstName = trimmed.isEmpty
        ? 'there'
        : trimmed.split(RegExp(r'\s+')).first;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text('Hi, $firstName', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Let’s get your workplace ready. Choose how you’ll use Attendly.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppChoiceCard(
          icon: Icons.storefront_rounded,
          title: 'Create a business',
          body:
              'Set up your organisation, then invite your team with secure '
              'staff codes.',
          onTap: () => context.push('/setup/create-organisation'),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppChoiceCard(
          icon: Icons.confirmation_number_outlined,
          title: 'Join with an invite token',
          body:
              'Paste the 20-character token your business owner shared '
              'with you.',
          onTap: () => context.push('/setup/join'),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Signed in as ${user?.email ?? 'your account'}',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
        ),
      ],
    );
  }
}

/// Membership exists but is inactive: access is paused, history is preserved.
class _PausedAccess extends StatelessWidget {
  const _PausedAccess({required this.account});

  final MyAccount account;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final orgName = account.organisation?.name ?? 'your organisation';
    final user = account.membership.fullName;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.amber50,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.amber600.withValues(alpha: .25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.pause_circle_outline_rounded,
                color: AppColors.amber600,
                size: AppIconSize.lg,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Access paused', style: textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your account at $orgName is currently deactivated. Ask the '
                'business owner to reactivate you — your attendance history '
                'is kept.',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.ink700),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Signed in as $user',
          style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
        ),
      ],
    );
  }
}
