import '../../organisation/domain/organisation_models.dart';

/// Shared date-only helpers for server-provided organisation-local dates.
/// These values are labels, not instants: never convert them to another zone.
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime firstDayOfMonth(DateTime value) =>
    DateTime(value.year, value.month, 1);

DateTime lastDayOfMonth(DateTime value) =>
    DateTime(value.year, value.month + 1, 0);

DateTime firstDayOfMonthOffset(DateTime value, int months) =>
    DateTime(value.year, value.month + months, 1);

DateTime lastDayOfMonthOffset(DateTime value, int months) =>
    DateTime(value.year, value.month + months + 1, 0);

bool isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime addCalendarDays(DateTime value, int days) =>
    DateTime(value.year, value.month, value.day + days);

String isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

DateTime? _dateOnly(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  return parsed == null ? null : dateOnly(parsed);
}

DateTime? _utcDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}

Duration? _seconds(Object? value) {
  if (value is! num) return null;
  final seconds = value.toInt();
  return seconds < 0 ? Duration.zero : Duration(seconds: seconds);
}

Map<String, dynamic> _map(Object? value) =>
    (value as Map?)?.cast<String, dynamic>() ?? const {};

MemberStatus _memberStatus(Object? value) => switch (value) {
  'active' => MemberStatus.active,
  'invited' => MemberStatus.invited,
  _ => MemberStatus.inactive,
};

/// One recorded work session. Times and durations are formatted by the server
/// in the organisation timezone; this model only parses what it received.
class AttendanceHistoryEntry {
  const AttendanceHistoryEntry({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.employeeCode,
    required this.memberStatus,
    required this.workplaceName,
    required this.workDate,
    required this.checkInAt,
    required this.checkOutAt,
    required this.checkInTime,
    required this.checkOutTime,
    required this.isLate,
    required this.isOpen,
    required this.isStaleOpen,
    required this.crossesMidnight,
    required this.duration,
    required this.elapsed,
  });

  factory AttendanceHistoryEntry.fromJson(Map<String, dynamic> json) {
    final workDate = _dateOnly(json['work_date']);
    final checkInAt = _utcDateTime(json['check_in_at']);
    if (workDate == null || checkInAt == null) {
      throw const FormatException('Attendance record is missing timestamps');
    }
    return AttendanceHistoryEntry(
      id: json['id'] as String,
      memberId: json['member_id'] as String? ?? '',
      memberName: json['member_name'] as String? ?? 'Employee',
      employeeCode: json['employee_code'] as String?,
      memberStatus: _memberStatus(json['member_status']),
      workplaceName: json['workplace_name'] as String? ?? 'Workplace',
      workDate: workDate,
      checkInAt: checkInAt,
      checkOutAt: _utcDateTime(json['check_out_at']),
      checkInTime: json['check_in_time'] as String? ?? '--:--',
      checkOutTime: json['check_out_time'] as String?,
      isLate: json['is_late'] as bool? ?? false,
      isOpen: json['is_open'] as bool? ?? json['check_out_at'] == null,
      isStaleOpen: json['is_stale_open'] as bool? ?? false,
      crossesMidnight: json['crosses_midnight'] as bool? ?? false,
      duration: _seconds(json['duration_seconds']),
      elapsed: _seconds(json['elapsed_seconds']),
    );
  }

  final String id;
  final String memberId;
  final String memberName;
  final String? employeeCode;
  final MemberStatus memberStatus;
  final String workplaceName;
  final DateTime workDate;
  final DateTime checkInAt;
  final DateTime? checkOutAt;
  final String checkInTime;
  final String? checkOutTime;
  final bool isLate;
  final bool isOpen;
  final bool isStaleOpen;
  final bool crossesMidnight;
  final Duration? duration;
  final Duration? elapsed;

  bool get isCompleted => !isOpen;

  /// Completed sessions expose their stored duration; open sessions expose the
  /// server-calculated elapsed time, clearly labelled as in progress.
  Duration? get displayDuration => isOpen ? elapsed : duration;

  String get statusLabel {
    if (isStaleOpen) return 'Open from a previous day';
    if (isOpen) return 'Still checked in';
    if (isLate) return 'Late';
    return 'Completed';
  }
}

class AttendanceHistoryMember {
  const AttendanceHistoryMember({
    required this.id,
    required this.fullName,
    required this.employeeCode,
    required this.status,
  });

  factory AttendanceHistoryMember.fromJson(Map<String, dynamic> json) =>
      AttendanceHistoryMember(
        id: json['id'] as String,
        fullName: json['full_name'] as String? ?? 'Employee',
        employeeCode: json['employee_code'] as String?,
        status: _memberStatus(json['status']),
      );

  final String id;
  final String fullName;
  final String? employeeCode;
  final MemberStatus status;
}

class AttendanceHistorySummary {
  const AttendanceHistorySummary({
    required this.sessionCount,
    required this.memberCount,
    required this.completedCount,
    required this.openCount,
    required this.lateCount,
    required this.totalWork,
  });

  factory AttendanceHistorySummary.fromJson(Map<String, dynamic> json) =>
      AttendanceHistorySummary(
        sessionCount: (json['session_count'] as num?)?.toInt() ?? 0,
        memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
        completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
        openCount: (json['open_count'] as num?)?.toInt() ?? 0,
        lateCount: (json['late_count'] as num?)?.toInt() ?? 0,
        totalWork: _seconds(json['total_work_seconds']) ?? Duration.zero,
      );

  final int sessionCount;
  final int memberCount;
  final int completedCount;
  final int openCount;
  final int lateCount;
  final Duration totalWork;

  bool get isEmpty => sessionCount == 0;

