import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/core/time/ym.dart';
import 'package:meta/meta.dart';

/// The windows analytics can be read over.
///
/// Calendar months are the default because budgets are monthly, but they are a
/// poor description of a month in progress: on the 5th, "this month" is five
/// days of spending being compared against someone else's thirty.
enum RangePreset {
  thisMonth,
  lastMonth,
  last30Days,
  last3Months,
  last6Months,
  yearToDate,

  /// Payday to the day before the next one. The app already knows the payday,
  /// and "since I was paid" is usually what people mean by "this month".
  payPeriod,

  custom;

  /// Whether the window follows a calendar or pay cycle, which decides what
  /// "the previous one" means — see [DateRange.previous].
  bool get isCyclic =>
      this == RangePreset.thisMonth ||
      this == RangePreset.lastMonth ||
      this == RangePreset.payPeriod;
}

/// An inclusive span of calendar days.
///
/// Both ends are whole days: every date in this app is a calendar day, never an
/// instant, and the aggregates these ranges are read against are keyed by
/// `yyyyMMdd`.
@immutable
class DateRange {
  DateRange({
    required DateTime from,
    required DateTime to,
    this.preset = RangePreset.custom,
    this.payday = 1,
  })  : from = from.dateOnly,
        to = to.dateOnly;

  final DateTime from;
  final DateTime to;
  final RangePreset preset;

  /// Carried so [previous] can step a pay cycle without being handed settings
  /// again. Irrelevant for every other preset.
  final int payday;

  /// Inclusive, so a single day is one day rather than zero.
  int get dayCount => to.difference(from).inDays + 1;

  /// The month this range covers, or null when it spans more than one.
  ///
  /// Not merely informative: a range that is exactly one calendar month can be
  /// answered from `monthly_category_totals` in a handful of row reads, while
  /// anything else has to go to the ledger.
  Ym? get wholeMonth {
    final ym = Ym.fromDate(from);
    final isWhole = from.day == 1 &&
        to.day == ym.dayCount &&
        Ym.fromDate(to).value == ym.value;
    return isWhole ? ym : null;
  }

  bool contains(DateTime date) {
    final day = date.dateOnly;
    return !day.isBefore(from) && !day.isAfter(to);
  }

  /// The window this one should be compared against.
  ///
  /// For a rolling or custom window it is the equal-length span immediately
  /// before it. For a calendar or pay cycle it is the *same stretch of the
  /// previous cycle* instead — five days into October compares against the
  /// first five days of September, not against 26–30 September. Spending has a
  /// monthly shape (rent at the turn, payday on the 28th), so lining the cycles
  /// up is the only comparison that answers "am I spending more than usual".
  DateRange get previous {
    if (!preset.isCyclic) {
      final end = from.subtract(const Duration(days: 1));
      return DateRange(
        from: end.subtract(Duration(days: dayCount - 1)),
        to: end,
        preset: preset,
        payday: payday,
      );
    }

    // `from` is already the first day of its cycle, so the previous cycle
    // starts exactly one month earlier — clamped, for a payday on the 31st.
    final start = preset == RangePreset.payPeriod
        ? dayOfMonthIn(from.year, from.month - 1, payday)
        : DateTime(from.year, from.month - 1, 1);

    // Clamp: five days into March has no 31st of February to match, and a
    // 30-day window cannot be laid over a 28-day one.
    final cycleEnd = preset == RangePreset.payPeriod
        ? _nextPayday(start, payday).subtract(const Duration(days: 1))
        : DateTime(start.year, start.month + 1, 0);
    final wanted = start.add(Duration(days: dayCount - 1));

    return DateRange(
      from: start,
      to: wanted.isAfter(cycleEnd) ? cycleEnd : wanted,
      preset: preset,
      payday: payday,
    );
  }

  static DateTime _nextPayday(DateTime day, int payday) =>
      dayOfMonthIn(day.year, day.month + 1, payday);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DateRange &&
          other.from == from &&
          other.to == to &&
          other.preset == preset);

  @override
  int get hashCode => Object.hash(from, to, preset);

  @override
  String toString() =>
      'DateRange(${from.toIsoDate()}..${to.toIsoDate()}, ${preset.name})';
}

/// Turns a [RangePreset] into concrete dates.
///
/// Pure: the clock and the payday come in as arguments, so every boundary here
/// is unit-tested without waiting for a month to turn over.
abstract final class Ranges {
  static DateRange resolve(
    RangePreset preset, {
    required DateTime now,
    required int payday,
    DateRange? custom,
  }) {
    final today = now.dateOnly;

    switch (preset) {
      case RangePreset.thisMonth:
        // Capped at today rather than running to the end of the month: a window
        // that includes days which have not happened dilutes every per-day
        // figure read from it.
        return DateRange(
          from: DateTime(today.year, today.month),
          to: today,
          preset: preset,
          payday: payday,
        );

      case RangePreset.lastMonth:
        final first = DateTime(today.year, today.month - 1);
        return DateRange(
          from: first,
          to: DateTime(first.year, first.month + 1, 0),
          preset: preset,
          payday: payday,
        );

      case RangePreset.last30Days:
        return DateRange(
          from: today.subtract(const Duration(days: 29)),
          to: today,
          preset: preset,
          payday: payday,
        );

      case RangePreset.last3Months:
        return DateRange(
          from: today.addMonthsClamped(-3).add(const Duration(days: 1)),
          to: today,
          preset: preset,
          payday: payday,
        );

      case RangePreset.last6Months:
        return DateRange(
          from: today.addMonthsClamped(-6).add(const Duration(days: 1)),
          to: today,
          preset: preset,
          payday: payday,
        );

      case RangePreset.yearToDate:
        return DateRange(
          from: DateTime(today.year),
          to: today,
          preset: preset,
          payday: payday,
        );

      case RangePreset.payPeriod:
        final start = currentPaydayOnOrBefore(today, payday);
        final end = dayOfMonthIn(start.year, start.month + 1, payday)
            .subtract(const Duration(days: 1));
        return DateRange(
          from: start,
          to: today.isBefore(end) ? today : end,
          preset: preset,
          payday: payday,
        );

      case RangePreset.custom:
        return custom ??
            DateRange(
              from: DateTime(today.year, today.month),
              to: today,
              preset: RangePreset.custom,
              payday: payday,
            );
    }
  }

  /// The payday on or before [day]. If this month's has not arrived yet, the
  /// period began with last month's.
  static DateTime currentPaydayOnOrBefore(DateTime day, int payday) {
    final thisMonth = dayOfMonthIn(day.year, day.month, payday);
    if (thisMonth.isAfter(day)) {
      return dayOfMonthIn(day.year, day.month - 1, payday);
    }
    return thisMonth;
  }
}
