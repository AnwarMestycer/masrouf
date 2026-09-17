import 'package:drift/drift.dart';
import 'package:masrouf/core/config/app_config.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/tables/local_tables.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';

part 'sync_queue_dao.g.dart';

@DriftAccessor(tables: <Type>[SyncQueueEntries])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  /// Marks a record as needing to reach the server.
  ///
  /// Overwrites any existing entry for the same record — that coalescing is the
  /// whole point of keying on `(entity, entityId)`. Attempt count and backoff
  /// reset, which is correct: the payload changed, so a previous failure says
  /// nothing about this one.
  Future<void> enqueue(SyncEntity entity, String id, SyncOp op) {
    final now = DateTime.now();
    return into(syncQueueEntries).insert(
      SyncQueueEntriesCompanion.insert(
        entity: entity.table,
        entityId: id,
        op: op.wire,
        enqueuedAt: now,
        nextAttemptAt: now,
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// Batched form, for a pull that has to re-enqueue nothing and a seed that has
  /// to enqueue a hundred rows at once.
  Future<void> enqueueAll(
    SyncEntity entity,
    Iterable<String> ids,
    SyncOp op,
  ) async {
    final now = DateTime.now();
    await batch((Batch b) {
      b.insertAllOnConflictUpdate(
        syncQueueEntries,
        ids
            .map(
              (id) => SyncQueueEntriesCompanion.insert(
                entity: entity.table,
                entityId: id,
                op: op.wire,
                enqueuedAt: now,
                nextAttemptAt: now,
              ),
            )
            .toList(growable: false),
      );
    });
  }

  /// The next batch that is actually due, oldest first.
  ///
  /// Ordering by `enqueuedAt` preserves causality across tables well enough for
  /// last-write-wins: an account is created before the transaction that points at
  /// it, so it pushes first and the foreign key resolves.
  Future<List<SyncQueueEntry>> due({
    int limit = AppConfig.syncPushBatchSize,
  }) {
    final now = DateTime.now();
    return (select(syncQueueEntries)
          ..where((t) => t.nextAttemptAt.isSmallerOrEqualValue(now))
          ..orderBy(<OrderClauseGenerator<$SyncQueueEntriesTable>>[
            (t) => OrderingTerm.asc(t.enqueuedAt),
          ])
          ..limit(limit))
        .get();
  }

  Future<void> markSynced(SyncEntity entity, String id) =>
      (delete(syncQueueEntries)
            ..where((t) => t.entity.equals(entity.table) & t.entityId.equals(id)))
          .go();

  Future<void> markAllSynced(SyncEntity entity, Iterable<String> ids) async {
    if (ids.isEmpty) return;
    await (delete(syncQueueEntries)
          ..where(
            (t) => t.entity.equals(entity.table) & t.entityId.isIn(ids),
          ))
        .go();
  }

  /// Records a failure and pushes the retry out exponentially.
  ///
  /// Once [AppConfig.syncMaxAttempts] is exhausted the entry stays in the queue
  /// rather than being dropped: the local row is still the user's data, and a
  /// silent discard would lose it. It simply stops being retried aggressively.
  Future<void> markFailed(
    SyncEntity entity,
    String id,
    String error,
  ) async {
    final existing = await (select(syncQueueEntries)
          ..where((t) => t.entity.equals(entity.table) & t.entityId.equals(id)))
        .getSingleOrNull();
    if (existing == null) return;

    final attempts = existing.attempts + 1;
    await (update(syncQueueEntries)
          ..where((t) => t.entity.equals(entity.table) & t.entityId.equals(id)))
        .write(
      SyncQueueEntriesCompanion(
        attempts: Value<int>(attempts),
        lastError: Value<String>(error),
        nextAttemptAt: Value<DateTime>(
          DateTime.now().add(_backoffFor(attempts)),
        ),
      ),
    );
  }

  /// Clears the backoff on every entry. Called the moment connectivity returns so
  /// a queue that backed off to five minutes while offline flushes immediately
  /// instead of making the user wait out a timer that was measuring the wrong
  /// thing.
  Future<void> resetBackoff() => update(syncQueueEntries).write(
        SyncQueueEntriesCompanion(nextAttemptAt: Value<DateTime>(DateTime.now())),
      );

  Stream<int> watchPendingCount() {
    final count = syncQueueEntries.entityId.count();
    return (selectOnly(syncQueueEntries)..addColumns(<Expression<Object>>[count]))
        .watchSingle()
        .map((row) => row.read(count) ?? 0);
  }

  Future<int> pendingCount() async {
    final count = syncQueueEntries.entityId.count();
    final row =
        await (selectOnly(syncQueueEntries)..addColumns(<Expression<Object>>[count]))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// Entries whose backoff has elapsed, i.e. work the next run could actually do.
  ///
  /// Distinct from [pendingCount], which counts everything still queued and is
  /// what the sync chip shows the user. Driving "should I run again?" off the
  /// total is what turned one unpushable row into an unbounded sync loop: the
  /// count stayed above zero forever, so every run immediately scheduled another.
  Future<int> dueCount() async {
    final now = DateTime.now();
    final count = syncQueueEntries.entityId.count();
    final row = await (selectOnly(syncQueueEntries)
          ..addColumns(<Expression<Object>>[count])
          ..where(syncQueueEntries.nextAttemptAt.isSmallerOrEqualValue(now)))
        .getSingle();
    return row.read(count) ?? 0;
  }

  static Duration _backoffFor(int attempts) {
    final capped = attempts.clamp(1, AppConfig.syncMaxAttempts);
    final millis = AppConfig.syncInitialBackoff.inMilliseconds * (1 << (capped - 1));
    return millis >= AppConfig.syncMaxBackoff.inMilliseconds
        ? AppConfig.syncMaxBackoff
        : Duration(milliseconds: millis);
  }
}
