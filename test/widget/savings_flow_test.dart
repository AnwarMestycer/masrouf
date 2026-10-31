import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/router/routes.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/repositories/settings_repository_impl.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/entities/savings_plan.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/entities/user_settings.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/savings/widgets/savings_sheets.dart';

import '../helpers/app_harness.dart';

/// The savings screen against the real router, repositories and database:
/// what it offers to put aside, and that putting it aside is a real transfer.
void main() {
  late AppDatabase db;
  late SyncEngine sync;
  const base = Currency.tnd;

  Future<List<TxnRow>> transfers() => (db.select(db.transactions)
        ..where((t) => t.type.equals(TxnType.transfer.wire)))
      .get();

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
        color: 0xFF2A78D6,
        sortOrder: 1,
        isDefault: true,
        updatedAt: DateTime.now(),
      ),
    ]);
    await SettingsRepositoryImpl(db: db, sync: sync, userId: testUser.id).save(
      UserSettings.fallback.copyWith(savings: const SavingsPlan(rate: 0.30)),
    );
    final today = DateTime.now();
    await db.transactionDao.insertTxn(
      testUser.id,
      Txn(
        id: 'salary',
        type: TxnType.income,
        amount: const Money(1000000, base),
        fxRateToBase: 1,
        categoryId: 'cat-salary',
        accountId: 'acc-cash',
        transferAccountId: null,
        date: today,
        note: null,
        tags: const <String>[],
        recurringRuleId: null,
        createdAt: today,
        updatedAt: today,
      ),
      base,
    );
  });

  tearDown(() => db.close());

  Future<void> putAsideFromScreen(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Put aside'));
    await tester.pumpAndSettle();
    expect(find.byType(SavingsMoveSheet), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(SavingsMoveSheet),
        matching: find.widgetWithText(FilledButton, 'Put aside'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('offers what is still to save, and moves exactly that',
      (tester) async {
    await db.accountDao.upsert(
      testUser.id,
      Account(
        id: 'acc-save',
        name: 'Épargne',
        type: AccountType.savings,
        currency: base,
        openingBalance: const Money(0, base),
        sortOrder: 1,
        archived: false,
        updatedAt: DateTime.now(),
      ),
    );
    final router = await pumpApp(tester, db: db, sync: sync);
    unawaited(router.push(Routes.savings));
    await tester.pumpAndSettle();

    expect(find.text('Still to put aside'), findsOneWidget);
    await putAsideFromScreen(tester);

    final written = (await transfers()).single;
    expect(written.amountMilli, 300000, reason: 'prefilled with the 30%');
    expect(written.accountId, 'acc-cash');
    expect(written.transferAccountId, 'acc-save');
    expect(find.textContaining('DT put aside'), findsOneWidget);
  });

  testWidgets('creates a savings account the first time one is needed',
      (tester) async {
    final router = await pumpApp(tester, db: db, sync: sync);
    unawaited(router.push(Routes.savings));
    await tester.pumpAndSettle();

    await putAsideFromScreen(tester);

    final accounts = await db.select(db.accounts).get();
    final created =
        accounts.singleWhere((a) => a.type == AccountType.savings.wire);
    expect(created.name, 'Savings');
    expect((await transfers()).single.transferAccountId, created.id);
  });

  testWidgets('the dashboard says when nothing is due this week',
      (tester) async {
    await pumpApp(tester, db: db, sync: sync);
    expect(find.text('Next 7 days'), findsOneWidget);
    expect(find.text('Nothing due in the next 7 days'), findsOneWidget);
  });
}

