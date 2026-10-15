import 'package:masrouf/core/money/money.dart';
import 'package:meta/meta.dart';

/// How much of what comes in is meant to be set aside.
///
/// A share of income rather than a fixed sum, because income here is not
/// monthly-on-a-date: it has arrived on the 26th, the 16th and the 5th. A fixed
/// amount is unpayable in a lean month and leaves money on the table in a good
/// one, while a share self-scales to whatever actually landed.
@immutable
class SavingsPlan {
  const SavingsPlan({
    required this.rate,
    this.floor,
    this.ceiling,
    this.recoveryPeriods = 1,
  });

  /// 0.30 for 30%.
  final double rate;

  /// Set aside at least this much even in a lean period, if there is income at
  /// all. Null for no floor.
  final Money? floor;

  /// Never commit more than this from a single period — a freelance windfall
  /// should not commit a sum that leaves nothing to live on. Null for no cap.
  final Money? ceiling;

  /// How many periods a shortfall is spread across before it is asked for in
  /// full.
  ///
  /// One by default: a gap is asked for in the very next period, which is the
  /// simplest thing to hold yourself to. Raise it when a single catch-up would
  /// be larger than a period can bear — an unpayable target is how this kind of
  /// plan stops being used.
  final int recoveryPeriods;

  /// What this plan asks of a period that received [income].
  ///
  /// Zero income commits nothing: there is nothing to take a share of, and
  /// applying the floor would invent a commitment out of an empty period.
  Money commitmentFor(Money income) {
    if (!income.isPositive) return Money.zero(income.currency);

    var amount = Money((income.milli * rate).round(), income.currency);

    final min = floor;
    if (min != null && amount < min) amount = min;

    final max = ceiling;
    if (max != null && max < amount) amount = max;

    // Never commit more than arrived, whatever the floor says.
    return income < amount ? income : amount;
  }
}

/// One cycle of the plan: what was asked, and what was actually set aside.
///
/// A period is closed by confirming it rather than by a date. Income does not
/// arrive on a schedule here, so "the end of the month" is not a moment the
/// ledger can recognise — but "I have counted what I saved" is.
@immutable
class SavingsPeriod {
  const SavingsPeriod({
    required this.id,
    required this.startedOn,
    required this.income,
    required this.committed,
    required this.confirmedOn,
    required this.saved,
    required this.updatedAt,
  });

  final String id;
  final DateTime startedOn;

  /// Income counted into this period so far. Grows until the period is closed.
  final Money income;

  /// The share of [income] this plan asked for, frozen when the period closed.
  final Money committed;

  final DateTime? confirmedOn;

  /// What was actually set aside. Null until confirmed.
  final Money? saved;

  final DateTime updatedAt;

  bool get isOpen => confirmedOn == null;
  bool get isConfirmed => confirmedOn != null;
}

/// The running account between the plan and what was actually saved.
///
/// Everything here derives from one invariant:
///
///     owed = max(0, everything committed - everything confirmed)
///
/// Saving less grows it by the gap. Saving more shrinks it, but it floors at
/// zero, so a good period never buys credit against a future one — which is the
/// asymmetry that keeps the plan honest in both directions.
@immutable
class SavingsLedger {
  const SavingsLedger({
    required this.committed,
    required this.saved,
    required this.plan,
  });

  /// Total committed across every closed period.
  final Money committed;

  /// Total confirmed across every closed period.
  final Money saved;

  final SavingsPlan plan;

  /// What is still owed to yourself.
  Money get owed {
    final gap = committed - saved;
    return gap.isPositive ? gap : Money.zero(committed.currency);
  }

  bool get isBehind => owed.isPositive;

  /// Saved beyond what was ever asked for. Carries no entitlement — it exists
  /// so the screen can say "ahead" rather than only "not behind".
  Money get ahead {
    final over = saved - committed;
    return over.isPositive ? over : Money.zero(committed.currency);
  }

  /// The slice of [owed] asked for in the next period.
  ///
  /// Spread across [SavingsPlan.recoveryPeriods], rounded up so the debt
  /// actually clears rather than leaving a millime behind forever.
  Money recoveryInstalment() {
    if (!isBehind) return Money.zero(committed.currency);
    final periods = plan.recoveryPeriods < 1 ? 1 : plan.recoveryPeriods;
    if (periods == 1) return owed;
    return Money(
      (owed.milli + periods - 1) ~/ periods,
      committed.currency,
    );
  }

  /// What the next period should aim for: its own share, plus catching up.
  Money targetFor(Money income) =>
      plan.commitmentFor(income) + recoveryInstalment();
}

/// Everything the savings screen and safe-to-spend read, in one value.
///
/// The open period's income is *derived* from the ledger rather than kept as a
/// running counter on the row — a counter is a second set of books, and the
/// savings goals in this app already show what happens when progress is stored
/// apart from the transactions that caused it. Income and commitment are frozen
/// onto the row only when the period is confirmed.
@immutable
class SavingsStatus {
  const SavingsStatus({
    required this.plan,
    required this.open,
    required this.incomeSoFar,
    required this.ledger,
  });

  final SavingsPlan plan;

  /// The period being accumulated, or null when none is open.
  final SavingsPeriod? open;

  /// Income received since the open period started. Zero when none is open.
  final Money incomeSoFar;

  /// The running account across every confirmed period.
  final SavingsLedger ledger;

  bool get hasPlan => plan.rate > 0;
  bool get isOpen => open != null;

  /// This period's own share, before any catching up.
  Money get commitment => plan.commitmentFor(incomeSoFar);

  /// What this period should aim for: its share plus the catch-up instalment.
  Money get target => commitment + ledger.recoveryInstalment();

  /// What safe-to-spend must hold back.
  ///
  /// The whole target, because nothing has been set aside yet — the money is
  /// still sitting in the account it arrived in. Reserving only part of it
  /// would be telling someone they can spend what they have already promised
  /// themselves.
  Money get reserved =>
      hasPlan && isOpen ? target : Money.zero(incomeSoFar.currency);
}
