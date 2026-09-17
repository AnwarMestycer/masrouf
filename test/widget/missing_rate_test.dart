import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/sync/sync_engine.dart';

import '../helpers/app_harness.dart';

/// A transaction freezes its exchange rate at write time, and editing the rate
/// afterwards deliberately never rewrites history. So a rate guessed as 1.0 is
/// permanently wrong with nothing downstream able to detect it — EUR 100 counted
/// as 100 TND forever. The add screen has to refuse rather than guess.
void main() {
  late AppDatabase db;
  late SyncEngine sync;

  setUp(() {
    db = openSeededDatabase();
    sync = testSyncEngine(db);
  });

  tearDown(() => db.close());

  /// Enters an amount and picks the category, leaving only the rate outstanding.
  Future<void> fillEntry(WidgetTester tester) async {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, '2').first);
    await tester.pump();
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
  }

  bool saveEnabled(WidgetTester tester) =>
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed !=
      null;

  testWidgets('a foreign account with no rate cannot be saved', (tester) async {
    // Base currency is TND; this account is in EUR and no rate row exists.
    await seedMinimalLedger(db, currency: Currency.eur);
    await pumpApp(tester, db: db, sync: sync);

    await fillEntry(tester);

    expect(find.textContaining('No exchange rate set for EUR'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // Still on the add screen, and nothing was written.
    expect(find.textContaining('No exchange rate set for EUR'), findsOneWidget);
    expect(await db.transactionDao.allForExport(testUser.id), isEmpty);
  });

  testWidgets('setting the rate unblocks the same entry', (tester) async {
    await seedMinimalLedger(db, currency: Currency.eur);
    await pumpApp(tester, db: db, sync: sync);

    await fillEntry(tester);
    expect(saveEnabled(tester), isFalse);

    // What the exchange-rates screen writes. The open add screen has to adopt
    // it without the account being re-tapped.
    await db.into(db.exchangeRates).insert(
          ExchangeRatesCompanion.insert(
            id: 'EUR',
            userId: testUser.id,
            currency: 'EUR',
            rateToBase: 3.4,
            updatedAt: DateTime.now(),
          ),
        );
    await tester.pumpAndSettle();

    expect(find.textContaining('No exchange rate set'), findsNothing);
    expect(saveEnabled(tester), isTrue);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final written = await db.transactionDao.allForExport(testUser.id);
    expect(written.single.fxRateToBase, 3.4);
  });

  testWidgets('an account in the base currency needs no rate', (tester) async {
    await seedMinimalLedger(db);
    await pumpApp(tester, db: db, sync: sync);

    await fillEntry(tester);

    expect(find.textContaining('No exchange rate set'), findsNothing);
    expect(saveEnabled(tester), isTrue);
  });
}
