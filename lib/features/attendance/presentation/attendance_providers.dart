import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart' show supabaseClientProvider;
import '../data/attendance_history_repository.dart';
import '../data/attendance_repository.dart';
import '../data/attendance_settings_repository.dart';
import '../domain/attendance_history_models.dart';
import '../domain/attendance_models.dart';

/// Single attendance data source. Widget tests override this with a fake.
final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => SupabaseAttendanceRepository(ref.watch(supabaseClientProvider)),
);

final attendanceHistoryRepositoryProvider =
    Provider<AttendanceHistoryRepository>(
      (ref) => SupabaseAttendanceHistoryRepository(
        ref.watch(supabaseClientProvider),
      ),
    );

final attendanceSettingsRepositoryProvider =
    Provider<AttendanceSettingsRepository>(
      (ref) => SupabaseAttendanceSettingsRepository(
        ref.watch(supabaseClientProvider),
      ),
    );

/// Effective owner policy for one organisation. The screen re-fetches after an
/// update so it always displays the values the server accepted.
final attendanceSettingsProvider = FutureProvider.autoDispose
    .family<AttendanceSettings, String>(
      (ref, organisationId) =>
          ref.watch(attendanceSettingsRepositoryProvider).fetch(organisationId),
      retry: (retryCount, error) => null,
    );

/// Today's server-authoritative attendance state for one employee.
final attendanceTodayProvider = FutureProvider.autoDispose
    .family<AttendanceToday, String>(
      (ref, organisationId) =>
          ref.watch(attendanceRepositoryProvider).fetchToday(organisationId),
      // A failed load must render a visible, user-triggered retry. Riverpod's
      // automatic retry would otherwise keep the screen in a loading state.
      retry: (retryCount, error) => null,
    );

typedef MyAttendanceHistoryQuery = ({
  String organisationId,
  DateTime? from,
  DateTime? to,
});

/// The employee's own history. Null dates let the server choose the current
/// organisation-local month.
final myAttendanceHistoryProvider = FutureProvider.autoDispose
    .family<AttendanceHistory, MyAttendanceHistoryQuery>(
      (ref, query) => ref
          .watch(attendanceHistoryRepositoryProvider)
          .fetchMyHistory(
            organisationId: query.organisationId,
            from: query.from,
            to: query.to,
          ),
      retry: (retryCount, error) => null,
    );

typedef AttendanceReportQuery = ({
  String organisationId,
  DateTime? from,
  DateTime? to,
  String? memberId,
});

/// Owner-scoped report. RLS/RPC validation is the authority; the query object
/// only expresses the requested filter.
final attendanceReportProvider = FutureProvider.autoDispose
    .family<AttendanceHistory, AttendanceReportQuery>(
      (ref, query) => ref
          .watch(attendanceHistoryRepositoryProvider)
          .fetchReport(
            organisationId: query.organisationId,
            from: query.from,
            to: query.to,
            memberId: query.memberId,
          ),
      retry: (retryCount, error) => null,
    );

/// Live owner dashboard counts computed from recorded sessions.
final ownerAttendanceOverviewProvider = FutureProvider.autoDispose
    .family<OwnerAttendanceOverview, String>(
      (ref, organisationId) => ref
          .watch(attendanceHistoryRepositoryProvider)
          .fetchOwnerOverview(organisationId),
      retry: (retryCount, error) => null,
    );
