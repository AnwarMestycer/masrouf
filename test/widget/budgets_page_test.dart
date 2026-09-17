import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/budget.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/budgets/budgets_page.dart';
import 'package:masrouf/presentation/categories/categories_page.dart';
import 'package:masrouf/presentation/dashboard/widgets/dashboard_widgets.dart';

import '../helpers/app_harness.dart';

/// Budgets reach the user through three screens. These cover the two that make
/// a decision — setting a cap, and being told when one is about to break.
void main() {
  late AppDatabase db;
  late SyncEngine sync;

  Txn expense(String id, int milli) => Txn(
        id: id,
        type: TxnType.expense,
        amount: Money(milli, Currency.tnd),
        fxRateToBase: 1,
        categoryId: 'cat-groceries',
        accountId: 'acc-cash',
        transferAccountId: null,
        date: DateTime.now(),
        note: null,
        tags: const <String>[],
        recurringRuleId: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  Future<void> setBudget(int milli) => db.budgetDao.upsert(
        testUser.id,
        Budget(
          id: 'b1',
          categoryId: 'cat-groceries',
          amount: Money(milli, Currency.tnd),
          updatedAt: DateTime.now(),
        ),
      );

  Future<List<BudgetRow>> budgetRows() =>
      (db.select(db.budgets)..where((t) => t.deletedAt.isNull())).get();

  setUp(() async {
    db = openSeededDatabase();
    sync = testSyncEngine(db);
    await seedMinimalLedger(db);
  });

  tearDown(() => db.close());

  Future<void> openBudgets(WidgetTester tester) =>
      openSettingsItem(tester, 'Budgets');

  testWidgets('every expense category is listed, capped or not', (tester) async {
    await pumpApp(tester, db: db, sync: sync);
    await openBudgets(tester);

    expect(find.byType(BudgetsPage), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('No cap'), findsOneWidget);
  });

  testWidgets('setting a cap writes one budget for the category',
      (tester) async {
    await pumpApp(tester, db: db, sync: sync);
    await openBudgets(tester);

    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(BudgetEditor),
        matching: find.byType(TextField),
      ),
      '300',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final rows = await budgetRows();
    expect(rows, hasLength(1));
    expect(rows.single.categoryId, 'cat-groceries');
    expect(rows.single.amountMilli, 300000);
  });

  testWidgets('editing replaces the cap rather than adding a second',
      (tester) async {
    await setBudget(300000);
    await pumpApp(tester, db: db, sync: sync);
    await openBudgets(tester);

    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(BudgetEditor),
        matching: find.byType(TextField),
      ),
      '450',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final rows = await budgetRows();
    expect(rows, hasLength(1), reason: 'one cap per category is the invariant');
    expect(rows.single.amountMilli, 450000);
  });

  testWidgets('removing a cap asks first', (tester) async {
    await setBudget(300000);
    await pumpApp(tester, db: db, sync: sync);
    await openBudgets(tester);

    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Remove this budget?'), findsOneWidget);
    expect(await budgetRows(), hasLength(1));

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Delete'),
      ),
    );
    await tester.pumpAndSettle();

    expect(await budgetRows(), isEmpty);
  });

  group('from the category editor', () {
    Future<void> openCategory(WidgetTester tester, String name) async {
      await openSettingsItem(tester, 'Categories');
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }

    Finder capField() => find.descendant(
          of: find.byType(CategoryEditor),
          matching: find.widgetWithText(TextField, 'Monthly cap'),
        );

    testWidgets('a cap can be set while editing the category', (tester) async {
      await pumpApp(tester, db: db, sync: sync);
      await openCategory(tester, 'Groceries');

      await tester.enterText(capField(), '250');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final rows = await budgetRows();
      expect(rows.single.categoryId, 'cat-groceries');
      expect(rows.single.amountMilli, 250000);
    });

    testWidgets('an existing cap is shown and can be changed', (tester) async {
      await setBudget(300000);
      await pumpApp(tester, db: db, sync: sync);
      await openCategory(tester, 'Groceries');

      expect(
        tester.widget<TextField>(capField()).controller?.text,
        '300.000',
        reason: 'the field must open on the existing cap, not blank',
      );

      await tester.enterText(capField(), '400');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final rows = await budgetRows();
      expect(rows, hasLength(1));
      expect(rows.single.amountMilli, 400000);
    });

    testWidgets('clearing the field removes the cap', (tester) async {
      await setBudget(300000);
      await pumpApp(tester, db: db, sync: sync);
      await openCategory(tester, 'Groceries');

      await tester.enterText(capField(), '');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(await budgetRows(), isEmpty);
    });

    testWidgets('leaving it blank writes no budget at all', (tester) async {
      await pumpApp(tester, db: db, sync: sync);
      await openCategory(tester, 'Groceries');

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(await budgetRows(), isEmpty);
    });
  });

  testWidgets('the dashboard shows a category even when its budget is fine',
      (tester) async {
    await setBudget(300000);
    await db.transactionDao
        .insertTxn(testUser.id, expense('t1', 30000), Currency.tnd);

    await pumpApp(tester, db: db, sync: sync);

    // The old card hid itself below 80% of the cap, which meant the first
    // screen said nothing about spending for most of the month.
    final card = find.byType(CategoryBreakdownCard);
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('Groceries')),
        findsOneWidget);
    expect(find.descendant(of: card, matching: find.textContaining('left')),
        findsOneWidget);
  });

  testWidgets('a nearly spent budget still reports what is left',
      (tester) async {
    await setBudget(100000);
    await db.transactionDao
        .insertTxn(testUser.id, expense('t1', 85000), Currency.tnd);

    await pumpApp(tester, db: db, sync: sync);

    final card = find.byType(CategoryBreakdownCard);
    expect(find.descendant(of: card, matching: find.textContaining('left')),
        findsOneWidget);
  });

  testWidgets('an overspent budget reports the overspend, not a negative',
      (tester) async {
    await setBudget(100000);
    await db.transactionDao
        .insertTxn(testUser.id, expense('t1', 130000), Currency.tnd);

    await pumpApp(tester, db: db, sync: sync);

    final card = find.byType(CategoryBreakdownCard);
    expect(find.descendant(of: card, matching: find.textContaining('over')),
        findsWidgets);
    // Scoped to the card: the transaction list legitimately shows negative
    // amounts, but a budget must never report "−30.000 left".
    expect(
      find.descendant(of: card, matching: find.textContaining('−')),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.textContaining('left')),
      findsNothing,
      reason: 'an overspent budget has nothing left',
    );
  });

  testWidgets('a category with no budget still appears, with its share',
      (tester) async {
    await db.transactionDao
        .insertTxn(testUser.id, expense('t1', 40000), Currency.tnd);

    await pumpApp(tester, db: db, sync: sync);

    final card = find.byType(CategoryBreakdownCard);
    expect(find.descendant(of: card, matching: find.text('Groceries')),
        findsOneWidget);
    expect(find.descendant(of: card, matching: find.textContaining('of')),
        findsNothing,
        reason: 'no cap means no "spent of cap" line');
  });
}
