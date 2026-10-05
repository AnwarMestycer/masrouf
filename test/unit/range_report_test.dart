import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/analytics/date_range.dart';
import 'package:masrouf/domain/entities/analytics/range_report.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

import '../helpers/test_database.dart';

/// The range report is read straight off the ledger because a window that is
/// not a whole calendar month cannot be answered from the monthly aggregate.
/// These check it against hand-countable figures.
void main() {
  late AppDatabase db;
  const userId = 'user-1';
  const base = Currency.tnd;
  const payday = 28;

  var seq = 0;
  Txn txn(
    DateTime date,
    int milli, {
    String category = 'cat-coffee',
    TxnType type = TxnType.expense,
    String? transferTo,
  }) =>
      Txn(
        id: 't${seq++}',
        type: type,
        amount: Money(milli, base),
        fxRateToBase: 1,
        categoryId: type == TxnType.transfer ? null : category,
        accountId: 'acc-cash',
        transferAccountId: transferTo,
        date: date,
        note: null,
        tags: const <String>[],
        recurringRuleId: null,
        createdAt: date,
        updatedAt: date,
      );

  Future<void> add(Txn t) => db.transactionDao.insertTxn(userId, t, base);

  Future<RangeReport> report(DateRange range, {TxnType? slice}) => db
      .analyticsDao
      .watchRangeReport(userId, range, base,
          sliceType: slice ?? TxnType.expense)
      .first;

  setUp(() async {
    db = openTestDatabase();
    seq = 0;
    for (final id in <String>['acc-cash', 'acc-other']) {
      await db.accountDao.upsert(
        userId,
        Account(
          id: id,
          name: id,
          type: AccountType.cash,
          currency: base,
          openingBalance: const Money(1000000, base),
          sortOrder: 0,
          archived: false,
          updatedAt: DateTime(2026, 8),
        ),
      );
    }
    await db.categoryDao.upsertAll(userId, <Category>[
      for (final name in <String>['coffee', 'rent', 'tuition'])
        Category(
          id: 'cat-$name',
          name: name,
          kind: CategoryKind.expense,
          icon: 'groceries',
          color: 0xFF2A78D6,
          sortOrder: 0,
          isDefault: false,
          updatedAt: DateTime(2026, 8),
        ),
    ]);
  });

  tearDown(() => db.close());

  group('the comparison that month-to-month got wrong', () {
    /// Five days of October against the whole of September reported a 78% fall
    /// during a month of heavier spending. The comparable window is the same
    /// stretch of the previous month, so both sides are five days.
    test('compares equal stretches, not whole months', () async {
      // October 1-5: 100 across five days.
      for (var day = 1; day <= 5; day++) {
        await add(txn(DateTime(2026, 10, day), 20000));
      }
      // September 1-5: 50. Then far more later in September, which a whole
      // month comparison would have counted and this must not.
      for (var day = 1; day <= 5; day++) {
        await add(txn(DateTime(2026, 9, day), 10000));
      }
      await add(txn(DateTime(2026, 9, 20), 500000));

      final range = Ranges.resolve(
        RangePreset.thisMonth,
        now: DateTime(2026, 10, 5),
        payday: payday,
      );
      final r = await report(range);

      expect(r.expense, const Money(100000, base));
      expect(
        r.previousExpense,
        const Money(50000, base),
        reason: 'only 1-5 September, not the whole month',
      );
      expect(r.expenseChangeRatio, closeTo(1.0, 0.0001), );
    });

    test('a window with no comparable spending reports no change', () async {
      await add(txn(DateTime(2026, 10, 2), 20000));
      final range = Ranges.resolve(
        RangePreset.thisMonth,
        now: DateTime(2026, 10, 5),
        payday: payday,
      );
      final r = await report(range);

      expect(r.previousExpense.isZero, isTrue);
      expect(
        r.expenseChangeRatio,
        isNull,
        reason: 'dividing by an empty window is infinite, not informative',
      );
    });
  });

  group('large payments', () {
    /// The shape of the real ledger: a long tail of small amounts and one bill
    /// that is most of the total.
    test('a payment that is a tenth of the window is set aside', () async {
      for (var day = 1; day <= 20; day++) {
        await add(txn(DateTime(2026, 9, day), 2000));
      }
      await add(txn(DateTime(2026, 9, 25), 322000, category: 'cat-tuition'));

      final range = Ranges.resolve(
        RangePreset.lastMonth,
        now: DateTime(2026, 10, 5),
        payday: payday,
      );
      final r = await report(range);

      expect(r.expense, const Money(362000, base));
      expect(r.large, hasLength(1));
      expect(r.large.single.amount, const Money(322000, base));
      expect(r.large.single.label, 'tuition');
      expect(r.everyday, const Money(40000, base), reason: '20 x 2.000');
      expect(
        r.medianTxn,
        const Money(2000, base),
        reason: 'the typical purchase, which the mean of 17.238 is not',
      );
    });

    /// The boundary the share test alone could not survive: with exactly ten
    /// equal payments each one *is* a tenth of the window, so a share rule on
    /// its own flags all ten and reports that none of the spending was
    /// everyday. Being large is not the same as being unlike your neighbours.
    test('identical payments are never all outliers', () async {
      for (var day = 1; day <= 10; day++) {
        await add(txn(DateTime(2026, 9, day), 3000));
      }
      final range = Ranges.resolve(
        RangePreset.lastMonth,
        now: DateTime(2026, 10, 5),
        payday: payday,
      );
      final r = await report(range);

      expect(r.large, isEmpty);
      expect(r.everyday, const Money(30000, base));
      expect(r.everyday, r.expense);
    });

    test('an evenly spread window sets nothing aside', () async {
      for (var day = 1; day <= 20; day++) {
        await add(txn(DateTime(2026, 9, day), 5000));
      }
      final range = Ranges.resolve(
        RangePreset.lastMonth,
        now: DateTime(2026, 10, 5),
        payday: payday,
      );
      final r = await report(range);

      expect(r.large, isEmpty);
      expect(r.everyday, r.expense);
    });

    test('everyday per day divides by the window, not by the entries',
        () async {
      for (var day = 1; day <= 10; day++) {
        await add(txn(DateTime(2026, 9, day), 3000));
      }
      final range = DateRange(
        from: DateTime(2026, 9),
        to: DateTime(2026, 9, 30),
      );
      final r = await report(range);

      expect(r.expense, const Money(30000, base));
      expect(r.everydayPerDay, const Money(1000, base), reason: '30.000 over 30 days');
    });
  });

  group('what the window excludes', () {
    test('transfers never reach the totals', () async {
      await add(txn(DateTime(2026, 9, 3), 10000));
      await add(
        txn(DateTime(2026, 9, 4), 500000,
            type: TxnType.transfer, transferTo: 'acc-other'),
      );

      final range = DateRange(
        from: DateTime(2026, 9),
        to: DateTime(2026, 9, 30),
      );
      final r = await report(range);

      expect(
        r.expense,
        const Money(10000, base),
        reason: 'moving money between your own accounts is not spending',
      );
      expect(r.txnCount, 1);
    });

    test('a deleted transaction leaves the window', () async {
      await add(txn(DateTime(2026, 9, 3), 10000));
      final doomed = txn(DateTime(2026, 9, 4), 25000);
      await add(doomed);
      await db.transactionDao.softDeleteTxn(userId, doomed, base);

      final range = DateRange(
        from: DateTime(2026, 9),
        to: DateTime(2026, 9, 30),
      );
      expect((await report(range)).expense, const Money(10000, base));
    });

    test('days outside the window are not counted', () async {
      await add(txn(DateTime(2026, 9, 30), 10000));
      await add(txn(DateTime(2026, 10), 99000));

      final range = DateRange(
        from: DateTime(2026, 9),
        to: DateTime(2026, 9, 30),
      );
      expect((await report(range)).expense, const Money(10000, base));
    });
  });

  group('category slices', () {
    test('are ranked, shared and carry the comparable window', () async {
      await add(txn(DateTime(2026, 10, 2), 30000, category: 'cat-rent'));
      await add(txn(DateTime(2026, 10, 3), 10000));
      await add(txn(DateTime(2026, 9, 2), 20000, category: 'cat-rent'));

      final range = Ranges.resolve(
        RangePreset.thisMonth,
        now: DateTime(2026, 10, 5),
        payday: payday,
      );
      final r = await report(range);

      expect(r.slices.map((s) => s.category?.name), <String>['rent', 'coffee']);
      expect(r.slices.first.total, const Money(30000, base));
      expect(r.slices.first.share, closeTo(0.75, 0.0001));
      expect(r.slices.first.previousTotal, const Money(20000, base));
      expect(r.slices.first.changeRatio, closeTo(0.5, 0.0001));
      expect(
        r.slices.last.previousTotal.isZero,
        isTrue,
        reason: 'coffee had nothing in the comparable window',
      );
    });

    test('the income slice type reports income, not spending', () async {
      await add(txn(DateTime(2026, 10, 2), 30000));
      await add(
        txn(DateTime(2026, 10, 3), 500000,
            type: TxnType.income, category: 'cat-rent'),
      );

      final range = Ranges.resolve(
        RangePreset.thisMonth,
        now: DateTime(2026, 10, 5),
        payday: payday,
      );
      final r = await report(range, slice: TxnType.income);

      expect(r.income, const Money(500000, base));
      expect(r.expense, const Money(30000, base));
      expect(r.slices, hasLength(1));
      expect(r.slices.single.total, const Money(500000, base));
    });
  });

  test('an empty window is empty rather than wrong', () async {
    final range = DateRange(
      from: DateTime(2026, 5),
      to: DateTime(2026, 5, 31),
    );
    final r = await report(range);

    expect(r.isEmpty, isTrue);
    expect(r.expense.isZero, isTrue);
    expect(r.medianTxn.isZero, isTrue);
    expect(r.large, isEmpty);
    expect(r.slices, isEmpty);
    expect(r.expenseChangeRatio, isNull);
  });
}
