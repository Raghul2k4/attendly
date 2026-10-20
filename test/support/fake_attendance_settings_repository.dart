import 'package:attendance/features/attendance/data/attendance_settings_repository.dart';
import 'package:attendance/features/attendance/domain/attendance_models.dart';

import 'attendance_fixtures.dart';

/// Deterministic owner-policy fake. It mirrors the server round trip: update
/// mutates the stored value and returns exactly what a re-read would return.
class FakeAttendanceSettingsRepository implements AttendanceSettingsRepository {
  FakeAttendanceSettingsRepository({
    AttendanceSettings? settings,
    this.fetchError,
    this.updateError,
  }) : settings = settings ?? testAttendanceSettings();

  AttendanceSettings settings;
  Object? fetchError;
  Object? updateError;

  int fetchCalls = 0;
  int updateCalls = 0;
  bool? lastAppPunchEnabled;
  bool? lastQrPunchEnabled;
  int? lastMaxAccuracyMeters;
  String? lastStartTime;
  int? lastGraceMinutes;
  Set<int>? lastWorkingDays;

  @override
  Future<AttendanceSettings> fetch(String organisationId) async {
    fetchCalls++;
    if (fetchError != null) throw fetchError!;
    return settings;
  }

  @override
  Future<AttendanceSettings> update({
    required String organisationId,
    required bool appPunchEnabled,
    required bool qrPunchEnabled,
    required int maxAccuracyMeters,
    required String startTime,
    required int graceMinutes,
    required Set<int> workingDays,
  }) async {
    updateCalls++;
    lastAppPunchEnabled = appPunchEnabled;
    lastQrPunchEnabled = qrPunchEnabled;
    lastMaxAccuracyMeters = maxAccuracyMeters;
    lastStartTime = startTime;
    lastGraceMinutes = graceMinutes;
    lastWorkingDays = {...workingDays};
    if (updateError != null) throw updateError!;
    settings = settings.copyWith(
      appPunchEnabled: appPunchEnabled,
      qrPunchEnabled: qrPunchEnabled,
      maxAccuracyMeters: maxAccuracyMeters,
      startTime: startTime,
      graceMinutes: graceMinutes,
      workingDays: {...workingDays},
    );
    return settings;
  }
}
