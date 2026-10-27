import 'package:attendance/core/widgets/brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BrandMark', () {
    testWidgets('renders the packaged brand artwork', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: BrandMark())),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        'assets/app_icon_source.png',
      );
      expect(image.semanticLabel, 'Attendance logo');
    });

    test('the artwork is bundled with the app', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final data = await rootBundle.load('assets/app_icon_source.png');
      expect(data.lengthInBytes, greaterThan(0));
    });
  });
}
