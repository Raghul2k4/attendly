import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../domain/attendance_history_models.dart';

/// Read-only attendance reporting. RPCs enforce employee/owner scope and return
/// organisation-local formatted rows, so the client never filters another
/// member's private history or formats timestamps in the device timezone.
abstract class AttendanceHistoryRepository {
  Future<AttendanceHistory> fetchMyHistory({
    required String organisationId,
    DateTime? from,
    DateTime? to,
  });

  Future<AttendanceHistory> fetchReport({
    required String organisationId,
    DateTime? from,
    DateTime? to,
    String? memberId,
  });

  Future<OwnerAttendanceOverview> fetchOwnerOverview(String organisationId);
}

class SupabaseAttendanceHistoryRepository
    implements AttendanceHistoryRepository {
  SupabaseAttendanceHistoryRepository(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (error, st) {
      Error.throwWithStackTrace(mapBackendError(error), st);
    }
  }

  String? _dateParam(DateTime? value) =>
      value == null ? null : isoDate(dateOnly(value));

  @override
  Future<AttendanceHistory> fetchMyHistory({
    required String organisationId,
    DateTime? from,
    DateTime? to,
  }) => _guard(() async {
    final response = await _client.rpc<Map<String, dynamic>>(
      'get_my_attendance_history',
      params: {
        'p_org': organisationId,
        'p_from': _dateParam(from),
        'p_to': _dateParam(to),
      },
    );
    return AttendanceHistory.fromJson(Map<String, dynamic>.from(response));
  });

  @override
  Future<AttendanceHistory> fetchReport({
    required String organisationId,
    DateTime? from,
    DateTime? to,
    String? memberId,
  }) => _guard(() async {
    final response = await _client.rpc<Map<String, dynamic>>(
      'get_attendance_report',
      params: {
        'p_org': organisationId,
        'p_from': _dateParam(from),
        'p_to': _dateParam(to),
        'p_member': memberId,
      },
    );
    return AttendanceHistory.fromJson(Map<String, dynamic>.from(response));
  });

  @override
  Future<OwnerAttendanceOverview> fetchOwnerOverview(String organisationId) =>
      _guard(() async {
        final response = await _client.rpc<Map<String, dynamic>>(
          'get_owner_attendance_overview',
          params: {'p_org': organisationId},
        );
        return OwnerAttendanceOverview.fromJson(
          Map<String, dynamic>.from(response),
        );
      });
}
