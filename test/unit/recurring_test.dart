import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/domain/entities/recurring_rule.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

RecurringRule rule({
  required Cadence cadence,
  int? dayOfMonth,
  int? dayOfWeek,
  required DateTime nextRun,
  bool active = true,
}) =>
    RecurringRule(
      id: 'r1',
      type: TxnType.expense,
      amount: const Money(500000, Currency.tnd),
      categoryId: 'cat',
      accountId: 'acc',
      transferAccountId: null,
      note: 'Rent',
      cadence: cadence,
      dayOfMonth: dayOfMonth,
      dayOfWeek: dayOfWeek,
      nextRunDate: nextRun,
      lastRunDate: null,
      active: active,
      updatedAt: DateTime.now(),
    );

void main() {
  group('RecurringRule.advanceFrom', () {
    test('weekly steps exactly seven days', () {
      final r = rule(
        cadence: Cadence.weekly,
        dayOfWeek: 1,
        nextRun: DateTime(2026, 8, 24),
      );
      expect(r.advanceFrom(DateTime(2026, 8, 24)), DateTime(2026, 8, 31));
    });

    test('monthly holds the nominal day across a short month', () {
      final r = rule(
        cadence: Cadence.monthly,
        dayOfMonth: 31,
        nextRun: DateTime(2026, 1, 31),
      );
      // January's 31st clamps into February...
      final february = r.advanceFrom(DateTime(2026, 1, 31));
      expect(february, DateTime(2026, 2, 28));
      // ...and the rule recovers its real day in March rather than staying on
      // the 28th forever.
      expect(r.advanceFrom(february), DateTime(2026, 3, 31));
    });

    test('monthly crosses the year boundary', () {
      final r = rule(
        cadence: Cadence.monthly,
        dayOfMonth: 5,
        nextRun: DateTime(2026, 12, 5),
      );
      expect(r.advanceFrom(DateTime(2026, 12, 5)), DateTime(2027, 1, 5));
    });
  });

  group('RecurringRule.isDueOn', () {
    test('is due on and after the scheduled day', () {
      final r = rule(
        cadence: Cadence.monthly,
        dayOfMonth: 1,
        nextRun: DateTime(2026, 8, 1),
      );
      expect(r.isDueOn(DateTime(2026, 7, 31)), isFalse);
      expect(r.isDueOn(DateTime(2026, 8, 1)), isTrue);
      // Catches up rather than skipping when the app was closed for weeks.
      expect(r.isDueOn(DateTime(2026, 8, 26)), isTrue);
    });

    test('an inactive rule is never due', () {
      final r = rule(
        cadence: Cadence.monthly,
        dayOfMonth: 1,
        nextRun: DateTime(2026, 8, 1),
        active: false,
      );
      expect(r.isDueOn(DateTime(2026, 8, 26)), isFalse);
    });
  });
}
