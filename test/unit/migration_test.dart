import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/domain/entities/budget.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../helpers/test_database.dart';

/// The first schema change this app has had.
///
/// A migration is the one piece of code that runs exactly once per device and
/// cannot be retried if it corrupts something: local rows are the user's only
/// copy of anything written offline. So the invariant under test is not "the new
/// table exists" but "the old rows are still there afterwards".
///
/// The v1 schema is written out by hand rather than generated, because the point
/// is to migrate from what shipped, not from whatever the current generator
/// produces.
void main() {
  late sqlite.Database raw;

  /// The subset of schema v1 these tests need: one row per table that the
  /// migration must not disturb.
  void createV1() {
    raw.execute('''
      CREATE TABLE accounts (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        currency TEXT NOT NULL,
        opening_balance_milli INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      );
    ''');
    raw.execute('''
      CREATE TABLE categories (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL,
        name TEXT NOT NULL,
        kind TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_default INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      );
    ''');
    raw.execute('PRAGMA user_version = 1');
  }

  setUp(() {
    useHostSqlite();
    raw = sqlite.sqlite3.openInMemory();
  });

  tearDown(() => raw.dispose());

  /// Opens the app database on [raw], which runs the migration.
  ///
  /// `closeUnderlyingOnClose: false` so closing the drift wrapper leaves the
  /// sqlite handle alive — the reopen test needs the same database twice, which
  /// is exactly what a real second app launch does.
  Future<AppDatabase> openMigrated() async {
    final db = AppDatabase.forTesting(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    // Any query forces `beforeOpen`/`onUpgrade` to run.
    await db.customSelect('SELECT 1').get();
    return db;
  }

  test('upgrading from v1 creates budgets and keeps existing rows', () async {
    createV1();
    raw.execute('''
      INSERT INTO accounts (id, user_id, updated_at, name, type, currency,
                            opening_balance_milli, created_at)
      VALUES ('acc-1', 'u1', 1, 'Cash', 'cash', 'TND', 55000, 1)
    ''');
    raw.execute('''
      INSERT INTO categories (id, user_id, updated_at, name, kind, icon,
                              color, created_at)
      VALUES ('cat-1', 'u1', 1, 'Groceries', 'expense', 'groceries', 1, 1)
    ''');

    final db = await openMigrated();
    addTearDown(db.close);

    expect(db.schemaVersion, 4);
    expect(
      raw.select('PRAGMA user_version').single['user_version'],
      4,
      reason: 'the migration must record that it ran',
    );

    // The user's rows survived untouched — the only thing that must never break.
    final accounts = await db.select(db.accounts).get();
    expect(accounts.single.name, 'Cash');
    expect(accounts.single.openingBalanceMilli, 55000);
    final categories = await db.select(db.categories).get();
    expect(categories.single.name, 'Groceries');

    // And both new tables are usable. v1 predates each of them, so this run
    // exercises every upgrade step in sequence rather than only the last.
    expect(await db.select(db.budgets).get(), isEmpty);
    expect(await db.select(db.plannedExpenses).get(), isEmpty);
    expect(await db.select(db.savingsGoals).get(), isEmpty);
    await db.budgetDao.upsert(
      'u1',
      Budget(
        id: 'b1',
        categoryId: 'cat-1',
        amount: const Money(200000, Currency.tnd),
        updatedAt: DateTime(2026, 8, 1),
      ),
    );
    expect(await db.budgetDao.watchAll('u1', Currency.tnd).first, hasLength(1));
  });

  test('a fresh install lands on the current schema without migrating',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();

    // onCreate builds everything, including budgets.
    expect(await db.select(db.budgets).get(), isEmpty);
    expect(await db.select(db.plannedExpenses).get(), isEmpty);
    expect(await db.select(db.savingsGoals).get(), isEmpty);
    expect(db.schemaVersion, 4);
  });

  test('reopening an already-migrated database changes nothing', () async {
    createV1();
    final first = await openMigrated();
    await first.budgetDao.upsert(
      'u1',
      Budget(
        id: 'b1',
        categoryId: 'cat-1',
        amount: const Money(200000, Currency.tnd),
        updatedAt: DateTime(2026, 8, 1),
      ),
    );
    await first.close();

    // Same file, opened again: onUpgrade must not run and must not wipe.
    final second = AppDatabase.forTesting(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    addTearDown(second.close);
    expect(
      await second.budgetDao.watchAll('u1', Currency.tnd).first,
      hasLength(1),
    );
  });

  test('upgrading from v2 adds the later tables and keeps budgets', () async {
    createV1();
    // A device that already took the budgets migration.
    raw.execute('''
      CREATE TABLE budgets (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL,
        category_id TEXT NOT NULL,
        amount_milli INTEGER NOT NULL,
        currency TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
    ''');
    raw.execute('''
      INSERT INTO budgets (id, user_id, updated_at, category_id,
                           amount_milli, currency, created_at)
      VALUES ('b1', 'u1', 1, 'cat-1', 200000, 'TND', 1)
    ''');
    raw.execute('PRAGMA user_version = 2');

    final db = await openMigrated();
    addTearDown(db.close);

    expect(raw.select('PRAGMA user_version').single['user_version'], 4);
    expect(
      (await db.select(db.budgets).get()).single.amountMilli,
      200000,
      reason: 'the v2 step must not re-run and must not disturb its own table',
    );
    expect(await db.select(db.plannedExpenses).get(), isEmpty);
    expect(await db.select(db.savingsGoals).get(), isEmpty);
  });
}
