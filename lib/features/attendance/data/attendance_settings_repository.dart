import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../domain/attendance_models.dart';

/// Owner-editable attendance policy.
///
/// Reads and writes go directly to `attendance_settings` under owner-only RLS;
/// the table constraints validate individual values and the punch function
/// re-reads the effective policy on every attempt.
abstract class AttendanceSettingsRepository {
  Future<AttendanceSettings> fetch(String organisationId);

  Future<AttendanceSettings> update({
    required String organisationId,
    required bool appPunchEnabled,
    required bool qrPunchEnabled,
    required int maxAccuracyMeters,
    required String startTime,
    required int graceMinutes,
    required Set<int> workingDays,
  });
}

class SupabaseAttendanceSettingsRepository
    implements AttendanceSettingsRepository {
  SupabaseAttendanceSettingsRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'app_punch_enabled, qr_punch_enabled, max_accuracy_meters, '
      'start_time, grace_minutes, working_days';

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (error, st) {
      Error.throwWithStackTrace(mapBackendError(error), st);
    }
  }

  @override
  Future<AttendanceSettings> fetch(String organisationId) => _guard(() async {
    final row = await _client
        .from('attendance_settings')
        .select(_columns)
        .eq('organisation_id', organisationId)
        .single();
    return AttendanceSettings.fromRow(Map<String, dynamic>.from(row));
  });

  @override
  Future<AttendanceSettings> update({
    required String organisationId,
    required bool appPunchEnabled,
    required bool qrPunchEnabled,
    required int maxAccuracyMeters,
    required String startTime,
    required int graceMinutes,
    required Set<int> workingDays,
  }) => _guard(() async {
    final days = workingDays.toList()..sort();
    final row = await _client
        .from('attendance_settings')
        .update({
          'app_punch_enabled': appPunchEnabled,
          'qr_punch_enabled': qrPunchEnabled,
          'max_accuracy_meters': maxAccuracyMeters,
          'start_time': startTime,
          'grace_minutes': graceMinutes,
          'working_days': days,
        })
        .eq('organisation_id', organisationId)
        .select(_columns)
        .single();
    return AttendanceSettings.fromRow(Map<String, dynamic>.from(row));
  });
}
