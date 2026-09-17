import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/result/result.dart';
import 'package:masrouf/core/time/ym.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/budget.dart';
import 'package:masrouf/domain/entities/planned_expense.dart';
import 'package:masrouf/domain/entities/savings_goal.dart';
import 'package:masrouf/domain/entities/analytics/analytics.dart';
import 'package:masrouf/domain/entities/analytics/cashflow_calendar.dart';
import 'package:masrouf/domain/entities/analytics/forecast.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/entities/history_filter.dart';
import 'package:masrouf/domain/entities/recurring_rule.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/entities/user_settings.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

/// Repository contracts.
///
/// Every read returns a `Stream` or a plain value rather than a `Result`: reads
/// come from the local database, which is always available, so there is no
/// failure mode worth propagating. Only writes — which can violate an invariant —
/// return [Result].

abstract interface class AccountRepository {
  Stream<List<AccountWithBalance>> watchWithBalances({bool includeArchived = false});
  Stream<List<Account>> watchAll({bool includeArchived = false});
  Future<Account?> getById(String id);
  Future<Result<Account>> create(Account account);
  Future<Result<Account>> update(Account account);
  Future<Result<void>> delete(String id);
  Future<Result<void>> reorder(List<String> orderedIds);
}

abstract interface class CategoryRepository {
  Stream<List<Category>> watchByKind(CategoryKind kind);
  Stream<List<Category>> watchAll();

  /// Recent-first ordering for the fast-add chip strip.
  Stream<List<Category>> watchQuickPicks(CategoryKind kind);

  Future<Result<Category>> create(Category category);
  Future<Result<Category>> update(Category category);
  Future<Result<void>> delete(String id);
  Future<Result<void>> reorder(List<String> orderedIds);

  /// Creates the starter set. No-op when categories already exist, so it is safe
  /// to call on every launch.
  /// [names] maps each seeded category's stable English key to the user's
  /// language, so the starter set is not English in an Arabic UI.
  Future<Result<void>> seedDefaultsIfEmpty(
    Currency base, {
    Map<String, String> names,
  });
}

abstract interface class TransactionRepository {
  Stream<List<TxnView>> watchRecent({int limit = 5});

  /// One page of history. Not a stream: the list is paged, and re-emitting every
  /// loaded page on each keystroke would defeat the paging.
  Future<List<TxnView>> page(HistoryFilter filter, {required int offset});

  /// Fires whenever the ledger changes, so a paged list knows to refresh.
  Stream<void> watchChanges();

  /// Every tag in use, for the history filter's tag facet.
  Stream<List<String>> watchTags();

  Future<Txn?> getById(String id);
  Future<Result<Txn>> add(Txn txn);
  Future<Result<Txn>> update(Txn txn);
  Future<Result<void>> delete(String id);

  /// Reinstates a deleted transaction — the undo path.
  Future<Result<void>> restore(String id);

  Future<Result<String>> exportCsv();
}

abstract interface class RecurringRepository {
  Stream<List<RecurringRule>> watchAll();

  /// One-shot read, for callers that are Futures and must not await a stream.
  Future<List<RecurringRule>> all();

  Future<Result<RecurringRule>> create(RecurringRule rule);
  Future<Result<RecurringRule>> update(RecurringRule rule);
  Future<Result<void>> delete(String id);
  Future<Result<void>> setActive(String id, {required bool active});

  /// Generates every occurrence that has come due, and returns how many were
  /// created. Idempotent: running it twice on the same day creates nothing new.
  Future<Result<int>> materialiseDue();

  Future<List<UpcomingBill>> upcomingBefore(DateTime horizon);
}

/// Monthly spending caps, one per category.
abstract interface class BudgetRepository {
  Stream<List<Budget>> watchAll();

  /// Caps with [ym]'s spend against them, worst first.
  Stream<List<BudgetProgress>> watchProgress(Ym ym);

  /// Creates or replaces the cap for a category. Keyed on the category, so two
  /// competing budgets for one category are not representable.
  Future<Result<Budget>> setForCategory(String categoryId, Money amount);

  Future<Result<void>> remove(String id);
}

/// Dated commitments that have not moved money yet.
abstract interface class PlannedRepository {
  Stream<List<PlannedExpenseView>> watchPending();

  /// Everything in a window, resolved or not — for the month list and calendar.
  Stream<List<PlannedExpenseView>> watchBetween(DateTime from, DateTime to);

  /// One-shot read of a window, for callers that are Futures.
  Future<List<PlannedExpenseView>> between(DateTime from, DateTime to);

  /// Pending plans due on or before [horizon]. What `SafeToSpend` reserves.
  Future<List<PlannedExpense>> pendingBefore(DateTime horizon);

  Future<Result<PlannedExpense>> save(PlannedExpense plan);

  /// Records the plan as having actually happened, writing the real transaction.
  Future<Result<void>> confirm(String id, {required String accountId});

  /// It did not happen. Kept, not deleted, so the calendar still shows it.
  Future<Result<void>> cancel(String id);

  Future<Result<void>> remove(String id);
}

/// Savings targets, each backed by a real account's balance.
abstract interface class GoalRepository {
  Stream<List<SavingsGoalProgress>> watchProgress();
  Future<Result<SavingsGoal>> save(SavingsGoal goal);
  Future<Result<void>> remove(String id);
}

abstract interface class AnalyticsRepository {
  Stream<MonthSummary> watchMonthSummary(Ym ym);
  Stream<List<CategorySlice>> watchCategorySlices(Ym ym, {TxnType type});
  Stream<List<CashflowPoint>> watchCashflow(Ym ym, CashflowGranularity granularity);
  Stream<IncomeBreakdown> watchIncomeBreakdown(Ym latest, {int monthCount});
  Future<List<MonthSummary>> summaries(List<Ym> months);

  /// Projects the coming months: what they are likely to cost and what is
  /// likely to be left over.
  Future<Forecast> forecast({int monthCount, int historyMonths});

  /// A month's expected outflows, grouped by day — plans plus enumerated
  /// recurring occurrences. Nothing in it has happened yet.
  Future<CashflowCalendar> calendar(Ym ym);
  Future<SafeToSpend> safeToSpend();

  /// Recomputes the derived tables from the ledger.
  Future<Result<void>> rebuild();
}

abstract interface class SettingsRepository {
  Stream<UserSettings> watch();
  Future<UserSettings> read();
  Future<Result<void>> save(UserSettings settings);

  Stream<List<ExchangeRate>> watchRates();
  Future<Map<String, double>> ratesToBase();
  Future<Result<void>> saveRate(Currency currency, double rateToBase);

  /// The account the add flow should preselect — the last one used.
  Future<String?> lastUsedAccountId();
  Future<void> rememberAccount(String accountId);

  /// Total across all accounts, converted to the base currency.
  Stream<Money> watchTotalBalance();
}
