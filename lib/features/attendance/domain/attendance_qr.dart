/// The permanent workplace QR payload format produced by
/// `generate_workplace_qr`:
///
/// `attendance:workplace:v1:<20-character-token>`
///
/// This is only a cheap local shape check. The server remains the authority on
/// whether the token exists, is current, and belongs to the employee's
/// organisation.
const attendanceQrPrefix = 'attendance:workplace:v1:';

String? attendanceQrToken(String? payload) {
  final raw = payload?.trim();
  if (raw == null || !raw.startsWith(attendanceQrPrefix)) return null;

  final token = raw
      .substring(attendanceQrPrefix.length)
      .toUpperCase()
      .replaceAll(RegExp('[^0-9A-Z]'), '');
  if (token.length != 20) return null;
  return token;
}

bool isAttendanceQrPayload(String? payload) =>
    attendanceQrToken(payload) != null;
