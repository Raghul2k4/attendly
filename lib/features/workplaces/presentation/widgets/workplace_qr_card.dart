import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/clipboard_copy.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../data/qr_pdf_exporter.dart';
import '../../domain/workplace_models.dart';
import '../../domain/workplace_qr_poster.dart';
import '../workplace_providers.dart';

/// Owner-facing QR lifecycle for one workplace: show the current code, download
/// a printable poster, replace or revoke it.
///
/// The live payload is loaded from `get_workplace_qr` whenever a live token
/// exists, so closing the screen, refreshing or relaunching the app never loses
/// the code (the first version held it in widget memory only).
class WorkplaceQrCard extends ConsumerStatefulWidget {
  const WorkplaceQrCard({
    super.key,
    required this.organisationId,
    required this.organisationName,
    required this.workplace,
  });

  final String organisationId;
  final String organisationName;
  final Workplace workplace;

  @override
  ConsumerState<WorkplaceQrCard> createState() => _WorkplaceQrCardState();
}

class _WorkplaceQrCardState extends ConsumerState<WorkplaceQrCard> {
  String? _payload;
  bool _loadingPayload = false;
  bool _payloadRequested = false;
  bool _printing = false;
  bool _busy = false;
  String? _payloadError;
  String? _error;

  String get _orgId => widget.organisationId;
  bool get _active => widget.workplace.isActive;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final statuses = ref.watch(qrStatusesProvider(_orgId));
    final liveStatus = statuses.value?[widget.workplace.id];
    final hasLiveCode = liveStatus != null;

    // A live code exists but this screen has not asked for it yet: fetch the
    // payload once the current frame is built.
    if (hasLiveCode &&
        _payload == null &&
        !_loadingPayload &&
        !_payloadRequested) {
      _payloadRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadPayload();
      });
    }

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
          if (_payload != null) ..._liveCode(context) else if (hasLiveCode)
            ..._reopening(Theme.of(context), liveStatus)
          else if (statuses.isLoading)
            ..._checkingStatus(Theme.of(context))
          else if (statuses.hasError)
            ..._statusError(Theme.of(context))
          else
            ..._noCodeYet(Theme.of(context)),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            _errorPanel(_error!),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (_busy || _printing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: LinearProgressIndicator(minHeight: 3),
            )
          else if (hasLiveCode)
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

  List<Widget> _liveCode(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return [
      Text(
        'Download the poster, print it, and put it up at the entrance. This '
        'code stays available here, so you can print it again whenever you '
        'need to.',
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
      const SizedBox(height: AppSpacing.md),
      FilledButton.icon(
        onPressed: _printing ? null : _downloadPdf,
        icon: _printing
            ? const SizedBox(
                width: AppIconSize.sm,
                height: AppIconSize.sm,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.surface,
                ),
              )
            : const Icon(Icons.picture_as_pdf_outlined),
        label: Text(_printing ? 'Preparing PDF…' : 'Download printable PDF'),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'The next screen is Android’s print sheet — choose “Save as PDF” to '
        'keep a copy, or pick a printer.',
        style: textTheme.labelSmall?.copyWith(color: AppColors.slate500),
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
    ];
  }

  List<Widget> _reopening(ThemeData theme, WorkplaceQrStatus? liveStatus) {
    final textTheme = theme.textTheme;
    if (_payloadError != null) {
      return [
        Text(
          _payloadError!,
          style: textTheme.bodySmall?.copyWith(color: AppColors.rose600),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: _retryPayload,
          child: const Text('Try again'),
        ),
      ];
    }

    return [
      Text(
        _loadingPayload
            ? 'Opening the current code…'
            : 'Loading the printable code for this workplace.',
        style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Active since '
        '${DateFormat.yMMMd().format(liveStatus!.createdAt.toLocal())}.',
        style: textTheme.bodySmall?.copyWith(color: AppColors.ink600),
      ),
      if (_loadingPayload) ...[
        const SizedBox(height: AppSpacing.md),
        const LinearProgressIndicator(minHeight: 3),
      ],
    ];
  }

  List<Widget> _checkingStatus(ThemeData theme) {
    return [
      Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('Checking QR status…', style: theme.textTheme.bodySmall),
        ],
      ),
    ];
  }

  List<Widget> _statusError(ThemeData theme) {
    return [
      Text(
        'We couldn’t check whether a QR code is active.',
        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.rose600),
      ),
      TextButton(
        onPressed: () => ref.invalidate(qrStatusesProvider(_orgId)),
        child: const Text('Check again'),
      ),
    ];
  }

  List<Widget> _noCodeYet(ThemeData theme) {
    return [
      Text(
        'Generate a permanent QR code for this workplace. Employees can '
        'scan it when QR attendance is enabled.',
        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.slate500),
      ),
    ];
  }

  Widget _errorPanel(String message) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.rose50,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.rose600.withValues(alpha: .25)),
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
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.rose600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPayload() async {
    setState(() {
      _loadingPayload = true;
      _payloadError = null;
    });
    try {
      final payload = await ref
          .read(workplaceRepositoryProvider)
          .fetchQrPayload(
            organisationId: _orgId,
            workplaceId: widget.workplace.id,
          );
      if (!mounted) return;
      setState(() => _payload = payload);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _payloadError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _payloadError =
            'We couldn’t open this QR code. Check your connection and try '
            'again.';
      });
    } finally {
      if (mounted) setState(() => _loadingPayload = false);
    }
  }

  void _retryPayload() {
    setState(() {
      _payloadError = null;
      _payloadRequested = false;
    });
  }

  Future<void> _downloadPdf() async {
    final payload = _payload;
    if (payload == null || _printing) return;

    setState(() {
      _printing = true;
      _error = null;
    });
    try {
      final bytes = await buildWorkplaceQrPoster(
        WorkplaceQrPosterData(
          payload: payload,
          workplaceName: widget.workplace.name,
          organisationName: widget.organisationName,
          generatedAt: DateTime.now(),
        ),
      );
      await ref
          .read(qrPdfExporterProvider)
          .saveOrPrint(
            bytes: bytes,
            filename: workplaceQrPosterFileName(
              workplaceName: widget.workplace.name,
            ),
          );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'We couldn’t prepare the PDF. Try again, or print the QR code '
            'above from another device.';
      });
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

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
      setState(() {
        _payload = payload;
        _payloadError = null;
        _payloadRequested = true;
      });
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
      setState(() {
        _payload = null;
        _payloadError = null;
        _payloadRequested = false;
      });
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
}
