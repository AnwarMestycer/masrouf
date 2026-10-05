import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/repositories/category_repository_impl.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

import '../helpers/app_harness.dart';
import '../helpers/test_database.dart';

/// How a ledger ends up with both Groceries and Courses.
///
/// `seedDefaultsIfEmpty` judges emptiness from the local category count, so it
/// is only a safe question to ask once the first pull has landed. `start` used
/// to fire that pull with `unawaited` and return immediately, so the seeder
/// always won the race: it saw an empty table, minted a full starter set, and
/// the pull then delivered the account's real categories alongside the copies.
/// Nothing failed, and the duplicates synced to every other device.
void main() {
  late AppDatabase db;
  const userId = 'user-1';
  const base = Currency.tnd;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Category category(String id, String name) => Category(
        id: id,
        name: name,
        kind: CategoryKind.expense,
        icon: 'groceries',
        color: 0xFF2A78D6,
        sortOrder: 0,
        isDefault: true,
        updatedAt: DateTime(2026, 10, 1),
      );

  group('the signal sign-in depends on', () {
    /// The guard is only worth anything if "offline" and "server is empty" are
    /// distinguishable. With no connection the engine must report that it never
    /// found out, so sign-in defers rather than seeds.
    test('an offline start reports no completed sync', () async {
      final engine = testSyncEngine(db);
      addTearDown(engine.dispose);

      await engine.start(userId, base);

      expect(
        engine.hasCompletedSync,
        isFalse,
        reason: 'offline means "we never learned what the server has"',
      );
    });

    /// `start` must not return until its first sync has run. If it returns
    /// early the caller's next line — the seed decision — reads a local table
    /// the pull has not reached yet, which is the original bug.
    test('start does not return before its first sync has run', () async {
      final engine = testSyncEngine(db);
      addTearDown(engine.dispose);

      await engine.start(userId, base);

      expect(
        engine.currentStatus.state.name,
        'offline',
        reason: 'the first sync must have already run and reported, not be '
            'left in flight for the caller to race',
      );
    });

    test('stopping clears the signal, so the next user starts unknown', () async {
      final engine = testSyncEngine(db);
      addTearDown(engine.dispose);

      await engine.start(userId, base);
      await engine.stop();

      expect(engine.hasCompletedSync, isFalse);
    });
  });

  group('seeding', () {
    test('does nothing when the account already has categories', () async {
      await db.categoryDao.upsertAll(userId, <Category>[
        category('existing', 'Courses'),
      ]);

      final engine = testSyncEngine(db);
      addTearDown(engine.dispose);
      final repository = CategoryRepositoryImpl(
        db: db,
        sync: engine,
        userId: userId,
      );

      await repository.seedDefaultsIfEmpty(base);

      final categories = await db.categoryDao.liveCount(userId);
      expect(
        categories,
        1,
        reason: 'a pulled category set must never be topped up with a seed',
      );
    });

    /// The seed itself is unconditional once called — it is the *caller* that
    /// must not call it on an unknown state. This pins the cost of getting that
    /// wrong, so the guard in SessionLifecycle cannot be dropped silently.
    test('seeds a full starter set when the table looks empty', () async {
      final engine = testSyncEngine(db);
      addTearDown(engine.dispose);
      final repository = CategoryRepositoryImpl(
        db: db,
        sync: engine,
        userId: userId,
      );

      await repository.seedDefaultsIfEmpty(base);

      expect(await db.categoryDao.liveCount(userId), greaterThan(10));
    });
  });
}
