import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/entities/planned_expense.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

import '../helpers/test_database.dart';

/// The entire point of a planned expense is what it does *not* do: it must never
/// reach the balance or the aggregates. If it ever did, the app would be telling
/// the user they had spent money that is still in their account.
void main() {
  late AppDatabase db;
  const userId = 'user-1';
  const base = Currency.tnd;

  PlannedExpense plan(
    String id,
    int milli, {
    DateTime? dueAt,
    PlannedStatus status = PlannedStatus.pending,
  }) =>
      PlannedExpense(
        id: id,
        categoryId: 'cat-groceries',
        accountId: 'acc-cash',
        amount: Money(milli, base),
        dueAt: dueAt ?? DateTime(2026, 9, 15, 10),
        note: null,
        status: status,
        transactionId: null,
        updatedAt: DateTime(2026, 8, 30),
      );

  setUp(() async {
    db = openTestDatabase();
    await db.accountDao.upsert(
      userId,
      Account(
        id: 'acc-cash',
        name: 'Cash',
        type: AccountType.cash,
        currency: base,
        openingBalance: const Money(500000, base),
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
    ]);
  });

  tearDown(() => db.close());

  Future<int> cashBalance() async {
    final row = await (db.select(db.accountBalances)
          ..where((t) => t.accountId.equals('acc-cash')))
        .getSingleOrNull();
    return row?.balanceMilli ?? 0;
  }

  test('a plan changes no balance and no aggregate', () async {
    final before = await cashBalance();
    expect(before, 500000);

    await db.plannedDao.upsert(userId, plan('p1', 80000));

    expect(await cashBalance(), before, reason: 'the money has not moved');
    expect(
      await db.select(db.monthlyCategoryTotals).get(),
      isEmpty,
      reason: 'a plan is not spending',
    );
    expect(await db.select(db.dailyTotals).get(), isEmpty);
  });

  test('only pending plans before the horizon are reserved', () async {
    await db.plannedDao.upsert(userId, plan('near', 30000,
        dueAt: DateTime(2026, 9, 10)));
    await db.plannedDao.upsert(userId, plan('far', 90000,
        dueAt: DateTime(2026, 11, 10)));
    await db.plannedDao.upsert(userId, plan('done', 50000,
        dueAt: DateTime(2026, 9, 11), status: PlannedStatus.done));
    await db.plannedDao.upsert(userId, plan('cancelled', 70000,
        dueAt: DateTime(2026, 9, 12), status: PlannedStatus.cancelled));

    final reserved = await db.plannedDao
        .pendingBefore(userId, DateTime(2026, 9, 25), base);

    expect(reserved.map((p) => p.id), <String>['near']);
  });

  test('a soft-deleted plan stops being reserved', () async {
    await db.plannedDao.upsert(userId, plan('p1', 30000));
    expect(
      await db.plannedDao.pendingBefore(userId, DateTime(2026, 10, 1), base),
      hasLength(1),
    );

    await db.plannedDao.softDelete('p1');

    expect(
      await db.plannedDao.pendingBefore(userId, DateTime(2026, 10, 1), base),
      isEmpty,
    );
  });

  test('pending plans stream soonest first', () async {
    await db.plannedDao
        .upsert(userId, plan('late', 10000, dueAt: DateTime(2026, 9, 20)));
    await db.plannedDao
        .upsert(userId, plan('soon', 10000, dueAt: DateTime(2026, 9, 2)));

    final views = await db.plannedDao.watchPending(userId, base).first;
    expect(views.map((v) => v.id), <String>['soon', 'late']);
    expect(views.first.category?.name, 'Groceries');
  });

  test('a plan carries a time of day, not just a date', () async {
    await db.plannedDao
        .upsert(userId, plan('p1', 10000, dueAt: DateTime(2026, 9, 15, 18, 30)));

    final stored =
        (await db.plannedDao.watchPending(userId, base).first).single.plan;
    expect(stored.dueAt.hour, 18);
    expect(stored.dueAt.minute, 30);
  });

  group('isDue', () {
    final now = DateTime(2026, 9, 15, 12);

    test('a pending plan whose moment has passed is due', () {
      expect(plan('p', 1, dueAt: DateTime(2026, 9, 15, 11)).isDue(now), isTrue);
    });

    test('a future plan is not due', () {
      expect(plan('p', 1, dueAt: DateTime(2026, 9, 15, 13)).isDue(now), isFalse);
    });

    test('a resolved plan is never due, however old', () {
      expect(
        plan('p', 1,
                dueAt: DateTime(2026, 1, 1), status: PlannedStatus.done)
            .isDue(now),
        isFalse,
      );
      expect(
        plan('p', 1,
                dueAt: DateTime(2026, 1, 1), status: PlannedStatus.cancelled)
            .isDue(now),
        isFalse,
      );
    });
  });
}
