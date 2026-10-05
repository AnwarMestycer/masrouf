import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/time/ym.dart';
import 'package:masrouf/data/backup/backup_service.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/daos/kv_dao.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/budget.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/entities/planned_expense.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

import '../helpers/test_database.dart';

/// A backup is only worth having if restoring it gives back exactly what was
/// there. The round-trip below is the test that matters: anything the writer
/// drops or the reader mis-parses shows up as a row that does not come back.
void main() {
  late AppDatabase db;
  late Directory root;
  late BackupService service;

  const userId = 'user-1';
  const base = Currency.tnd;

  /// Encodes on this isolate. `compute` would need a real Flutter binding and
  /// spawn an isolate per call, which a unit test neither has nor wants.
  Future<String> encodeHere(Object payload) async => jsonEncode(payload);

  Txn expense(String id, int milli, {DateTime? date}) => Txn(
        id: id,
        type: TxnType.expense,
        amount: Money(milli, base),
        fxRateToBase: 1,
        categoryId: 'cat-groceries',
        accountId: 'acc-cash',
        transferAccountId: null,
        date: date ?? DateTime(2026, 10, 2),
        note: 'bread',
        tags: const <String>['weekly'],
        recurringRuleId: null,
        createdAt: DateTime(2026, 10, 2),
        updatedAt: DateTime(2026, 10, 2),
      );

  setUp(() async {
    db = openTestDatabase();
    root = await Directory.systemTemp.createTemp('masrouf-backup-test');
    service = BackupService(
      db: db,
      userId: userId,
      base: base,
      root: root,
      encode: encodeHere,
    );

    await db.accountDao.upsert(
      userId,
      Account(
        id: 'acc-cash',
        name: 'Cash',
        type: AccountType.cash,
        currency: base,
        openingBalance: const Money(100000, base),
        sortOrder: 0,
        archived: false,
        updatedAt: DateTime(2026, 10, 1),
      ),
    );
    await db.categoryDao.upsertAll(userId, <Category>[
      Category(
        id: 'cat-groceries',
        name: 'Groceries',
        kind: CategoryKind.expense,
        icon: 'groceries',
        color: 0xFF2A78D6,
        sortOrder: 0,
        isDefault: true,
        updatedAt: DateTime(2026, 10, 1),
      ),
    ]);
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('an empty ledger writes no file', () async {
    final empty = openTestDatabase();
    final emptyService = BackupService(
      db: empty,
      userId: userId,
      base: base,
      root: root,
      encode: encodeHere,
    );

    expect(await emptyService.create(), isNull);
    expect(await emptyService.list(), isEmpty);
    await empty.close();
  });

  test('a backup round-trips the ledger exactly', () async {
    await db.transactionDao.insertTxn(userId, expense('t1', 12500), base);
    await db.transactionDao.insertTxn(userId, expense('t2', 7000), base);
    await db.budgetDao.upsert(
      userId,
      Budget(
        id: 'b1',
        categoryId: 'cat-groceries',
        amount: const Money(200000, base),
        updatedAt: DateTime(2026, 10, 1),
      ),
    );
    await db.plannedDao.upsert(
      userId,
      PlannedExpense(
        id: 'p1',
        categoryId: 'cat-groceries',
        accountId: 'acc-cash',
        amount: const Money(45000, base),
        dueAt: DateTime(2026, 10, 20, 9),
        note: 'rent',
        status: PlannedStatus.pending,
        transactionId: null,
        updatedAt: DateTime(2026, 10, 1),
      ),
    );

    final file = await service.create();
    expect(file, isNotNull);

    // Wipe everything the backup covers, exactly as a reinstall would.
    await db.clearSyncedData();
    expect(await db.select(db.transactions).get(), isEmpty);

    final restored = await service.restore(file!);
    expect(restored, greaterThan(0));

    final txns = await db.select(db.transactions).get();
    expect(txns.map((t) => t.id).toSet(), <String>{'t1', 't2'});

    final t1 = txns.firstWhere((t) => t.id == 't1');
    expect(t1.amountMilli, 12500, reason: 'amounts must survive as thousandths');
    expect(t1.note, 'bread');
    expect(t1.tags, <String>['weekly']);
    expect(t1.currency, base.code);

    expect(await db.select(db.budgets).get(), hasLength(1));
    expect(await db.select(db.plannedExpenses).get(), hasLength(1));
    expect(await db.select(db.accounts).get(), hasLength(1));
    expect(await db.select(db.categories).get(), hasLength(1));
  });

  /// Dropping tombstones would make a restore resurrect everything the user had
  /// deleted — the same failure a hard delete causes in sync.
  test('deleted rows survive as tombstones', () async {
    await db.transactionDao.insertTxn(userId, expense('t1', 12500), base);
    final row = await db.transactionDao.getById('t1');
    await db.transactionDao.softDeleteTxn(userId, row!, base);

    final file = await service.create();
    await db.clearSyncedData();
    await service.restore(file!);

    final restored =
        await (db.select(db.transactions)..where((t) => t.id.equals('t1')))
            .getSingle();
    expect(restored.deletedAt, isNotNull);
  });

  /// Restore-as-truth: the file is now the user's intent, so every row has to
  /// reach the server rather than be overwritten by the next pull.
  test('restore enqueues every row and clears the pull cursors', () async {
    await db.transactionDao.insertTxn(userId, expense('t1', 12500), base);

    final file = await service.create();
    await db.kvDao.putTimestamp(
      'pull_cursor.${SyncEntity.transactions.table}',
      DateTime(2026, 10, 3),
    );
    await db.clearSyncedData();

    await service.restore(file!);

    final queued = await db.select(db.syncQueueEntries).get();
    expect(
      queued.where((q) => q.entity == SyncEntity.transactions.table).length,
      1,
    );
    expect(
      queued.every((q) => q.op == SyncOp.upsert.wire),
      isTrue,
      reason: 'a restore is an upsert of the file, never a delete',
    );
    expect(
      await db.kvDao.getTimestamp('pull_cursor.${SyncEntity.transactions.table}'),
      isNull,
      reason: 'a stale cursor would skip the rows the restore just replaced',
    );
  });

  test('restore rebuilds the aggregates the dashboard reads', () async {
    await db.transactionDao.insertTxn(userId, expense('t1', 12500), base);
    await db.transactionDao.insertTxn(userId, expense('t2', 7000), base);

    final file = await service.create();
    await db.clearSyncedData();
    await service.restore(file!);

    final totals = await db.select(db.monthlyCategoryTotals).get();
    final october = totals.where(
      (t) => t.ym == const Ym.of(2026, 10).value && t.type == TxnType.expense.wire,
    );
    expect(october, hasLength(1));
    expect(
      october.single.totalMilli,
      19500,
      reason: 'aggregates are derived state and must be recomputed on restore',
    );
  });

  group('retention', () {
    test('only the newest four backups are kept', () async {
      await db.transactionDao.insertTxn(userId, expense('t1', 12500), base);

      for (var i = 0; i < 6; i++) {
        // The filename carries a whole-second timestamp, so a loop without a
        // gap would overwrite one file rather than create six.
        await service.create();
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      }

      expect(await service.list(), hasLength(BackupService.keepCount));
    });
  });

  group('rejecting what is not a backup', () {
    test('a file that is not JSON is rejected', () async {
      final bad = File('${root.path}/not-a-backup.json');
      await bad.writeAsString('this is not json');

      expect(() => service.restore(bad), throwsA(isA<FormatException>()));
    });

    test('a newer format version is rejected rather than half-read', () async {
      final future = File('${root.path}/future.json');
      await future.writeAsString(
        jsonEncode(<String, dynamic>{
          'version': BackupService.formatVersion + 1,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'tables': <String, dynamic>{},
        }),
      );

      expect(() => service.restore(future), throwsA(isA<FormatException>()));
    });

    test('JSON that is not a backup is rejected', () async {
      final list = File('${root.path}/list.json');
      await list.writeAsString(jsonEncode(<int>[1, 2, 3]));

      expect(() => service.restore(list), throwsA(isA<FormatException>()));
    });
  });

  group('automatic backup', () {
    test('does nothing while the switch is off', () async {
      await db.transactionDao.insertTxn(userId, expense('t1', 12500), base);

      expect(await service.maybeAutoBackup(), isNull);
      expect(await service.list(), isEmpty);
    });

    test('runs when enabled and no backup has ever been taken', () async {
      await db.kvDao.setFlag(KvDao.autoBackup, value: true);
      await db.transactionDao.insertTxn(userId, expense('t1', 12500), base);

      expect(await service.maybeAutoBackup(), isNotNull);
    });

    test('does not run again within the interval', () async {
      await db.kvDao.setFlag(KvDao.autoBackup, value: true);
      await db.transactionDao.insertTxn(userId, expense('t1', 12500), base);

      expect(await service.maybeAutoBackup(), isNotNull);
      expect(
        await service.maybeAutoBackup(),
        isNull,
        reason: 'a second launch the same day must not write another file',
      );
    });

    test('runs again once the interval has elapsed', () async {
      await db.kvDao.setFlag(KvDao.autoBackup, value: true);
      await db.transactionDao.insertTxn(userId, expense('t1', 12500), base);

      await db.kvDao.putTimestamp(
        KvDao.lastBackupAt,
        DateTime.now().toUtc().subtract(
              BackupService.autoInterval + const Duration(hours: 1),
            ),
      );

      expect(await service.maybeAutoBackup(), isNotNull);
    });
  });
}
