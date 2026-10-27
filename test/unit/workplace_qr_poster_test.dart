import 'package:attendance/features/workplaces/domain/workplace_qr_poster.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('workplaceQrPoster', () {
    test('produces clean lowercase filename from workplace name', () {
      expect(
        workplaceQrPosterFileName(workplaceName: 'Main Shop'),
        'attendly-workplace-qr-main-shop.pdf',
      );
      expect(
        workplaceQrPosterFileName(workplaceName: 'North Office (Floor 2)'),
        'attendly-workplace-qr-north-office-floor-2.pdf',
      );
      expect(
        workplaceQrPosterFileName(workplaceName: '---'),
        'attendly-workplace-qr-workplace.pdf',
      );
    });

    test('buildWorkplaceQrPoster generates a non-empty valid PDF byte array', () async {
      final bytes = await buildWorkplaceQrPoster(
        WorkplaceQrPosterData(
          payload: 'attendance:workplace:v1:ABCD2-EFGH3-JKMN4-PQRST',
          workplaceName: 'Main Shop',
          organisationName: 'Techloft',
          generatedAt: DateTime(2026, 10, 27, 10, 0),
        ),
      );
      expect(bytes.isNotEmpty, isTrue);
      // PDF files begin with %PDF-
      expect(bytes.sublist(0, 5), [0x25, 0x50, 0x44, 0x46, 0x2D]);
    });
  });
}
