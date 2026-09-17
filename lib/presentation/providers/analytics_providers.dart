import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/core/config/app_config.dart';
import 'package:masrouf/core/time/ym.dart';
import 'package:masrouf/domain/entities/analytics/analytics.dart';
import 'package:masrouf/domain/entities/analytics/cashflow_calendar.dart';
import 'package:masrouf/domain/entities/analytics/forecast.dart';
import 'package:masrouf/domain/entities/budget.dart';
import 'package:masrouf/domain/entities/planned_expense.dart';
import 'package:masrouf/domain/entities/savings_goal.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

/// The month the analytics screens are looking at.
///
/// A plain notifier rather than a route parameter: the dashboard and the
/// analytics tab share it, so stepping back a month on one and switching tabs
/// keeps the context.
class SelectedMonth extends Notifier<Ym> {
  @override
  Ym build() => Ym.current();

  void previous() => state = state.previous;

  /// Refuses to move past the current month — there is no data ahead of today,
  /// and an empty future month reads as a bug rather than as a boundary.
  void next() {
    final now = Ym.current();
    if (state.value >= now.value) return;
    state = state.next;
  }

  void reset() => state = Ym.current();

  bool get isCurrent => state.value >= Ym.current().value;
}

final selectedMonthProvider =
    NotifierProvider<SelectedMonth, Ym>(SelectedMonth.new);

/// Each of these is keyed by month, so Riverpod caches per month and stepping
/// back to a month you already viewed is instant.
final monthSummaryProvider = StreamProvider.family<MonthSummary, Ym>(
  (ref, ym) => ref.watch(analyticsRepositoryProvider).watchMonthSummary(ym),
);

final categorySlicesProvider =
    StreamProvider.family<List<CategorySlice>, (Ym, TxnType)>(
  (ref, args) => ref
      .watch(analyticsRepositoryProvider)
      .watchCategorySlices(args.$1, type: args.$2),
);

final cashflowProvider =
    StreamProvider.family<List<CashflowPoint>, (Ym, CashflowGranularity)>(
  (ref, args) =>
      ref.watch(analyticsRepositoryProvider).watchCashflow(args.$1, args.$2),
);

final incomeBreakdownProvider = StreamProvider.family<IncomeBreakdown, Ym>(
  (ref, ym) => ref.watch(analyticsRepositoryProvider).watchIncomeBreakdown(
        ym,
        monthCount: AppConfig.analyticsMonthWindow,
      ),
);

/// Safe-to-spend depends on balances and on the recurring schedule, neither of
/// which the aggregate tables can stream. Recomputed whenever the ledger changes.
final safeToSpendProvider = FutureProvider<SafeToSpend>((ref) async {
  // Establishes the dependency that makes this recompute after every write.
  await ref.watch(ledgerRevisionProvider.future);
  return ref.watch(analyticsRepositoryProvider).safeToSpend();
});

/// Caps with this month's spend against them, worst first.
///
/// Keyed by month like the other analytics families, so stepping back to a month
/// already viewed is instant.
final budgetProgressProvider =
    StreamProvider.family<List<BudgetProgress>, Ym>(
  (ref, ym) => ref.watch(budgetRepositoryProvider).watchProgress(ym),
);

final budgetsProvider = StreamProvider<List<Budget>>(
  (ref) => ref.watch(budgetRepositoryProvider).watchAll(),
);

/// A month's expected outflows, keyed by month so stepping back is instant.
final calendarProvider = FutureProvider.family<CashflowCalendar, Ym>(
  (ref, ym) async {
    // Watched, not awaited. Awaiting the revision stream would hold the screen
    // on a spinner until the ledger happens to change — the data it needs is
    // already readable. Watching still re-runs this on every write.
    ref.watch(ledgerRevisionProvider);
    return ref.watch(analyticsRepositoryProvider).calendar(ym);
  },
);

final goalsProvider = StreamProvider<List<SavingsGoalProgress>>(
  (ref) => ref.watch(goalRepositoryProvider).watchProgress(),
);

/// The coming months' projection.
///
/// Recomputed whenever the ledger changes, like safe-to-spend: a new
/// transaction can move the historical baseline the projection rests on.
final forecastProvider = FutureProvider<Forecast>((ref) async {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(analyticsRepositoryProvider).forecast();
});

/// Plans that have not been resolved, soonest first.
final pendingPlansProvider = StreamProvider<List<PlannedExpenseView>>(
  (ref) => ref.watch(plannedRepositoryProvider).watchPending(),
);

/// Plans whose moment has passed and which the user has not answered for.
///
/// The dashboard asks about these rather than logging them: a plan is what the
/// user intended, not evidence that it happened.
final duePlansProvider = Provider<List<PlannedExpenseView>>((ref) {
  final now = DateTime.now();
  final pending = ref.watch(pendingPlansProvider).value;
  if (pending == null) return const <PlannedExpenseView>[];
  return pending.where((v) => v.plan.isDue(now)).toList(growable: false);
});

/// Ticks on every ledger change.
///
/// A single cheap stream that carries no rows, so widgets that only need to know
/// "something changed" do not deserialise a result set to find out.
final ledgerRevisionProvider = StreamProvider<int>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  var revision = 0;
  return repository.watchChanges().map((_) => revision++);
});

/// Every tag currently in use, for the history filter.
final allTagsProvider = StreamProvider<List<String>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchTags(),
);

final recentTransactionsProvider = StreamProvider<List<TxnView>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchRecent(limit: 6),
);

final recurringRulesProvider = StreamProvider(
  (ref) => ref.watch(recurringRepositoryProvider).watchAll(),
);
