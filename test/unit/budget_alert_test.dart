import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/notifications/budget_alert.dart';
import 'package:masrouf/core/time/ym.dart';
import 'package:masrouf/domain/entities/budget.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

/// Budget alerts are the one notification the app fires without being asked at a
/// particular time, so the deduplication rules are the whole feature: an alert
/// that repeats on every write would be worse than no alert at all.
void main() {
  const base = Currency.tnd;
  const ym = Ym.of(2026, 10);

  Category category(String id) => Category(
        id: id,
        name: 'Groceries',
        kind: CategoryKind.expense,
        icon: 'groceries',
        color: 0xFF2A78D6,
        sortOrder: 0,
        isDefault: false,
        updatedAt: DateTime(2026, 10, 1),
      );

  BudgetProgress progressAt(
    String id,
    int capMilli,
    int spentMilli, {
    bool withCategory = true,
  }) =>
      BudgetProgress(
        budget: Budget(
          id: id,
          categoryId: 'cat-$id',
          amount: Money(capMilli, base),
          updatedAt: DateTime(2026, 10, 1),
        ),
        category: withCategory ? category('cat-$id') : null,
        spent: Money(spentMilli, base),
      );

  String keyFor(String id, BudgetAlertLevel level) =>
      BudgetAlerts.flagKey(id, ym, level);

  group('crossing', () {
    test('a budget under 80% fires nothing', () {
      final decision = BudgetAlerts.evaluate(
        progress: <BudgetProgress>[progressAt('b1', 100000, 50000)],
        firedKeys: <String>{},
        ym: ym,
      );

      expect(decision.toFire, isEmpty);
      expect(decision.toMark, isEmpty);
    });

    test('crossing 80% fires the near-limit alert and flags it', () {
      final decision = BudgetAlerts.evaluate(
        progress: <BudgetProgress>[progressAt('b1', 100000, 85000)],
        firedKeys: <String>{},
        ym: ym,
      );

      expect(decision.toFire, hasLength(1));
      expect(decision.toFire.single.level, BudgetAlertLevel.nearLimit);
      expect(decision.toMark, <String>[keyFor('b1', BudgetAlertLevel.nearLimit)]);
    });

    test('spending exactly the cap counts as overspent', () {
      final decision = BudgetAlerts.evaluate(
        progress: <BudgetProgress>[progressAt('b1', 100000, 100000)],
        firedKeys: <String>{},
        ym: ym,
      );

      expect(decision.toFire.single.level, BudgetAlertLevel.overspent);
    });

    /// Reaching the line is worth reporting, so the crossing still fires — but
    /// BudgetProgress.isOver is strictly greater, so at exactly the cap an
    /// "over budget" message contradicts every screen showing the same budget
    /// and quotes an overage of zero. Observed on a device: "Rent is over
    /// budget — 115.000 DT of 115.000 DT used — 0.000 DT over."
    test('exactly at the cap is fully spent, not over', () {
      final decision = BudgetAlerts.evaluate(
        progress: <BudgetProgress>[progressAt('b1', 115000, 115000)],
        firedKeys: <String>{},
        ym: ym,
      );

      final alert = decision.toFire.single;
      expect(alert.level, BudgetAlertLevel.overspent);
      expect(alert.isFullySpent, isTrue);
      expect(alert.progress.overspend.milli, 0);
      expect(
        alert.progress.isOver,
        isFalse,
        reason: 'the alert must agree with what the budgets screen says',
      );
    });

    test('a single millime over is a real overspend', () {
      final decision = BudgetAlerts.evaluate(
        progress: <BudgetProgress>[progressAt('b1', 115000, 115001)],
        firedKeys: <String>{},
        ym: ym,
      );

      final alert = decision.toFire.single;
      expect(alert.isFullySpent, isFalse);
      expect(alert.progress.overspend.milli, 1);
      expect(alert.progress.isOver, isTrue);
    });

    test('being under the cap is never reported as fully spent', () {
      final decision = BudgetAlerts.evaluate(
        progress: <BudgetProgress>[progressAt('b1', 100000, 85000)],
        firedKeys: <String>{},
        ym: ym,
      );

      expect(decision.toFire.single.isFullySpent, isFalse);
    });

    /// One write can take a budget past both lines. Saying "nearly there" and
    /// "over budget" in the same breath reads as a bug, so only the higher one
    /// is shown — but both are flagged, or the 80% alert would fire later when
    /// the user drops back under 100%.
    test('a jump past both levels fires once but flags both', () {
      final decision = BudgetAlerts.evaluate(
        progress: <BudgetProgress>[progressAt('b1', 100000, 130000)],
        firedKeys: <String>{},
        ym: ym,
      );

      expect(decision.toFire, hasLength(1));
      expect(decision.toFire.single.level, BudgetAlertLevel.overspent);
      expect(
        decision.toMark.toSet(),
        <String>{
          keyFor('b1', BudgetAlertLevel.nearLimit),
          keyFor('b1', BudgetAlertLevel.overspent),
        },
      );
    });
  });

  group('deduplication', () {
    test('an already-flagged level does not fire again', () {
      final decision = BudgetAlerts.evaluate(
        progress: <BudgetProgress>[progressAt('b1', 100000, 85000)],
        firedKeys: <String>{keyFor('b1', BudgetAlertLevel.nearLimit)},
        ym: ym,
      );

      expect(decision.toFire, isEmpty);
      expect(decision.toMark, isEmpty);
      expect(decision.toClear, isEmpty);
    });

    test('passing 100% still fires for a budget already flagged at 80%', () {
      final decision = BudgetAlerts.evaluate(
        progress: <BudgetProgress>[progressAt('b1', 100000, 110000)],
        firedKeys: <String>{keyFor('b1', BudgetAlertLevel.nearLimit)},
        ym: ym,
      );

      expect(decision.toFire.single.level, BudgetAlertLevel.overspent);
      expect(decision.toMark, <String>[keyFor('b1', BudgetAlertLevel.overspent)]);
    });

    /// Raising a cap, or deleting the transaction that blew it, puts the user
    /// back under the line. Leaving the flag set would mean they were never told
    /// again that month — so the flag is cleared and the alert re-armed.
    test('falling back below a flagged level clears the flag', () {
      final decision = BudgetAlerts.evaluate(
        progress: <BudgetProgress>[progressAt('b1', 100000, 40000)],
        firedKeys: <String>{
          keyFor('b1', BudgetAlertLevel.nearLimit),
          keyFor('b1', BudgetAlertLevel.overspent),
        },
        ym: ym,
      );

      expect(decision.toFire, isEmpty);
      expect(
        decision.toClear.toSet(),
        <String>{
          keyFor('b1', BudgetAlertLevel.nearLimit),
          keyFor('b1', BudgetAlertLevel.overspent),
        },
      );
    });

    /// A cap is recurring, so October's alert says nothing about November.
    test('the flag key is scoped to the month', () {
      expect(
        BudgetAlerts.flagKey('b1', const Ym.of(2026, 10), BudgetAlertLevel.nearLimit),
        isNot(
          BudgetAlerts.flagKey(
            'b1',
            const Ym.of(2026, 11),
            BudgetAlertLevel.nearLimit,
          ),
        ),
      );
    });
  });

  group('what never alerts', () {
    test('a budget whose category was deleted is skipped', () {
      final decision = BudgetAlerts.evaluate(
        progress: <BudgetProgress>[
          progressAt('b1', 100000, 150000, withCategory: false),
        ],
        firedKeys: <String>{},
        ym: ym,
      );

      expect(decision.toFire, isEmpty);
      expect(decision.toMark, isEmpty);
    });

    /// `BudgetProgress.ratio` reports 0 for a zero cap rather than infinity, so
    /// without the explicit guard a zero-cap budget would look permanently fine;
    /// with it, it is explicitly never alerted on.
    test('a zero cap never crosses', () {
      final decision = BudgetAlerts.evaluate(
        progress: <BudgetProgress>[progressAt('b1', 0, 50000)],
        firedKeys: <String>{},
        ym: ym,
      );

      expect(decision.toFire, isEmpty);
    });
  });

  test('several budgets are evaluated independently', () {
    final decision = BudgetAlerts.evaluate(
      progress: <BudgetProgress>[
        progressAt('under', 100000, 10000),
        progressAt('near', 100000, 90000),
        progressAt('over', 100000, 120000),
      ],
      firedKeys: <String>{},
      ym: ym,
    );

    expect(
      <String, BudgetAlertLevel>{
        for (final alert in decision.toFire) alert.budgetId: alert.level,
      },
      <String, BudgetAlertLevel>{
        'near': BudgetAlertLevel.nearLimit,
        'over': BudgetAlertLevel.overspent,
      },
    );
  });
}
