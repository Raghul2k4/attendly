import 'attendance_history_models.dart';

/// One owner correction of a recorded session. The server keeps the original
/// value, the corrected value, the reason and the acting owner, so this is an
/// audit record rather than a silent edit.
class AttendanceCorrection {
  const AttendanceCorrection({
    required this.id,
    required this.sessionId,
    required this.memberId,
    required this.memberName,
    required this.employeeCode,
    required this.workDate,
    required this.workplaceName,
    required this.originalCheckOutAt,
    required this.originalCheckOutTime,
    required this.correctedCheckOutAt,
    required this.correctedCheckOutTime,
    required this.reason,
    required this.actorName,
    required this.createdAt,
    required this.createdAtLocal,
  });

  factory AttendanceCorrection.fromJson(Map<String, dynamic> json) {
    final workDate = parseServerDate(json['work_date']);
    final correctedAt = parseServerInstant(json['corrected_check_out_at']);
    final createdAt = parseServerInstant(json['created_at']);
    if (workDate == null || correctedAt == null || createdAt == null) {
      throw const FormatException('Correction is missing its timestamps');
    }
    return AttendanceCorrection(
      id: json['id'] as String,
      sessionId: json['session_id'] as String? ?? '',
      memberId: json['member_id'] as String? ?? '',
      memberName: json['member_name'] as String? ?? 'Employee',
      employeeCode: json['employee_code'] as String?,
      workDate: workDate,
      workplaceName: json['workplace_name'] as String? ?? 'Workplace',
      originalCheckOutAt: parseServerInstant(json['original_check_out_at']),
      originalCheckOutTime: json['original_check_out_time'] as String?,
      correctedCheckOutAt: correctedAt,
      correctedCheckOutTime:
          json['corrected_check_out_time'] as String? ?? '--:--',
      reason: json['reason'] as String? ?? '',
      actorName: json['actor_name'] as String? ?? 'Owner',
      createdAt: createdAt,
      createdAtLocal: json['created_at_local'] as String? ?? '',
    );
  }

  final String id;
  final String sessionId;
  final String memberId;
  final String memberName;
  final String? employeeCode;
  final DateTime workDate;
  final String workplaceName;
  final DateTime? originalCheckOutAt;
  final String? originalCheckOutTime;
  final DateTime correctedCheckOutAt;
  final String correctedCheckOutTime;
  final String reason;
  final String actorName;
  final DateTime createdAt;

  /// Server-formatted timestamp in the organisation timezone.
  final String createdAtLocal;

  /// "15:40 → 18:30" or "No check-out → 18:30" for a missed punch-out.
  String get changeLabel {
    final from = originalCheckOutTime ?? 'No check-out';
    return '$from → $correctedCheckOutTime';
  }
}

/// The server's confirmation for one applied correction.
class AttendanceCorrectionResult {
  const AttendanceCorrectionResult({
    required this.correctionId,
    required this.sessionId,
    required this.memberName,
    required this.employeeCode,
    required this.workDate,
    required this.timezone,
    required this.correctedCheckOutAt,
    required this.correctedCheckOutTime,
    required this.duration,
    required this.correctedAt,
  });

  factory AttendanceCorrectionResult.fromJson(Map<String, dynamic> json) {
    final correctedAt = parseServerInstant(json['corrected_check_out_at']);
    final appliedAt = parseServerInstant(json['corrected_at']);
    final workDate = parseServerDate(json['work_date']);
    if (correctedAt == null || appliedAt == null || workDate == null) {
      throw const FormatException('Correction result is missing its times');
    }
    return AttendanceCorrectionResult(
      correctionId: json['correction_id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      memberName: json['member_name'] as String? ?? 'Employee',
      employeeCode: json['employee_code'] as String?,
      workDate: workDate,
      timezone: json['timezone'] as String? ?? 'UTC',
      correctedCheckOutAt: correctedAt,
      correctedCheckOutTime:
          json['corrected_check_out_time'] as String? ?? '--:--',
      duration: parseServerDuration(json['duration_seconds']) ?? Duration.zero,
      correctedAt: appliedAt,
    );
  }

  final String correctionId;
  final String sessionId;
  final String memberName;
  final String? employeeCode;
  final DateTime workDate;
  final String timezone;
  final DateTime correctedCheckOutAt;
  final String correctedCheckOutTime;
  final Duration duration;
  final DateTime correctedAt;
}
