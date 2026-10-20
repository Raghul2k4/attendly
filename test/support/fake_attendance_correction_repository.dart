import 'package:attendance/features/attendance/data/attendance_correction_repository.dart';
import 'package:attendance/features/attendance/domain/attendance_correction_models.dart';

import 'attendance_correction_fixtures.dart';

/// Deterministic correction repository for widget tests.
class FakeAttendanceCorrectionRepository
    implements AttendanceCorrectionRepository {
  FakeAttendanceCorrectionRepository({
    this.corrections = const [],
    this.result,
    this.error,
  });

  final List<AttendanceCorrection> corrections;
  final AttendanceCorrectionResult? result;
  final Object? error;

  final List<({String sessionId, DateTime date, String time, String reason})>
  calls = [];
  int listCalls = 0;

  @override
  Future<AttendanceCorrectionResult> correctCheckOut({
    required String sessionId,
    required DateTime date,
    required String time,
    required String reason,
  }) async {
    calls.add((sessionId: sessionId, date: date, time: time, reason: reason));
    final failure = error;
    if (failure != null) throw failure;
    return result ?? testCorrectionResult(sessionId: sessionId);
  }

  @override
  Future<List<AttendanceCorrection>> fetchCorrections(
    String organisationId,
  ) async {
    listCalls++;
    final failure = error;
    if (failure != null) throw failure;
    return corrections;
  }
}
