import 'package:attendance/features/attendance/domain/attendance_qr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('attendance QR payload', () {
    test('accepts the generated workplace payload', () {
      expect(
        attendanceQrToken('attendance:workplace:v1:ABCD2-EFGH3-JKMN4-PQRST'),
        'ABCD2EFGH3JKMN4PQRST',
      );
      expect(
        isAttendanceQrPayload(
          'attendance:workplace:v1:ABCD2-EFGH3-JKMN4-PQRST',
        ),
        isTrue,
      );
    });

    test('normalises case and separators before the server call', () {
      expect(
        attendanceQrToken(
          '  attendance:workplace:v1:abcd2 efgh3-jkmn4/pqrst  ',
        ),
        'ABCD2EFGH3JKMN4PQRST',
      );
    });

    test('rejects unrelated, malformed or short payloads', () {
      expect(isAttendanceQrPayload('https://example.com'), isFalse);
      expect(isAttendanceQrPayload('attendance:workplace:v1:'), isFalse);
      expect(
        isAttendanceQrPayload('attendance:workplace:v1:ABCD2-EFGH3'),
        isFalse,
      );
      expect(isAttendanceQrPayload(null), isFalse);
      expect(isAttendanceQrPayload('   '), isFalse);
    });
  });
}
