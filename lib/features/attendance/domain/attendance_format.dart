import 'attendance_models.dart';

/// "2h 14m" / "14m" / "Less than a minute".
String formatElapsed(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  if (minutes > 0) return '${minutes}m';
  return 'Less than a minute';
}

/// "8h 52m" / "52m" — completed work duration, including zero.
String formatWorked(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

/// "02:14:08" (or "14:08" under an hour) for the live checked-in timer.
String formatTimer(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  return '$minutes:$seconds';
}

/// "321 m" / "1.1 km".
String formatDistance(double? metres) {
  if (metres == null || !metres.isFinite) return 'an unknown distance';
  if (metres >= 1000) return '${(metres / 1000).toStringAsFixed(1)} km';
  return '${metres.round()} m';
}

class AttendanceRejectionCopy {
  const AttendanceRejectionCopy({required this.title, required this.message});

  final String title;
  final String message;
}

/// Specific, calm copy for each structured server rejection. The server is the
/// authority; this function only translates its reason code.
AttendanceRejectionCopy attendanceRejectionCopy(
  PunchResult result, {
  int? maxAccuracyMeters,
}) {
  final workplaceName = result.workplace?.name;
  final radius = result.workplace?.radiusMeters;

  return switch (result.rejectionReason) {
    'outside_geofence' => AttendanceRejectionCopy(
      title: 'Outside the workplace area',
      message: workplaceName == null
          ? 'You’re outside the permitted workplace area. Move closer and try '
                'again.'
          : 'You’re about ${formatDistance(result.distanceMeters)} from '
                '$workplaceName. The permitted radius is ${radius ?? 0} m — '
                'move inside it and try again.',
    ),
    'location_accuracy_too_low' => AttendanceRejectionCopy(
      title: 'Location is too imprecise',
      message:
          'Your location is accurate to about ±${result.accuracyMeters?.round() ?? '?'} '
          'm. The limit is ${maxAccuracyMeters ?? 50} m — move outdoors or near '
          'a window and try again.',
    ),
    'invalid_location' => const AttendanceRejectionCopy(
      title: 'Location not recorded',
      message:
          'We couldn’t read a valid location. Turn on location services and try '
          'again.',
    ),
    'invalid_qr' => const AttendanceRejectionCopy(
      title: 'QR code not accepted',
      message:
          'This QR code isn’t valid for your business or has been replaced. Ask '
          'your owner for the current code.',
    ),
    'workplace_inactive' => const AttendanceRejectionCopy(
      title: 'Workplace unavailable',
      message:
          'This workplace is currently inactive. Ask your owner to reactivate '
          'it.',
    ),
    'workplace_not_found' => const AttendanceRejectionCopy(
      title: 'Workplace not found',
      message:
          'That workplace no longer exists. Refresh the screen and try again.',
    ),
    'no_workplace' => const AttendanceRejectionCopy(
      title: 'No workplace set up',
      message:
          'Your owner hasn’t added an active workplace yet. Ask them to finish '
          'location setup.',
    ),
    'already_checked_in' => const AttendanceRejectionCopy(
      title: 'Already checked in',
      message:
          'You already have an open check-in today. Refresh to see your current '
          'session.',
    ),
    'not_checked_in' => const AttendanceRejectionCopy(
      title: 'No open check-in',
      message:
          'There’s no open check-in to close. Refresh to see your current '
          'status.',
    ),
    'already_completed_today' => const AttendanceRejectionCopy(
      title: 'Today is already complete',
      message:
          'Your attendance for today is already recorded. Ask your owner if a '
          'correction is needed.',
    ),
    _ => const AttendanceRejectionCopy(
      title: 'Punch not recorded',
      message:
          'The server didn’t accept this punch. Refresh and check your status '
          'before trying again.',
    ),
  };
}

String acceptedPunchTitle(PunchResult result) =>
    result.action?.pastTense ?? 'Attendance recorded';

String acceptedPunchMessage(PunchResult result) {
  final session = result.session;
  return switch (result.action) {
    PunchAction.punchIn =>
      session == null
          ? 'Your check-in was recorded.'
          : 'Your check-in was recorded at ${session.checkInTime}.',
    PunchAction.punchOut =>
      session == null
          ? 'Your check-out was recorded.'
          : 'Your check-out was recorded at ${session.checkOutTime ?? '—'}. You '
                'worked ${formatWorked(session.worked)} today.',
    null => 'The server confirmed your attendance.',
  };
}
