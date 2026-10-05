import 'package:drift/drift.dart';
import 'package:masrouf/core/config/app_config.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/row_writer.dart';
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
  ///
  /// Must list every entity that [PushWorker.pushOrder] does. Budgets, planned
  /// expenses and savings goals were pushed but missing here, so they reached the
  /// server and never came back: a reinstall silently lost every cap, plan and
  /// goal the user had set while their transactions returned intact.
  static const List<SyncEntity> order = <SyncEntity>[
    SyncEntity.userSettings,
    SyncEntity.accounts,
    SyncEntity.categories,
    SyncEntity.budgets,
    SyncEntity.plannedExpenses,
    SyncEntity.savingsGoals,
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

    await db.transaction(() => applyRemoteRows(db, userId, entity, accepted));

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
