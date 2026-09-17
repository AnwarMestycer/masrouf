import 'package:drift/drift.dart';
import 'package:masrouf/core/config/app_config.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/mappers.dart';
import 'package:masrouf/data/remote/api/sync_api.dart';
import 'package:masrouf/data/remote/dto/remote_mappers.dart';
import 'package:masrouf/data/sync/conflict_resolver.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';

/// Pulls server changes into the local database.
///
/// Delta-based: each table keeps its own `updated_at` cursor in the KV store, so
/// a routine sync transfers only what changed rather than the whole ledger. The
/// cursor advances only after a page has been committed locally, so a crash
/// mid-pull re-fetches that page instead of skipping it.
class PullWorker {
  PullWorker({required this.db, required this.api});

  final AppDatabase db;
  final SyncApi api;

  /// Tables in foreign-key order.
  ///
  /// Accounts and categories must land before the transactions that reference
  /// them, or the insert violates the FK that `PRAGMA foreign_keys = ON` enforces.
  static const List<SyncEntity> order = <SyncEntity>[
    SyncEntity.userSettings,
    SyncEntity.accounts,
    SyncEntity.categories,
    SyncEntity.recurringRules,
    SyncEntity.transactions,
    SyncEntity.exchangeRates,
  ];

  /// Returns the number of rows applied.
  Future<int> pullAll(String userId, Currency base) async {
    var applied = 0;
    var ledgerTouched = false;

    for (final entity in order) {
      final count = await _pullEntity(userId, entity);
      applied += count;
      if (count > 0 &&
          (entity == SyncEntity.transactions || entity == SyncEntity.accounts)) {
        ledgerTouched = true;
      }
    }

    if (ledgerTouched) {
      // A pull can rewrite arbitrary history — including rows from months ago —
      // so the derived tables are recomputed rather than nudged. Incremental
      // reversal would need the previous version of every changed row, which the
      // device no longer has.
      await db.transactionDao.rebuildAggregates(userId, base);
    }
    return applied;
  }

  Future<int> _pullEntity(String userId, SyncEntity entity) async {
    final cursorKey = KvDaoKeys.pullCursor(entity);
    var since = await db.kvDao.getTimestamp(cursorKey);
    var applied = 0;

    while (true) {
      final rows = await api.pullSince(entity, since);
      if (rows.isEmpty) break;

      applied += await _apply(userId, entity, rows);

      // Advance past the newest row in this page. Using the row timestamp rather
      // than the device clock keeps the cursor on the server's timeline.
      since = rows.map(rowUpdatedAt).reduce((a, b) => a.isAfter(b) ? a : b);
      await db.kvDao.putTimestamp(cursorKey, since);

      if (rows.length < AppConfig.syncPullPageSize) break;
    }
    return applied;
  }

