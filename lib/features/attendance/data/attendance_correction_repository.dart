import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../domain/attendance_correction_models.dart';
import '../domain/attendance_history_models.dart';

/// Owner-only attendance corrections. The server decides who may correct a
/// record, what time is acceptable and what is written to the audit trail; the
/// client only expresses the request.
abstract class AttendanceCorrectionRepository {
  /// Corrects the check-out of one session. [date] and [time] are wall-clock
  /// values in the organisation timezone - the server converts them.
  Future<AttendanceCorrectionResult> correctCheckOut({
    required String sessionId,
    required DateTime date,
    required String time,
    required String reason,
  });

  /// The organisation's correction history, newest first.
  Future<List<AttendanceCorrection>> fetchCorrections(String organisationId);
}

class SupabaseAttendanceCorrectionRepository
    implements AttendanceCorrectionRepository {
  SupabaseAttendanceCorrectionRepository(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (error, st) {
      Error.throwWithStackTrace(mapBackendError(error), st);
    }
  }

  String _timeParam(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}:00';
  }

  @override
  Future<AttendanceCorrectionResult> correctCheckOut({
    required String sessionId,
    required DateTime date,
    required String time,
    required String reason,
  }) => _guard(() async {
    final response = await _client.rpc<Map<String, dynamic>>(
      'correct_attendance_checkout',
      params: {
        'p_session': sessionId,
        'p_check_out_date': isoDate(dateOnly(date)),
        'p_check_out_time': _timeParam(time),
        'p_reason': reason.trim(),
      },
    );
    return AttendanceCorrectionResult.fromJson(
      Map<String, dynamic>.from(response),
    );
  });

  @override
  Future<List<AttendanceCorrection>> fetchCorrections(String organisationId) =>
      _guard(() async {
        final response = await _client.rpc<List<dynamic>>(
          'list_attendance_corrections',
          params: {'p_org': organisationId},
        );
        final rows = (response as List?) ?? const <dynamic>[];
        return rows
            .whereType<Map>()
            .map((row) => AttendanceCorrection.fromJson(row.cast()))
            .toList(growable: false);
      });
}
