import 'package:flutter_test/flutter_test.dart';
import 'package:watm_app/core/utils/firestore_helpers.dart';

void main() {
  group('calendar helpers', () {
    test('the local week starts on Monday', () {
      expect(
        startOfLocalWeek(DateTime(2026, 8, 5, 21, 30)),
        DateTime(2026, 8, 3),
      );
      expect(
        startOfLocalWeek(DateTime(2026, 8, 9, 23, 59)),
        DateTime(2026, 8, 3),
      );
    });

    test('weekly bounds include Monday through Sunday only', () {
      final weekStart = DateTime(2026, 8, 3);

      expect(isDateInLocalWeek(DateTime(2026, 8, 3), weekStart), isTrue);
      expect(
        isDateInLocalWeek(DateTime(2026, 8, 9, 23, 59), weekStart),
        isTrue,
      );
      expect(isDateInLocalWeek(DateTime(2026, 8, 10), weekStart), isFalse);
      expect(isDateInLocalWeek(DateTime(2026, 8, 2), weekStart), isFalse);
    });

    test('daily document ids stay zero padded', () {
      expect(dailyDocId(DateTime(2026, 8, 3)), '2026-08-03');
    });

    test('saving the same day never increments the streak twice', () {
      expect(
        nextDailyStreak(
          todayExists: true,
          todayStreak: 4,
          previousDayExists: true,
          previousDayStreak: 3,
        ),
        4,
      );
    });

    test('a consecutive cloud check-in increments the previous streak', () {
      expect(
        nextDailyStreak(
          todayExists: false,
          todayStreak: 0,
          previousDayExists: true,
          previousDayStreak: 3,
        ),
        4,
      );
      expect(
        nextDailyStreak(
          todayExists: false,
          todayStreak: 0,
          previousDayExists: false,
          previousDayStreak: 0,
        ),
        1,
      );
    });
  });
}
