import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../domain/attendance_models.dart';

/// Server-authoritative attendance access. The client sends evidence and an
/// action intent; the database function decides the outcome.
abstract class AttendanceRepository {
  Future<AttendanceToday> fetchToday(String organisationId);

  Future<PunchResult> punch({
    required String organisationId,
    required PunchAction action,
    required PunchMethod method,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required String idempotencyKey,
    String? workplaceId,
    String? qrPayload,
  });
}

class SupabaseAttendanceRepository implements AttendanceRepository {
  SupabaseAttendanceRepository(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (error, st) {
      Error.throwWithStackTrace(mapBackendError(error), st);
    }
  }

  @override
  Future<AttendanceToday> fetchToday(String organisationId) => _guard(() async {
    final response = await _client.rpc<Map<String, dynamic>>(
      'get_attendance_state',
      params: {'p_org': organisationId},
    );
    return AttendanceToday.fromJson(Map<String, dynamic>.from(response));
  });

  @override
  Future<PunchResult> punch({
    required String organisationId,
    required PunchAction action,
    required PunchMethod method,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required String idempotencyKey,
    String? workplaceId,
    String? qrPayload,
  }) => _guard(() async {
    final response = await _client.rpc<Map<String, dynamic>>(
      'punch_attendance',
      params: {
        'p_org': organisationId,
        'p_event_type': action.rpcValue,
        'p_method': method.name,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_accuracy_meters': accuracyMeters,
        'p_idempotency_key': idempotencyKey,
        'p_workplace': workplaceId,
        'p_qr_payload': qrPayload,
      },
    );
    return PunchResult.fromJson(Map<String, dynamic>.from(response));
  });
}
