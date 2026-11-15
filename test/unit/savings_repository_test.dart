import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/ids.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/time/ym.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/repositories/account_repository_impl.dart';
import 'package:masrouf/data/repositories/analytics_repository_impl.dart';
import 'package:masrouf/data/repositories/planned_repository_impl.dart';
import 'package:masrouf/data/repositories/recurring_repository_impl.dart';
import 'package:masrouf/data/repositories/savings_repository_impl.dart';
import 'package:masrouf/data/repositories/transaction_repository_impl.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/entities/savings_goal.dart';
import 'package:masrouf/domain/entities/savings_plan.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

import '../helpers/app_harness.dart';
import '../helpers/test_database.dart';

/// A month of the plan, walked against a real ledger and a movable clock.
///
/// The month's income and what it has put aside are derived from transactions
/// rather than kept as counters, so these check that both track the ledger
/// while the month is open and stop tracking it once the month has closed.
void main() {
  late AppDatabase db;
  late SyncEngine sync;
  late SavingsRepositoryImpl repo;
  late DateTime now;
  const userId = 'u1';
  const base = Currency.tnd;
  const plan = SavingsPlan(rate: 0.30);

  Money dt(num amount) => Money((amount * 1000).round(), base);

  var seq = 0;
  Future<void> income(num amount, {DateTime? on}) {
    final date = on ?? now;
    return db.transactionDao.insertTxn(
      userId,
      Txn(
        id: 'i${seq++}',
        type: TxnType.income,
        amount: dt(amount),
        fxRateToBase: 1,
        categoryId: 'cat-salary',
        accountId: 'acc-bank',
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

  /// A transfer typed on the add screen, not through the savings sheet.
  Future<void> transfer(String from, String to, num amount, {DateTime? on}) {
    final date = on ?? now;
    return db.transactionDao.insertTxn(
      userId,
      Txn(
        id: 'x${seq++}',
        type: TxnType.transfer,
        amount: dt(amount),
        fxRateToBase: 1,
        categoryId: null,
        accountId: from,
        transferAccountId: to,
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

  Future<Txn> putAside(num amount, {String? goalId, String to = 'acc-save'}) async =>
      (await repo.putAside(
        fromAccountId: 'acc-bank',
        toAccountId: to,
        amount: dt(amount),
        fxRateToBase: 1,
        goalId: goalId,
      ))
          .valueOrNull!;

  SavingsRepositoryImpl build({SavingsPlan p = plan}) {
    final transactions = TransactionRepositoryImpl(
      db: db,
      sync: sync,
      userId: userId,
      base: base,
    );
    return SavingsRepositoryImpl(
      db: db,
      sync: sync,
      transactions: transactions,
      accounts: AccountRepositoryImpl(
        db: db,
        sync: sync,
        userId: userId,
        base: base,
      ),
      userId: userId,
      base: base,
      plan: p,
      clock: () => now,
    );
  }

  Future<SavingsStatus> status() => repo.watchStatus().first;

  Account account(String id, AccountType type, {int sort = 0}) => Account(
        id: id,
        name: id,
        type: type,
        currency: base,
        openingBalance: dt(0),
        sortOrder: sort,
        archived: false,
        updatedAt: DateTime(2026, 8),
      );

  setUp(() async {
    seq = 0;
    now = DateTime(2026, 10, 10, 12);
    db = openTestDatabase();
    sync = testSyncEngine(db);
    await db.accountDao.upsert(userId, account('acc-bank', AccountType.bank));
    await db.accountDao
        .upsert(userId, account('acc-cash', AccountType.cash, sort: 1));
    await db.accountDao
        .upsert(userId, account('acc-save', AccountType.savings, sort: 2));
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

  group('this month', () {
    test('asks for a share of what has arrived, and holds all of it back',
        () async {
      await income(1000);
      final s = await status();
      expect(s.month, const Ym.of(2026, 10));
      expect(s.startedOn, DateTime(2026, 10));
      expect(s.incomeSoFar, dt(1000));
      expect(s.target, dt(300));
      expect(s.reserved, dt(300), reason: 'nothing has been put aside yet');
    });

    test('income from last month is not this month’s', () async {
      await income(1000, on: DateTime(2026, 9, 28));
      expect((await status()).incomeSoFar.isZero, isTrue);
    });

    /// The whole point of saving by transfer: the money has already left the
    /// spendable balance, so holding it back again would count it out twice.
    test('putting money aside lowers what is held back by as much', () async {
      await income(1000);
      await putAside(100);
      await putAside(150);

      final s = await status();
      expect(s.savedSoFar, dt(250));
      expect(s.remaining, dt(50));
      expect(s.reserved, dt(50));
    });

    test('saving beyond the target holds nothing back and shows as ahead',
        () async {
      await income(1000);
      await putAside(400);
      final s = await status();
      expect(s.reserved.isZero, isTrue);
      expect(s.aheadThisMonth, dt(100));
    });

    /// Taking money back makes it spendable again — it is in an ordinary
    /// account once more — but what the month set aside stays set aside.
    test('taking money back does not bring the hold-back back', () async {
      await income(1000);
      await putAside(300);
      await repo.takeBack(
        fromAccountId: 'acc-save',
        toAccountId: 'acc-bank',
        amount: dt(80),
        fxRateToBase: 1,
      );
      final s = await status();
      expect(s.savedSoFar, dt(300));
      expect(s.reserved.isZero, isTrue);
    });

    test('a transfer typed on the add screen counts like one made here',
        () async {
      await income(1000);
      await transfer('acc-bank', 'acc-save', 120);
      expect((await status()).savedSoFar, dt(120));
    });

    test('moving money between two ordinary accounts saves nothing', () async {
      await income(1000);
      await transfer('acc-bank', 'acc-cash', 500);
      expect((await status()).savedSoFar.isZero, isTrue);
    });

    test('moving money between two savings accounts saves nothing', () async {
      await db.accountDao
          .upsert(userId, account('acc-save-2', AccountType.savings, sort: 3));
      await income(1000);
      await putAside(200);
      await transfer('acc-save', 'acc-save-2', 200);
      expect((await status()).savedSoFar, dt(200), reason: 'counted once');
    });

    test('nothing is held back without a plan', () async {
      repo = build(p: const SavingsPlan(rate: 0));
      await income(1000);
      final s = await status();
      expect(s.hasPlan, isFalse);
      expect(s.reserved.isZero, isTrue);
    });
  });

  group('rolling over', () {
    test('opens this month once, under the id every device derives',
        () async {
      await repo.rollOver();
      await repo.rollOver();

      final rows = await db.select(db.savingsPeriods).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, Ids.savingsMonthId(userId, 202610));
      expect(rows.single.confirmedOn, isNull);
    });

    test('writes nothing when there is no plan', () async {
      repo = build(p: const SavingsPlan(rate: 0));
      await repo.rollOver();
      expect(await db.select(db.savingsPeriods).get(), isEmpty);
    });

    test('closes a finished month with its own income and transfers',
        () async {
      await repo.rollOver();
      await income(1000);
      await putAside(250);

      now = DateTime(2026, 11, 1, 9);
      await repo.rollOver();

      final closed = (await repo.watchConfirmed().first).single;
      expect(closed.month, const Ym.of(2026, 10));
      expect(closed.income, dt(1000));
      expect(closed.committed, dt(300));
      expect(closed.saved, dt(250));
      expect(closed.confirmedOn, DateTime(2026, 10, 31));

      final s = await status();
      expect(s.month, const Ym.of(2026, 11));
      expect(s.startedOn, DateTime(2026, 11));
      expect(s.ledger.owed, dt(50));
    });

    /// Once closed, a month is history: editing an old transaction must not
    /// quietly rewrite what it asked for.
    test('a closed month does not follow later ledger edits', () async {
      await repo.rollOver();
      await income(1000);
      now = DateTime(2026, 11, 1);
      await repo.rollOver();

      await income(5000, on: DateTime(2026, 10, 15));
      expect((await repo.watchConfirmed().first).single.income, dt(1000));
    });

    test('a shortfall is asked for again next month', () async {
      await repo.rollOver();
      await income(1000);
      await putAside(180);

      now = DateTime(2026, 11, 3);
      await repo.rollOver();
      await income(1000);

      final s = await status();
      expect(s.ledger.owed, dt(120));
      expect(s.target, dt(420), reason: 'its own 300, plus the 120 owed');
      expect(s.reserved, dt(420));
    });

    /// Stated outright in the design: a good month must not reduce what later
    /// months ask for.
    test('a surplus clears the debt but never becomes credit', () async {
      await repo.rollOver();
      await income(1000);
      await putAside(180); // owes 120

      now = DateTime(2026, 11, 3);
      await repo.rollOver();
      await income(1000);
      await putAside(600); // 420 asked, 180 over

      now = DateTime(2026, 12, 2);
      await repo.rollOver();
      await income(1000);

      final s = await status();
      expect(s.ledger.owed.isZero, isTrue);
      expect(s.target, dt(300), reason: 'the surplus bought nothing');
    });

    test('months the app was never opened in are still closed', () async {
      await repo.rollOver();
      await income(1000, on: DateTime(2026, 11, 5));

      now = DateTime(2027, 1, 4);
      await repo.rollOver();

      final months = (await repo.watchConfirmed().first)
          .map((p) => p.month)
          .toList();
      expect(months, <Ym>[
        const Ym.of(2026, 12),
        const Ym.of(2026, 11),
        const Ym.of(2026, 10),
      ]);
      final november = (await repo.watchConfirmed().first)[1];
      expect(november.committed, dt(300));
      expect(november.saved, dt(0));
    });

    /// A plan switched back on after months off must not invent commitments
    /// for the months it was off.
    test('nothing is filled in when no month was open', () async {
      repo = build(p: const SavingsPlan(rate: 0));
      await repo.rollOver();
      now = DateTime(2027, 3, 2);
      repo = build();
      await repo.rollOver();

      final rows = await db.select(db.savingsPeriods).get();
      expect(rows.single.id, Ids.savingsMonthId(userId, 202703));
    });

    test('a deleted month stays deleted', () async {
      await repo.rollOver();
      await repo.removePeriod(Ids.savingsMonthId(userId, 202610));
      await repo.rollOver();

      final rows = await db.select(db.savingsPeriods).get();
      expect(rows.single.deletedAt, isNotNull);
    });
  });

  group('periods from before months', () {
    Future<void> legacy({
      required DateTime startedOn,
      DateTime? confirmedOn,
      Money? saved,
    }) =>
        db.savingsDao.upsert(
          userId,
          SavingsPeriod(
            id: 'legacy',
            startedOn: startedOn,
            income: dt(0),
            committed: confirmedOn == null ? dt(0) : dt(300),
            confirmedOn: confirmedOn,
            saved: saved,
            updatedAt: startedOn,
          ),
        );

    /// Transactions carry a day and no time, so two periods sharing a day
    /// would both count that day's income.
    test('one confirmed mid-month starts the month the day after', () async {
      await legacy(
        startedOn: DateTime(2026, 9, 20),
        confirmedOn: DateTime(2026, 10, 4),
        saved: dt(300),
      );
      await income(1000, on: DateTime(2026, 10, 3));
      await income(500, on: DateTime(2026, 10, 6));

      final s = await status();
      expect(s.startedOn, DateTime(2026, 10, 5));
      expect(s.incomeSoFar, dt(500), reason: 'the 3rd belongs to the old one');
    });

    test('one still open closes as of yesterday, and the month takes over',
        () async {
      await legacy(startedOn: DateTime(2026, 10, 3));
      await income(1000, on: DateTime(2026, 10, 4));
      await putAside(100);
      await repo.rollOver();

      final old = await db.savingsDao.getById('legacy');
      expect(old!.confirmedOn, DateTime(2026, 10, 9));
      expect(old.income, dt(1000));
      expect(
        old.saved!.isZero,
        isTrue,
        reason: 'today’s saving belongs to the month that starts today',
      );

      final s = await status();
      expect(s.startedOn, DateTime(2026, 10, 10));
      expect(s.savedSoFar, dt(100));
    });

    test('one opened today is dropped rather than closed empty', () async {
      await legacy(startedOn: DateTime(2026, 10, 10));
      await repo.rollOver();
      final old = await (db.select(db.savingsPeriods)
            ..where((t) => t.id.equals('legacy')))
          .getSingle();
      expect(old.deletedAt, isNotNull);
    });
  });

  group('reviewing a month', () {
    Future<SavingsPeriod> closedOctober() async {
      await repo.rollOver();
      await income(1000);
      await putAside(200);
      now = DateTime(2026, 11, 1);
      await repo.rollOver();
      return (await repo.watchConfirmed().first).single;
    }

    test('records money saved outside the app', () async {
      final october = await closedOctober();
      expect((await status()).ledger.owed, dt(100));

      await repo.review(october.id, dt(300));
      expect((await status()).ledger.owed.isZero, isTrue);
    });

    test('refuses a negative amount, and an open month', () async {
      final october = await closedOctober();
      expect((await repo.review(october.id, dt(-1))).isErr, isTrue);
      expect(
        (await repo.review(Ids.savingsMonthId(userId, 202611), dt(1))).isErr,
        isTrue,
      );
    });
  });

  group('transfers', () {
    test('putting aside needs a savings account on the receiving end',
        () async {
      final result = await repo.putAside(
        fromAccountId: 'acc-bank',
        toAccountId: 'acc-cash',
        amount: dt(10),
        fxRateToBase: 1,
      );
      expect(result.isErr, isTrue);
    });

    test('taking back needs a savings account on the sending end', () async {
      final result = await repo.takeBack(
        fromAccountId: 'acc-bank',
        toAccountId: 'acc-save',
        amount: dt(10),
        fxRateToBase: 1,
      );
      expect(result.isErr, isTrue);
    });

    test('a saving is a transfer, so analytics never counts it as spending',
        () async {
      final txn = await putAside(100);
      expect(txn.type, TxnType.transfer);
      expect(txn.categoryId, isNull);
    });

    test('creates a savings account only when there is none', () async {
      final existing = await repo.ensureSavingsAccount('Savings');
      expect(existing.valueOrNull!.id, 'acc-save');

      await db.accountDao.softDelete('acc-save');
      final created = await repo.ensureSavingsAccount('Savings');
      expect(created.valueOrNull!.type, AccountType.savings);
      expect(created.valueOrNull!.id, isNot('acc-save'));
    });
  });

  group('goals', () {
    SavingsGoal goal(String id) => SavingsGoal(
          id: id,
          name: id,
          target: dt(1000),
          accountId: 'acc-save',
          targetDate: null,
          updatedAt: DateTime(2026, 10),
        );

    Future<Map<String, Money>> progress() async => <String, Money>{
          for (final g in await repo.watchGoals().first) g.goal.id: g.saved,
        };

    /// What went wrong when progress was the account's whole balance: two
    /// goals on one account each claimed all of it.
    test('two goals on one account each hold only their own', () async {
      await repo.saveGoal(goal('car'));
      await repo.saveGoal(goal('hajj'));
      await putAside(300, goalId: 'car');
      await putAside(150, goalId: 'hajj');
      await putAside(50);

      expect(await progress(), <String, Money>{
        'car': dt(300),
        'hajj': dt(150),
      });
    });

    test('starts from zero, whatever the account already holds', () async {
      await transfer('acc-bank', 'acc-save', 900);
      await repo.saveGoal(goal('car'));
      expect((await progress())['car'], dt(0));
    });

    test('taking back reduces the goal it came from', () async {
      await repo.saveGoal(goal('car'));
      await putAside(300, goalId: 'car');
      await repo.takeBack(
        fromAccountId: 'acc-save',
        toAccountId: 'acc-bank',
        amount: dt(120),
        fxRateToBase: 1,
        goalId: 'car',
      );
      expect((await progress())['car'], dt(180));
    });

    test('refuses to take back more than the goal holds', () async {
      await repo.saveGoal(goal('car'));
      await putAside(100, goalId: 'car');
      final result = await repo.takeBack(
        fromAccountId: 'acc-save',
        toAccountId: 'acc-bank',
        amount: dt(150),
        fxRateToBase: 1,
        goalId: 'car',
      );
      expect(result.isErr, isTrue);
      expect((await progress())['car'], dt(100));
    });

    test('an edit on the add screen keeps the transfer’s goal', () async {
      await repo.saveGoal(goal('car'));
      final saved = await putAside(100, goalId: 'car');
      // The edit screen builds a fresh Txn with no goal on it.
      final edited = Txn(
        id: saved.id,
        type: TxnType.transfer,
        amount: dt(140),
        fxRateToBase: 1,
        categoryId: null,
        accountId: 'acc-bank',
        transferAccountId: 'acc-save',
        date: saved.date,
        note: null,
        tags: const <String>[],
        recurringRuleId: null,
        createdAt: now,
        updatedAt: now,
      );
      await TransactionRepositoryImpl(
        db: db,
        sync: sync,
        userId: userId,
        base: base,
      ).update(edited);
      expect((await progress())['car'], dt(140));
    });

    test('removing a goal leaves its money where it is', () async {
      await repo.saveGoal(goal('car'));
      await putAside(300, goalId: 'car');
      await repo.removeGoal('car');

      expect(await repo.watchGoals().first, isEmpty);
      expect((await status()).savedSoFar, dt(300));
    });
  });

  group('safe to spend', () {
    Future<Money> safeToSpend(Money reserved) {
      final transactions = TransactionRepositoryImpl(
        db: db,
        sync: sync,
        userId: userId,
        base: base,
      );
      return AnalyticsRepositoryImpl(
        db: db,
        recurring: RecurringRepositoryImpl(
          db: db,
          sync: sync,
          userId: userId,
          base: base,
        ),
        planned: PlannedRepositoryImpl(
          db: db,
          sync: sync,
          transactions: transactions,
          userId: userId,
          base: base,
        ),
        userId: userId,
        base: base,
        paydayDayOfMonth: 25,
        ratesToBase: const <String, double>{},
        savingsReserved: reserved,
      ).safeToSpend().then((s) => s.amount);
    }

    /// Before this, a savings account counted as spendable, so last month's
    /// savings were offered back as this week's spending money.
    test('leaves savings accounts out, and holds back only what is left',
        () async {
      await income(2000);
      expect(await safeToSpend((await status()).reserved), dt(2000 - 600));

      await putAside(450);
      final s = await status();
      expect(s.reserved, dt(150));
      expect(
        await safeToSpend(s.reserved),
        dt(2000 - 450 - 150),
        reason: 'the 450 is out of the bank, and is not held back again',
      );
    });

    test('money taken back is spendable again', () async {
      await income(2000);
      await putAside(600);
      await repo.takeBack(
        fromAccountId: 'acc-save',
        toAccountId: 'acc-bank',
        amount: dt(100),
        fxRateToBase: 1,
      );
      expect(
        await safeToSpend((await status()).reserved),
        dt(2000 - 600 + 100),
      );
    });
  });
}
