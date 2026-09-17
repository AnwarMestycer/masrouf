import 'package:masrouf/core/error/auth_error_mapper.dart';
import 'package:masrouf/core/error/failure.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/mappers.dart';
import 'package:masrouf/data/remote/api/sync_api.dart';
import 'package:masrouf/data/remote/dto/remote_mappers.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';

/// Drains the outbox to Supabase.
///
/// Reads the *current* local row for each queued id rather than a stored payload:
/// that is what makes the queue self-coalescing, and it guarantees the server
/// receives the state the user can actually see on their screen.
class PushWorker {
  PushWorker({required this.db, required this.api});

  final AppDatabase db;
  final SyncApi api;

  /// Pushes one batch. Returns the number of records that reached the server.
  ///
  /// A transient failure (offline, rate limited) aborts the whole run — there is
  /// no point hammering a dead connection with the remaining entities. A
  /// permanent failure on one record is recorded against that record alone so a
  /// single bad row cannot block the rest of the queue.
  Future<PushOutcome> pushBatch(String userId) async {
    final due = await db.syncQueueDao.due();
    if (due.isEmpty) return const PushOutcome(pushed: 0, transientFailure: null);

    // Group by table so each table is one request, while preserving the
    // foreign-key ordering that lets a new account precede its transactions.
    final byEntity = <SyncEntity, List<SyncQueueEntry>>{};
    for (final entry in due) {
      byEntity
          .putIfAbsent(SyncEntity.fromTable(entry.entity), () => <SyncQueueEntry>[])
          .add(entry);
    }

    var pushed = 0;
    for (final entity in pushOrder) {
      final entries = byEntity[entity];
      if (entries == null || entries.isEmpty) continue;

      try {
        pushed += await _pushEntity(userId, entity, entries);
      } on Object catch (error, stackTrace) {
        final failure = mapDataError(error, stackTrace);
        if (failure.isTransient) {
          return PushOutcome(pushed: pushed, transientFailure: failure);
        }
        for (final entry in entries) {
          await db.syncQueueDao.markFailed(
            entity,
            entry.entityId,
            failure.toString(),
          );
        }
      }
    }

    return PushOutcome(pushed: pushed, transientFailure: null);
  }

  /// Push order, chosen so a row's foreign keys already exist on the server:
  /// accounts before the transactions that point at them, categories before the
  /// budgets and rules that reference them.
  ///
  /// Every [SyncEntity] must appear here. An entity left out is not a compile
  /// error — it is silently never pushed, and because its queue entries are then
  /// never marked synced *or* failed, they sit in the outbox forever. See the
  /// coverage test in `test/unit/sync_test.dart`.
  static const List<SyncEntity> pushOrder = <SyncEntity>[
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

  Future<int> _pushEntity(
    String userId,
    SyncEntity entity,
    List<SyncQueueEntry> entries,
  ) async {
    final deletions = entries.where((e) => SyncOp.fromWire(e.op) == SyncOp.delete);
    final upserts = entries.where((e) => SyncOp.fromWire(e.op) == SyncOp.upsert);

    var pushed = 0;

    for (final entry in deletions) {
      await api.markDeleted(entity, entry.entityId, DateTime.now());
      await db.syncQueueDao.markSynced(entity, entry.entityId);
      pushed++;
    }

    final ids = upserts.map((e) => e.entityId).toList(growable: false);
    if (ids.isEmpty) return pushed;

    final payload = await _payloadFor(userId, entity, ids);
    if (payload.isNotEmpty) {
      await api.upsertAll(entity, payload);
    }

    // Ids whose local row vanished (hard-deleted by a cache clear) are dropped
    // from the queue too — there is nothing left to send, and leaving them would
    // retry forever.
    await db.syncQueueDao.markAllSynced(entity, ids);
    return pushed + payload.length;
  }

  Future<List<Json>> _payloadFor(
    String userId,
    SyncEntity entity,
    List<String> ids,
  ) async {
    switch (entity) {
      case SyncEntity.accounts:
        final rows = await (db.select(db.accounts)..where((t) => t.id.isIn(ids)))
            .get();
        return rows
            .map((r) => accountToJson(userId, r.toEntity(), deletedAt: r.deletedAt))
            .toList(growable: false);

      case SyncEntity.categories:
        final rows =
            await (db.select(db.categories)..where((t) => t.id.isIn(ids))).get();
        return rows
            .map((r) => categoryToJson(userId, r.toEntity(), deletedAt: r.deletedAt))
            .toList(growable: false);

      case SyncEntity.transactions:
        final rows = await (db.select(db.transactions)
              ..where((t) => t.id.isIn(ids)))
            .get();
        return rows
            .map((r) => txnToJson(userId, r.toEntity(), deletedAt: r.deletedAt))
            .toList(growable: false);

      case SyncEntity.recurringRules:
        final rows = await (db.select(db.recurringRules)
              ..where((t) => t.id.isIn(ids)))
            .get();
        return rows
            .map(
              (r) => recurringToJson(userId, r.toEntity(), deletedAt: r.deletedAt),
            )
            .toList(growable: false);

      case SyncEntity.budgets:
        final rows =
            await (db.select(db.budgets)..where((t) => t.id.isIn(ids))).get();
        return rows
            .map(
              (r) => budgetToJson(
                userId,
                r.toEntity(Currency.fromCode(r.currency)),
                deletedAt: r.deletedAt,
              ),
            )
            .toList(growable: false);

      case SyncEntity.plannedExpenses:
        final rows = await (db.select(db.plannedExpenses)
              ..where((t) => t.id.isIn(ids)))
            .get();
        return rows
            .map(
              (r) => plannedToJson(
                userId,
                r.toEntity(Currency.fromCode(r.currency)),
                deletedAt: r.deletedAt,
              ),
            )
            .toList(growable: false);

      case SyncEntity.savingsGoals:
        final rows = await (db.select(db.savingsGoals)
              ..where((t) => t.id.isIn(ids)))
            .get();
        return rows
            .map(
              (r) => goalToJson(
                userId,
                r.toEntity(Currency.fromCode(r.currency)),
                deletedAt: r.deletedAt,
              ),
            )
            .toList(growable: false);

      case SyncEntity.exchangeRates:
        final rows = await (db.select(db.exchangeRates)
              ..where((t) => t.id.isIn(ids)))
            .get();
        return rows
            .map((r) => rateToJson(userId, r.toEntity()))
            .toList(growable: false);

      case SyncEntity.userSettings:
        final row = await (db.select(db.userSettingsRows)
              ..where((t) => t.id.isIn(ids)))
            .getSingleOrNull();
        if (row == null) return const <Json>[];
        return <Json>[settingsToJson(userId, row.toEntity())];
    }
  }
}

/// Result of one push run.
class PushOutcome {
  const PushOutcome({required this.pushed, required this.transientFailure});

  final int pushed;

  /// Non-null when the run stopped early because the network was unavailable.
  /// The engine uses this to stay quiet rather than showing an error the user
  /// cannot act on.
  final Failure? transientFailure;

  bool get isTransientlyBlocked => transientFailure != null;
}
