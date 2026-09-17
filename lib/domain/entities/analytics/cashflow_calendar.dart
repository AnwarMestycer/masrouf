import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:meta/meta.dart';

/// Where a calendar entry came from.
///
/// Kept distinct because the two behave differently: a plan is a one-off the
/// user can confirm or skip, a rule keeps producing occurrences on its own.
enum CalendarSource { planned, recurring }

/// One expected outflow on one day.
///
/// Nothing here has happened yet. The calendar shows the *shape* of a month
/// before it arrives, which is exactly the information the ledger cannot carry:
/// the ledger only knows what has already been spent.
@immutable
class CalendarEntry {
  const CalendarEntry({
    required this.id,
    required this.label,
    required this.amount,
    required this.date,
    required this.source,
  });

  final String id;
  final String label;
  final Money amount;
  final DateTime date;
  final CalendarSource source;
}

/// A month's expected outflows, grouped by day of month.
@immutable
class CashflowCalendar {
  const CashflowCalendar({required this.byDay, required this.currency});

  /// Day of month (1-31) to that day's entries. Days with nothing are absent
  /// rather than present-and-empty, so a caller can ask `containsKey`.
  final Map<int, List<CalendarEntry>> byDay;

  final Currency currency;

  Money totalFor(int day) => Money(
        (byDay[day] ?? const <CalendarEntry>[])
            .fold<int>(0, (sum, e) => sum + e.amount.milli),
        currency,
      );

  Money get total => Money(
        byDay.values
            .expand((entries) => entries)
            .fold<int>(0, (sum, e) => sum + e.amount.milli),
        currency,
      );

  bool get isEmpty => byDay.isEmpty;
}
