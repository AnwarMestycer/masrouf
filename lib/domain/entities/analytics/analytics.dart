import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/time/ym.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:meta/meta.dart';

/// Headline numbers for one month.
@immutable
class MonthSummary {
  const MonthSummary({
    required this.ym,
    required this.income,
    required this.expense,
  });

  const MonthSummary.empty(this.ym, Money zero)
      : income = zero,
        expense = zero;

  final Ym ym;
  final Money income;

  /// A positive magnitude — the direction is implied by the field.
  final Money expense;

  Money get net => income - expense;

  /// Share of income that was spent, or null when there was no income to divide
  /// by. Null rather than zero so the UI can say "—" instead of an untrue 0 %.
  double? get burnRate =>
      income.isZero ? null : expense.milli / income.milli;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MonthSummary &&
          other.ym == ym &&
          other.income == income &&
          other.expense == expense);

  @override
  int get hashCode => Object.hash(ym, income, expense);
}

/// One slice of the spending donut, and one row of the ranked list beneath it.
@immutable
class CategorySlice {
  const CategorySlice({
    required this.category,
    required this.total,
    required this.txnCount,
    required this.share,
    required this.previousTotal,
  });

  /// Null for the synthetic "uncategorised" slice left behind when a category is
  /// deleted but its transactions remain.
  final Category? category;

  final Money total;
  final int txnCount;

  /// Fraction of the month's total spend, 0..1. Precomputed so the chart and the
  /// list cannot disagree about rounding.
  final double share;

  /// Same category in the previous month, for the delta chip.
  final Money previousTotal;

  /// Signed relative change, or null when the previous month was zero — division
  /// would be infinite, and "+∞ %" is not a useful thing to show.
  double? get changeRatio => previousTotal.isZero
      ? null
      : (total.milli - previousTotal.milli) / previousTotal.milli;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategorySlice &&
          other.category == category &&
          other.total == total &&
          other.txnCount == txnCount &&
          other.previousTotal == previousTotal);

  @override
  int get hashCode => Object.hash(category, total, txnCount, previousTotal);
}

/// One bucket of the cash-flow chart — a day or a week depending on granularity.
@immutable
class CashflowPoint {
  const CashflowPoint({
    required this.start,
    required this.income,
    required this.expense,
  });

  final DateTime start;
  final Money income;
  final Money expense;

  Money get net => income - expense;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CashflowPoint &&
          other.start == start &&
          other.income == income &&
          other.expense == expense);

  @override
  int get hashCode => Object.hash(start, income, expense);
}

enum CashflowGranularity { daily, weekly }

/// Income split by source category across several months.
@immutable
class IncomeBreakdown {
  const IncomeBreakdown({required this.months, required this.series});

  /// Oldest first, so chart x-axes read left to right without re-sorting.
  final List<Ym> months;

  /// One entry per income category, each holding one total per month in [months].
  final List<IncomeSeries> series;

  bool get isEmpty => series.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IncomeBreakdown &&
          _listEquals(other.months, months) &&
          _listEquals(other.series, series));

  @override
  int get hashCode => Object.hash(Object.hashAll(months), Object.hashAll(series));
}

@immutable
class IncomeSeries {
  const IncomeSeries({required this.category, required this.totals});

  final Category? category;

  /// Parallel to [IncomeBreakdown.months]; zero-filled for months with no income
  /// in this category so every series has the same length and charts need no
  /// null handling.
  final List<Money> totals;

  Money get grandTotal => totals.isEmpty
      ? Money.zero(totals.first.currency)
      : totals.reduce((a, b) => a + b);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IncomeSeries &&
          other.category == category &&
          _listEquals(other.totals, totals));

  @override
  int get hashCode => Object.hash(category, Object.hashAll(totals));
}

/// Balance minus everything already known to be owed before the next payday.
@immutable
class SafeToSpend {
  const SafeToSpend({
    required this.amount,
    required this.currentBalance,
    required this.upcomingBills,
    required this.reserved,
    required this.horizon,
  });

  /// May be negative — that is precisely the signal worth surfacing.
  final Money amount;

  final Money currentBalance;

  /// Recurring rules due between today and [horizon], soonest first.
  final List<UpcomingBill> upcomingBills;

  /// The part of the subtraction that came from planned expenses rather than
  /// recurring bills. Surfaced separately so the user can see *why* the figure
  /// is lower than their balance — an unexplained gap reads as a bug.
  final Money reserved;

  /// The next payday.
  final DateTime horizon;

  int get daysRemaining =>
      horizon.difference(DateTime.now()).inDays.clamp(0, 366);

  /// What is left per remaining day. Null on payday itself, where dividing by
  /// zero days would be meaningless.
  Money? get perDay {
    final days = daysRemaining;
    if (days <= 0) return null;
    return Money(amount.milli ~/ days, amount.currency);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SafeToSpend &&
          other.amount == amount &&
          other.currentBalance == currentBalance &&
          other.horizon == horizon &&
          _listEquals(other.upcomingBills, upcomingBills));

  @override
  int get hashCode => Object.hash(
        amount,
        currentBalance,
        horizon,
        Object.hashAll(upcomingBills),
      );
}

@immutable
class UpcomingBill {
  const UpcomingBill({
    required this.ruleId,
    required this.label,
    required this.amount,
    required this.dueDate,
  });

  final String ruleId;
  final String label;
  final Money amount;
  final DateTime dueDate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UpcomingBill &&
          other.ruleId == ruleId &&
          other.amount == amount &&
          other.dueDate == dueDate);

  @override
  int get hashCode => Object.hash(ruleId, amount, dueDate);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
