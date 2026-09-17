import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/domain/entities/recurring_rule.dart';
import 'package:masrouf/domain/entities/savings_goal.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

/// The forecast rests on two pieces of arithmetic that are easy to get subtly
/// wrong and impossible to notice afterwards: enumerating a rule's occurrences,
/// and choosing a baseline that one unusual month cannot distort.
void main() {
  group('occurrencesBetween', () {
    RecurringRule rule({
      required Cadence cadence,
      required DateTime nextRun,
      int? dayOfMonth,
      bool active = true,
    }) =>
        RecurringRule(
          id: 'r',
          type: TxnType.expense,
          amount: const Money(10000, Currency.tnd),
          categoryId: 'c',
          accountId: 'a',
          transferAccountId: null,
          note: null,
          cadence: cadence,
          dayOfMonth: dayOfMonth,
          dayOfWeek: cadence == Cadence.weekly ? nextRun.weekday : null,
          nextRunDate: nextRun,
          lastRunDate: null,
          active: active,
          updatedAt: DateTime(2026, 1, 1),
        );

    test('a weekly rule yields every week in the window, not just one', () {
      // The old behaviour read the stored cursor alone, so a month of a weekly
      // bill counted once — under-reporting commitments by a factor of four.
      final dates = rule(
        cadence: Cadence.weekly,
        nextRun: DateTime(2026, 9, 2),
      ).occurrencesBetween(DateTime(2026, 9, 1), DateTime(2026, 9, 30));

      expect(dates, hasLength(5));
      expect(dates.first, DateTime(2026, 9, 2));
      expect(dates.last, DateTime(2026, 9, 30));
    });

    test('a monthly rule yields once per month', () {
      final dates = rule(
        cadence: Cadence.monthly,
        nextRun: DateTime(2026, 9, 5),
        dayOfMonth: 5,
      ).occurrencesBetween(DateTime(2026, 9, 1), DateTime(2026, 11, 30));

      expect(dates, <DateTime>[
        DateTime(2026, 9, 5),
        DateTime(2026, 10, 5),
        DateTime(2026, 11, 5),
      ]);
    });

    test('a rule on the 31st clamps into short months', () {
      final dates = rule(
        cadence: Cadence.monthly,
        nextRun: DateTime(2027, 1, 31),
        dayOfMonth: 31,
      ).occurrencesBetween(DateTime(2027, 1, 1), DateTime(2027, 3, 31));

      expect(dates.map((d) => d.day), <int>[31, 28, 31],
          reason: 'February has no 31st; it must not skip the month');
    });

    test('a cursor left behind is walked forward into the window', () {
      // An app not opened for months has a stale next_run_ymd. The window still
      // has to see real dates rather than nothing.
      final dates = rule(
        cadence: Cadence.monthly,
        nextRun: DateTime(2026, 1, 10),
        dayOfMonth: 10,
      ).occurrencesBetween(DateTime(2026, 9, 1), DateTime(2026, 10, 31));

      expect(dates, <DateTime>[
        DateTime(2026, 9, 10),
        DateTime(2026, 10, 10),
      ]);
    });

    test('an inactive rule commits nothing', () {
      expect(
        rule(
          cadence: Cadence.monthly,
          nextRun: DateTime(2026, 9, 5),
          dayOfMonth: 5,
          active: false,
        ).occurrencesBetween(DateTime(2026, 9, 1), DateTime(2026, 12, 31)),
        isEmpty,
      );
    });

    test('a backwards window yields nothing rather than looping', () {
      expect(
        rule(cadence: Cadence.weekly, nextRun: DateTime(2026, 9, 2))
            .occurrencesBetween(DateTime(2026, 9, 30), DateTime(2026, 9, 1)),
        isEmpty,
      );
    });

    test('a long horizon is capped rather than unbounded', () {
      final dates = rule(
        cadence: Cadence.weekly,
        nextRun: DateTime(2026, 1, 1),
      ).occurrencesBetween(
        DateTime(2026, 1, 1),
        DateTime(2050, 1, 1),
        maxOccurrences: 10,
      );
      expect(dates, hasLength(10));
    });
  });

  group('savings goal progress', () {
    SavingsGoalProgress progress({
      required int target,
      required int saved,
      DateTime? targetDate,
    }) =>
        SavingsGoalProgress(
          goal: SavingsGoal(
            id: 'g',
            name: 'Trip',
            target: Money(target, Currency.tnd),
            accountId: 'acc-savings',
            targetDate: targetDate,
            updatedAt: DateTime(2026, 1, 1),
          ),
          saved: Money(saved, Currency.tnd),
          accountName: 'Savings',
        );

    test('progress is the account balance against the target', () {
      final p = progress(target: 1000000, saved: 250000);
      expect(p.ratio, closeTo(0.25, 0.001));
      expect(p.remaining.milli, 750000);
      expect(p.isReached, isFalse);
    });

    test('overshooting reaches the goal and leaves nothing remaining', () {
      final p = progress(target: 1000000, saved: 1200000);
      expect(p.isReached, isTrue);
      expect(p.remaining.milli, 0, reason: 'remaining floors at zero');
    });

    test('the monthly requirement divides what is left by the months left', () {
      final p = progress(
        target: 1200000,
        saved: 200000,
        targetDate: DateTime(2027, 3, 1),
      );
      // 1,000,000 left over 5 months from January 2027.
      expect(p.monthsRemaining(DateTime(2026, 10, 15)), 5);
      expect(p.requiredPerMonth(DateTime(2026, 10, 15))!.milli, 200000);
    });

    test('a goal due this month still needs its whole remainder', () {
      final p = progress(
        target: 500000,
        saved: 100000,
        targetDate: DateTime(2026, 10, 20),
      );
      expect(
        p.monthsRemaining(DateTime(2026, 10, 15)),
        1,
        reason: 'never zero months, or the requirement divides by nothing',
      );
      expect(p.requiredPerMonth(DateTime(2026, 10, 15))!.milli, 400000);
    });

    test('a reached goal asks for nothing per month', () {
      final p = progress(
        target: 500000,
        saved: 500000,
        targetDate: DateTime(2027, 1, 1),
      );
      expect(p.requiredPerMonth(DateTime(2026, 10, 15)), isNull);
    });

    test('a goal with no date has no monthly requirement', () {
      expect(
        progress(target: 500000, saved: 100000)
            .requiredPerMonth(DateTime(2026, 10, 15)),
        isNull,
      );
    });
  });
}
