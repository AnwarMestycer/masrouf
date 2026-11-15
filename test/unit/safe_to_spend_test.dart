import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/repositories/analytics_repository_impl.dart';
import 'package:masrouf/data/repositories/planned_repository_impl.dart';
import 'package:masrouf/data/repositories/recurring_repository_impl.dart';
import 'package:masrouf/data/repositories/transaction_repository_impl.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/analytics/analytics.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/entities/planned_expense.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

import '../helpers/app_harness.dart';
import '../helpers/test_database.dart';

/// The window safe-to-spend holds bills and plans against.
///
/// Payday on the 31st, standing on the 31st, with the salary not yet typed in:
/// the window used to jump straight to 30 November and hold the whole coming
/// month's plans against a balance the salary had not reached, which reads as
/// a month's deficit on the one day it is least true.
void main() {
  late AppDatabase db;
  late SyncEngine sync;
  late DateTime now;
  const userId = 'u1';
  const base = Currency.tnd;

  Money dt(num amount) => Money((amount * 1000).round(), base);

  Future<SafeToSpend> safeToSpend() {
    final transactions = TransactionRepositoryImpl(
      db: db,
      sync: sync,
      userId: userId,
      base: base,
    );
    return AnalyticsRepositoryImpl(
      db: db,
      recurring: RecurringRepositoryImpl(
        db: db,
        sync: sync,
        userId: userId,
        base: base,
      ),
      planned: PlannedRepositoryImpl(
        db: db,
        sync: sync,
        transactions: transactions,
        userId: userId,
        base: base,
      ),
      userId: userId,
      base: base,
      paydayDayOfMonth: 31,
      ratesToBase: const <String, double>{},
      clock: () => now,
    ).safeToSpend();
  }

  Future<void> plan(String id, num amount, DateTime dueAt) =>
      db.plannedDao.upsert(
        userId,
        PlannedExpense(
          id: id,
          categoryId: null,
          accountId: 'acc-bank',
          amount: dt(amount),
          dueAt: dueAt,
          note: null,
          status: PlannedStatus.pending,
          transactionId: null,
          updatedAt: DateTime(2026, 10),
        ),
      );

  Future<void> income(num amount, DateTime on) => db.transactionDao.insertTxn(
        userId,
        Txn(
          id: 'salary',
          type: TxnType.income,
          amount: dt(amount),
          fxRateToBase: 1,
          categoryId: 'cat-salary',
          accountId: 'acc-bank',
          transferAccountId: null,
          date: on,
          note: null,
          tags: const <String>[],
          recurringRuleId: null,
          createdAt: on,
          updatedAt: on,
        ),
        base,
      );

  setUp(() async {
    now = DateTime(2026, 10, 31, 9);
    db = openTestDatabase();
    sync = testSyncEngine(db);
    await db.accountDao.upsert(
      userId,
      Account(
        id: 'acc-bank',
        name: 'Bank',
        type: AccountType.bank,
        currency: base,
        openingBalance: dt(100),
        sortOrder: 0,
        archived: false,
        updatedAt: DateTime(2026, 8),
      ),
    );
    await db.categoryDao.upsertAll(userId, <Category>[
      Category(
        id: 'cat-salary',
        name: 'Salary',
        kind: CategoryKind.income,
        icon: 'wallet',
        color: 0xFF2A78D6,
        sortOrder: 0,
        isDefault: true,
        updatedAt: DateTime(2026, 8),
      ),
    ]);
    await plan('today', 20, DateTime(2026, 10, 31, 15));
    await plan('next-month', 250, DateTime(2026, 11, 2, 10));
  });

  tearDown(() => db.close());

  test('on payday before the salary, the window stops at today', () async {
    final safe = await safeToSpend();
    expect(safe.awaitingPayday, isTrue);
    expect(safe.horizon, DateTime(2026, 10, 31));
    expect(safe.reserved, dt(20), reason: 'November’s plan is not yet due');
    expect(safe.amount, dt(100 - 20));
    expect(safe.perDay, isNull);
  });

  test('once the salary is in, it looks ahead to the next payday', () async {
    await income(1000, DateTime(2026, 10, 31));
    final safe = await safeToSpend();
    expect(safe.awaitingPayday, isFalse);
    expect(safe.horizon, DateTime(2026, 11, 30));
    expect(safe.currentBalance, dt(1100));
    expect(safe.reserved, dt(20 + 250));
    expect(safe.amount, dt(1100 - 270));
  });

  test('a plan due later on the horizon day is still held back', () async {
    now = DateTime(2026, 10, 30, 9);
    final safe = await safeToSpend();
    expect(safe.awaitingPayday, isFalse);
    expect(safe.horizon, DateTime(2026, 10, 31));
    expect(
      safe.reserved,
      dt(20),
      reason: 'due at 15:00 on payday, which bare midnight used to miss',
    );
  });

  test('the breakdown adds up to the figure', () async {
    final safe = await safeToSpend();
    expect(
      safe.currentBalance - safe.bills - safe.reserved - safe.savingsReserved,
      safe.amount,
    );
  });
}
