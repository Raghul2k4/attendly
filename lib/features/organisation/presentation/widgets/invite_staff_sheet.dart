import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/clipboard_copy.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_error_panel.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/sheet_handle.dart';
import '../../domain/organisation_models.dart';
import '../organisation_providers.dart';

/// Bottom sheet that issues a staff code + one-time invite token. The raw
/// token is displayed exactly once (the server stores only a hash), so the
/// success view prioritises copying before leaving.
class InviteStaffSheet extends ConsumerStatefulWidget {
  const InviteStaffSheet({
    super.key,
    required this.organisationId,
    required this.organisationName,
  });

  final String organisationId;
  final String organisationName;

  static Future<void> show(
    BuildContext context, {
    required String organisationId,
    required String organisationName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => InviteStaffSheet(
        organisationId: organisationId,
        organisationName: organisationName,
      ),
    );
  }

  @override
  ConsumerState<InviteStaffSheet> createState() => _InviteStaffSheetState();
}

class _InviteStaffSheetState extends ConsumerState<InviteStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _submitting = false;
  AppException? _error;
  InviteResult? _result;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(organisationRepositoryProvider)
          .inviteEmployee(
            organisationId: widget.organisationId,
            fullName: _nameController.text,
          );
      ref.invalidate(staffProvider(widget.organisationId));
      ref.invalidate(myAccountProvider);
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = mapBackendError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _shareText(InviteResult result) {
    final token = Validators.formatInviteToken(result.inviteToken);
    return 'Hi ${result.employeeName}, join ${widget.organisationName} on '
        'Attendly.\n\nStaff code: ${result.employeeCode}\n'
        'Invite token: $token\n\nOpen the app, choose "Join with an invite '
        'token" and paste it. The token works once.';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final result = _result;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: result == null
            ? _buildForm(context)
            : _buildResult(context, result),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          Text('Add a team member', style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Create their staff code and a one-time invite token you can '
            'share.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            label: 'Employee name',
            controller: _nameController,
            validator: Validators.employeeName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            enabled: !_submitting,
            onFieldSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppErrorPanel(
              message: _error!.message,
              kind: _error!.kind,
              onRetry: _submit,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppPrimaryButton(
            label: 'Create invite',
            onPressed: _submit,
            inProgress: _submitting,
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context, InviteResult result) {
    final textTheme = Theme.of(context).textTheme;
    final token = Validators.formatInviteToken(result.inviteToken);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHandle(),
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.emerald50,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.emerald700,
                size: AppIconSize.md,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invite ready', style: textTheme.titleLarge),
                  Text(
                    'for ${result.employeeName}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _CodeBlock(
          label: 'STAFF CODE',
          value: result.employeeCode,
          copyLabel: 'Staff code',
        ),
        const SizedBox(height: AppSpacing.md),
        _CodeBlock(
          label: 'INVITE TOKEN — SHOWN ONCE',
          value: token,
          copyLabel: 'Invite token',
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Share both with ${result.employeeName}. The token lets them join a '
          'single time — we only keep a hash, so it can’t be shown again.',
          style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
        ),
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton.icon(
          onPressed: () => copyToClipboard(
            context,
            _shareText(result),
            label: 'Invite details',
          ),
          icon: const Icon(Icons.copy_all_rounded),
          label: const Text('Copy invite details'),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppPrimaryButton(
          label: 'Done',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({
    required this.label,
    required this.value,
    required this.copyLabel,
  });

  final String label;
  final String value;
  final String copyLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.slate500,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(
                  value,
                  style: textTheme.titleMedium?.copyWith(letterSpacing: 1.2),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy $copyLabel',
            onPressed: () => copyToClipboard(context, value, label: copyLabel),
            icon: const Icon(
              Icons.copy_rounded,
              size: AppIconSize.md,
              color: AppColors.ink600,
            ),
          ),
        ],
      ),
    );
  }
}
