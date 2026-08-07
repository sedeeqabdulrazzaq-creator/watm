const List<String> kArabicWeekdays = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

String arabicWeekdayName(int weekday) {
  if (weekday < DateTime.monday || weekday > DateTime.sunday) {
    return kArabicWeekdays.first;
  }
  return kArabicWeekdays[weekday - 1];
}

String formatScheduleTime(int hour, int minute) {
  final normalizedHour = hour.clamp(0, 23).toInt();
  final normalizedMinute = minute.clamp(0, 59).toInt();
  final hour12 = normalizedHour == 0
      ? 12
      : normalizedHour > 12
          ? normalizedHour - 12
          : normalizedHour;
  final period = normalizedHour < 12 ? 'صباحاً' : 'مساءً';
  final paddedHour = hour12.toString().padLeft(2, '0');
  final paddedMinute = normalizedMinute.toString().padLeft(2, '0');
  return '$paddedHour:$paddedMinute $period';
}

int stableNotificationId(String value) {
  var hash = 17;
  for (final unit in value.codeUnits) {
    hash = ((hash * 31) + unit) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

DateTime nextReminderDate({
  required DateTime now,
  required int hour,
  required int minute,
  int? weekday,
}) {
  var candidate = DateTime(
    now.year,
    now.month,
    now.day,
    hour.clamp(0, 23).toInt(),
    minute.clamp(0, 59).toInt(),
  );
  if (weekday == null) {
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  final targetWeekday =
      weekday.clamp(DateTime.monday, DateTime.sunday).toInt();
  while (candidate.weekday != targetWeekday || !candidate.isAfter(now)) {
    candidate = candidate.add(const Duration(days: 1));
  }
  return candidate;
}
