import 'package:attendance/app/theme/app_theme.dart';
import 'package:attendance/core/errors/app_exception.dart';
import 'package:attendance/features/workplaces/presentation/widgets/workplace_qr_card.dart';
import 'package:attendance/features/workplaces/presentation/workplace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../support/fake_workplace_repository.dart';
import '../support/organisation_fixtures.dart';
import '../support/workplace_fixtures.dart';

void main() {
  group('WorkplaceQrCard', () {
    Future<void> pumpCard(
      WidgetTester tester,
      FakeWorkplaceRepository repository, {
      bool active = true,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workplaceRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: WorkplaceQrCard(
                  organisationId: testOrganisation.id,
                  workplace: testWorkplace(isActive: active),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('generates a QR and shows it exactly once in this session', (
      tester,
    ) async {
      final repository = FakeWorkplaceRepository();
      await pumpCard(tester, repository);

      expect(find.text('Generate QR'), findsOneWidget);
      expect(find.text('Not set up'), findsOneWidget);

      await tester.tap(find.text('Generate QR'));
      await tester.pumpAndSettle();

      expect(repository.generateCalls, 1);
      expect(repository.lastOrgId, testOrganisation.id);
      expect(repository.lastWorkplaceId, 'wp-1');
      expect(find.byType(QrImageView), findsOneWidget);
      expect(
        find.textContaining('only time this code is shown'),
        findsOneWidget,
      );
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Replace QR'), findsOneWidget);
      expect(find.text('Revoke'), findsOneWidget);
    });

    testWidgets('replacing a live QR requires confirmation', (tester) async {
      final repository = FakeWorkplaceRepository(
        qrStatuses: {'wp-1': testQrStatus()},
      );
      await pumpCard(tester, repository);

      expect(find.text('Active'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);

      await tester.tap(find.text('Replace QR'));
      await tester.pumpAndSettle();
      expect(find.text('Replace the QR code?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.generateCalls, 0);

      await tester.tap(find.text('Replace QR'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Replace QR'));
      await tester.pumpAndSettle();

      expect(repository.generateCalls, 1);
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('revoking needs confirmation and clears the live state', (
      tester,
    ) async {
      final repository = FakeWorkplaceRepository(
        qrStatuses: {'wp-1': testQrStatus()},
      );
      await pumpCard(tester, repository);

      await tester.tap(find.text('Revoke'));
      await tester.pumpAndSettle();
      expect(find.text('Revoke this QR code?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Revoke'));
      await tester.pumpAndSettle();

      expect(repository.revokeCalls, 1);
      expect(find.text('QR code revoked'), findsOneWidget);
      expect(find.text('Generate QR'), findsOneWidget);
    });

    testWidgets('inactive workplaces cannot generate a QR', (tester) async {
      final repository = FakeWorkplaceRepository();
      await pumpCard(tester, repository, active: false);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Generate QR'),
      );
      expect(button.onPressed, isNull);
      expect(find.textContaining('This workplace is inactive'), findsOneWidget);
    });

    testWidgets('generation failure is surfaced without fake success', (
      tester,
    ) async {
      final repository = FakeWorkplaceRepository(
        generateError: const AppException(
          'This workplace is inactive. Reactivate it before generating a QR '
          'code.',
          kind: AppErrorKind.conflict,
        ),
      );
      await pumpCard(tester, repository);

      await tester.tap(find.text('Generate QR'));
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsNothing);
      expect(find.textContaining('This workplace is inactive'), findsOneWidget);
      expect(find.text('Generate QR'), findsOneWidget);
    });
  });
}
