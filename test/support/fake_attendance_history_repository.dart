import 'package:attendance/features/attendance/data/attendance_history_repository.dart';
import 'package:attendance/features/attendance/domain/attendance_history_models.dart';

import 'attendance_history_fixtures.dart';

typedef MyHistoryCall = ({String organisationId, DateTime? from, DateTime? to});

typedef ReportCall = ({
  String organisationId,
  DateTime? from,
  DateTime? to,
  String? memberId,
});

/// Deterministic reporting fake. Builders let tests return a different payload
/// for a requested month/filter while still recording exactly what was asked.
class FakeAttendanceHistoryRepository implements AttendanceHistoryRepository {
  FakeAttendanceHistoryRepository({
    AttendanceHistory? myHistory,
    AttendanceHistory? report,
    OwnerAttendanceOverview? overview,
    this.myHistoryBuilder,
    this.reportBuilder,
    this.myHistoryError,
    this.reportError,
    this.overviewError,
  }) : myHistory = myHistory ?? testAttendanceHistory(),
       report = report ?? testAttendanceHistory(),
       overview = overview ?? testOwnerOverview();

  AttendanceHistory myHistory;
  AttendanceHistory report;
  OwnerAttendanceOverview overview;
  final AttendanceHistory Function(String, DateTime?, DateTime?)?
  myHistoryBuilder;
  final AttendanceHistory Function(String, DateTime?, DateTime?, String?)?
  reportBuilder;
  Object? myHistoryError;
  Object? reportError;
  Object? overviewError;

  int myHistoryCalls = 0;
  int reportCalls = 0;
  int overviewCalls = 0;
  final List<MyHistoryCall> myHistoryQueries = [];
  final List<ReportCall> reportQueries = [];

  @override
  Future<AttendanceHistory> fetchMyHistory({
    required String organisationId,
    DateTime? from,
    DateTime? to,
  }) async {
    myHistoryCalls++;
    myHistoryQueries.add((organisationId: organisationId, from: from, to: to));
    if (myHistoryError != null) throw myHistoryError!;
    return myHistoryBuilder?.call(organisationId, from, to) ?? myHistory;
  }

  @override
  Future<AttendanceHistory> fetchReport({
    required String organisationId,
    DateTime? from,
    DateTime? to,
    String? memberId,
  }) async {
    reportCalls++;
    reportQueries.add((
      organisationId: organisationId,
      from: from,
      to: to,
      memberId: memberId,
    ));
    if (reportError != null) throw reportError!;
    return reportBuilder?.call(organisationId, from, to, memberId) ?? report;
  }

  @override
  Future<OwnerAttendanceOverview> fetchOwnerOverview(
    String organisationId,
  ) async {
    overviewCalls++;
    if (overviewError != null) throw overviewError!;
    return overview;
  }
}
