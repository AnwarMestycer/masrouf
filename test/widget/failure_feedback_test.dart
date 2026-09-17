import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:masrouf/core/error/failure.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/money/money_formatter.dart';
import 'package:masrouf/l10n/app_localizations.dart';
import 'package:masrouf/core/result/result.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/common/feedback.dart';
import 'package:masrouf/presentation/dashboard/widgets/dashboard_widgets.dart';

import '../helpers/app_harness.dart';

/// Every write went through `Result`, and almost every call site then did
/// `if (result.isOk) pop()` — so a failure produced no feedback at all. These
/// tests pin the two halves of the fix: failures are announced, and a value that
/// could not be read is never rendered as a confident zero.
void main() {
  late AppDatabase db;
  late SyncEngine sync;

  setUp(() async {
    db = openSeededDatabase();
    sync = testSyncEngine(db);
    await seedMinimalLedger(db);
  });

  tearDown(() => db.close());

  group('Result.report', () {
    testWidgets('a failure is shown to the user in their language',
        (tester) async {
      late BuildContext ctx;
      await pumpApp(tester, db: db, sync: sync);
      ctx = tester.element(find.byType(Scaffold).first);

      const result = Err<void>(Failure(FailureCode.network));
      expect(result.report(ctx), isFalse);
      await tester.pump();

      expect(
        find.text('No connection. Check your network and try again.'),
        findsOneWidget,
      );
    });

    testWidgets('a success says nothing and reports true', (tester) async {
      await pumpApp(tester, db: db, sync: sync);
      final ctx = tester.element(find.byType(Scaffold).first);

      const result = Ok<void>(null);
      expect(result.report(ctx), isTrue);
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('internal detail never reaches the user', (tester) async {
      await pumpApp(tester, db: db, sync: sync);
      final ctx = tester.element(find.byType(Scaffold).first);

      const result = Err<void>(
        Failure(
          FailureCode.storage,
          debugMessage: 'SqliteException(787): FOREIGN KEY constraint failed',
        ),
      );
      result.report(ctx);
      await tester.pump();

      expect(find.textContaining('SqliteException'), findsNothing);
      expect(find.text('Something went wrong. Please try again.'),
          findsOneWidget);
    });
  });

  group('never a fabricated zero', () {
    testWidgets('a readable balance is shown normally', (tester) async {
      await pumpApp(tester, db: db, sync: sync);

      final header = find.byType(BalanceHeader);
      expect(find.descendant(of: header, matching: find.text('100,000 DT')),
          findsOneWidget);
      expect(find.descendant(of: header, matching: find.text('—')),
          findsNothing);
    });

    testWidgets('an unreadable balance shows a dash, not 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (context) => BalanceHeader(
                // A zero that is *not* the real value: exactly the state that
                // used to be rendered as "0.000 DT" and believed.
                total: const Money(0, Currency.tnd),
                unavailable: true,
                formatter: MoneyFormatter('en'),
                l10n: L10n.of(context),
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('—'), findsOneWidget);
      expect(
        find.textContaining('0.000'),
        findsNothing,
        reason: 'a zero the user could act on must never be invented',
      );
    });
  });

  group('account delete', () {
    setUp(() async {
      await db.accountDao.upsert(
        testUser.id,
        Account(
          id: 'acc-bank',
          name: 'Zitouna',
          type: AccountType.bank,
          currency: Currency.tnd,
          openingBalance: const Money(50000, Currency.tnd),
          sortOrder: 1,
          archived: false,
          updatedAt: DateTime.now(),
        ),
      );
    });

    testWidgets('deleting an account asks first', (tester) async {
      await pumpApp(tester, db: db, sync: sync);
      await openSettingsItem(tester, 'Accounts');

      await tester.tap(find.text('Zitouna'));
      await tester.pumpAndSettle();

      final deleteButton = find.widgetWithText(TextButton, 'Delete');
      await tester.ensureVisible(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('Delete this account?'), findsOneWidget);
      // Still there until confirmed.
      final live = await (db.select(db.accounts)
            ..where((t) => t.deletedAt.isNull()))
          .get();
      expect(live.map((a) => a.name), contains('Zitouna'));
    });
  });
}
