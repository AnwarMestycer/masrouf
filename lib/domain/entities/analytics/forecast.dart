import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/time/ym.dart';
import 'package:meta/meta.dart';

/// What one future month is expected to look like.
///
/// Expense is decomposed into three parts the user can name, rather than a
/// single number they have to trust:
///
/// - [typical] — what months like this usually cost, from history
/// - [committed] — recurring rules that fall in the month
/// - [planned] — dated commitments the user entered themselves
///
/// The decomposition is the point. A projection nobody can interrogate is a
/// number nobody should act on, and this one can be read back as "your usual
/// spending, plus the bills you know about, plus what you planned".
@immutable
class MonthForecast {
  const MonthForecast({
    required this.ym,
    required this.typical,
    required this.committed,
    required this.planned,
    required this.expectedIncome,
  });

  final Ym ym;

  /// Historical baseline, excluding anything a recurring rule generated —
  /// those are counted in [committed] instead, and counting them twice would
  /// inflate every month by the rent.
  final Money typical;

  final Money committed;
  final Money planned;
  final Money expectedIncome;

  Money get projectedExpense => typical + committed + planned;

  /// What the month is expected to leave behind. Negative means the month is
  /// projected to cost more than it brings in.
  Money get projectedSavings => expectedIncome - projectedExpense;
}

/// A run of months, with the confidence to state alongside it.
@immutable
class Forecast {
  const Forecast({required this.months, required this.historyMonths});

  final List<MonthForecast> months;

  /// How many past months the baseline was drawn from.
  final int historyMonths;

  /// Below three months there is not enough history for a median to mean
  /// anything. The figure is still shown — a new user asking "can I save?"
  /// deserves an answer — but it is labelled provisional rather than presented
  /// as fact.
  bool get isProvisional => historyMonths < 3;

  /// Cumulative savings across the horizon — the answer to "how much can I
  /// put aside". Null when there is no horizon to sum.
  Money? get totalSavings => months.isEmpty
      ? null
      : months.map((m) => m.projectedSavings).reduce((a, b) => a + b);
}
