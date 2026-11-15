import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/domain/entities/analytics/analytics.dart';
import 'package:masrouf/domain/entities/planned_expense.dart';
import 'package:meta/meta.dart';

/// One outflow expected in the coming week: a recurring bill or a plan.
@immutable
class UpcomingItem {
  const UpcomingItem({
    required this.id,
    required this.label,
    required this.amount,
    required this.date,
    required this.isPlan,
  });

  final String id;
  final String label;
  final Money amount;

  /// The calendar day it falls on.
  final DateTime date;

  /// A one-off plan rather than a recurring rule.
  final bool isPlan;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UpcomingItem &&
          other.id == id &&
          other.label == label &&
          other.amount == amount &&
          other.date == date &&
          other.isPlan == isPlan);

  @override
  int get hashCode => Object.hash(id, label, amount, date, isPlan);
}

/// What falls due between today and six days from now.
///
/// Pure, so the window's edges are pinned by tests rather than by care.
abstract final class UpcomingWeek {
  static const int days = 7;

  /// The last day the window includes.
  static DateTime lastDay(DateTime now) =>
      now.dateOnly.add(const Duration(days: days - 1));

  /// Bills and plans in the window, soonest first and largest first within a
  /// day.
  ///
  /// A plan already due is left out: the dashboard asks about it in its own
  /// card above, and listing it twice would make one plan read as two.
  static List<UpcomingItem> from({
    required Iterable<UpcomingBill> bills,
    required Iterable<PlannedExpenseView> plans,
    required DateTime now,
    required String Function(PlannedExpenseView view) planLabel,
  }) {
    final first = now.dateOnly;
    final last = lastDay(now);
    bool inWindow(DateTime day) => !day.isBefore(first) && !day.isAfter(last);

    final items = <UpcomingItem>[
      for (final bill in bills)
        if (inWindow(bill.dueDate.dateOnly))
          UpcomingItem(
            id: bill.ruleId,
            label: bill.label,
            amount: bill.amount,
            date: bill.dueDate.dateOnly,
            isPlan: false,
          ),
      for (final view in plans)
        if (view.plan.isPending &&
            !view.plan.isDue(now) &&
            inWindow(view.plan.dueAt.dateOnly))
          UpcomingItem(
            id: view.plan.id,
            label: planLabel(view),
            amount: view.plan.amount,
            date: view.plan.dueAt.dateOnly,
            isPlan: true,
          ),
    ];

    items.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : b.amount.milli.compareTo(a.amount.milli);
    });
    return items;
  }
}
