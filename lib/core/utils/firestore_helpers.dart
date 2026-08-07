import 'package:cloud_firestore/cloud_firestore.dart';

/// Small, framework-agnostic helpers for reading loosely-typed Firestore
/// document data. Extracted from several presentation files that each
/// re-implemented the same lookups; behavior is unchanged, only the
/// location moved.

/// Returns the first non-empty, trimmed string value found under [keys] in
/// [data], checked in order. Returns [fallback] when none of them hold a
/// non-empty value.
String firstNonEmptyString(
  Map<String, dynamic> data,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return fallback;
}

/// Parses [value] as an [int]. Accepts a raw `int` or a numeric string;
/// returns `0` when it cannot be parsed.
int parseIntOrZero(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

/// Reads the first Firestore [Timestamp] found under [keys] in [data] (in
/// order) and converts it to a [DateTime]. Falls back to the Unix epoch
/// when none of the keys hold a [Timestamp].
DateTime firstTimestamp(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is Timestamp) return value.toDate();
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

/// Formats [date] as the zero-padded `yyyy-MM-dd` id used for daily and
/// weekly Firestore documents (check-ins, returns, weekly reviews...).
String dailyDocId(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Returns the local calendar day without a time component.
DateTime startOfLocalDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

/// WATM weeks start on Monday, matching Dart's `DateTime.weekday` contract.
DateTime startOfLocalWeek(DateTime date) {
  final day = startOfLocalDay(date);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// True when [date] belongs to the Monday-to-Sunday week beginning at
/// [weekStart]. The upper bound is exclusive to avoid double counting.
bool isDateInLocalWeek(DateTime date, DateTime weekStart) {
  final normalizedStart = startOfLocalWeek(weekStart);
  final end = normalizedStart.add(const Duration(days: 7));
  return !date.isBefore(normalizedStart) && date.isBefore(end);
}

/// Calculates a daily check-in streak from cloud-backed day documents.
/// Re-saving today's entry never increments the streak a second time.
int nextDailyStreak({
  required bool todayExists,
  required int todayStreak,
  required bool previousDayExists,
  required int previousDayStreak,
}) {
  if (todayExists) return todayStreak > 0 ? todayStreak : 1;
  if (previousDayExists && previousDayStreak > 0) {
    return previousDayStreak + 1;
  }
  return 1;
}
