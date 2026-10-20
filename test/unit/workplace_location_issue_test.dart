import 'package:attendance/features/workplaces/domain/workplace_location_issue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkplaceLocationIssue', () {
    test(
      'every recoverable issue explains what happened and offers an action',
      () {
        for (final issue in WorkplaceLocationIssue.values) {
          expect(issue.message, isNotEmpty);
          expect(issue.actionLabel, isNotEmpty);
        }
      },
    );

    test('location-off issue opens Android location settings', () {
      const issue = WorkplaceLocationIssue.servicesDisabled;

      expect(issue.message, contains('Location is turned off'));
      expect(issue.actionLabel, 'Location settings');
      expect(issue.opensLocationSettings, isTrue);
      expect(issue.opensAppSettings, isFalse);
    });

    test('blocked permission opens app settings', () {
      const issue = WorkplaceLocationIssue.permissionBlocked;

      expect(issue.message, contains('blocked'));
      expect(issue.actionLabel, 'App settings');
      expect(issue.opensLocationSettings, isFalse);
      expect(issue.opensAppSettings, isTrue);
    });

    test('first denial and transient failures retry the request', () {
      for (final issue in [
        WorkplaceLocationIssue.permissionDenied,
        WorkplaceLocationIssue.timeout,
        WorkplaceLocationIssue.unknown,
      ]) {
        expect(issue.actionLabel, 'Try again');
        expect(issue.opensLocationSettings, isFalse);
        expect(issue.opensAppSettings, isFalse);
      }
    });
  });
}
