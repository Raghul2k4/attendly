import 'package:attendance/app/theme/app_theme.dart';
import 'package:attendance/features/organisation/presentation/organisation_providers.dart'
    show myAccountProvider;
import 'package:attendance/features/workplaces/presentation/workplace_providers.dart';
import 'package:attendance/features/workplaces/presentation/workplaces_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_workplace_repository.dart';
import '../support/organisation_fixtures.dart';
import '../support/workplace_fixtures.dart';

void main() {
  group('WorkplacesScreen', () {
    Future<void> pumpScreen(
      WidgetTester tester,
      FakeWorkplaceRepository repository,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myAccountProvider.overrideWith((ref) async => testOwnerAccount()),
            workplaceRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const WorkplacesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('empty state explains the next step', (tester) async {
      final repository = FakeWorkplaceRepository();
      await pumpScreen(tester, repository);

      expect(find.text('No workplaces yet'), findsOneWidget);
      expect(find.text('Add your first workplace'), findsOneWidget);
      expect(find.text('Add workplace'), findsNothing);
      expect(repository.fetchCalls, 1);
      expect(repository.lastOrgId, testOrganisation.id);
    });

    testWidgets('lists radius, active state and live QR status', (
      tester,
    ) async {
      final repository = FakeWorkplaceRepository(
        workplaces: [
          testWorkplace(),
          testWorkplace(
            id: 'wp-2',
            name: 'Warehouse',
            radiusMeters: 250,
            isActive: false,
          ),
        ],
        qrStatuses: {'wp-1': testQrStatus()},
      );
      await pumpScreen(tester, repository);

      expect(find.text('Main shop'), findsOneWidget);
      expect(find.text('Warehouse'), findsOneWidget);
      expect(find.textContaining('100 m radius'), findsOneWidget);
      expect(find.textContaining('250 m radius'), findsOneWidget);
      expect(find.text('QR active'), findsOneWidget);
      expect(find.text('No QR'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.text('Add workplace'), findsOneWidget);
    });

    testWidgets('workplace load failure is recoverable', (tester) async {
      final repository = FakeWorkplaceRepository(
        fetchError: Exception('offline'),
      );
      await pumpScreen(tester, repository);

      expect(
        find.textContaining('couldn’t load your workplaces'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
