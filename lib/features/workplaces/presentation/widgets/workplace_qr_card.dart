import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/clipboard_copy.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../domain/workplace_models.dart';
import '../workplace_providers.dart';

/// Owner-facing QR lifecycle for one workplace: generate, show once, replace
/// or revoke. The raw payload is held only in this widget's memory; the
/// server stores a hash and can never return it again.
class WorkplaceQrCard extends ConsumerStatefulWidget {
  const WorkplaceQrCard({
    super.key,
    required this.organisationId,
    required this.workplace,
  });

  final String organisationId;
  final Workplace workplace;

  @override
  ConsumerState<WorkplaceQrCard> createState() => _WorkplaceQrCardState();
}

class _WorkplaceQrCardState extends ConsumerState<WorkplaceQrCard> {
  String? _payload;
  bool _busy = false;
  String? _error;

  String get _orgId => widget.organisationId;
  bool get _active => widget.workplace.isActive;

  Future<void> _generate() async {
    final statuses = ref.read(qrStatusesProvider(_orgId)).value;
    final hasLiveCode =
        (statuses?.containsKey(widget.workplace.id) ?? false) ||
        _payload != null;
    if (hasLiveCode && !await _confirmReplace()) return;
    if (!mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final payload = await ref
          .read(workplaceRepositoryProvider)
          .generateQr(organisationId: _orgId, workplaceId: widget.workplace.id);
      ref.invalidate(qrStatusesProvider(_orgId));
      if (!mounted) return;
      setState(() => _payload = payload);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is AppException
            ? error.message
            : 'We couldn’t generate a QR code. Try again.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke() async {
    final confirmed = await _confirm(
      title: 'Revoke this QR code?',
      body:
          'The printed code will stop working immediately. You can generate '
          'a new one afterwards.',
      action: 'Revoke',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(workplaceRepositoryProvider)
          .revokeQr(organisationId: _orgId, workplaceId: widget.workplace.id);
      ref.invalidate(qrStatusesProvider(_orgId));
      if (!mounted) return;
      setState(() => _payload = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('QR code revoked')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is AppException
            ? error.message
            : 'We couldn’t revoke the QR code. Check your connection and try '
                  'again.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmReplace() => _confirm(
    title: 'Replace the QR code?',
    body:
        'The current printed code will stop working immediately. Print the '
        'new code and swap it at the workplace.',
    action: 'Replace QR',
  );

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final statuses = ref.watch(qrStatusesProvider(_orgId));
    final liveStatus = statuses.value?[widget.workplace.id];
    final hasLiveCode = liveStatus != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.emerald50,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: AppColors.emerald700,
                  size: AppIconSize.md,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text('Workplace QR', style: textTheme.titleMedium),
              ),
              AppBadge(
                label: hasLiveCode ? 'Active' : 'Not set up',
                background: hasLiveCode
                    ? AppColors.emerald50
                    : AppColors.slate200.withValues(alpha: .45),
                foreground: hasLiveCode
                    ? AppColors.emerald700
                    : AppColors.slate500,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_payload != null) ...[
            Text(
              'This is the only time this code is shown. Print it, or display '
              'it on a screen at the workplace entrance.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: QrImageView(
                  data: _payload!,
                  version: QrVersions.auto,
                  size: 208,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton.icon(
                onPressed: () =>
                    copyToClipboard(context, _payload!, label: 'QR code data'),
                icon: const Icon(Icons.copy_rounded, size: AppIconSize.sm),
                label: const Text('Copy code data'),
              ),
            ),
          ] else if (hasLiveCode) ...[
            Text(
              'A QR code is active for this workplace. For security we can’t '
              'show it again — use the printed copy, or replace it if it was '
              'lost.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Active since ${DateFormat.yMMMd().format(liveStatus.createdAt.toLocal())}.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.ink600),
            ),
          ] else if (statuses.isLoading) ...[
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('Checking QR status…', style: textTheme.bodySmall),
              ],
            ),
          ] else if (statuses.hasError) ...[
            Text(
              'We couldn’t check whether a QR code is active.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.rose600),
            ),
            TextButton(
              onPressed: () => ref.invalidate(qrStatusesProvider(_orgId)),
              child: const Text('Check again'),
            ),
          ] else ...[
            Text(
              'Generate a permanent QR code for this workplace. Employees can '
              'scan it when QR attendance is enabled.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.rose50,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AppColors.rose600.withValues(alpha: .25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.rose600,
                    size: AppIconSize.sm,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _error!,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.rose600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: LinearProgressIndicator(minHeight: 3),
            )
          else if (_payload != null || hasLiveCode)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: _active ? _generate : null,
                  icon: const Icon(Icons.autorenew_rounded),
                  label: const Text('Replace QR'),
                ),
                TextButton(
                  onPressed: _revoke,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.rose600,
                  ),
                  child: const Text('Revoke'),
                ),
              ],
            )
          else
            FilledButton.tonalIcon(
              onPressed: _active && !statuses.isLoading ? _generate : null,
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text('Generate QR'),
            ),
          if (!_active) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This workplace is inactive. Turn it back on above and save '
              'before generating a QR code.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.amber600),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'Anyone who copies this code can try to check in. Location checks '
            'still apply, and you can replace the code at any time.',
            style: textTheme.labelSmall?.copyWith(color: AppColors.slate400),
          ),
        ],
      ),
    );
  }
}