  Duration get averageCompleted => completedCount == 0
      ? Duration.zero
      : Duration(seconds: totalWork.inSeconds ~/ completedCount);
}

/// Server-scoped attendance history. The same shape serves an employee's own
/// history and an owner's report; employee responses intentionally carry no
/// member roster.
class AttendanceHistory {
  const AttendanceHistory({
    required this.timezone,
    required this.today,
    required this.from,
    required this.to,
    required this.members,
    required this.sessions,
    required this.summary,
  });

  factory AttendanceHistory.fromJson(Map<String, dynamic> json) {
    final today = _dateOnly(json['today']);
    final from = _dateOnly(json['from']);
    final to = _dateOnly(json['to']);
    if (today == null || from == null || to == null) {
      throw const FormatException('Attendance history is missing its period');
    }
    return AttendanceHistory(
      timezone: json['timezone'] as String? ?? 'UTC',
      today: today,
      from: from,
      to: to,
      members:
          (json['members'] as List?)
              ?.whereType<Map>()
              .map((row) => AttendanceHistoryMember.fromJson(row.cast()))
              .toList(growable: false) ??
          const [],
      sessions:
          (json['sessions'] as List?)
              ?.whereType<Map>()
              .map((row) => AttendanceHistoryEntry.fromJson(row.cast()))
              .toList(growable: false) ??
          const [],
      summary: AttendanceHistorySummary.fromJson(_map(json['summary'])),
    );
  }

  final String timezone;
  final DateTime today;
  final DateTime from;
  final DateTime to;
  final List<AttendanceHistoryMember> members;
  final List<AttendanceHistoryEntry> sessions;
  final AttendanceHistorySummary summary;

  bool get isEmpty => sessions.isEmpty;

  bool get canMoveNextMonth =>
      firstDayOfMonth(from).isBefore(firstDayOfMonth(today));
}

class AttendanceOpenSession {
  const AttendanceOpenSession({
    required this.memberId,
    required this.memberName,
    required this.employeeCode,
    required this.checkInTime,
    required this.workDate,
    required this.isLate,
    required this.isStaleOpen,
  });

  factory AttendanceOpenSession.fromJson(Map<String, dynamic> json) {
    final workDate = _dateOnly(json['work_date']);
    if (workDate == null) {
      throw const FormatException('Open session is missing its work date');
    }
    return AttendanceOpenSession(
      memberId: json['member_id'] as String? ?? '',
      memberName: json['member_name'] as String? ?? 'Employee',
      employeeCode: json['employee_code'] as String?,
      checkInTime: json['check_in_time'] as String? ?? '--:--',
      workDate: workDate,
      isLate: json['is_late'] as bool? ?? false,
      isStaleOpen: json['is_stale_open'] as bool? ?? false,
    );
  }

  final String memberId;
  final String memberName;
  final String? employeeCode;
  final String checkInTime;
  final DateTime workDate;
  final bool isLate;
  final bool isStaleOpen;
}

/// Live owner dashboard counts. Every count is computed by the server from
/// recorded sessions; "no record yet" is never labelled as an absence.
class OwnerAttendanceOverview {
  const OwnerAttendanceOverview({
    required this.timezone,
    required this.serverTime,
    required this.today,
    required this.isWorkingDay,
    required this.activeEmployeeCount,
    required this.presentTodayCount,
    required this.checkedInNowCount,
    required this.completedTodayCount,
    required this.lateTodayCount,
    required this.unresolvedPriorCount,
    required this.noRecordTodayCount,
    required this.openSessions,
    required this.recentSessions,
  });

  factory OwnerAttendanceOverview.fromJson(Map<String, dynamic> json) {
    final today = _dateOnly(json['today']);
    final serverTime = _utcDateTime(json['server_time']);
    if (today == null || serverTime == null) {
      throw const FormatException('Attendance overview is missing server time');
    }
    return OwnerAttendanceOverview(
      timezone: json['timezone'] as String? ?? 'UTC',
      serverTime: serverTime,
      today: today,
      isWorkingDay: json['is_working_day'] as bool? ?? false,
      activeEmployeeCount:
          (json['active_employee_count'] as num?)?.toInt() ?? 0,
      presentTodayCount: (json['present_today_count'] as num?)?.toInt() ?? 0,
      checkedInNowCount: (json['checked_in_now_count'] as num?)?.toInt() ?? 0,
      completedTodayCount:
          (json['completed_today_count'] as num?)?.toInt() ?? 0,
      lateTodayCount: (json['late_today_count'] as num?)?.toInt() ?? 0,
      unresolvedPriorCount:
          (json['unresolved_prior_count'] as num?)?.toInt() ?? 0,
      noRecordTodayCount: (json['no_record_today_count'] as num?)?.toInt() ?? 0,
      openSessions:
          (json['open_sessions'] as List?)
              ?.whereType<Map>()
              .map((row) => AttendanceOpenSession.fromJson(row.cast()))
              .toList(growable: false) ??
          const [],
      recentSessions:
          (json['recent_sessions'] as List?)
              ?.whereType<Map>()
              .map((row) => AttendanceHistoryEntry.fromJson(row.cast()))
              .toList(growable: false) ??
          const [],
    );
  }

  final String timezone;
  final DateTime serverTime;
  final DateTime today;
  final bool isWorkingDay;
  final int activeEmployeeCount;
  final int presentTodayCount;
  final int checkedInNowCount;
  final int completedTodayCount;
  final int lateTodayCount;
  final int unresolvedPriorCount;
  final int noRecordTodayCount;
  final List<AttendanceOpenSession> openSessions;
  final List<AttendanceHistoryEntry> recentSessions;
}
