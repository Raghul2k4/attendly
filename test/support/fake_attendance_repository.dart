import 'package:attendance/features/attendance/data/attendance_repository.dart';
import 'package:attendance/features/attendance/domain/attendance_models.dart';

import 'attendance_fixtures.dart';

/// Deterministic attendance fake: tests script the state, the punch outcome and
/// any transport error, then assert exactly what the screen submitted.
class FakeAttendanceRepository implements AttendanceRepository {
  FakeAttendanceRepository({
    AttendanceToday? today,
    this.punchResult,
    this.nextTodayAfterPunch,
    this.fetchError,
    this.punchError,
  }) : today = today ?? testAttendanceToday();

  AttendanceToday today;
  AttendanceToday? nextTodayAfterPunch;
  PunchResult? punchResult;
  Object? fetchError;
  Object? punchError;

  int fetchCalls = 0;
  int punchCalls = 0;
  String? lastOrganisationId;
  PunchAction? lastAction;
  PunchMethod? lastMethod;
  double? lastLatitude;
  double? lastLongitude;
  double? lastAccuracyMeters;
  String? lastWorkplaceId;
  String? lastQrPayload;
  String? lastSessionIdForPunchOut;
  final List<String> idempotencyKeys = [];

  @override
  Future<AttendanceToday> fetchToday(String organisationId) async {
    fetchCalls++;
    lastOrganisationId = organisationId;
    if (fetchError != null) throw fetchError!;
    return today;
  }

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
  }) async {
    punchCalls++;
    lastOrganisationId = organisationId;
    lastAction = action;
    lastMethod = method;
    lastLatitude = latitude;
    lastLongitude = longitude;
    lastAccuracyMeters = accuracyMeters;
    lastWorkplaceId = workplaceId;
    lastQrPayload = qrPayload;
    idempotencyKeys.add(idempotencyKey);
    if (punchError != null) throw punchError!;
    final result = punchResult;
    if (result == null) {
      throw StateError('FakeAttendanceRepository.punchResult not set');
    }
    if (action == PunchAction.punchOut) {
      lastSessionIdForPunchOut = result.session?.id;
    }
    if (result.accepted && nextTodayAfterPunch != null) {
      today = nextTodayAfterPunch!;
    }
    return result;
  }
}
