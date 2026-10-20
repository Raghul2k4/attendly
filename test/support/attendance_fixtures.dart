import 'package:attendance/features/attendance/domain/attendance_models.dart';

AttendanceSettings testAttendanceSettings({
  bool appPunchEnabled = true,
  bool qrPunchEnabled = false,
  int maxAccuracyMeters = 50,
  String startTime = '09:00',
  int graceMinutes = 10,
  Set<int> workingDays = const {1, 2, 3, 4, 5},
}) => AttendanceSettings(
  appPunchEnabled: appPunchEnabled,
  qrPunchEnabled: qrPunchEnabled,
  maxAccuracyMeters: maxAccuracyMeters,
  startTime: startTime,
  graceMinutes: graceMinutes,
  workingDays: workingDays,
);

AttendanceWorkplace testAttendanceWorkplace({
  String id = 'wp-1',
  String name = 'Main Shop',
  int radiusMeters = 100,
}) => AttendanceWorkplace(id: id, name: name, radiusMeters: radiusMeters);

DateTime testWorkDate([DateTime? now]) {
  final value = now ?? DateTime.now();
  return DateTime(value.year, value.month, value.day);
}

AttendanceSession testAttendanceSession({
  String id = 'session-1',
  DateTime? workDate,
  DateTime? checkInAt,
  DateTime? checkOutAt,
  String checkInTime = '09:12',
  String? checkOutTime,
}) {
  final today = testWorkDate();
  final start = checkInAt ?? today.add(const Duration(hours: 9, minutes: 12));
  return AttendanceSession(
    id: id,
    workDate: workDate ?? testWorkDate(start),
    checkInAt: start.toUtc(),
    checkOutAt: checkOutAt?.toUtc(),
    checkInTime: checkInTime,
    checkOutTime: checkOutTime,
  );
}

AttendanceToday testAttendanceToday({
  AttendanceDayState state = AttendanceDayState.notStarted,
  AttendanceSession? session,
  AttendanceWorkplace? workplace,
  AttendanceSettings? settings,
  DateTime? workDate,
}) {
  final start = DateTime.now().toUtc().subtract(const Duration(minutes: 75));
  final resolvedSession =
      session ??
      switch (state) {
        AttendanceDayState.notStarted => null,
        AttendanceDayState.checkedIn => testAttendanceSession(
          checkInAt: start,
          checkInTime: '09:12',
        ),
        AttendanceDayState.completed => testAttendanceSession(
          checkInAt: start.subtract(const Duration(hours: 8)),
          checkOutAt: start,
          checkInTime: '09:12',
          checkOutTime: '17:42',
        ),
      };

  return AttendanceToday(
    serverTime: DateTime.now().toUtc(),
    workDate: workDate ?? testWorkDate(),
    timezone: 'Asia/Kolkata',
    state: state,
    session: resolvedSession,
    workplace: workplace ?? testAttendanceWorkplace(),
    settings: settings ?? testAttendanceSettings(),
  );
}

PunchResult testPunchResult({
  bool accepted = true,
  String eventType = 'punch_in',
  String? rejectionReason,
  double? distanceMeters = 12,
  double? accuracyMeters = 8,
  AttendanceWorkplace? workplace,
  AttendanceSession? session,
}) => PunchResult(
  eventId: 'event-1',
  eventType: eventType,
  method: PunchMethod.app,
  accepted: accepted,
  rejectionReason: rejectionReason,
  serverTime: DateTime.now().toUtc(),
  accuracyMeters: accuracyMeters,
  distanceMeters: distanceMeters,
  workplace: workplace ?? testAttendanceWorkplace(),
  session: session,
);
