import 'package:drift/drift.dart';

/// The outbox. One row per locally-changed record that has not reached the server.
///
/// Keyed by `(entity, entityId)` rather than being an append-only operation log:
/// the pusher reads the *current* local row and upserts it, so ten offline edits
/// to one transaction collapse into a single push. An op log would replay all ten
/// and could not be coalesced without replaying conflicts too. This composes
/// exactly with last-write-wins, which only cares about final state.
@DataClassName('SyncQueueEntry')
class SyncQueueEntries extends Table {
  TextColumn get entity => text()();
  TextColumn get entityId => text()();

  /// `upsert` or `delete` — see [SyncOp]. A row that is created and then deleted
  /// while offline overwrites its own queue entry and pushes once, as a delete.
  TextColumn get op => text().withLength(max: 10)();

  DateTimeColumn get enqueuedAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Exponential backoff gate. The pusher only picks up rows whose time has come,
  /// so one poisoned record cannot spin the queue.
  DateTimeColumn get nextAttemptAt => dateTime()();

  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{entity, entityId};
}

/// Incrementally maintained monthly totals per category.
///
/// Local-only and never synced: it is pure derived state, rebuildable from
/// `transactions` at any time. Maintained inside the same drift transaction as
/// the write that changes it, which is what lets the dashboard read a handful of
/// rows instead of scanning the whole ledger, and lets a single insert invalidate
/// one narrow provider rather than every analytics widget.
@DataClassName('MonthlyCategoryTotalRow')
class MonthlyCategoryTotals extends Table {
  TextColumn get userId => text()();

  /// `yyyyMM`.
  IntColumn get ym => integer()();

  TextColumn get type => text().withLength(max: 10)();

  /// Empty string for uncategorised, not NULL — NULL cannot participate in a
  /// composite primary key.
  TextColumn get categoryId => text()();

  /// Already converted to the user's base currency using each row's frozen rate.
  IntColumn get totalMilli => integer().withDefault(const Constant(0))();

  IntColumn get txnCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey =>
      <Column<Object>>{userId, ym, type, categoryId};
}

/// Incrementally maintained daily totals, for the cash-flow chart.
@DataClassName('DailyTotalRow')
class DailyTotals extends Table {
  TextColumn get userId => text()();

  /// `yyyyMMdd`.
  IntColumn get ymd => integer()();

  TextColumn get type => text().withLength(max: 10)();
  IntColumn get totalMilli => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{userId, ymd, type};
}

/// Live account balance, in the account's own currency.
///
/// Kept as a running total rather than a `SUM()` over transactions so the balance
/// header stays O(accounts) forever instead of degrading as history grows.
@DataClassName('AccountBalanceRow')
class AccountBalances extends Table {
  TextColumn get userId => text()();
  TextColumn get accountId => text()();
  IntColumn get balanceMilli => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{userId, accountId};
}

/// Small local key/value store: per-entity pull cursors, the seeded flag, the
/// last account used by the add flow. Not synced — all of it is device state.
@DataClassName('KvEntry')
class KvEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}
