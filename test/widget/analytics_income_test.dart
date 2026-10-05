import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

import '../helpers/app_harness.dart';

/// Analytics computed both of these and rendered neither: the donut was pinned
/// to expenses even though the query takes a type, and `MonthSummary.burnRate`
/// had no call site at all.
void main() {
  late AppDatabase db;
  late SyncEngine sync;

  Txn txn(String id, TxnType type, int milli, String categoryId) => Txn(
        id: id,
        type: type,
        amount: Money(milli, Currency.tnd),
        fxRateToBase: 1,
        categoryId: categoryId,
        accountId: 'acc-cash',
        transferAccountId: null,
        date: DateTime.now(),
        note: null,
        tags: const <String>[],
        recurringRuleId: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  setUp(() async {
    db = openSeededDatabase();
    sync = testSyncEngine(db);
    await seedMinimalLedger(db);
    await db.categoryDao.upsertAll(testUser.id, <Category>[
      Category(
        id: 'cat-salary',
        name: 'Salary',
        kind: CategoryKind.income,
        icon: 'wallet',
        color: 0xFF1BAF7A,
        sortOrder: 0,
        isDefault: true,
        updatedAt: DateTime.now(),
      ),
    ]);
    // 1000 in, 250 out — a quarter of income spent.
    await db.transactionDao
        .insertTxn(testUser.id, txn('t1', TxnType.income, 1000000, 'cat-salary'), Currency.tnd);
    await db.transactionDao.insertTxn(
      testUser.id,
      txn('t2', TxnType.expense, 250000, 'cat-groceries'),
      Currency.tnd,
    );
  });

  tearDown(() => db.close());

  Future<void> openAnalytics(WidgetTester tester) async {
    await tester.tap(find.text('Analytics'));
    await tester.pumpAndSettle();
  }

  testWidgets('the month summary states how much of income was spent',
      (tester) async {
    await pumpApp(tester, db: db, sync: sync);
    await openAnalytics(tester);

    expect(find.text('Spent 25% of income'), findsOneWidget);
  });

  testWidgets('a month with no income says so rather than showing 0%',
      (tester) async {
    await db.transactionDao.softDeleteTxn(
      testUser.id,
      txn('t1', TxnType.income, 1000000, 'cat-salary'),
      Currency.tnd,
    );
    await pumpApp(tester, db: db, sync: sync);
    await openAnalytics(tester);

    // The Analytics tab reads over a chosen window now, so it says "period"
    // rather than "month"; the dashboard keeps the monthly wording.
    expect(find.text('No income in this period'), findsOneWidget);
    expect(find.textContaining('0% of income'), findsNothing);
  });

  testWidgets('the donut can be switched to income', (tester) async {
    await pumpApp(tester, db: db, sync: sync);
    await openAnalytics(tester);

    // Expenses by default.
    expect(find.text('Spending by category'), findsOneWidget);
    expect(find.text('Groceries'), findsWidgets);

    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<TxnType>),
        matching: find.text('Income'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Income by category'), findsOneWidget);
    expect(find.text('Salary'), findsWidgets);
    // The centre readout must follow the toggle, not stay on "Out".
    expect(find.text('In'), findsWidgets);
  });
}
