import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/dashboard/widgets/dashboard_widgets.dart';

import '../helpers/app_harness.dart';

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

  setUp(() async {
    db = openSeededDatabase();
    sync = testSyncEngine(db);
    await seedMinimalLedger(db);
    await db.accountDao.upsert(
      testUser.id,
      Account(
        id: 'acc-bank',
        name: 'Zitouna',
        type: AccountType.bank,
        currency: Currency.tnd,
        openingBalance: const Money(356000, Currency.tnd),
        sortOrder: 1,
        archived: false,
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() => db.close());

  group('dashboard account balances', () {
    testWidgets('every account is listed with its own balance', (tester) async {
      await pumpApp(tester, db: db, sync: sync);

      expect(find.byType(AccountBalanceStrip), findsOneWidget);
      final strip = find.byType(AccountBalanceStrip);
      expect(find.descendant(of: strip, matching: find.text('Cash')),
          findsOneWidget);
      expect(find.descendant(of: strip, matching: find.text('Zitouna')),
          findsOneWidget);
      // Comma decimal separator: amounts are formatted with the user's stored
      // locale, which defaults to fr, not with the widget tree's locale.
      expect(find.descendant(of: strip, matching: find.text('100,000 DT')),
          findsOneWidget);
      expect(find.descendant(of: strip, matching: find.text('356,000 DT')),
          findsOneWidget);
    });

    testWidgets('a balance follows its own account, not the total',
        (tester) async {
      await db.transactionDao
          .insertTxn(testUser.id, expense('t1', 25000), Currency.tnd);
      await pumpApp(tester, db: db, sync: sync);

      final strip = find.byType(AccountBalanceStrip);
      // Only Cash was spent from.
      expect(find.descendant(of: strip, matching: find.text('75,000 DT')),
          findsOneWidget);
      expect(find.descendant(of: strip, matching: find.text('356,000 DT')),
          findsOneWidget);
    });
  });

  /// fl_chart reports index -1 for a touch in the donut's centre hole or in the
  /// gap between two arcs — both of which are easy to hit on a 62px hole. The
  /// index was stored and used unchecked, so the screen died with
  /// `RangeError: not in inclusive range 0..6: -1`.
  group('donut touch', () {
    testWidgets('touching the centre of the donut does not crash',
        (tester) async {
      await db.transactionDao
          .insertTxn(testUser.id, expense('t1', 25000), Currency.tnd);
      await pumpApp(tester, db: db, sync: sync);

      await tester.tap(find.text('Analytics'));
      await tester.pumpAndSettle();

      final chart = find.byType(PieChart);
      expect(chart, findsOneWidget);

      // Dead centre: the hole, which belongs to no section.
      await tester.tapAt(tester.getCenter(chart));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PieChart), findsOneWidget);
    });

    testWidgets('dragging across the donut and off it does not crash',
        (tester) async {
      await db.transactionDao
          .insertTxn(testUser.id, expense('t1', 25000), Currency.tnd);
      await pumpApp(tester, db: db, sync: sync);

      await tester.tap(find.text('Analytics'));
      await tester.pumpAndSettle();

      final centre = tester.getCenter(find.byType(PieChart));
      final gesture = await tester.startGesture(centre);
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-160, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
