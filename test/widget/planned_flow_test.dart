import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/planned_expense.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/planned/planned_page.dart';

import '../helpers/app_harness.dart';

/// A plan is a promise, not a payment. These tests hold the line between the
/// two: it reserves money, it never moves it, and the only thing that turns it
/// into a real transaction is the user saying so.
void main() {
  late AppDatabase db;
  late SyncEngine sync;

  PlannedExpense plan({
    required String id,
    required int milli,
    required DateTime dueAt,
    PlannedStatus status = PlannedStatus.pending,
  }) =>
      PlannedExpense(
        id: id,
        categoryId: 'cat-groceries',
        accountId: 'acc-cash',
        amount: Money(milli, Currency.tnd),
        dueAt: dueAt,
        note: 'Rent',
        status: status,
        transactionId: null,
        updatedAt: DateTime.now(),
      );

  Future<List<PlannedExpenseRow>> plans() =>
      (db.select(db.plannedExpenses)..where((t) => t.deletedAt.isNull())).get();

  Future<int> cashBalance() async {
    final row = await (db.select(db.accountBalances)
          ..where((t) => t.accountId.equals('acc-cash')))
        .getSingleOrNull();
    return row?.balanceMilli ?? 0;
  }

  setUp(() async {
    db = openSeededDatabase();
    sync = testSyncEngine(db);
    await seedMinimalLedger(db);
  });

  tearDown(() => db.close());

  testWidgets('planning an expense leaves the balance alone', (tester) async {
    await pumpApp(tester, db: db, sync: sync);
    await openSettingsItem(tester, 'Planned');

    expect(find.byType(PlannedPage), findsOneWidget);
    expect(find.text('Nothing planned'), findsOneWidget);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'New planned expense'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(PlannedEditor),
        matching: find.byType(TextField),
      ).first,
      '80',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final written = await plans();
    expect(written.single.amountMilli, 80000);
    expect(written.single.status, 'pending');
    expect(
      await cashBalance(),
      100000,
      reason: 'the opening balance is untouched — no money has moved',
    );
    expect(await db.select(db.monthlyCategoryTotals).get(), isEmpty);
  });

  testWidgets('a due plan is asked about, not logged', (tester) async {
    await db.plannedDao.upsert(
      testUser.id,
      plan(
        id: 'p1',
        milli: 40000,
        dueAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    );

    await pumpApp(tester, db: db, sync: sync);

    expect(find.byType(DuePlanCard), findsOneWidget);
    expect(find.text('Did this happen?'), findsOneWidget);
    expect(
      await db.transactionDao.allForExport(testUser.id),
      isEmpty,
      reason: 'nothing may be written until the user confirms',
    );
    expect(await cashBalance(), 100000);
  });

  testWidgets('confirming a due plan writes the transaction once',
      (tester) async {
    await db.plannedDao.upsert(
      testUser.id,
      plan(
        id: 'p1',
        milli: 40000,
        dueAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    );
    await pumpApp(tester, db: db, sync: sync);

    await tester.tap(find.widgetWithText(FilledButton, 'Log it'));
    await tester.pumpAndSettle();

    final written = await db.transactionDao.allForExport(testUser.id);
    expect(written, hasLength(1));
    expect(written.single.amount.milli, 40000);
    expect(await cashBalance(), 60000, reason: 'now the money has moved');

    final stored = await plans();
    expect(stored.single.status, 'done');
    expect(stored.single.transactionId, written.single.id);

    // And the prompt is gone, so it cannot be logged twice.
    expect(find.byType(DuePlanCard), findsNothing);
  });

  testWidgets('skipping a due plan writes nothing', (tester) async {
    await db.plannedDao.upsert(
      testUser.id,
      plan(
        id: 'p1',
        milli: 40000,
        dueAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    );
    await pumpApp(tester, db: db, sync: sync);

    await tester.tap(find.widgetWithText(TextButton, 'Skip'));
    await tester.pumpAndSettle();

    expect(await db.transactionDao.allForExport(testUser.id), isEmpty);
    expect(await cashBalance(), 100000);
    expect((await plans()).single.status, 'cancelled');
    expect(find.byType(DuePlanCard), findsNothing);
  });

  testWidgets('a future plan is not asked about yet', (tester) async {
    await db.plannedDao.upsert(
      testUser.id,
      plan(
        id: 'p1',
        milli: 40000,
        dueAt: DateTime.now().add(const Duration(days: 3)),
      ),
    );
    await pumpApp(tester, db: db, sync: sync);

    expect(find.byType(DuePlanCard), findsNothing);
  });

  testWidgets('the planned screen states what is set aside', (tester) async {
    await db.plannedDao.upsert(
      testUser.id,
      plan(
        id: 'p1',
        milli: 40000,
        dueAt: DateTime.now().add(const Duration(days: 3)),
      ),
    );
    await pumpApp(tester, db: db, sync: sync);
    await openSettingsItem(tester, 'Planned');

    // The number that explains why Safe to spend is below the balance.
    expect(find.textContaining('40,000 DT set aside'), findsOneWidget);
  });
}
