import 'package:flutter_test/flutter_test.dart';
import 'package:watm_app/core/utils/schedule_helpers.dart';

void main() {
  group('schedule helpers', () {
    test('keeps a future daily reminder on the same day', () {
      final now = DateTime(2026, 8, 2, 9, 0);
      expect(
        nextReminderDate(now: now, hour: 10, minute: 30),
        DateTime(2026, 8, 2, 10, 30),
      );
    });

    test('moves a passed daily reminder to tomorrow', () {
      final now = DateTime(2026, 8, 2, 11, 0);
      expect(
        nextReminderDate(now: now, hour: 10, minute: 30),
        DateTime(2026, 8, 3, 10, 30),
      );
    });

    test('finds the next selected weekday', () {
      final now = DateTime(2026, 8, 2, 9, 0);
      final next = nextReminderDate(
        now: now,
        hour: 8,
        minute: 0,
        weekday: DateTime.wednesday,
      );
      expect(next.weekday, DateTime.wednesday);
      expect(next, DateTime(2026, 8, 5, 8, 0));
    });

    test('notification ids are stable and positive', () {
      final first = stableNotificationId('schedule-document-id');
      final second = stableNotificationId('schedule-document-id');
      expect(first, second);
      expect(first, greaterThan(0));
    });

    test('formats Arabic morning and evening times', () {
      expect(formatScheduleTime(8, 5), '08:05 صباحاً');
      expect(formatScheduleTime(20, 30), '08:30 مساءً');
    });
  });
}
