import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/recurring_rule.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/settings/recurring_page.dart';

import '../helpers/app_harness.dart';

/// The editor has always supported an existing rule, but nothing ever opened it
/// with one: the list rows were `SwitchListTile`s with no `onTap`, so a typo'd
/// rent amount could be toggled off and never corrected or removed. These tests
/// pin the row tap that makes the whole edit path reachable.
void main() {
  late AppDatabase db;
  late SyncEngine sync;

  RecurringRule rentRule() => RecurringRule(
        id: 'rule-rent',
        type: TxnType.expense,
        amount: const Money(500000, Currency.tnd),
        categoryId: 'cat-groceries',
        accountId: 'acc-cash',
        transferAccountId: null,
        note: 'Rent',
        cadence: Cadence.monthly,
        dayOfMonth: 5,
        dayOfWeek: null,
        nextRunDate: DateTime(2026, 9, 5),
        lastRunDate: null,
        active: true,
        updatedAt: DateTime(2026, 8, 26),
      );

  setUp(() async {
    db = openSeededDatabase();
    sync = testSyncEngine(db);
    await seedMinimalLedger(db);
    await db.recurringDao.upsert(testUser.id, rentRule());
  });

  tearDown(() => db.close());

  Future<void> openRecurring(WidgetTester tester) =>
      openSettingsItem(tester, 'Recurring');

  /// Read with a one-shot query, not `watchAll().first`. `testWidgets` runs in a
  /// fake-async zone that only advances when the tester pumps, so awaiting a
  /// drift *stream* here never completes and takes the test shell down with it.
  Future<List<RecurringRuleRow>> rules() => (db.select(db.recurringRules)
        ..where((t) => t.deletedAt.isNull()))
      .get();

  /// Finders are scoped to the route under test on purpose. Routes below the
  /// top one stay in the widget tree, so an unscoped `find.byType` also matches
  /// the shell's own widgets — which is how these assertions first went looking
  /// at the wrong screen.
  Finder inEditor(Finder matching) => find.descendant(
        of: find.byType(RecurringEditor),
        matching: matching,
      );

  /// The editor's amount box: the first field inside the sheet. Located by
  /// position rather than contents so the assertion does not also depend on how
  /// money is formatted.
  Finder amountField() => inEditor(find.byType(TextField)).first;

  /// The editor is a scrollable bottom sheet, so its buttons sit below the fold
  /// on a test-sized screen. Tapping without scrolling first silently misses.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a rule opens it populated', (tester) async {
    await pumpApp(tester, db: db, sync: sync);
    await openRecurring(tester);

    expect(find.byType(RecurringEditor), findsNothing);

    await tester.tap(find.text('Rent'));
    await tester.pumpAndSettle();

    expect(find.byType(RecurringEditor), findsOneWidget);
    expect(
      tester.widget<TextField>(amountField()).controller?.text,
      '500.000',
      reason: 'the editor must open on the rule, not blank',
    );
    // Delete only exists in edit mode, so its presence proves the rule was
    // passed through rather than a create sheet being opened.
    expect(find.widgetWithText(TextButton, 'Delete'), findsOneWidget);
  });

  testWidgets('editing updates the rule instead of duplicating it',
      (tester) async {
    await pumpApp(tester, db: db, sync: sync);
    await openRecurring(tester);

    await tester.tap(find.text('Rent'));
    await tester.pumpAndSettle();

    await tester.enterText(amountField(), '620');
    await tester.pumpAndSettle();
    await tapVisible(tester, inEditor(find.widgetWithText(FilledButton, 'Save')));

    final all = await rules();
    expect(all, hasLength(1), reason: 'an edit must not create a second rule');
    expect(all.single.id, 'rule-rent');
    expect(all.single.amountMilli, 620000);
  });

  testWidgets('deleting asks first, then removes the rule', (tester) async {
    await pumpApp(tester, db: db, sync: sync);
    await openRecurring(tester);

    await tester.tap(find.text('Rent'));
    await tester.pumpAndSettle();
    final deleteButton = inEditor(find.widgetWithText(TextButton, 'Delete'));
    await tapVisible(tester, deleteButton);

    // A confirmation, not an immediate delete.
    expect(find.textContaining('Delete this rule?'), findsOneWidget);
    expect(await rules(), hasLength(1));

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Cancel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(await rules(), hasLength(1), reason: 'cancel must keep the rule');

    await tapVisible(tester, deleteButton);
    // The dialog's own Delete, above the editor's.
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Delete'),
      ),
    );
    await tester.pumpAndSettle();

    expect(await rules(), isEmpty);
  });

  testWidgets('the toggle still works without opening the editor',
      (tester) async {
    await pumpApp(tester, db: db, sync: sync);
    await openRecurring(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(RecurringPage),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RecurringEditor), findsNothing);
    expect((await rules()).single.active, isFalse);
  });

  testWidgets('a missing account is reported on the account row, not the amount',
      (tester) async {
    await pumpApp(tester, db: db, sync: sync);
    await openRecurring(tester);

    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'New recurring rule'),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, inEditor(find.widgetWithText(FilledButton, 'Save')));

    // Every missing field is named at once, each under its own control.
    expect(find.text('Pick an account'), findsOneWidget);
    expect(find.text('Pick a category'), findsOneWidget);
    expect(
      tester.widget<TextField>(amountField()).decoration?.errorText,
      'Amount must be greater than zero',
      reason: 'the amount box must carry only the amount error',
    );
  });

  testWidgets('the amount box is labelled Amount, not Income', (tester) async {
    await pumpApp(tester, db: db, sync: sync);
    await openRecurring(tester);

    await tester.tap(find.text('Rent'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(amountField()).decoration?.labelText,
      'Amount',
    );
  });
}