  Future<int> _apply(String userId, SyncEntity entity, List<Json> rows) async {
    final ids =
        rows.map((row) => rowKeyFor(entity, row)).toList(growable: false);
    final pending = await _pendingIds(entity, ids);
    final localVersions = await _localUpdatedAt(entity, ids);

    final accepted = rows.where((row) {
      final id = rowKeyFor(entity, row);
      return ConflictResolver.shouldApply(
        serverRow: row,
        localUpdatedAt: localVersions[id],
        localHasPendingChange: pending.contains(id),
      );
    }).toList(growable: false);

    if (accepted.isEmpty) return 0;

    await db.transaction(() async {
      switch (entity) {
        case SyncEntity.accounts:
          await db.batch((Batch b) {
            b.insertAllOnConflictUpdate(
              db.accounts,
              accepted.map((row) {
                final account = accountFromJson(row);
                return AccountsCompanion.insert(
                  id: account.id,
                  userId: userId,
                  name: account.name,
                  type: account.type.wire,
                  currency: account.currency.code,
                  openingBalanceMilli:
                      Value<int>(account.openingBalance.milli),
                  sortOrder: Value<int>(account.sortOrder),
                  archived: Value<bool>(account.archived),
                  createdAt: DateTime.now(),
                  updatedAt: account.updatedAt,
                  deletedAt: Value<DateTime?>(tombstoneOf(row)),
                );
              }).toList(growable: false),
            );
          });

        case SyncEntity.categories:
          await db.batch((Batch b) {
            b.insertAllOnConflictUpdate(
              db.categories,
              accepted.map((row) {
                final category = categoryFromJson(row);
                return CategoriesCompanion.insert(
                  id: category.id,
                  userId: userId,
                  name: category.name,
                  kind: category.kind.wire,
                  icon: category.icon,
                  color: category.color,
                  sortOrder: Value<int>(category.sortOrder),
                  isDefault: Value<bool>(category.isDefault),
                  createdAt: DateTime.now(),
                  updatedAt: category.updatedAt,
                  deletedAt: Value<DateTime?>(tombstoneOf(row)),
                );
              }).toList(growable: false),
            );
          });

        case SyncEntity.transactions:
          await db.batch((Batch b) {
            b.insertAllOnConflictUpdate(
              db.transactions,
              accepted.map((row) {
                final txn = txnFromJson(row);
                return TransactionsCompanion.insert(
                  id: txn.id,
                  userId: userId,
                  type: txn.type.wire,
                  amountMilli: txn.amount.milli,
                  currency: txn.amount.currency.code,
                  fxRateToBase: Value<double>(txn.fxRateToBase),
                  categoryId: Value<String?>(txn.categoryId),
                  accountId: txn.accountId,
                  transferAccountId: Value<String?>(txn.transferAccountId),
                  dateYmd: txn.date.ymd,
                  note: Value<String?>(txn.note),
                  tags: txn.tags,
                  recurringRuleId: Value<String?>(txn.recurringRuleId),
                  createdAt: txn.createdAt,
                  updatedAt: txn.updatedAt,
                  deletedAt: Value<DateTime?>(tombstoneOf(row)),
                );
              }).toList(growable: false),
            );
          });

        case SyncEntity.recurringRules:
          await db.batch((Batch b) {
            b.insertAllOnConflictUpdate(
              db.recurringRules,
              accepted.map((row) {
                final rule = recurringFromJson(row);
                return RecurringRulesCompanion.insert(
                  id: rule.id,
                  userId: userId,
                  type: rule.type.wire,
                  amountMilli: rule.amount.milli,
                  currency: rule.amount.currency.code,
                  categoryId: Value<String?>(rule.categoryId),
                  accountId: rule.accountId,
                  transferAccountId: Value<String?>(rule.transferAccountId),
                  note: Value<String?>(rule.note),
                  cadence: rule.cadence.wire,
                  dayOfMonth: Value<int?>(rule.dayOfMonth),
                  dayOfWeek: Value<int?>(rule.dayOfWeek),
                  nextRunYmd: rule.nextRunDate.ymd,
                  lastRunYmd: Value<int?>(rule.lastRunDate?.ymd),
                  active: Value<bool>(rule.active),
                  createdAt: DateTime.now(),
                  updatedAt: rule.updatedAt,
                  deletedAt: Value<DateTime?>(tombstoneOf(row)),
                );
              }).toList(growable: false),
            );
          });

        case SyncEntity.budgets:
          await db.batch((Batch b) {
            b.insertAllOnConflictUpdate(
              db.budgets,
              accepted.map((row) {
                final budget = budgetFromJson(row);
                return BudgetsCompanion.insert(
                  id: budget.id,
                  userId: userId,
                  categoryId: budget.categoryId,
                  amountMilli: budget.amount.milli,
                  currency: budget.amount.currency.code,
                  createdAt: DateTime.now(),
                  updatedAt: budget.updatedAt,
                  deletedAt: Value<DateTime?>(tombstoneOf(row)),
                );
              }).toList(growable: false),
            );
          });

        case SyncEntity.plannedExpenses:
          await db.batch((Batch b) {
            b.insertAllOnConflictUpdate(
              db.plannedExpenses,
              accepted.map((row) {
                final plan = plannedFromJson(row);
                return PlannedExpensesCompanion.insert(
                  id: plan.id,
                  userId: userId,
                  categoryId: Value<String?>(plan.categoryId),
                  accountId: Value<String?>(plan.accountId),
                  amountMilli: plan.amount.milli,
                  currency: plan.amount.currency.code,
                  dueAt: plan.dueAt,
                  note: Value<String?>(plan.note),
                  status: plan.status.wire,
                  transactionId: Value<String?>(plan.transactionId),
                  createdAt: DateTime.now(),
                  updatedAt: plan.updatedAt,
                  deletedAt: Value<DateTime?>(tombstoneOf(row)),
                );
              }).toList(growable: false),
            );
          });

        case SyncEntity.savingsGoals:
          await db.batch((Batch b) {
            b.insertAllOnConflictUpdate(
              db.savingsGoals,
              accepted.map((row) {
                final goal = goalFromJson(row);
                return SavingsGoalsCompanion.insert(
                  id: goal.id,
                  userId: userId,
                  name: goal.name,
                  targetMilli: goal.target.milli,
                  currency: goal.target.currency.code,
                  accountId: goal.accountId,
                  targetDate: Value<DateTime?>(goal.targetDate),
                  createdAt: DateTime.now(),
                  updatedAt: goal.updatedAt,
                  deletedAt: Value<DateTime?>(tombstoneOf(row)),
                );
              }).toList(growable: false),
            );
          });

        case SyncEntity.exchangeRates:
          await db.batch((Batch b) {
            b.insertAllOnConflictUpdate(
              db.exchangeRates,
              accepted.map((row) {
                final rate = rateFromJson(row);
                return ExchangeRatesCompanion.insert(
                  // Rates are keyed by currency on the server; the local table
                  // needs a surrogate id, and the code is a natural stable one.
                  id: rate.currency.code,
                  userId: userId,
                  currency: rate.currency.code,
                  rateToBase: rate.rateToBase,
                  updatedAt: rate.updatedAt,
                );
              }).toList(growable: false),
            );
          });

        case SyncEntity.userSettings:
          await db.batch((Batch b) {
            b.insertAllOnConflictUpdate(
              db.userSettingsRows,
              accepted.map((row) {
                final settings = settingsFromJson(row);
                return UserSettingsRowsCompanion.insert(
                  id: userId,
                  userId: userId,
                  baseCurrency: settings.baseCurrency.code,
                  locale: settings.locale,
                  themeMode: themeModeToWire(settings.themeMode),
                  paydayDayOfMonth: settings.paydayDayOfMonth,
                  updatedAt: rowUpdatedAt(row),
                );
              }).toList(growable: false),
            );
          });
      }
    });

    return accepted.length;
  }

