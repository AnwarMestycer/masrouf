import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/time/ym.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/budget.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

import '../helpers/test_database.dart';

/// Budgets read their spend from `monthly_category_totals`, the same maintained
/// aggregate the dashboard uses. That is the whole reason the feature is cheap —
/// and the reason these tests check progress against writes rather than against
/// a hand-built number: if the aggregates and the caps ever disagree, the user
/// sees a cap that is quietly wrong.
void main() {
  late AppDatabase db;
  const userId = 'user-1';
  const base = Currency.tnd;
  final ym = Ym.fromDate(DateTime(2026, 8, 15));

  Txn expense(String id, int milli, {String categoryId = 'cat-groceries'}) =>
      Txn(
        id: id,
        type: TxnType.expense,
        amount: Money(milli, base),
        fxRateToBase: 1,
        categoryId: categoryId,
        accountId: 'acc-cash',
        transferAccountId: null,
        date: DateTime(2026, 8, 15),
        note: null,
        tags: const <String>[],
        recurringRuleId: null,
        createdAt: DateTime(2026, 8, 15),
        updatedAt: DateTime(2026, 8, 15),
      );

  Budget budget(String id, String categoryId, int milli) => Budget(
        id: id,
        categoryId: categoryId,
        amount: Money(milli, base),
        updatedAt: DateTime(2026, 8, 1),
      );

  Future<List<BudgetProgress>> progress() =>
      db.budgetDao.watchProgress(userId, ym, base).first;

  setUp(() async {
    db = openTestDatabase();

    await db.accountDao.upsert(
      userId,
      Account(
        id: 'acc-cash',
        name: 'Cash',
        type: AccountType.cash,
        currency: base,
        openingBalance: const Money(1000000, base),
        sortOrder: 0,
        archived: false,
        updatedAt: DateTime.now(),
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
        updatedAt: DateTime.now(),
      ),
      Category(
        id: 'cat-transport',
        name: 'Transport',
        kind: CategoryKind.expense,
        icon: 'transport',
        color: 0xFF1BAF7A,
        sortOrder: 1,
        isDefault: true,
        updatedAt: DateTime.now(),
      ),
    ]);
  });

  tearDown(() => db.close());

  test('a budget with no spending reports the full cap as remaining', () async {
    await db.budgetDao.upsert(userId, budget('b1', 'cat-groceries', 300000));

    final entry = (await progress()).single;
    expect(entry.spent.milli, 0);
    expect(entry.remaining.milli, 300000);
    expect(entry.isOver, isFalse);
    expect(entry.ratio, 0);
  });

  test('spending is counted against the cap', () async {
    await db.budgetDao.upsert(userId, budget('b1', 'cat-groceries', 300000));
    await db.transactionDao.insertTxn(userId, expense('t1', 120000), base);

    final entry = (await progress()).single;
    expect(entry.spent.milli, 120000);
    expect(entry.remaining.milli, 180000);
    expect(entry.ratio, closeTo(0.4, 0.001));
    expect(entry.isNearLimit, isFalse);
  });

  test('overspend is reported as an amount, not a negative remainder',
      () async {
    await db.budgetDao.upsert(userId, budget('b1', 'cat-groceries', 100000));
    await db.transactionDao.insertTxn(userId, expense('t1', 140000), base);

    final entry = (await progress()).single;
    expect(entry.isOver, isTrue);
    expect(entry.overspend.milli, 40000);
    expect(entry.remaining.milli, 0, reason: 'remaining floors at zero');
    expect(entry.ratio, closeTo(1.4, 0.001));
  });

  test('the near-limit warning starts at four fifths of the cap', () async {
    await db.budgetDao.upsert(userId, budget('b1', 'cat-groceries', 100000));
    await db.transactionDao.insertTxn(userId, expense('t1', 79000), base);
    expect((await progress()).single.isNearLimit, isFalse);

    await db.transactionDao.insertTxn(userId, expense('t2', 2000), base);
    final entry = (await progress()).single;
    expect(entry.ratio, closeTo(0.81, 0.001));
    expect(entry.isNearLimit, isTrue);
    expect(entry.isOver, isFalse);
  });

  test('only the selected month counts against the cap', () async {
    await db.budgetDao.upsert(userId, budget('b1', 'cat-groceries', 300000));
    await db.transactionDao.insertTxn(userId, expense('t1', 50000), base);

    // Same category, previous month.
    await db.transactionDao.insertTxn(
      userId,
      expense('t2', 90000).copyWith(date: DateTime(2026, 7, 15)),
      base,
    );

    expect((await progress()).single.spent.milli, 50000);
  });

  test('income never counts against a spending cap', () async {
    await db.budgetDao.upsert(userId, budget('b1', 'cat-groceries', 300000));
    await db.transactionDao.insertTxn(
      userId,
      expense('t1', 200000).copyWith(type: TxnType.income),
      base,
    );

    expect((await progress()).single.spent.milli, 0);
  });

  test('budgets are ordered worst first', () async {
    await db.budgetDao.upsert(userId, budget('b1', 'cat-groceries', 100000));
    await db.budgetDao.upsert(userId, budget('b2', 'cat-transport', 100000));
    await db.transactionDao.insertTxn(userId, expense('t1', 20000), base);
    await db.transactionDao.insertTxn(
      userId,
      expense('t2', 90000, categoryId: 'cat-transport'),
      base,
    );

    final all = await progress();
    expect(all.map((p) => p.category?.name), <String>['Transport', 'Groceries']);
  });

  test('a soft-deleted budget disappears', () async {
    await db.budgetDao.upsert(userId, budget('b1', 'cat-groceries', 300000));
    expect(await progress(), hasLength(1));

    await db.budgetDao.softDelete('b1');
    expect(await progress(), isEmpty);
  });

  /// The whole point of reading the maintained aggregate: a write anywhere in
  /// the ledger has to reach the budget without anything re-querying by hand.
  test('progress re-emits after a transaction is written', () async {
    await db.budgetDao.upsert(userId, budget('b1', 'cat-groceries', 300000));

    final spent = db.budgetDao
        .watchProgress(userId, ym, base)
        .map((list) => list.single.spent.milli);

    expect(spent, emitsInOrder(<int>[0, 45000, 0]));

    await pumpEventQueue();
    final txn = expense('t1', 45000);
    await db.transactionDao.insertTxn(userId, txn, base);
    await pumpEventQueue();
    await db.transactionDao.softDeleteTxn(userId, txn, base);
    await pumpEventQueue();
  });

  test('a budget whose category was deleted still lists, without a name',
      () async {
    await db.budgetDao.upsert(userId, budget('b1', 'cat-groceries', 300000));
    await db.categoryDao.softDelete('cat-groceries');

    final entry = (await progress()).single;
    expect(entry.category, isNull);
    expect(entry.cap.milli, 300000);
  });
}
