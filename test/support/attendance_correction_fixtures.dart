import 'package:attendance/features/attendance/domain/attendance_correction_models.dart';

final testCorrectionToday = DateTime(2026, 10, 20);

AttendanceCorrection testCorrection({
  String id = 'correction-1',
  String sessionId = 'session-1',
  String memberId = 'm-1',
  String memberName = 'Priya Sharma',
  String? employeeCode = 'ABCD-EFGH',
  DateTime? workDate,
  String workplaceName = 'Main Shop',
  String? originalCheckOutTime = '17:42',
  String correctedCheckOutTime = '18:30',
  String reason = 'Owner confirmed the employee left at 18:30',
  String actorName = 'Raghul',
  String createdAtLocal = '20 Oct 2026 19:20',
}) {
  final date = workDate ?? DateTime(2026, 10, 19);
  return AttendanceCorrection(
    id: id,
    sessionId: sessionId,
    memberId: memberId,
    memberName: memberName,
    employeeCode: employeeCode,
    workDate: date,
    workplaceName: workplaceName,
    originalCheckOutAt: originalCheckOutTime == null
        ? null
        : DateTime.utc(date.year, date.month, date.day, 12, 12),
    originalCheckOutTime: originalCheckOutTime,
    correctedCheckOutAt: DateTime.utc(date.year, date.month, date.day, 13, 0),
    correctedCheckOutTime: correctedCheckOutTime,
    reason: reason,
    actorName: actorName,
    createdAt: DateTime.utc(2026, 10, 20, 13, 50),
    createdAtLocal: createdAtLocal,
  );
}

AttendanceCorrectionResult testCorrectionResult({
  String correctionId = 'correction-1',
  String sessionId = 'session-1',
  String memberName = 'Priya Sharma',
  String? employeeCode = 'ABCD-EFGH',
  DateTime? workDate,
  String timezone = 'Asia/Kolkata',
  String correctedCheckOutTime = '18:30',
  Duration duration = const Duration(hours: 9, minutes: 18),
}) {
  final date = workDate ?? DateTime(2026, 10, 19);
  return AttendanceCorrectionResult(
    correctionId: correctionId,
    sessionId: sessionId,
    memberName: memberName,
    employeeCode: employeeCode,
    workDate: date,
    timezone: timezone,
    correctedCheckOutAt: DateTime.utc(date.year, date.month, date.day, 13, 0),
    correctedCheckOutTime: correctedCheckOutTime,
    duration: duration,
    correctedAt: DateTime.utc(2026, 10, 20, 13, 50),
  );
}
