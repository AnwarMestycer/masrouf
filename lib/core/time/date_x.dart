/// Date helpers shared by the add flow, history grouping and recurrence.
extension DateOnlyX on DateTime {
  /// Midnight local time. Every `date` in this app is a calendar day, never an
  /// instant — carrying a time component would make "today" depend on when the
  /// row happened to be written.
  DateTime get dateOnly => DateTime(year, month, day);

  /// `yyyyMMdd`, the key for the local daily aggregate table.
  int get ymd => year * 10000 + month * 100 + day;

  bool isSameDayAs(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  bool get isToday => isSameDayAs(DateTime.now());

  bool get isYesterday =>
      isSameDayAs(DateTime.now().subtract(const Duration(days: 1)));

  /// Monday-based week start, matching the fr/ar calendars used in-app.
  DateTime get startOfWeek => dateOnly.subtract(Duration(days: weekday - 1));

  /// Adds [months] while clamping the day: 31 Jan + 1 month is 28/29 Feb, not
  /// 2/3 March the way naive `DateTime(y, m + 1, 31)` arithmetic would give.
  DateTime addMonthsClamped(int months) {
    final targetMonth = month + months;
    final targetYear = year + (targetMonth - 1) ~/ 12;
    final normalisedMonth = (targetMonth - 1) % 12 + 1;
    final lastDayOfTarget = DateTime(targetYear, normalisedMonth + 1, 0).day;
    return DateTime(targetYear, normalisedMonth, day.clamp(1, lastDayOfTarget));
  }

  /// ISO `yyyy-MM-dd`, the wire format for a Postgres `date` column.
  String toIsoDate() => '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

DateTime parseIsoDate(String value) => DateTime.parse(value).dateOnly;

/// Clamps a nominal day-of-month onto a real month, e.g. a rule that runs on the
/// 31st lands on the 30th in April.
DateTime dayOfMonthIn(int year, int month, int dayOfMonth) {
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, dayOfMonth.clamp(1, lastDay));
}
