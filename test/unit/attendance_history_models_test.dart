import 'package:attendance/features/attendance/domain/attendance_history_models.dart';
import 'package:attendance/features/organisation/domain/organisation_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attendance_history_fixtures.dart';

void main() {
  group('AttendanceHistory.fromJson', () {
    test('maps server times, summaries and the member roster as received', () {
      final history = AttendanceHistory.fromJson({
        'timezone': 'Asia/Kolkata',
        'today': '2026-10-20',
        'from': '2026-10-01',
        'to': '2026-10-20',
        'members': [
          {
            'id': 'm-1',
            'full_name': 'Priya Sharma',
            'employee_code': 'ABCD-EFGH',
            'status': 'active',
          },
          {
            'id': 'm-2',
            'full_name': 'Rahul Verma',
            'employee_code': 'JKMN-PQRS',
            'status': 'inactive',
          },
        ],
        'sessions': [
          {
            'id': 's-1',
            'member_id': 'm-1',
            'member_name': 'Priya Sharma',
            'employee_code': 'ABCD-EFGH',
            'member_status': 'active',
            'workplace_id': 'wp-1',
            'workplace_name': 'Main Shop',
            'work_date': '2026-10-20',
            'check_in_at': '2026-10-20T03:42:00+00:00',
            'check_out_at': '2026-10-20T12:12:00+00:00',
            'check_in_time': '09:12',
            'check_out_time': '17:42',
            'is_late': false,
            'is_open': false,
            'is_stale_open': false,
            'crosses_midnight': false,
            'duration_seconds': 30600,
            'elapsed_seconds': null,
          },
          {
            'id': 's-2',
            'member_id': 'm-2',
            'member_name': 'Rahul Verma',
            'employee_code': 'JKMN-PQRS',
            'member_status': 'inactive',
            'workplace_id': 'wp-1',
            'workplace_name': 'Main Shop',
            'work_date': '2026-10-19',
            'check_in_at': '2026-10-19T18:30:00+00:00',
            'check_out_at': null,
            'check_in_time': '00:00',
            'check_out_time': null,
            'is_late': true,
            'is_open': true,
            'is_stale_open': true,
            'crosses_midnight': false,
            'duration_seconds': null,
            'elapsed_seconds': 5400,
          },
        ],
        'summary': {
          'session_count': 2,
          'member_count': 2,
          'completed_count': 1,
          'open_count': 1,
          'late_count': 1,
          'total_work_seconds': 30600,
        },
      });

      expect(history.timezone, 'Asia/Kolkata');
      expect(history.today, DateTime(2026, 10, 20));
      expect(history.members, hasLength(2));
      expect(history.members[1].status, MemberStatus.inactive);
      expect(history.sessions, hasLength(2));
      expect(
        history.sessions.first.duration,
        const Duration(hours: 8, minutes: 30),
      );
      expect(history.sessions.first.isCompleted, isTrue);
      expect(history.sessions.last.isOpen, isTrue);
      expect(history.sessions.last.isStaleOpen, isTrue);
      expect(history.sessions.last.elapsed, const Duration(minutes: 90));
      expect(history.sessions.last.statusLabel, 'Open from a previous day');
      expect(history.summary.totalWork, const Duration(hours: 8, minutes: 30));
      expect(history.summary.openCount, 1);
      expect(history.canMoveNextMonth, isFalse);
    });

    test('a past month can move forward', () {
      final history = testAttendanceHistory(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      );

      expect(history.canMoveNextMonth, isTrue);
    });

    test('rejects a payload without a period', () {
      expect(
        () => AttendanceHistory.fromJson({
          'timezone': 'UTC',
          'today': '2026-10-20',
          'sessions': const [],
          'summary': const {},
        }),
        throwsFormatException,
      );
    });
  });

  group('OwnerAttendanceOverview.fromJson', () {
    test('maps live counts, open sessions and recent activity', () {
      final overview = OwnerAttendanceOverview.fromJson({
        'timezone': 'Asia/Kolkata',
        'server_time': '2026-10-20T05:00:00+00:00',
        'today': '2026-10-20',
        'is_working_day': true,
        'active_employee_count': 2,
        'present_today_count': 1,
        'checked_in_now_count': 1,
        'completed_today_count': 0,
        'late_today_count': 1,
        'unresolved_prior_count': 1,
        'no_record_today_count': 1,
        'open_sessions': [
          {
            'member_id': 'm-1',
            'member_name': 'Priya Sharma',
            'employee_code': 'ABCD-EFGH',
            'check_in_time': '09:20',
            'work_date': '2026-10-19',
            'is_late': true,
            'is_stale_open': true,
          },
        ],
        'recent_sessions': [
          {
            'id': 's-1',
            'member_id': 'm-1',
            'member_name': 'Priya Sharma',
            'employee_code': 'ABCD-EFGH',
            'member_status': 'active',
            'workplace_id': 'wp-1',
            'workplace_name': 'Main Shop',
            'work_date': '2026-10-19',
            'check_in_at': '2026-10-19T03:50:00+00:00',
            'check_out_at': null,
            'check_in_time': '09:20',
            'check_out_time': null,
            'is_late': true,
            'is_open': true,
            'is_stale_open': true,
            'crosses_midnight': false,
            'duration_seconds': null,
            'elapsed_seconds': 3600,
          },
        ],
      });

      expect(overview.activeEmployeeCount, 2);
      expect(overview.presentTodayCount, 1);
      expect(overview.lateTodayCount, 1);
      expect(overview.unresolvedPriorCount, 1);
      expect(overview.openSessions.single.memberName, 'Priya Sharma');
      expect(overview.openSessions.single.isStaleOpen, isTrue);
      expect(overview.recentSessions.single.isOpen, isTrue);
      expect(overview.serverTime.isUtc, isTrue);
    });
  });
}
