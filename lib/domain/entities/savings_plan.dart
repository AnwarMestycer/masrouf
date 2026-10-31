import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/core/time/ym.dart';
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

/// One month of the plan: what it asked, and what was actually set aside.
///
/// A period is a calendar month. It opens by itself and closes by itself once
/// the month is over; nothing waits on a button. Closing freezes the month's
/// income, its share and what was saved onto the row, because from then on it
/// is history and must not move when an old transaction is edited.
///
/// Rows written before monthly periods existed were opened and confirmed by
/// hand and may span any stretch of days. They stay as they are: their
/// commitments and confirmations still count toward what is owed.
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

  /// The first day the period counts. The first of the month, except for the
  /// month in which an older hand-confirmed period ended — see
  /// [SavingsCalendar.windowStart].
  final DateTime startedOn;

  /// Income counted into this period. Zero until the period is closed.
  final Money income;

  /// The share of [income] this plan asked for, frozen when the period closed.
  final Money committed;

  /// The last day the period covers, set when it closes. Null while open.
  ///
  /// For a monthly period this is the month's last day rather than the day it
  /// happened to be closed on, so the next period's start follows from it
  /// directly.
  final DateTime? confirmedOn;

  /// What was set aside. Null until closed.
  final Money? saved;

  final DateTime updatedAt;

  bool get isOpen => confirmedOn == null;
  bool get isConfirmed => confirmedOn != null;

  /// The month this period belongs to.
  Ym get month => Ym.fromDate(startedOn);

  SavingsPeriod copyWith({Money? saved, DateTime? updatedAt}) => SavingsPeriod(
        id: id,
        startedOn: startedOn,
        income: income,
        committed: committed,
        confirmedOn: confirmedOn,
        saved: saved ?? this.saved,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// The day boundaries of a monthly period.
///
/// Pure, so the two edges that have each been got wrong once are pinned by
/// tests rather than by care.
abstract final class SavingsCalendar {
  /// The first day [month] counts income and savings from.
  ///
  /// The first of the month, unless an earlier period already covers some of
  /// it — then the day after that one ends. Transactions carry a calendar day
  /// and no time, so two periods sharing a day would both count that day's
  /// income. Only arises in the month a hand-confirmed period ended in.
  static DateTime windowStart(Ym month, DateTime? lastCovered) {
    final first = month.firstDay;
    if (lastCovered == null) return first;
    final after = lastCovered.dateOnly.add(const Duration(days: 1));
    return after.isAfter(first) ? after : first;
  }

  /// The last day of [month] to count, as of [today].
  ///
  /// Today while the month is running, the month's last day once it is over.
  /// Never earlier than [start]: a window that begins tomorrow would otherwise
  /// be asked about an empty range and report a commitment of nothing.
  static DateTime windowEnd(Ym month, DateTime start, DateTime today) {
    final last = month.lastDay;
    final day = today.dateOnly;
    final end = day.isAfter(last) ? last : day;
    return start.isAfter(end) ? start : end;
  }
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

  /// The slice of [owed] asked for in the open month.
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
/// The month's income and what has been saved so far are *derived* from the
/// ledger rather than kept as running counters on the row — a counter is a
/// second set of books. Both are frozen onto the row only when the month
/// closes.
@immutable
class SavingsStatus {
  const SavingsStatus({
    required this.plan,
    required this.month,
    required this.startedOn,
    required this.incomeSoFar,
    required this.savedSoFar,
    required this.ledger,
  });

  final SavingsPlan plan;

  /// The month being accumulated. Always the current one.
  final Ym month;

  /// The first day this month counts, normally the 1st.
  final DateTime startedOn;

  /// Income received this month so far.
  final Money incomeSoFar;

  /// Moved into savings accounts this month so far.
  ///
  /// Money in only. Taking money back out makes it spendable again — it is in
  /// an ordinary account once more — but it does not undo what this month set
  /// aside, so it does not bring the hold-back back either.
  final Money savedSoFar;

  /// The running account across every closed period.
  final SavingsLedger ledger;

  bool get hasPlan => plan.rate > 0;

  /// This month's own share, before any catching up.
  Money get commitment => plan.commitmentFor(incomeSoFar);

  /// What this month should aim for: its share plus the catch-up instalment.
  Money get target => commitment + ledger.recoveryInstalment();

  /// What is still to be set aside this month. Never negative.
  Money get remaining {
    final left = target - savedSoFar;
    return left.isPositive ? left : Money.zero(target.currency);
  }

  /// Set aside beyond this month's target.
  Money get aheadThisMonth {
    final over = savedSoFar - target;
    return over.isPositive ? over : Money.zero(target.currency);
  }

  /// What safe-to-spend must hold back.
  ///
  /// Only what is still to be saved. Whatever has already been moved into a
  /// savings account has left the spendable balance by itself; reserving it
  /// again would count the same money out twice.
  Money get reserved =>
      hasPlan ? remaining : Money.zero(incomeSoFar.currency);
}
