import 'package:attendance/features/attendance/domain/attendance_history_models.dart';
import 'package:attendance/features/organisation/domain/organisation_models.dart';

final testHistoryToday = DateTime(2026, 10, 20);
final testHistoryMonthStart = DateTime(2026, 10, 1);

AttendanceHistoryEntry testHistoryEntry({
  String id = 'session-1',
  String memberId = 'm-1',
  String memberName = 'Priya Sharma',
  String? employeeCode = 'ABCD-EFGH',
  MemberStatus memberStatus = MemberStatus.active,
  String workplaceName = 'Main Shop',
  DateTime? workDate,
  String checkInTime = '09:12',
  String? checkOutTime = '17:42',
  bool isLate = false,
  bool isOpen = false,
  bool isStaleOpen = false,
  bool crossesMidnight = false,
  Duration duration = const Duration(hours: 8, minutes: 30),
  Duration elapsed = const Duration(hours: 2, minutes: 5),
}) {
  final date = workDate ?? testHistoryToday;
  final checkIn = DateTime.utc(date.year, date.month, date.day, 3, 42);
  return AttendanceHistoryEntry(
    id: id,
    memberId: memberId,
    memberName: memberName,
    employeeCode: employeeCode,
    memberStatus: memberStatus,
    workplaceName: workplaceName,
    workDate: date,
    checkInAt: checkIn,
    checkOutAt: isOpen
        ? null
        : checkIn.add(
            isLate ? duration + const Duration(minutes: 5) : duration,
          ),
    checkInTime: checkInTime,
    checkOutTime: isOpen ? null : checkOutTime,
    isLate: isLate,
    isOpen: isOpen,
    isStaleOpen: isStaleOpen,
    crossesMidnight: crossesMidnight,
    duration: isOpen ? null : duration,
    elapsed: isOpen ? elapsed : null,
  );
}

AttendanceHistoryMember testHistoryMember({
  String id = 'm-1',
  String fullName = 'Priya Sharma',
  String? employeeCode = 'ABCD-EFGH',
  MemberStatus status = MemberStatus.active,
}) => AttendanceHistoryMember(
  id: id,
  fullName: fullName,
  employeeCode: employeeCode,
  status: status,
);

AttendanceHistory testAttendanceHistory({
  String timezone = 'Asia/Kolkata',
  DateTime? today,
  DateTime? from,
  DateTime? to,
  List<AttendanceHistoryEntry>? sessions,
  List<AttendanceHistoryMember>? members,
  int? sessionCount,
  int? memberCount,
  int? completedCount,
  int? openCount,
  int? lateCount,
  Duration? totalWork,
}) {
  final resolvedSessions = sessions ?? [testHistoryEntry()];
  final completed = resolvedSessions.where((entry) => entry.isCompleted);
  return AttendanceHistory(
    timezone: timezone,
    today: today ?? testHistoryToday,
    from: from ?? testHistoryMonthStart,
    to: to ?? (today ?? testHistoryToday),
    members: members ?? [testHistoryMember()],
    sessions: resolvedSessions,
    summary: AttendanceHistorySummary(
      sessionCount: sessionCount ?? resolvedSessions.length,
      memberCount:
          memberCount ??
          resolvedSessions.map((entry) => entry.memberId).toSet().length,
      completedCount: completedCount ?? completed.length,
      openCount:
          openCount ?? resolvedSessions.where((entry) => entry.isOpen).length,
      lateCount:
          lateCount ?? resolvedSessions.where((entry) => entry.isLate).length,
      totalWork:
          totalWork ??
          completed.fold<Duration>(
            Duration.zero,
            (total, entry) => total + (entry.duration ?? Duration.zero),
          ),
    ),
  );
}

OwnerAttendanceOverview testOwnerOverview({
  DateTime? today,
  bool isWorkingDay = true,
  int activeEmployeeCount = 2,
  int presentTodayCount = 1,
  int checkedInNowCount = 1,
  int completedTodayCount = 0,
  int lateTodayCount = 0,
  int unresolvedPriorCount = 0,
  int? noRecordTodayCount,
  List<AttendanceOpenSession>? openSessions,
  List<AttendanceHistoryEntry>? recentSessions,
}) {
  final resolvedToday = today ?? testHistoryToday;
  return OwnerAttendanceOverview(
    timezone: 'Asia/Kolkata',
    serverTime: DateTime.utc(2026, 10, 20, 5),
    today: resolvedToday,
    isWorkingDay: isWorkingDay,
    activeEmployeeCount: activeEmployeeCount,
    presentTodayCount: presentTodayCount,
    checkedInNowCount: checkedInNowCount,
    completedTodayCount: completedTodayCount,
    lateTodayCount: lateTodayCount,
    unresolvedPriorCount: unresolvedPriorCount,
    noRecordTodayCount:
        noRecordTodayCount ?? activeEmployeeCount - presentTodayCount,
    openSessions:
        openSessions ??
        [
          AttendanceOpenSession(
            memberId: 'm-2',
            memberName: 'Suresh Kumar',
            employeeCode: 'WXYZ-2345',
            checkInTime: '09:12',
            workDate: resolvedToday,
            isLate: false,
            isStaleOpen: false,
          ),
        ],
    recentSessions:
        recentSessions ??
        [
          testHistoryEntry(
            memberId: 'm-2',
            memberName: 'Suresh Kumar',
            employeeCode: 'WXYZ-2345',
            isOpen: true,
            checkOutTime: null,
          ),
        ],
  );
}
