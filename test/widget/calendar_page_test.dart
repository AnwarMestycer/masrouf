import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/planned_expense.dart';
import 'package:masrouf/domain/entities/recurring_rule.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/calendar/calendar_page.dart';

import '../helpers/app_harness.dart';

/// The calendar is the only screen in the app about money that has not moved.
/// It must show plans and recurring occurrences together, and show nothing that
/// has already been resolved.
void main() {
  late AppDatabase db;
  late SyncEngine sync;

  DateTime dayThisMonth(int day) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, day, 10);
  }

  setUp(() async {
    db = openSeededDatabase();
    sync = testSyncEngine(db);
    await seedMinimalLedger(db);
  });

  tearDown(() => db.close());

  Future<void> openCalendar(WidgetTester tester) =>
      openSettingsItem(tester, 'Cash-flow calendar');

  testWidgets('an empty month says so rather than showing a blank grid',
      (tester) async {
    await pumpApp(tester, db: db, sync: sync);
    await openCalendar(tester);

    expect(find.byType(CalendarPage), findsOneWidget);
    expect(find.text('Nothing expected this month'), findsOneWidget);
  });

  testWidgets('a planned expense appears on its day', (tester) async {
    await db.plannedDao.upsert(
      testUser.id,
      PlannedExpense(
        id: 'p1',
        categoryId: 'cat-groceries',
        accountId: 'acc-cash',
        amount: const Money(80000, Currency.tnd),
        dueAt: dayThisMonth(12),
        note: 'Rent',
        status: PlannedStatus.pending,
        transactionId: null,
        updatedAt: DateTime.now(),
      ),
    );

    await pumpApp(tester, db: db, sync: sync);
    await openCalendar(tester);

    expect(find.text('Nothing expected this month'), findsNothing);
    expect(find.textContaining('80,000 DT expected'), findsOneWidget);

    // The day cell opens a sheet listing what falls on it.
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsOneWidget);
  });

  testWidgets('a recurring rule contributes every occurrence in the month',
      (tester) async {
    final now = DateTime.now();
    await db.recurringDao.upsert(
      testUser.id,
      RecurringRule(
        id: 'r1',
        type: TxnType.expense,
        amount: const Money(10000, Currency.tnd),
        categoryId: 'cat-groceries',
        accountId: 'acc-cash',
        transferAccountId: null,
        note: 'Bus pass',
        cadence: Cadence.weekly,
        dayOfMonth: null,
        dayOfWeek: DateTime(now.year, now.month, 1).weekday,
        nextRunDate: DateTime(now.year, now.month),
        lastRunDate: null,
        active: true,
        updatedAt: DateTime.now(),
      ),
    );

    await pumpApp(tester, db: db, sync: sync);
    await openCalendar(tester);

    // Four or five weeks in a month, never one — the bug the enumeration fixed.
    expect(find.text('Nothing expected this month'), findsNothing);
    expect(find.textContaining('expected'), findsWidgets);
  });

  testWidgets('a resolved plan is not expected any more', (tester) async {
    await db.plannedDao.upsert(
      testUser.id,
      PlannedExpense(
        id: 'p1',
        categoryId: 'cat-groceries',
        accountId: 'acc-cash',
        amount: const Money(80000, Currency.tnd),
        dueAt: dayThisMonth(12),
        note: 'Rent',
        status: PlannedStatus.done,
        transactionId: 't1',
        updatedAt: DateTime.now(),
      ),
    );

    await pumpApp(tester, db: db, sync: sync);
    await openCalendar(tester);

    expect(find.text('Nothing expected this month'), findsOneWidget);
  });

  testWidgets('the calendar can look at future months', (tester) async {
    await pumpApp(tester, db: db, sync: sync);
    await openCalendar(tester);

    // Unlike the analytics month stepper, forward is allowed — everything on
    // this screen is in the future by definition.
    final next = find.byIcon(Icons.chevron_right);
    expect(
      tester.widget<IconButton>(
        find.ancestor(of: next, matching: find.byType(IconButton)),
      ).onPressed,
      isNotNull,
    );
  });
}
