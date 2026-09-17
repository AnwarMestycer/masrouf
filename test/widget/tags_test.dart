import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/history_filter.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/add/fast_add_page.dart';
import 'package:masrouf/presentation/add/widgets/add_widgets.dart';

import '../helpers/app_harness.dart';

/// Transactions have always stored tags, and history search has always matched
/// them — there was simply no way to enter one, so the column was permanently
/// empty. These tests cover the input and the filter facet it feeds.
void main() {
  late AppDatabase db;
  late SyncEngine sync;

  setUp(() async {
    db = openSeededDatabase();
    sync = testSyncEngine(db);
    await seedMinimalLedger(db);
  });

  tearDown(() => db.close());

  Future<void> addTagged(WidgetTester tester, String tag) async {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, '5').first);
    await tester.pump();
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();

    // The add screen's middle section is a lazy list, so the tag field is not
    // built until it is scrolled into view.
    final tagField = find.descendant(
      of: find.byType(TagInput),
      matching: find.byType(TextField),
    );
    await tester.dragUntilVisible(
      tagField,
      find
          .descendant(
            of: find.byType(FastAddPage),
            matching: find.byType(ListView),
          )
          .first,
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    await tester.enterText(tagField, tag);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('a tag typed on the add screen is written to the row',
      (tester) async {
    await pumpApp(tester, db: db, sync: sync);
    await addTagged(tester, 'ramadan');

    final written = await db.transactionDao.allForExport(testUser.id);
    expect(written.single.tags, <String>['ramadan']);
  });

  testWidgets('tags are normalised so casing does not split them',
      (tester) async {
    await pumpApp(tester, db: db, sync: sync);
    await addTagged(tester, '  Ramadan ');

    final written = await db.transactionDao.allForExport(testUser.id);
    expect(written.single.tags, <String>['ramadan']);
  });

  testWidgets('filtering by tag narrows history to matching rows',
      (tester) async {
    await pumpApp(tester, db: db, sync: sync);
    await addTagged(tester, 'ramadan');
    await addTagged(tester, 'gym');

    final tagged = await db.transactionDao.history(
      testUser.id,
      const HistoryFilter(tags: <String>{'ramadan'}),
      Currency.tnd,
    );
    expect(tagged, hasLength(1));
    expect(tagged.single.txn.tags, <String>['ramadan']);

    // A tag that exists must not match a longer one that contains it.
    final none = await db.transactionDao.history(
      testUser.id,
      const HistoryFilter(tags: <String>{'rama'}),
      Currency.tnd,
    );
    expect(none, isEmpty);
  });

  // Outside testWidgets on purpose: awaiting a drift *stream* inside the
  // fake-async zone never completes.
  test('the tag list is derived from the rows in use', () async {
    final database = openSeededDatabase();
    addTearDown(database.close);
    await seedMinimalLedger(database);

    expect(await database.transactionDao.watchAllTags(testUser.id).first,
        isEmpty);

    await database.transactionDao.insertTxn(
      testUser.id,
      taggedTxn(<String>['gym', 'ramadan']),
      Currency.tnd,
    );

    expect(
      await database.transactionDao.watchAllTags(testUser.id).first,
      <String>['gym', 'ramadan'],
      reason: 'sorted, de-duplicated, and only what rows actually carry',
    );
  });
}

Txn taggedTxn(List<String> tags) => Txn(
      id: 't-tagged',
      type: TxnType.expense,
      amount: const Money(5000, Currency.tnd),
      fxRateToBase: 1,
      categoryId: 'cat-groceries',
      accountId: 'acc-cash',
      transferAccountId: null,
      date: DateTime(2026, 8, 26),
      note: null,
      tags: tags,
      recurringRuleId: null,
      createdAt: DateTime(2026, 8, 26),
      updatedAt: DateTime(2026, 8, 26),
    );
