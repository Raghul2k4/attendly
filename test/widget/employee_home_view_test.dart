import 'package:attendance/app/theme/app_theme.dart';
import 'package:attendance/features/organisation/presentation/employee_home_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/organisation_fixtures.dart';

void main() {
  group('EmployeeHomeView', () {
    testWidgets('shows identity, organisation and staff code from the server', (
      tester,
    ) async {
      final account = testEmployeeAccount(
        fullName: 'Priya Sharma',
        employeeCode: 'ABCD-EFGH',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(body: EmployeeHomeView(account: account)),
        ),
      );

      expect(find.text('Hi, Priya'), findsOneWidget);
      expect(find.text('You’re part of Corner Cafe.'), findsOneWidget);
      expect(find.text('Corner Cafe'), findsOneWidget);
      expect(find.text('ABCD-EFGH'), findsOneWidget);
      expect(find.byTooltip('Copy staff code'), findsOneWidget);
      expect(find.text('Attendance punching is next'), findsOneWidget);
    });
  });
}
