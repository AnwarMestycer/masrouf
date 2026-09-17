import 'package:drift/drift.dart';
import 'package:masrouf/data/local/converters/tags_converter.dart';

/// Columns every synced table carries.
///
/// [updatedAt] is the last-write-wins clock and [deletedAt] is the tombstone: a
/// row deleted offline has to remain present locally so the deletion can be
/// pushed, and has to remain present *on the server* so other devices learn about
/// it on their next delta pull. Hard deletes only happen during compaction.
mixin SyncedTable on Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(name: 'accounts_user_sort', columns: {#userId, #sortOrder})
@TableIndex(name: 'accounts_user_updated', columns: {#userId, #updatedAt})
@DataClassName('AccountRow')
class Accounts extends Table with SyncedTable {
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get type => text().withLength(max: 16)();
  TextColumn get currency => text().withLength(min: 3, max: 3)();

  /// Thousandths of a currency unit. See `Money`.
  IntColumn get openingBalanceMilli => integer().withDefault(const Constant(0))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

@TableIndex(name: 'categories_user_kind', columns: {#userId, #kind, #sortOrder})
@TableIndex(name: 'categories_user_updated', columns: {#userId, #updatedAt})
@DataClassName('CategoryRow')
class Categories extends Table with SyncedTable {
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get kind => text().withLength(max: 8)();
  TextColumn get icon => text().withLength(max: 40)();
  IntColumn get color => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

// Mirrors the Postgres index set: the history list and month filters ride
// (userId, dateYmd), analytics rides (userId, categoryId), balances ride
// (userId, accountId), and the delta pull rides (userId, updatedAt).
@TableIndex(name: 'txn_user_date', columns: {#userId, #dateYmd})
@TableIndex(name: 'txn_user_category', columns: {#userId, #categoryId})
@TableIndex(name: 'txn_user_account', columns: {#userId, #accountId})
@TableIndex(name: 'txn_user_updated', columns: {#userId, #updatedAt})
@TableIndex(name: 'txn_rule', columns: {#recurringRuleId})
@DataClassName('TxnRow')
class Transactions extends Table with SyncedTable {
  TextColumn get type => text().withLength(max: 10)();
  IntColumn get amountMilli => integer()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  RealColumn get fxRateToBase => real().withDefault(const Constant(1))();
  TextColumn get categoryId => text().nullable()();
  TextColumn get accountId => text()();
  TextColumn get transferAccountId => text().nullable()();

  /// The calendar day as `yyyyMMdd`.
  ///
  /// An integer rather than a timestamp because every query against it is a
  /// calendar operation — "this month", "group by day" — and a timestamp would
  /// let a timezone shift move a transaction between months. Integer ordering is
  /// also chronological for free, so the `(userId, dateYmd DESC)` index serves
  /// the history list directly.
  IntColumn get dateYmd => integer()();

  TextColumn get note => text().nullable()();
  TextColumn get tags => text().map(const TagsConverter())();
  TextColumn get recurringRuleId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

@TableIndex(name: 'recurring_user_next', columns: {#userId, #nextRunYmd})
@TableIndex(name: 'recurring_user_updated', columns: {#userId, #updatedAt})
@DataClassName('RecurringRuleRow')
class RecurringRules extends Table with SyncedTable {
  TextColumn get type => text().withLength(max: 10)();
  IntColumn get amountMilli => integer()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  TextColumn get categoryId => text().nullable()();
  TextColumn get accountId => text()();
  TextColumn get transferAccountId => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get cadence => text().withLength(max: 10)();
  IntColumn get dayOfMonth => integer().nullable()();
  IntColumn get dayOfWeek => integer().nullable()();
  IntColumn get nextRunYmd => integer()();
  IntColumn get lastRunYmd => integer().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
}

/// A monthly spending cap for one category.
///
/// One row per category, applying every month rather than being stored per
/// month. A per-month budget immediately needs a rollover story — does an
/// underspent March raise April's cap? — and that is a different feature. A
/// single recurring cap is what a first budget actually is.
///
/// The spend side is not stored here: `monthly_category_totals` already
/// maintains it incrementally, so progress is a join rather than new
/// bookkeeping that could drift out of step with the ledger.
@TableIndex(name: 'budgets_user_category', columns: {#userId, #categoryId})
@TableIndex(name: 'budgets_user_updated', columns: {#userId, #updatedAt})
@DataClassName('BudgetRow')
class Budgets extends Table with SyncedTable {
  TextColumn get categoryId => text()();
  IntColumn get amountMilli => integer()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  DateTimeColumn get createdAt => dateTime()();
}

/// Money the user intends to spend on a given date, which has not moved yet.
///
/// Deliberately its own table rather than a flag on [Transactions]. The
/// aggregates key purely off `date_ymd` with no upper bound, so a future-dated
/// transaction row would be folded into `account_balances` and
/// `monthly_category_totals` the moment it existed — the balance would drop for
/// money still in the account. Keeping plans out of the ledger entirely is the
/// only way the balance stays a statement of fact.
///
/// [dueAt] is a full timestamp, not the `date_ymd` integer transactions use.
/// That integer exists so a timezone shift cannot move a transaction between
/// months; a plan needs a time of day to be worth reminding about, and it is
/// never aggregated, so the trade does not apply.
@TableIndex(name: 'planned_user_due', columns: {#userId, #dueAt})
@TableIndex(name: 'planned_user_updated', columns: {#userId, #updatedAt})
@DataClassName('PlannedExpenseRow')
class PlannedExpenses extends Table with SyncedTable {
  TextColumn get categoryId => text().nullable()();
  TextColumn get accountId => text().nullable()();
  IntColumn get amountMilli => integer()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  DateTimeColumn get dueAt => dateTime()();
  TextColumn get note => text().nullable()();

  /// `pending` | `done` | `cancelled`. Only `pending` reserves money.
  TextColumn get status => text().withLength(max: 10)();

  /// Set when a pending plan was logged as a real transaction, so the two can
  /// be traced to each other after the fact.
  TextColumn get transactionId => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
}

/// A savings target, tracked by an account's real balance.
///
/// There is no `saved` column on purpose. Progress *is* [accountId]'s balance,
/// so the goal can never disagree with the ledger — a second running total
/// would be a parallel books nobody reconciles, and the first time the two
/// diverge the user cannot tell which is lying.
@TableIndex(name: 'goals_user_updated', columns: {#userId, #updatedAt})
@DataClassName('SavingsGoalRow')
class SavingsGoals extends Table with SyncedTable {
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get targetMilli => integer()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();

  /// The account whose balance is the progress.
  TextColumn get accountId => text()();

  /// Optional. With one, the goal can say what it needs per month; without one
  /// it is simply a target to move toward.
  DateTimeColumn get targetDate => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('ExchangeRateRow')
class ExchangeRates extends Table with SyncedTable {
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  RealColumn get rateToBase => real()();
}

@DataClassName('UserSettingsRow')
class UserSettingsRows extends Table with SyncedTable {
  TextColumn get baseCurrency => text().withLength(min: 3, max: 3)();
  TextColumn get locale => text().withLength(max: 8)();
  TextColumn get themeMode => text().withLength(max: 8)();
  IntColumn get paydayDayOfMonth => integer()();
}
