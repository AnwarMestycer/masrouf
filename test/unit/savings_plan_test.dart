import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/domain/entities/savings_plan.dart';

/// The whole scheme reduces to one invariant:
///
///     owed = max(0, everything committed - everything confirmed)
///
/// Saving less grows it. Saving more shrinks it but floors at zero, so a good
/// period never buys credit against a future one. Both halves of that asymmetry
/// are pinned here, because changing either silently changes what the app asks
/// of someone next month.
void main() {
  const base = Currency.tnd;
  Money dt(num amount) => Money((amount * 1000).round(), base);

  const plan = SavingsPlan(rate: 0.30);

  SavingsLedger ledger(num committed, num saved, {SavingsPlan p = plan}) =>
      SavingsLedger(committed: dt(committed), saved: dt(saved), plan: p);

  group('what a period asks for', () {
    test('a share of what actually arrived', () {
      expect(plan.commitmentFor(dt(1000)), dt(300));
      expect(plan.commitmentFor(dt(150)), dt(45));
    });

    /// Income has landed on the 26th, the 16th and the 5th. A lean period is a
    /// smaller commitment, not a missed one.
    test('a lean period commits less rather than failing', () {
      expect(plan.commitmentFor(dt(150)), dt(45));
    });

    test('no income commits nothing', () {
      expect(plan.commitmentFor(dt(0)).isZero, isTrue);
      expect(
        const SavingsPlan(rate: 0.30, floor: Money(50000, base))
            .commitmentFor(dt(0))
            .isZero,
        isTrue,
        reason: 'a floor must not invent a commitment out of an empty period',
      );
    });

    test('a floor lifts a small period, a ceiling caps a windfall', () {
      const bounded = SavingsPlan(
        rate: 0.30,
        floor: Money(100000, base),
        ceiling: Money(400000, base),
      );
      expect(bounded.commitmentFor(dt(200)), dt(100), reason: 'floor applies');
      expect(bounded.commitmentFor(dt(1000)), dt(300), reason: 'inside bounds');
      expect(bounded.commitmentFor(dt(5000)), dt(400), reason: 'ceiling caps');
    });

    test('never commits more than arrived, whatever the floor says', () {
      const bounded = SavingsPlan(rate: 0.30, floor: Money(100000, base));
      expect(
        bounded.commitmentFor(dt(40)),
        dt(40),
        reason: 'you cannot set aside money you did not receive',
      );
    });
  });

  group('saving less', () {
    /// The case that motivated the feature: committed 300, managed 180.
    test('the gap is what you owe yourself', () {
      final l = ledger(300, 180);
      expect(l.owed, dt(120));
      expect(l.isBehind, isTrue);
    });

    test('next period is asked for its own share plus the catch-up', () {
      final l = ledger(300, 180);
      expect(
        l.targetFor(dt(1000)),
        dt(420),
        reason: '300 of its own, plus the 120 still owed',
      );
    });

    test('gaps accumulate across periods', () {
      expect(ledger(900, 500).owed, dt(400));
    });
  });

  group('saving more', () {
    /// Stated outright: a good month must not reduce what later months ask for.
    test('a surplus clears the debt but never becomes credit', () {
      expect(ledger(300, 500).owed.isZero, isTrue);
      expect(
        ledger(300, 500).targetFor(dt(1000)),
        dt(300),
        reason: 'next period still asks for its full share',
      );
    });

    test('an overshoot is reported as ahead rather than owed', () {
      final l = ledger(300, 500);
      expect(l.ahead, dt(200));
      expect(l.isBehind, isFalse);
    });

    /// Catching up is exactly what a surplus is for, so it does pay the debt
    /// down — it simply cannot push it below zero.
    test('a later surplus pays off an earlier shortfall', () {
      // Period one committed 300 and saved 180; period two committed 300 and
      // saved 420, which covers its own share and the 120 owed.
      final l = ledger(600, 600);
      expect(l.owed.isZero, isTrue);
      expect(l.targetFor(dt(1000)), dt(300));
    });

    test('a partial recovery leaves the remainder owed', () {
      final l = ledger(600, 540);
      expect(l.owed, dt(60));
      expect(l.targetFor(dt(1000)), dt(360));
    });
  });

  group('spreading a catch-up', () {
    /// One by default, which is what was asked for: the gap is owed next month.
    test('by default the whole gap is asked for next period', () {
      expect(ledger(300, 0).recoveryInstalment(), dt(300));
    });

    /// A single catch-up can be larger than a period can bear, and an unpayable
    /// target is how a plan like this stops being used.
    test('a spread plan asks for a slice at a time', () {
      const spread = SavingsPlan(rate: 0.30, recoveryPeriods: 3);
      final l = ledger(300, 0, p: spread);
      expect(l.recoveryInstalment(), dt(100));
      expect(l.targetFor(dt(1000)), dt(400));
    });

    test('a spread instalment rounds up so the debt actually clears', () {
      const spread = SavingsPlan(rate: 0.30, recoveryPeriods: 3);
      // 100.001 over three periods is 33.334, not 33.333 — otherwise a millime
      // survives every pass and the debt never reaches zero.
      final l = ledger(100.001, 0, p: spread);
      expect(l.recoveryInstalment(), dt(33.334));
    });

    test('nothing owed asks for nothing extra', () {
      expect(ledger(300, 300).recoveryInstalment().isZero, isTrue);
      expect(ledger(300, 300).targetFor(dt(1000)), dt(300));
    });
  });

  /// Walks the sequence the feature exists for: a normal period, a month where
  /// money had to come back out, and the recovery after it.
  test('a three period run behaves end to end', () {
    // Period 1: 1000 in, commits 300, saves 300.
    var l = ledger(300, 300);
    expect(l.owed.isZero, isTrue);

    // Period 2: 1000 in, commits 300, but only 50 was left.
    l = ledger(600, 350);
    expect(l.owed, dt(250));
    expect(l.targetFor(dt(1000)), dt(550), reason: '300 plus the 250 owed');

    // Period 3: pays the lot back and a little more.
    l = ledger(900, 900);
    expect(l.owed.isZero, isTrue);
    expect(
      l.targetFor(dt(1000)),
      dt(300),
      reason: 'back to a normal period once square',
    );
  });
}
