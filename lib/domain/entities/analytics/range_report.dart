import 'package:masrouf/core/config/app_config.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/domain/entities/analytics/analytics.dart';
import 'package:masrouf/domain/entities/analytics/date_range.dart';
import 'package:meta/meta.dart';

/// One transaction big enough to move the window's total on its own.
@immutable
class LargePayment {
  const LargePayment({
    required this.id,
    required this.label,
    required this.amount,
    required this.date,
  });

  final String id;

  /// Category name, or the note when there is no category.
  final String label;
  final Money amount;
  final DateTime date;
}

/// Everything the range view reads, from a single pass over the window.
///
/// Carries the comparable window's totals alongside its own: a figure with
/// nothing to compare it against is the thing the month view already does
/// badly.
@immutable
class RangeReport {
  const RangeReport({
    required this.range,
    required this.income,
    required this.expense,
    required this.previousExpense,
    required this.previousIncome,
    required this.txnCount,
    required this.medianTxn,
    required this.meanTxn,
    required this.activeDays,
    required this.busiestDay,
    required this.busiestDayTotal,
    required this.large,
    required this.slices,
  });

  const RangeReport.empty(this.range, Money zero)
      : income = zero,
        expense = zero,
        previousExpense = zero,
        previousIncome = zero,
        txnCount = 0,
        medianTxn = zero,
        meanTxn = zero,
        activeDays = 0,
        busiestDay = null,
        busiestDayTotal = zero,
        large = const <LargePayment>[],
        slices = const <CategorySlice>[];

  final DateRange range;
  final Money income;

  /// A positive magnitude — the direction is implied by the field.
  final Money expense;
  final Money previousExpense;
  final Money previousIncome;

  final int txnCount;

  /// The middle transaction, which describes an ordinary purchase in a way the
  /// mean cannot: a ledger of 2 DT coffees and one 322 DT tuition payment has a
  /// mean nobody ever spent.
  final Money medianTxn;

  /// The average purchase. Shown beside [medianTxn] rather than instead of it:
  /// the gap between the two *is* the finding. A ledger whose mean is three
  /// times its median is one where a few large payments are carrying the total.
  final Money meanTxn;

  /// Days in the window with at least one transaction.
  ///
  /// The denominator that makes a daily average honest. Spending 300 over three
  /// days of a thirty-day window is not "10 a day".
  final int activeDays;

  /// The heaviest single day, or null when the window is empty.
  final DateTime? busiestDay;
  final Money busiestDayTotal;

  /// Payments large enough to dominate the total on their own, biggest first.
  final List<LargePayment> large;

  /// Spending by category across the window, each carrying the comparable
  /// window's figure.
  final List<CategorySlice> slices;

  Money get largeTotal => large.isEmpty
      ? Money.zero(expense.currency)
      : large.map((p) => p.amount).reduce((a, b) => a + b);

  /// What was spent once the large payments are set aside — the number that
  /// answers "what does a normal week cost me".
  Money get everyday => expense - largeTotal;

  /// Spending per day of the window, everything included.
  Money get perDay => Money(
        range.dayCount == 0 ? 0 : expense.milli ~/ range.dayCount,
        expense.currency,
      );

  /// Spending per day on which anything was actually spent.
  ///
  /// Read together with [perDay]: a large gap between them means the spending
  /// is bursty rather than steady, which is a different thing to know.
  Money get perActiveDay => Money(
        activeDays == 0 ? 0 : expense.milli ~/ activeDays,
        expense.currency,
      );

  /// Everyday spending per day of the window. Large payments are excluded
  /// deliberately: one tuition bill would otherwise set a daily rate that no
  /// day resembles.
  Money get everydayPerDay => Money(
        range.dayCount == 0 ? 0 : everyday.milli ~/ range.dayCount,
        expense.currency,
      );

  /// Signed relative change against the comparable window, or null when that
  /// window was empty — dividing by it would be infinite, and "+∞%" says
  /// nothing.
  double? get expenseChangeRatio => previousExpense.isZero
      ? null
      : (expense.milli - previousExpense.milli) / previousExpense.milli;

  double? get incomeChangeRatio => previousIncome.isZero
      ? null
      : (income.milli - previousIncome.milli) / previousIncome.milli;

  Money get net => income - expense;

  /// Share of the window's income that was spent, or null when there was none
  /// to divide by. Null rather than zero so the UI can say so outright instead
  /// of showing an untrue 0%.
  double? get burnRate =>
      income.isZero ? null : expense.milli / income.milli;

  /// Whether spending so dwarfs the window's income that the percentage says
  /// more about where the window's edges fell than about any spending habit.
  ///
  /// A ten-day window that misses payday but catches the rent it paid for
  /// reports four figures of "income spent". The direction is the only part of
  /// that worth showing.
  bool get burnRateIsUninformative {
    final rate = burnRate;
    return rate != null && rate > AppConfig.analyticsBurnRateCeiling;
  }

  bool get isEmpty => txnCount == 0;
}
