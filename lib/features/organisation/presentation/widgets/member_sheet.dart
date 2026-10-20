import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_error_panel.dart';
import '../../domain/organisation_models.dart';
import '../organisation_providers.dart';
import 'status_chips.dart';
import '../../../../core/widgets/surface_card.dart';

/// Owner actions for one member. Status changes go through the server RPC
/// (seat limits, guards and audit all live there); this sheet only confirms
/// intent and reports the mapped result.
class MemberSheet extends ConsumerStatefulWidget {
  const MemberSheet({
    super.key,
    required this.organisationId,
    required this.member,
  });

  final String organisationId;
  final Membership member;

  static Future<void> show(
    BuildContext context, {
    required String organisationId,
    required Membership member,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          MemberSheet(organisationId: organisationId, member: member),
    );
  }

  @override
  ConsumerState<MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends ConsumerState<MemberSheet> {
  bool _busy = false;
  AppException? _error;

  Future<void> _deactivate() async {
    final member = widget.member;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Deactivate ${member.fullName}?'),
        content: const Text(
          'They’ll lose access immediately and their seat becomes available '
          'for someone else. Attendance history is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.rose600),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _setStatus(active: false);
  }

  Future<void> _reactivate() => _setStatus(active: true);

  Future<void> _setStatus({required bool active}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(organisationRepositoryProvider)
          .setMemberStatus(
            organisationId: widget.organisationId,
            memberId: widget.member.id,
            active: active,
          );
      ref.invalidate(staffProvider(widget.organisationId));
      ref.invalidate(myAccountProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = mapBackendError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final member = widget.member;
    final explanation = switch (member.status) {
      MemberStatus.invited =>
        'This invite hasn’t been accepted yet. Share the invite token with '
            'them — it was shown once when the invite was created.',
      MemberStatus.active =>
        'They can currently sign in and use attendance. Deactivating frees '
            'their seat and keeps their attendance history.',
      MemberStatus.inactive =>
        'This account is deactivated. Reactivating uses a seat again and '
            'restores their access.',
    };

    return Padding(
      padding: MediaQuery.viewInsetsOf(context),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.slate200,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            Row(
              children: [
                InitialAvatar(initials: member.initials, size: 52),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.fullName, style: textTheme.titleLarge),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        member.employeeCode ?? 'No staff code',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.slate500,
                          letterSpacing: .6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: MemberStatusChip(status: member.status),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(explanation, style: textTheme.bodyMedium),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppErrorPanel(
                message: _error!.message,
                kind: _error!.kind,
                onRetry: member.isActive ? _reactivate : _deactivate,
              ),
            ],
            if (!member.isOwner && member.status != MemberStatus.invited) ...[
              const SizedBox(height: AppSpacing.xl),
              if (member.isActive)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _deactivate,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rose600,
                    side: BorderSide(
                      color: AppColors.rose600.withValues(alpha: .4),
                    ),
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: AppIconSize.sm,
                          height: AppIconSize.sm,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_off_outlined),
                  label: const Text('Deactivate employee'),
                )
              else
                AppPrimaryButton(
                  label: 'Reactivate employee',
                  onPressed: _reactivate,
                  inProgress: _busy,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
