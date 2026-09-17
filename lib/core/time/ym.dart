import 'package:meta/meta.dart';

/// A year-month, stored as the integer `yyyyMM` (August 2026 -> `202608`).
///
/// An int rather than a DateTime because it is the primary key of the local
/// monthly aggregate tables: integer comparison indexes well, sorts
/// chronologically for free, and cannot carry an accidental time-of-day or
/// timezone that would split one month across two rows.
@immutable
class Ym implements Comparable<Ym> {
  const Ym(this.value);

  const Ym.of(int year, int month) : value = year * 100 + month;

  Ym.fromDate(DateTime date) : value = date.year * 100 + date.month;

  static Ym current() => Ym.fromDate(DateTime.now());

  final int value;

  int get year => value ~/ 100;
  int get month => value % 100;

  Ym get previous => month == 1 ? Ym.of(year - 1, 12) : Ym.of(year, month - 1);
  Ym get next => month == 12 ? Ym.of(year + 1, 1) : Ym.of(year, month + 1);

  DateTime get firstDay => DateTime(year, month);

  /// Last instant-free day of the month. `DateTime(y, m + 1, 0)` normalises
  /// December to the following January correctly, so no month-length table.
  DateTime get lastDay => DateTime(year, month + 1, 0);

  int get dayCount => lastDay.day;

  bool contains(DateTime date) => Ym.fromDate(date).value == value;

  /// The [count] months ending at this one, oldest first. Used for the
  /// month-over-month charts.
  /// This month and the [count] - 1 months after it, oldest first.
  ///
  /// The forward counterpart of [lastMonths], for a projection horizon.
  List<Ym> nextMonths(int count) {
    final result = <Ym>[];
    var cursor = this;
    for (var i = 0; i < count; i++) {
      result.add(cursor);
      cursor = cursor.next;
    }
    return result;
  }

  List<Ym> lastMonths(int count) {
    final months = <Ym>[];
    var cursor = this;
    for (var i = 0; i < count; i++) {
      months.insert(0, cursor);
      cursor = cursor.previous;
    }
    return months;
  }

  @override
  int compareTo(Ym other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Ym && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}';
}
