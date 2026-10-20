/// Attendance domain models. All authoritative values are mapped from server
/// responses exactly as received; the client never invents punch times.
enum AttendanceDayState { notStarted, checkedIn, completed }

enum PunchAction {
  punchIn,
  punchOut;

  String get rpcValue => this == PunchAction.punchIn ? 'punch_in' : 'punch_out';

  String get buttonLabel =>
      this == PunchAction.punchIn ? 'Punch in' : 'Punch out';

  String get pastTense =>
      this == PunchAction.punchIn ? 'Checked in' : 'Checked out';
}

enum PunchMethod { app, qr }

AttendanceDayState _dayStateFrom(Object? value) => switch (value) {
  'checked_in' => AttendanceDayState.checkedIn,
  'completed' => AttendanceDayState.completed,
  _ => AttendanceDayState.notStarted,
};

Map<String, dynamic> _map(Object? value) =>
    (value as Map?)?.cast<String, dynamic>() ?? const {};

double? _double(Object? value) => (value as num?)?.toDouble();

DateTime? _dateTime(Object? value) =>
    value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.workDate,
    required this.checkInAt,
    required this.checkOutAt,
    required this.checkInTime,
    required this.checkOutTime,
    required this.isLate,
  });

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    final checkInAt = _dateTime(json['check_in_at']);
    final workDate = _dateTime(json['work_date']);
    if (checkInAt == null || workDate == null) {
      throw const FormatException('Attendance session is missing timestamps');
    }
    return AttendanceSession(
      id: json['id'] as String,
      workDate: workDate,
      checkInAt: checkInAt.toUtc(),
      checkOutAt: _dateTime(json['check_out_at'])?.toUtc(),
      checkInTime: json['check_in_time'] as String? ?? '—',
      checkOutTime: json['check_out_time'] as String?,
      isLate: json['is_late'] as bool? ?? false,
    );
  }

  final String id;
  final DateTime workDate;
  final DateTime checkInAt;
  final DateTime? checkOutAt;

  /// Local time strings formatted server-side in the organisation timezone.
  final String checkInTime;
  final String? checkOutTime;

  /// Classified by the server when the session was opened. It is stored, so
  /// changing the owner's schedule later cannot rewrite this history.
  final bool isLate;

  bool get isOpen => checkOutAt == null;
  bool get isCompleted => checkOutAt != null;

  Duration get worked {
    final out = checkOutAt;
    if (out == null) return Duration.zero;
    final duration = out.difference(checkInAt);
    return duration.isNegative ? Duration.zero : duration;
  }

  Duration elapsed([DateTime? now]) {
    final duration = (now ?? DateTime.now().toUtc()).difference(checkInAt);
    return duration.isNegative ? Duration.zero : duration;
  }
}

class AttendanceWorkplace {
  const AttendanceWorkplace({
    required this.id,
    required this.name,
    required this.radiusMeters,
  });

