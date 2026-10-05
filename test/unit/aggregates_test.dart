import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/time/ym.dart';
import 'package:masrouf/domain/entities/analytics/analytics.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/domain/entities/analytics/date_range.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/entities/history_filter.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

import '../helpers/test_database.dart';

/// The derived tables are the app's performance strategy: the dashboard reads
/// them instead of scanning the ledger. If they drift out of step with the rows
/// the user sees wrong totals with nothing to signal it, so these tests pin the
/// incremental path against a full rebuild — the two must always agree.
void main() {
  late AppDatabase db;
  const userId = 'user-1';
  const base = Currency.tnd;

  late Account cash;
  late Account bank;
  late Category groceries;
  late Category salary;

  Txn expense(String id, int milli, DateTime date, {String? categoryId}) => Txn(
        id: id,
        type: TxnType.expense,
        amount: Money(milli, base),
        fxRateToBase: 1,
        categoryId: categoryId ?? groceries.id,
        accountId: cash.id,
        transferAccountId: null,
        date: date,
        note: null,
        tags: const <String>[],
        recurringRuleId: null,
        createdAt: date,
        updatedAt: date,
      );

  Future<int> balanceOf(String accountId) async {
    final row = await (db.select(db.accountBalances)
          ..where((t) => t.accountId.equals(accountId)))
        .getSingleOrNull();
    return row?.balanceMilli ?? 0;
  }

  Future<int> monthlyTotal(Ym ym, TxnType type) async {
    final rows = await (db.select(db.monthlyCategoryTotals)
          ..where((t) => t.ym.equals(ym.value) & t.type.equals(type.wire)))
        .get();
    return rows.fold<int>(0, (sum, row) => sum + row.totalMilli);
  }

  /// The invariant: replaying every row from scratch must land on exactly the
  /// same numbers the incremental path produced.
  Future<void> expectMatchesRebuild() async {
    final beforeBalances = <String, int>{
      for (final row in await db.select(db.accountBalances).get())
        row.accountId: row.balanceMilli,
    };
    final beforeMonthly = <String, int>{
      for (final row in await db.select(db.monthlyCategoryTotals).get())
        '${row.ym}|${row.type}|${row.categoryId}': row.totalMilli,
    };
    final beforeDaily = <String, int>{
      for (final row in await db.select(db.dailyTotals).get())
        '${row.ymd}|${row.type}': row.totalMilli,
    };

    await db.transactionDao.rebuildAggregates(userId, base);

    expect(
      <String, int>{
        for (final row in await db.select(db.accountBalances).get())
          row.accountId: row.balanceMilli,
      },
      beforeBalances,
      reason: 'incremental balances diverged from a full rebuild',
    );
    expect(
      <String, int>{
        for (final row in await db.select(db.monthlyCategoryTotals).get())
          '${row.ym}|${row.type}|${row.categoryId}': row.totalMilli,
      },
      beforeMonthly,
      reason: 'incremental monthly totals diverged from a full rebuild',
    );
    expect(
      <String, int>{
        for (final row in await db.select(db.dailyTotals).get())
          '${row.ymd}|${row.type}': row.totalMilli,
      },
      beforeDaily,
      reason: 'incremental daily totals diverged from a full rebuild',
    );
  }

  setUp(() async {
    db = openTestDatabase();

    cash = Account(
      id: 'acc-cash',
      name: 'Cash',
      type: AccountType.cash,
      currency: base,
      openingBalance: const Money(100000, base), // 100 DT already in the wallet
      sortOrder: 0,
      archived: false,
      updatedAt: DateTime.now(),
    );
    bank = Account(
      id: 'acc-bank',
      name: 'Bank',
      type: AccountType.bank,
      currency: base,
      openingBalance: const Money.zero(base),
      sortOrder: 1,
      archived: false,
      updatedAt: DateTime.now(),
    );
    groceries = Category(
      id: 'cat-groceries',
      name: 'Groceries',
      kind: CategoryKind.expense,
      icon: 'groceries',
      color: 0xFF2A78D6,
      sortOrder: 0,
      isDefault: true,
      updatedAt: DateTime.now(),
    );
    salary = Category(
      id: 'cat-salary',
      name: 'Salary',
      kind: CategoryKind.income,
      icon: 'wallet',
      color: 0xFF1BAF7A,
      sortOrder: 0,
      isDefault: true,
      updatedAt: DateTime.now(),
    );

    await db.accountDao.upsert(userId, cash);
    await db.accountDao.upsert(userId, bank);
    await db.categoryDao.upsertAll(userId, <Category>[groceries, salary]);
  });

  tearDown(() => db.close());

  test('an insert folds into balances, monthly and daily totals', () async {
    final date = DateTime(2026, 8, 26);
    await db.transactionDao
        .insertTxn(userId, expense('t1', 25000, date), base);

    // 100 DT opening minus 25 DT spent.
    expect(await balanceOf(cash.id), 75000);
    expect(await monthlyTotal(Ym.fromDate(date), TxnType.expense), 25000);
    await expectMatchesRebuild();
  });

  test('an account with no transactions still reports its opening balance',
      () async {
    await db.transactionDao.rebuildAggregates(userId, base);
    expect(await balanceOf(cash.id), 100000);
    expect(await balanceOf(bank.id), 0);
  });

  test('an edit reverses the old row before applying the new one', () async {
    final date = DateTime(2026, 8, 26);
    final original = expense('t1', 25000, date);
    await db.transactionDao.insertTxn(userId, original, base);

    final edited = original.copyWith(amount: const Money(40000, base));
    await db.transactionDao.updateTxn(userId, original, edited, base);

    // 25 must not be double-counted alongside 40.
    expect(await balanceOf(cash.id), 60000);
    expect(await monthlyTotal(Ym.fromDate(date), TxnType.expense), 40000);
    await expectMatchesRebuild();
  });

  test('moving a transaction to another month moves its totals too', () async {
    final august = DateTime(2026, 8, 26);
    final july = DateTime(2026, 7, 26);
    final original = expense('t1', 25000, august);
    await db.transactionDao.insertTxn(userId, original, base);

    await db.transactionDao.updateTxn(
      userId,
      original,
      original.copyWith(date: july),
      base,
    );

    expect(await monthlyTotal(Ym.fromDate(august), TxnType.expense), 0);
    expect(await monthlyTotal(Ym.fromDate(july), TxnType.expense), 25000);
    await expectMatchesRebuild();
  });

  test('delete then restore returns to exactly the original numbers', () async {
    final date = DateTime(2026, 8, 26);
    final txn = expense('t1', 25000, date);
    await db.transactionDao.insertTxn(userId, txn, base);

    await db.transactionDao.softDeleteTxn(userId, txn, base);
    expect(await balanceOf(cash.id), 100000);
    expect(await monthlyTotal(Ym.fromDate(date), TxnType.expense), 0);

    await db.transactionDao.restoreTxn(userId, txn, base);
    expect(await balanceOf(cash.id), 75000);
    expect(await monthlyTotal(Ym.fromDate(date), TxnType.expense), 25000);
    await expectMatchesRebuild();
  });

  test('a transfer moves balances without touching spending totals', () async {
    final date = DateTime(2026, 8, 26);
    await db.transactionDao.insertTxn(
      userId,
      Txn(
        id: 't-transfer',
        type: TxnType.transfer,
        amount: const Money(30000, base),
        fxRateToBase: 1,
        categoryId: null,
        accountId: cash.id,
        transferAccountId: bank.id,
        date: date,
        note: null,
        tags: const <String>[],
        recurringRuleId: null,
        createdAt: date,
        updatedAt: date,
      ),
      base,
    );

    expect(await balanceOf(cash.id), 70000);
    expect(await balanceOf(bank.id), 30000);
    // Moving your own money is neither income nor spending.
    expect(await monthlyTotal(Ym.fromDate(date), TxnType.expense), 0);
    expect(await monthlyTotal(Ym.fromDate(date), TxnType.income), 0);
    await expectMatchesRebuild();
  });

  test('a foreign-currency row is aggregated at its frozen rate', () async {
    final date = DateTime(2026, 8, 26);
    await db.accountDao.upsert(
      userId,
      Account(
        id: 'acc-eur',
        name: 'Euro',
        type: AccountType.foreign,
        currency: Currency.eur,
        openingBalance: const Money.zero(Currency.eur),
        sortOrder: 2,
        archived: false,
        updatedAt: DateTime.now(),
      ),
    );

    await db.transactionDao.insertTxn(
      userId,
      Txn(
        id: 't-eur',
        type: TxnType.expense,
        amount: const Money(12500, Currency.eur), // 12.50 EUR
        fxRateToBase: 3.3,
        categoryId: groceries.id,
        accountId: 'acc-eur',
        transferAccountId: null,
        date: date,
        note: null,
        tags: const <String>[],
        recurringRuleId: null,
        createdAt: date,
        updatedAt: date,
      ),
      base,
    );

    // Reported in TND...
    expect(await monthlyTotal(Ym.fromDate(date), TxnType.expense), 41250);
    // ...but the account's own balance stays in euros.
    expect(await balanceOf('acc-eur'), -12500);
    await expectMatchesRebuild();
  });

  test('income and expense accumulate separately in the same month', () async {
    final date = DateTime(2026, 8, 10);
    await db.transactionDao.insertTxn(
      userId,
      Txn(
        id: 't-salary',
        type: TxnType.income,
        amount: const Money(2000000, base),
        fxRateToBase: 1,
        categoryId: salary.id,
        accountId: bank.id,
        transferAccountId: null,
        date: date,
        note: null,
        tags: const <String>[],
        recurringRuleId: null,
        createdAt: date,
        updatedAt: date,
      ),
      base,
    );
    await db.transactionDao
        .insertTxn(userId, expense('t-food', 25000, date), base);

    expect(await monthlyTotal(Ym.fromDate(date), TxnType.income), 2000000);
    expect(await monthlyTotal(Ym.fromDate(date), TxnType.expense), 25000);
    expect(await balanceOf(bank.id), 2000000);
    await expectMatchesRebuild();
  });

  test('a hundred writes stay consistent with a rebuild', () async {
    for (var day = 1; day <= 25; day++) {
      for (var n = 0; n < 4; n++) {
        await db.transactionDao.insertTxn(
          userId,
          expense('t-$day-$n', 1000 + n * 37, DateTime(2026, 8, day)),
          base,
        );
      }
    }
    expect(await monthlyTotal(const Ym(202608), TxnType.expense), 105550);
    await expectMatchesRebuild();
  });

  group('history filters', () {
    test('a transfer matches a filter on either of its accounts', () async {
      final date = DateTime(2026, 8, 26);
      await db.transactionDao.insertTxn(
        userId,
        Txn(
          id: 't-transfer',
          type: TxnType.transfer,
          amount: const Money(30000, base),
          fxRateToBase: 1,
          categoryId: null,
          accountId: cash.id,
          transferAccountId: bank.id,
          date: date,
          note: null,
          tags: const <String>[],
          recurringRuleId: null,
          createdAt: date,
          updatedAt: date,
        ),
        base,
      );

      final fromDestination = await db.transactionDao.history(
        userId,
        HistoryFilter(accountIds: <String>{bank.id}),
        base,
      );
      expect(fromDestination, hasLength(1));
    });

    test('search matches notes case-insensitively', () async {
      final date = DateTime(2026, 8, 26);
      await db.transactionDao.insertTxn(
        userId,
        expense('t1', 25000, date).copyWith(note: 'Monoprix Lac'),
        base,
      );

      expect(
        await db.transactionDao
            .history(userId, const HistoryFilter(search: 'monoprix'), base),
        hasLength(1),
      );
      expect(
        await db.transactionDao
            .history(userId, const HistoryFilter(search: 'carrefour'), base),
        isEmpty,
      );
    });

    test('deleted rows drop out of history', () async {
      final date = DateTime(2026, 8, 26);
      final txn = expense('t1', 25000, date);
      await db.transactionDao.insertTxn(userId, txn, base);
      await db.transactionDao.softDeleteTxn(userId, txn, base);

      expect(
        await db.transactionDao.history(userId, HistoryFilter.none, base),
        isEmpty,
      );
    });
  });

  /// The aggregates are written with raw SQL, which drift cannot inspect. Unless
  /// each of those writes declares the tables it touches, the dashboard's streams
  /// never fire and the user has to leave the screen and come back to see the
  /// entry they just made.
  group('live updates', () {
    test('the month summary re-emits after an insert', () async {
      final date = DateTime(2026, 8, 26);
      final ym = Ym.fromDate(date);
      final summaries = db.analyticsDao.watchMonthSummary(userId, ym, base);

      expect(
        summaries.map((s) => s.expense.milli),
        emitsInOrder(<int>[0, 25000, 40000]),
      );

      await pumpEventQueue();
      await db.transactionDao
          .insertTxn(userId, expense('t1', 25000, date), base);
      await pumpEventQueue();
      await db.transactionDao
          .insertTxn(userId, expense('t2', 15000, date), base);
      await pumpEventQueue();
    });

    test('account balances re-emit after an insert', () async {
      final balances = db.accountDao
          .watchWithBalances(userId)
          .map((list) => list.firstWhere((a) => a.account.id == cash.id))
          .map((a) => a.balance.milli);

      expect(balances, emitsInOrder(<int>[100000, 75000]));

      await pumpEventQueue();
      await db.transactionDao.insertTxn(
        userId,
        expense('t1', 25000, DateTime(2026, 8, 26)),
        base,
      );
      await pumpEventQueue();
    });

    test('the cashflow series re-emits across an insert and a delete', () async {
      final date = DateTime(2026, 8, 26);
      final ym = Ym.fromDate(date);
      final txn = expense('t1', 25000, date);

      final spentPerMonth = db.analyticsDao
          .watchCashflow(
            userId,
            DateRange(from: ym.firstDay, to: ym.lastDay),
            base,
            CashflowGranularity.daily,
          )
          .map(
            (points) =>
                points.fold<int>(0, (sum, p) => sum + p.expense.milli),
          );

      expect(spentPerMonth, emitsInOrder(<int>[0, 25000, 0]));

      await pumpEventQueue();
      await db.transactionDao.insertTxn(userId, txn, base);
      await pumpEventQueue();
      await db.transactionDao.softDeleteTxn(userId, txn, base);
      await pumpEventQueue();
    });
  });
}
