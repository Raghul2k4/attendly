import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/env/env_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_panel.dart';
import '../../auth/presentation/auth_controller.dart';

/// Post-auth home while the database-backed screens ship. Shows the real
/// signed-in identity and working sign-out — nothing simulated.
class AccountHomeScreen extends ConsumerStatefulWidget {
  const AccountHomeScreen({super.key});

  @override
  ConsumerState<AccountHomeScreen> createState() => _AccountHomeScreenState();
}

class _AccountHomeScreenState extends ConsumerState<AccountHomeScreen> {
  bool _signingOut = false;
  AppException? _signOutError;

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() {
      _signingOut = true;
      _signOutError = null;
    });
    try {
      await ref.read(authActionsProvider).signOut();
      // Router reacts to authChanges; nothing here.
    } on AppException catch (error) {
      if (mounted) setState(() => _signOutError = error);
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final textTheme = Theme.of(context).textTheme;
    final name =
        user?.userMetadata?['full_name'] as String? ?? user?.email ?? 'there';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text(
              'Signed in as',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
            ),
            Text(name, style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            if (user?.email case final email?)
              Text(
                email,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.slate500,
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
            Text('What works today', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '• Account creation, sign in and sign out\n'
              '• Your session stays valid between app restarts\n\n'
              'Organisation setup, staff codes and attendance arrive with '
              'the next database update.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xxl),
            if (_signOutError != null) ...[
              AppErrorPanel(
                message: _signOutError!.message,
                kind: _signOutError!.kind,
                onRetry: _signOut,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            AppPrimaryButton(
              label: 'Sign out',
              onPressed: _signOut,
              inProgress: _signingOut,
            ),
            if (!EnvConfig.isReal) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Supabase credentials still point at placeholder values — '
                'this session is running against a real but unconfigured '
                'project.',
                style: textTheme.bodySmall?.copyWith(color: AppColors.amber600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
