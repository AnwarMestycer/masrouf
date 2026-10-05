import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/sync/pull_worker.dart';
import 'package:masrouf/data/sync/push_worker.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';

import '../helpers/test_database.dart';

/// The outbox is the only thing standing between an offline write and losing it.
/// Both failures covered here were silent: nothing crashed, nothing was logged,
/// and the only visible symptom was the app talking to the network forever while
/// the user did nothing.
void main() {
  /// `PushWorker._order` is a hand-maintained list, not a switch, so leaving an
  /// entity out is not a compile error. An omitted entity is never pushed — and
  /// because its entries are then never marked synced *or* failed, they sit in
  /// the outbox permanently. That is exactly what happened when `budgets` was
  /// added everywhere else and missed here.
  test('every synced entity has a place in the push order', () {
    expect(
      PushWorker.pushOrder.toSet(),
      SyncEntity.values.toSet(),
      reason: 'an entity missing from the push order is never pushed at all',
    );
    expect(
      PushWorker.pushOrder.length,
      SyncEntity.values.length,
      reason: 'no duplicates',
    );
  });

  /// The counterpart check, and the one that was missing. `budgets`,
  /// `planned_expenses` and `savings_goals` were in the push order but not the
  /// pull order, so they reached the server and never came back: a reinstall
  /// restored every transaction and silently lost every cap, plan and goal.
  /// Nothing failed — the rows simply were not asked for.
  test('every synced entity has a place in the pull order', () {
    expect(
      PullWorker.order.toSet(),
      SyncEntity.values.toSet(),
      reason: 'an entity missing from the pull order is never pulled back',
    );
    expect(PullWorker.order.length, SyncEntity.values.length, reason: 'no duplicates');
  });

  test('a row cannot be pulled before the row it points at', () {
    const order = PullWorker.order;
    expect(
      order.indexOf(SyncEntity.categories),
      lessThan(order.indexOf(SyncEntity.budgets)),
      reason: 'a budget carries a category_id foreign key',
    );
    expect(
      order.indexOf(SyncEntity.accounts),
      lessThan(order.indexOf(SyncEntity.transactions)),
    );
  });

  test('categories are pushed before the budgets that reference them', () {
    const order = PushWorker.pushOrder;
    expect(
      order.indexOf(SyncEntity.categories),
      lessThan(order.indexOf(SyncEntity.budgets)),
      reason: 'a budget carries a category_id foreign key',
    );
    expect(
      order.indexOf(SyncEntity.accounts),
      lessThan(order.indexOf(SyncEntity.transactions)),
    );
  });

  group('due vs pending', () {
    late AppDatabase db;

    setUp(() => db = openTestDatabase());
    tearDown(() => db.close());

    test('a freshly queued entry is both pending and due', () async {
      await db.syncQueueDao.enqueue(SyncEntity.budgets, 'b1', SyncOp.upsert);

      expect(await db.syncQueueDao.pendingCount(), 1);
      expect(await db.syncQueueDao.dueCount(), 1);
    });

    /// The distinction the sync loop depends on. A failed entry is still queued —
    /// the chip must keep saying "1 change waiting" — but it is not work the next
    /// run can do, and treating it as such is what span the network loop.
    test('a failed entry stays pending but stops being due', () async {
      await db.syncQueueDao.enqueue(SyncEntity.budgets, 'b1', SyncOp.upsert);
      await db.syncQueueDao.markFailed(SyncEntity.budgets, 'b1', 'no such table');

      expect(
        await db.syncQueueDao.pendingCount(),
        1,
        reason: 'the user must still be told the change has not landed',
      );
      expect(
        await db.syncQueueDao.dueCount(),
        0,
        reason: 'it is backing off, so there is nothing to retry yet',
      );
    });

    test('a synced entry leaves the queue entirely', () async {
      await db.syncQueueDao.enqueue(SyncEntity.budgets, 'b1', SyncOp.upsert);
      await db.syncQueueDao.markSynced(SyncEntity.budgets, 'b1');

      expect(await db.syncQueueDao.pendingCount(), 0);
      expect(await db.syncQueueDao.dueCount(), 0);
    });

    test('resetting backoff makes a failed entry due again', () async {
      await db.syncQueueDao.enqueue(SyncEntity.budgets, 'b1', SyncOp.upsert);
      await db.syncQueueDao.markFailed(SyncEntity.budgets, 'b1', 'offline');
      expect(await db.syncQueueDao.dueCount(), 0);

      // What reconnecting does.
      await db.syncQueueDao.resetBackoff();

      expect(await db.syncQueueDao.dueCount(), 1);
    });
  });
}
