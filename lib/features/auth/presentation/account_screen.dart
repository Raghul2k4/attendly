import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_error_panel.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/surface_card.dart';
import '../../organisation/domain/organisation_models.dart';
import '../../organisation/presentation/organisation_providers.dart';
import 'auth_controller.dart';
import 'privacy_policy_screen.dart';
import '../../../core/widgets/buy_me_coffee_card.dart';

/// Account and settings: who you are, which business you belong to, the
/// privacy policy, sign-out, and the Play-required account deletion.
///
/// Deletion is server-confirmed; the destructive dialog requires typing
/// DELETE and explains exactly what is removed for owners and employees.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await ref.read(authActionsProvider).signOut();
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Future<void> _confirmDelete(MyAccount? account) async {
    // The dialog pops itself after the server confirms deletion. The auth
    // state then sends the router to the welcome screen; popping anything
    // here would remove that destination.
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteAccountDialog(account: account),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final accountAsync = ref.watch(myAccountProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: SafeArea(
        child: accountAsync.when(
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
            final name = _displayName(account, user?.email);
            final email = user?.email ?? 'No email on this account';

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                SurfaceCard(
                  child: Row(
                    children: [
                      InitialAvatar(
                        initials: _initials(name),
                        size: 56,
                        background: AppColors.emerald50,
                        foreground: AppColors.emerald700,
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: textTheme.titleLarge),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              email,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.slate500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Business', style: textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.md),
                      if (account == null)
                        Text(
                          'You’re not connected to a business yet. Create one '
                          'or join with an invite token from the home screen.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.ink700,
                          ),
                        )
                      else ...[
                        _DetailRow(
                          label: 'Business',
                          value: account.organisation?.name ?? '—',
                        ),
                        _DetailRow(
                          label: 'Role',
                          value: account.membership.isOwner
                              ? 'Owner'
                              : 'Employee',
                        ),
                        if (!account.membership.isOwner &&
                            account.membership.employeeCode != null)
                          _DetailRow(
                            label: 'Staff code',
                            value: account.membership.employeeCode!,
                          ),
                        _DetailRow(
                          label: 'Status',
                          value: account.membership.isActive
                              ? 'Active'
                              : 'Paused by the owner',
                        ),
                        if (account.organisation != null)
                          _DetailRow(
                            label: 'Timezone',
                            value: account.organisation!.timezone,
                          ),
                        if (account.plan != null)
                          _DetailRow(
                            label: 'Plan',
                            value: account.plan!.hasStaffLimit
                                ? '${account.plan!.displayName} · '
                                      '${account.plan!.maxActiveEmployees} seats'
                                : '${account.plan!.displayName} · Unlimited '
                                      'staff',
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.privacy_tip_outlined,
                            color: AppColors.ink700,
                          ),
                          title: const Text('Privacy policy'),
                          subtitle: const Text(
                            'What is stored, why, and how to remove it',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PrivacyPolicyScreen(),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: _signingOut
                              ? const SizedBox(
                                  width: AppIconSize.md,
                                  height: AppIconSize.md,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.logout_rounded),
                          title: const Text('Sign out'),
                          subtitle: const Text(
                            'You can sign in again with your email and password',
                          ),
                          onTap: _signingOut ? null : _signOut,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const BuyMeCoffeeCard(),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Danger zone',
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.rose600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.rose50,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: AppColors.rose600.withValues(alpha: .2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Delete account', style: textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        account?.membership.isOwner == true
                            ? 'Deleting your account deletes your business and '
                                  'every attendance record in it. Your team '
                                  'loses access. This cannot be undone.'
                            : 'Deleting your account removes your sign-in '
                                  'identity and frees your seat. Your employer '
                                  'keeps its attendance records. This cannot be '
                                  'undone.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.ink700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.rose600,
                          side: const BorderSide(color: AppColors.rose600),
                        ),
                        onPressed: () => _confirmDelete(account),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Delete account'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _displayName(MyAccount? account, String? email) {
    final full = account?.membership.fullName.trim();
    if (full != null && full.isNotEmpty) return full;
    return email == null || email.trim().isEmpty ? 'Your account' : email;
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.ink900),
            ),
          ),
        ],
      ),
    );
  }
}

/// Typed-confirmation dialog. The RPC re-checks the DELETE string, so this
/// dialog is a safety net, not a security boundary.
class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog({required this.account});

  final MyAccount? account;

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _confirmation.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  bool get _canDelete => _confirmation.text.trim() == 'DELETE' && !_busy;

  Future<void> _delete() async {
    if (!_canDelete) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authActionsProvider).deleteAccount();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'We couldn’t delete the account. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final owner = account?.membership.isOwner == true;
    final orgName = account?.organisation?.name;

    final consequence = owner
        ? 'This permanently deletes ${orgName ?? 'your business'}, its '
              'workplaces, every attendance record, correction and audit entry. '
              'Your team members lose access to the business.'
        : account != null
        ? 'This permanently deletes your sign-in identity and frees your seat '
              'at ${orgName ?? 'your employer'}. Your employer keeps its '
              'attendance records, including your attendance history.'
        : 'This permanently deletes your sign-in identity and profile.';

    return AlertDialog(
      title: const Text('Delete account?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$consequence This cannot be undone.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.ink700, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Type DELETE to confirm',
              controller: _confirmation,
              textCapitalization: TextCapitalization.characters,
              enabled: !_busy,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.rose600),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.rose600,
            foregroundColor: Colors.white,
          ),
          onPressed: _canDelete ? _delete : null,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Delete account'),
        ),
      ],
    );
  }
}
