import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/core/time/ym.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/analytics/cashflow_calendar.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

import '../helpers/test_database.dart';

/// The weekly digest reads `daily_totals`, and the calendar reads plans plus
/// enumerated rule occurrences. Neither may include anything that has not
/// happened, or has already been resolved.
void main() {
  late AppDatabase db;
  const userId = 'user-1';
  const base = Currency.tnd;

  Txn expense(String id, int milli, DateTime date) => Txn(
        id: id,
        type: TxnType.expense,
        amount: Money(milli, base),
        fxRateToBase: 1,
        categoryId: 'cat-groceries',
        accountId: 'acc-cash',
        transferAccountId: null,
        date: date,
        note: null,
        tags: const <String>[],
        recurringRuleId: null,
        createdAt: date,
        updatedAt: date,
      );

  setUp(() async {
    db = openTestDatabase();
    await db.accountDao.upsert(
      userId,
      Account(
        id: 'acc-cash',
        name: 'Cash',
        type: AccountType.cash,
        currency: base,
        openingBalance: const Money(1000000, base),
        sortOrder: 0,
        archived: false,
        updatedAt: DateTime.now(),
      ),
    );
    await db.categoryDao.upsertAll(userId, <Category>[
      Category(
        id: 'cat-groceries',
        name: 'Groceries',
        kind: CategoryKind.expense,
        icon: 'groceries',
        color: 0xFF2A78D6,
        sortOrder: 0,
        isDefault: true,
        updatedAt: DateTime.now(),
      ),
    ]);
  });

  tearDown(() => db.close());

  group('weekly totals', () {
    test('only the requested window counts', () async {
      await db.transactionDao
          .insertTxn(userId, expense('in1', 10000, DateTime(2026, 9, 7)), base);
      await db.transactionDao
          .insertTxn(userId, expense('in2', 5000, DateTime(2026, 9, 13)), base);
      // A day either side of the window.
      await db.transactionDao
          .insertTxn(userId, expense('before', 90000, DateTime(2026, 9, 6)), base);
      await db.transactionDao
          .insertTxn(userId, expense('after', 90000, DateTime(2026, 9, 14)), base);

      final total = await db.analyticsDao.expenseBetween(
        userId,
        DateTime(2026, 9, 7),
        DateTime(2026, 9, 13),
      );
      expect(total, 15000);
    });

    test('a week with nothing in it is zero, not an error', () async {
      expect(
        await db.analyticsDao.expenseBetween(
          userId,
          DateTime(2026, 9, 7),
          DateTime(2026, 9, 13),
        ),
        0,
      );
    });

    test('income does not count toward spending', () async {
      await db.transactionDao.insertTxn(
        userId,
        Txn(
          id: 'i1',
          type: TxnType.income,
          amount: const Money(900000, base),
          fxRateToBase: 1,
          categoryId: 'cat-groceries',
          accountId: 'acc-cash',
          transferAccountId: null,
          date: DateTime(2026, 9, 8),
          note: null,
          tags: const <String>[],
          recurringRuleId: null,
          createdAt: DateTime(2026, 9, 8),
          updatedAt: DateTime(2026, 9, 8),
        ),
        base,
      );

      expect(
        await db.analyticsDao.expenseBetween(
          userId,
          DateTime(2026, 9, 7),
          DateTime(2026, 9, 13),
        ),
        0,
      );
    });
  });

  group('CashflowCalendar', () {
    CalendarEntry entry(int day, int milli, CalendarSource source) =>
        CalendarEntry(
          id: '$day-$milli',
          label: 'x',
          amount: Money(milli, base),
          date: DateTime(2026, 9, day),
          source: source,
        );

    test('a day total sums everything falling on it', () {
      final calendar = CashflowCalendar(
        byDay: <int, List<CalendarEntry>>{
          5: <CalendarEntry>[
            entry(5, 30000, CalendarSource.planned),
            entry(5, 20000, CalendarSource.recurring),
          ],
        },
        currency: base,
      );

      expect(calendar.totalFor(5).milli, 50000);
      expect(calendar.total.milli, 50000);
    });

    test('a day with nothing on it totals zero rather than throwing', () {
      const calendar = CashflowCalendar(
        byDay: <int, List<CalendarEntry>>{},
        currency: base,
      );
      expect(calendar.totalFor(12).milli, 0);
      expect(calendar.isEmpty, isTrue);
    });
  });

  group('week boundaries', () {
    test('startOfWeek anchors on Monday', () {
      // The cash-flow chart already buckets weeks from Monday; the digest must
      // agree with it or the two screens report different weeks.
      expect(DateTime(2026, 9, 9).startOfWeek, DateTime(2026, 9, 7));
      expect(DateTime(2026, 9, 7).startOfWeek, DateTime(2026, 9, 7));
      expect(DateTime(2026, 9, 13).startOfWeek, DateTime(2026, 9, 7));
    });
  });

  group('Ym.nextMonths', () {
    test('runs forward from the given month, inclusive', () {
      expect(
        const Ym.of(2026, 11).nextMonths(3).map((m) => m.value),
        <int>[202611, 202612, 202701],
      );
    });
  });
}