  factory AttendanceWorkplace.fromJson(Map<String, dynamic> json) =>
      AttendanceWorkplace(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Workplace',
        radiusMeters: (json['radius_meters'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String name;
  final int radiusMeters;
}

class AttendanceSettings {
  const AttendanceSettings({
    required this.appPunchEnabled,
    required this.qrPunchEnabled,
    required this.maxAccuracyMeters,
    required this.startTime,
    required this.graceMinutes,
    required this.workingDays,
  });

  factory AttendanceSettings.fromJson(Map<String, dynamic> json) =>
      AttendanceSettings(
        appPunchEnabled: json['app_punch_enabled'] as bool? ?? true,
        qrPunchEnabled: json['qr_punch_enabled'] as bool? ?? false,
        maxAccuracyMeters: (json['max_accuracy_meters'] as num?)?.toInt() ?? 50,
        startTime: _timeHHmm(json['start_time']),
        graceMinutes: (json['grace_minutes'] as num?)?.toInt() ?? 10,
        workingDays:
            (json['working_days'] as List?)
                ?.map((day) => (day as num).toInt())
                .toSet() ??
            const {1, 2, 3, 4, 5},
      );

  /// Direct owner settings row (PostgREST returns `time` as `HH:mm:ss`).
  factory AttendanceSettings.fromRow(Map<String, dynamic> row) =>
      AttendanceSettings.fromJson(row);

  final bool appPunchEnabled;
  final bool qrPunchEnabled;
  final int maxAccuracyMeters;
  final String startTime;
  final int graceMinutes;
  final Set<int> workingDays;

  bool get anyPunchEnabled => appPunchEnabled || qrPunchEnabled;

  AttendanceSettings copyWith({
    bool? appPunchEnabled,
    bool? qrPunchEnabled,
    int? maxAccuracyMeters,
    String? startTime,
    int? graceMinutes,
    Set<int>? workingDays,
  }) => AttendanceSettings(
    appPunchEnabled: appPunchEnabled ?? this.appPunchEnabled,
    qrPunchEnabled: qrPunchEnabled ?? this.qrPunchEnabled,
    maxAccuracyMeters: maxAccuracyMeters ?? this.maxAccuracyMeters,
    startTime: startTime ?? this.startTime,
    graceMinutes: graceMinutes ?? this.graceMinutes,
    workingDays: workingDays ?? this.workingDays,
  );
}

String _timeHHmm(Object? value) {
  final raw = value is String ? value : '';
  return raw.length >= 5 ? raw.substring(0, 5) : '09:00';
}

class AttendanceToday {
  const AttendanceToday({
    required this.serverTime,
    required this.workDate,
    required this.timezone,
    required this.state,
    required this.session,
    required this.workplace,
    required this.settings,
  });

  factory AttendanceToday.fromJson(Map<String, dynamic> json) {
    final serverTime = _dateTime(json['server_time']);
    final workDate = _dateTime(json['work_date']);
    if (serverTime == null || workDate == null) {
      throw const FormatException('Attendance state is missing server time');
    }
    final sessionJson = _map(json['session']);
    final workplaceJson = _map(json['workplace']);
    return AttendanceToday(
      serverTime: serverTime.toUtc(),
      workDate: workDate,
      timezone: json['timezone'] as String? ?? 'UTC',
      state: _dayStateFrom(json['state']),
      session: sessionJson.isEmpty
          ? null
          : AttendanceSession.fromJson(sessionJson),
      workplace: workplaceJson.isEmpty
          ? null
          : AttendanceWorkplace.fromJson(workplaceJson),
      settings: AttendanceSettings.fromJson(_map(json['settings'])),
    );
  }

  final DateTime serverTime;
  final DateTime workDate;
  final String timezone;
  final AttendanceDayState state;
  final AttendanceSession? session;
  final AttendanceWorkplace? workplace;
  final AttendanceSettings settings;

  bool get hasOpenSession =>
      state == AttendanceDayState.checkedIn && session != null;

  bool get isComplete => state == AttendanceDayState.completed;

  /// The next action the employee can take, or null when today is complete or
  /// no method is enabled.
  PunchAction? get nextAction {
    if (isComplete || !settings.anyPunchEnabled) return null;
    return state == AttendanceDayState.checkedIn
        ? PunchAction.punchOut
        : PunchAction.punchIn;
  }
}

class PunchResult {
  const PunchResult({
    required this.eventId,
    required this.eventType,
    required this.method,
    required this.accepted,
    required this.rejectionReason,
    required this.serverTime,
    required this.accuracyMeters,
    required this.distanceMeters,
    required this.workplace,
    required this.session,
  });

  factory PunchResult.fromJson(Map<String, dynamic> json) {
    final serverTime = _dateTime(json['server_time']);
    if (serverTime == null) {
      throw const FormatException('Punch result is missing server time');
    }
    final sessionJson = _map(json['session']);
    final workplaceJson = _map(json['workplace']);
    return PunchResult(
      eventId: json['event_id'] as String,
      eventType: json['event_type'] as String? ?? '',
      method: json['method'] == 'qr' ? PunchMethod.qr : PunchMethod.app,
      accepted: json['validation_result'] == 'accepted',
      rejectionReason: json['rejection_reason'] as String?,
      serverTime: serverTime.toUtc(),
      accuracyMeters: _double(json['accuracy_meters']),
      distanceMeters: _double(json['distance_meters']),
      workplace: workplaceJson.isEmpty
          ? null
          : AttendanceWorkplace.fromJson(workplaceJson),
      session: sessionJson.isEmpty
          ? null
          : AttendanceSession.fromJson(sessionJson),
    );
  }

  final String eventId;
  final String eventType;
  final PunchMethod method;
  final bool accepted;
  final String? rejectionReason;
  final DateTime serverTime;
  final double? accuracyMeters;
  final double? distanceMeters;
  final AttendanceWorkplace? workplace;
  final AttendanceSession? session;

  PunchAction? get action => switch (eventType) {
    'punch_in' => PunchAction.punchIn,
    'punch_out' => PunchAction.punchOut,
    _ => null,
  };
}
