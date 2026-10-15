import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/repositories/savings_repository_impl.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/entities/savings_plan.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

import '../helpers/app_harness.dart';
import '../helpers/test_database.dart';

/// Commit, reserve, confirm, settle — walked against a real ledger.
///
/// The open period's income is derived from transactions rather than kept as a
/// counter on the row, so these also check that it tracks the ledger while the
/// period is open and stops tracking it once the period is closed.
void main() {
  late AppDatabase db;
  late SavingsRepositoryImpl repo;
  const userId = 'u1';
  const base = Currency.tnd;
  const plan = SavingsPlan(rate: 0.30);

  Money dt(num amount) => Money((amount * 1000).round(), base);

  /// Periods cannot share a start date — transactions carry a calendar day and
  /// no time — so the ledger here is laid out across real days.
  final today = DateTime.now();
  DateTime day(int offset) =>
      DateTime(today.year, today.month, today.day).add(Duration(days: offset));

  var seq = 0;
  Future<void> income(num amount, {DateTime? on}) {
    final date = on ?? DateTime.now();
    return db.transactionDao.insertTxn(
      userId,
      Txn(
        id: 'i${seq++}',
        type: TxnType.income,
        amount: dt(amount),
        fxRateToBase: 1,
        categoryId: 'cat-salary',
        accountId: 'acc-cash',
        transferAccountId: null,
        date: date,
        note: null,
        tags: const <String>[],
        recurringRuleId: null,
        createdAt: date,
        updatedAt: date,
      ),
      base,
    );
  }

  SavingsRepositoryImpl build({SavingsPlan p = plan}) =>
      SavingsRepositoryImpl(
        db: db,
        sync: testSyncEngine(db),
        userId: userId,
        base: base,
        plan: p,
      );

  setUp(() async {
    seq = 0;
    db = openTestDatabase();
    await db.accountDao.upsert(
      userId,
      Account(
        id: 'acc-cash',
        name: 'Cash',
        type: AccountType.cash,
        currency: base,
        openingBalance: dt(0),
        sortOrder: 0,
        archived: false,
        updatedAt: DateTime(2026, 8),
      ),
    );
    await db.categoryDao.upsertAll(userId, <Category>[
      Category(
        id: 'cat-salary',
        name: 'Salary',
        kind: CategoryKind.income,
        icon: 'wallet',
        color: 0xFF2A78D6,
        sortOrder: 0,
        isDefault: true,
        updatedAt: DateTime(2026, 8),
      ),
    ]);
    repo = build();
  });

  tearDown(() => db.close());

  group('opening a period', () {
    test('starts one, and refuses a second', () async {
      expect((await repo.start()).isOk, isTrue);
      final second = await repo.start();
      expect(
        second.isErr,
        isTrue,
        reason: 'two open periods would both claim the same income',
      );
    });

    test('income after the start counts toward it', () async {
      await repo.start();
      await income(1000);

      final status = await repo.watchStatus().first;
      expect(status.incomeSoFar, dt(1000));
      expect(status.commitment, dt(300), reason: '30% of what arrived');
      expect(status.target, dt(300), reason: 'nothing owed yet');
      expect(status.reserved, dt(300));
    });

    /// Lean periods commit less rather than failing — income here has arrived
    /// on the 26th, the 16th and the 5th, and a fixed sum would be unpayable.
    test('a lean period commits proportionally less', () async {
      await repo.start();
      await income(150);
      expect((await repo.watchStatus().first).commitment, dt(45));
    });

    test('nothing is reserved when there is no plan', () async {
      final none = build(p: const SavingsPlan(rate: 0));
      await none.start();
      await income(1000);

      final status = await none.watchStatus().first;
      expect(status.hasPlan, isFalse);
      expect(status.reserved.isZero, isTrue);
    });
  });

  group('confirming', () {
    test('freezes the income and commitment onto the period', () async {
      await repo.start();
      await income(1000);
      final confirmed = (await repo.confirm(dt(300))).valueOrNull!;

      expect(confirmed.income, dt(1000));
      expect(confirmed.committed, dt(300));
      expect(confirmed.saved, dt(300));
      expect(confirmed.isConfirmed, isTrue);
    });

    /// Once closed, a period is history: editing an old transaction must not
    /// quietly rewrite what it asked for.
    test('a closed period does not follow later ledger edits', () async {
      await repo.start();
      await income(1000);
      await repo.confirm(dt(300));

      await income(5000);
      final periods = await repo.watchConfirmed().first;
      expect(
        periods.single.income,
        dt(1000),
        reason: 'frozen at confirmation, not re-derived',
      );
    });

    test('confirming with no period open fails', () async {
      expect((await repo.confirm(dt(100))).isErr, isTrue);
    });

    test('a negative amount is refused', () async {
      await repo.start();
      expect((await repo.confirm(dt(-1))).isErr, isTrue);
    });

    test('closing one period allows the next to open', () async {
      await repo.start();
      await income(1000);
      await repo.confirm(dt(300));
      expect((await repo.start()).isOk, isTrue);
    });
  });

  group('the running account', () {
    test('saving less leaves the gap owed, and asks for it next', () async {
      await repo.start();
      await income(1000);
      await repo.confirm(dt(180));

      // The next period begins tomorrow, so its income is its own.
      await repo.start();
      await income(1000, on: day(1));
      final status = await repo.watchStatus().first;

      expect(status.ledger.owed, dt(120));
      expect(
        status.target,
        dt(420),
        reason: 'its own 300, plus the 120 still owed',
      );
      expect(
        status.reserved,
        dt(420),
        reason: 'safe-to-spend holds back the catch-up too',
      );
    });

    /// Stated outright in the design: a good month must not reduce what later
    /// months ask for.
    test('saving more clears the debt but never becomes credit', () async {
      await repo.start();
      await income(1000);
      await repo.confirm(dt(180)); // owes 120

      await repo.start();
      await income(1000, on: day(1));
      await repo.confirm(dt(500)); // 300 of its own plus 200 extra

      await repo.start();
      await income(1000, on: day(2));
      final status = await repo.watchStatus().first;

      expect(status.ledger.owed.isZero, isTrue);
      expect(
        status.target,
        dt(300),
        reason: 'back to a plain share; the surplus bought nothing',
      );
    });

    test('a deleted period leaves the running account', () async {
      await repo.start();
      await income(1000);
      final closed = (await repo.confirm(dt(100))).valueOrNull!;

      await repo.start();
      expect((await repo.watchStatus().first).ledger.owed, dt(200));

      await repo.remove(closed.id);
      expect((await repo.watchStatus().first).ledger.owed.isZero, isTrue);
    });
  });
}