  Future<Set<String>> _pendingIds(SyncEntity entity, List<String> ids) async {
    final rows = await (db.select(db.syncQueueEntries)
          ..where(
            (t) => t.entity.equals(entity.table) & t.entityId.isIn(ids),
          ))
        .get();
    return rows.map((r) => r.entityId).toSet();
  }

  /// Local `updated_at` for the ids in this page, so the resolver can compare.
  Future<Map<String, DateTime>> _localUpdatedAt(
    SyncEntity entity,
    List<String> ids,
  ) async {
    final table = switch (entity) {
      SyncEntity.accounts => db.accounts.actualTableName,
      SyncEntity.categories => db.categories.actualTableName,
      SyncEntity.transactions => db.transactions.actualTableName,
      SyncEntity.recurringRules => db.recurringRules.actualTableName,
      SyncEntity.budgets => db.budgets.actualTableName,
      SyncEntity.plannedExpenses => db.plannedExpenses.actualTableName,
      SyncEntity.savingsGoals => db.savingsGoals.actualTableName,
      SyncEntity.exchangeRates => db.exchangeRates.actualTableName,
      SyncEntity.userSettings => db.userSettingsRows.actualTableName,
    };

    final placeholders = List<String>.filled(ids.length, '?').join(',');
    final rows = await db
        .customSelect(
          'SELECT id, updated_at FROM $table WHERE id IN ($placeholders)',
          variables: ids.map<Variable<Object>>(Variable<String>.new).toList(),
        )
        .get();

    return <String, DateTime>{
      for (final row in rows)
        row.read<String>('id'): row.read<DateTime>('updated_at'),
    };
  }
}

/// Cursor keys, kept beside the worker that owns them.
abstract final class KvDaoKeys {
  static String pullCursor(SyncEntity entity) => 'pull_cursor.${entity.table}';
}
