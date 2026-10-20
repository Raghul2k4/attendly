import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/location/location_service.dart';
import '../../../core/utils/clipboard_copy.dart';
import '../../../core/widgets/app_error_panel.dart';
import '../../../core/widgets/surface_card.dart';
import '../../organisation/domain/organisation_models.dart';
import '../../organisation/presentation/organisation_providers.dart';
import '../domain/attendance_format.dart';
import '../domain/attendance_models.dart';
import '../domain/attendance_qr.dart';
import 'attendance_providers.dart';
import 'qr_scan_launcher.dart';
import 'widgets/attendance_notice.dart';
import 'widgets/attendance_status_card.dart';
import 'widgets/attendance_summary_card.dart';

/// Employee home: one clear attendance action, server-confirmed state and the
/// evidence behind today's session. A success state is only shown after the
/// RPC returns an accepted result.
class EmployeeHomeView extends ConsumerStatefulWidget {
  const EmployeeHomeView({super.key, required this.account});

  final MyAccount account;

  @override
  ConsumerState<EmployeeHomeView> createState() => _EmployeeHomeViewState();
}

class _EmployeeHomeViewState extends ConsumerState<EmployeeHomeView> {
  final _uuid = const Uuid();
  Timer? _ticker;
  bool _live = false;
  bool _punching = false;
  AttendanceNoticeData? _notice;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _live) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refresh(String organisationId) async {
    ref.invalidate(attendanceTodayProvider(organisationId));
    try {
      await ref.read(attendanceTodayProvider(organisationId).future);
    } catch (_) {
      // The provider renders the recoverable error state.
    }
  }

  Future<void> _punch(
    String organisationId,
    AttendanceToday today,
    PunchAction action, {
    PunchMethod method = PunchMethod.app,
    String? qrPayload,
  }) async {
    if (_punching) return;
    setState(() {
      _punching = true;
      _notice = null;
    });

    try {
      final reading = await ref.read(locationServiceProvider).currentPosition();
      final result = await ref
          .read(attendanceRepositoryProvider)
          .punch(
            organisationId: organisationId,
            action: action,
            method: method,
            latitude: reading.latitude,
            longitude: reading.longitude,
            accuracyMeters: reading.accuracyMeters,
            idempotencyKey: _uuid.v4(),
            workplaceId: method == PunchMethod.app ? today.workplace?.id : null,
            qrPayload: qrPayload,
          );

      if (!mounted) return;

      if (result.accepted) {
        setState(() {
          _notice = AttendanceNoticeData(
            kind: AttendanceNoticeKind.accepted,
            title: acceptedPunchTitle(result),
            message: acceptedPunchMessage(result),
          );
        });
        await _refresh(organisationId);
      } else {
        final rejection = attendanceRejectionCopy(
          result,
          maxAccuracyMeters: today.settings.maxAccuracyMeters,
        );
        setState(() {
          _notice = AttendanceNoticeData(
            kind: AttendanceNoticeKind.warning,
            title: rejection.title,
            message: rejection.message,
          );
        });
        await _refresh(organisationId);
      }
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _notice = AttendanceNoticeData(
          kind: AttendanceNoticeKind.error,
          title: 'Punch not recorded',
          message: error.message,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notice = const AttendanceNoticeData(
          kind: AttendanceNoticeKind.error,
          title: 'Punch not recorded',
          message:
              'We couldn’t confirm this punch with the server. Refresh and '
              'check your status before trying again.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _punching = false);
      }
    }
  }

  Future<void> _scanAndPunch(
    String organisationId,
    AttendanceToday today,
  ) async {
    if (_punching) return;

    String? payload;
    try {
      payload = await ref.read(qrScanLauncherProvider).scan(context);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notice = const AttendanceNoticeData(
          kind: AttendanceNoticeKind.error,
          title: 'Scanner unavailable',
          message:
              'We couldn’t open the camera. Try again, or use the app punch if '
              'your owner has enabled it.',
        );
      });
      return;
    }

    if (!mounted || payload == null) return;

    final token = attendanceQrToken(payload);
    if (token == null) {
      setState(() {
        _notice = const AttendanceNoticeData(
          kind: AttendanceNoticeKind.warning,
          title: 'Not a workplace QR code',
          message:
              'Point the camera at the printed Attendance code from your '
              'owner. Nothing was recorded.',
        );
      });
      return;
    }
    final canonicalPayload = '$attendanceQrPrefix$token';

    final action = today.nextAction;
    if (action == null) {
      setState(() {
        _notice = const AttendanceNoticeData(
          kind: AttendanceNoticeKind.warning,
          title: 'Attendance changed',
          message:
              'Your attendance state changed while scanning. Refresh and check '
              'your status before trying again. Nothing was recorded.',
        );
      });
      await _refresh(organisationId);
      return;
    }

    await _punch(
      organisationId,
      today,
      action,
      method: PunchMethod.qr,
      qrPayload: canonicalPayload,
    );
  }

  @override
  Widget build(BuildContext context) {
    final organisation = widget.account.organisation;
    if (organisation == null) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          AppErrorPanel(
            message: 'We couldn’t load your organisation. Try again.',
            kind: AppErrorKind.server,
            onRetry: () => ref.invalidate(myAccountProvider),
          ),
        ],
      );
    }

    final state = ref.watch(attendanceTodayProvider(organisation.id));
    final today = state.value;
    _live = today?.hasOpenSession ?? false;

    if (today == null) {
      if (state.isLoading) {
        return const _LoadingView();
      }
      final error = state.error;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          AppErrorPanel(
            message: error is AppException
                ? error.message
                : 'We couldn’t load your attendance. Try again.',
            kind: error is AppException ? error.kind : AppErrorKind.unknown,
            onRetry: () =>
                ref.invalidate(attendanceTodayProvider(organisation.id)),
          ),
        ],
      );
    }

    final firstName = widget.account.membership.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .first;
    final code = widget.account.membership.employeeCode ?? '—';

    return RefreshIndicator(
      onRefresh: () => _refresh(organisation.id),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          Row(
            children: [
              InitialAvatar(
                initials: widget.account.membership.initials,
                size: 52,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, $firstName',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      organisation.name,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.slate500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: AppIconSize.sm,
                color: AppColors.slate500,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                DateFormat('EEEE, d MMMM').format(today.workDate),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.slate500),
              ),
              if (state.isLoading) ...[
                const Spacer(),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AttendanceStatusCard(
            today: today,
            now: DateTime.now().toUtc(),
            punching: _punching,
            onPunch: () {
              final action = today.nextAction;
              if (action != null) _punch(organisation.id, today, action);
            },
            onScanQr: () => _scanAndPunch(organisation.id, today),
          ),
          if (_notice != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AttendanceNotice(data: _notice!),
          ],
          const SizedBox(height: AppSpacing.lg),
          AttendanceSummaryCard(today: today),
          const SizedBox(height: AppSpacing.lg),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR STAFF CODE',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: AppColors.slate500, letterSpacing: 1.1),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        code,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          letterSpacing: 2,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy staff code',
                      onPressed: () =>
                          copyToClipboard(context, code, label: 'Staff code'),
                      icon: const Icon(
                        Icons.copy_rounded,
                        size: AppIconSize.md,
                        color: AppColors.ink600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'This identifies you to your owner. It is not a password — '
                  'never use it to sign in.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.slate500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: 120),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Loading today’s attendance…',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.slate500),
        ),
      ],
    );
  }
}
