import 'package:masrouf/core/money/money.dart';
import 'package:meta/meta.dart';

/// A savings target, fed by transfers into savings accounts.
///
/// A goal holds no money and no total. Its progress is the transfers
/// earmarked for it — into a savings account, minus back out — so it cannot
/// drift from the ledger, and two goals can never both claim the same dinar.
/// Held in the base currency: the editor only creates it there.
@immutable
class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.target,
    required this.accountId,
    required this.targetDate,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final Money target;

  /// The savings account money for this goal goes to by default.
  ///
  /// Not where progress comes from. It once was — the account's whole balance
  /// — which let two goals on one account each claim all of it.
  final String accountId;

  final DateTime? targetDate;
  final DateTime updatedAt;

  SavingsGoal copyWith({
    String? name,
    Money? target,
    String? accountId,
    DateTime? targetDate,
    DateTime? updatedAt,
    bool clearTargetDate = false,
  }) =>
      SavingsGoal(
        id: id,
        name: name ?? this.name,
        target: target ?? this.target,
        accountId: accountId ?? this.accountId,
        targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavingsGoal &&
          other.id == id &&
          other.name == name &&
          other.target == target &&
          other.accountId == accountId &&
          other.targetDate == targetDate);

  @override
  int get hashCode => Object.hash(id, name, target, accountId, targetDate);
}

/// A goal with what has actually been set aside for it.
@immutable
class SavingsGoalProgress {
  const SavingsGoalProgress({
    required this.goal,
    required this.saved,
    required this.accountName,
  });

  final SavingsGoal goal;

  /// Earmarked transfers into savings accounts minus those taken back out, in
  /// the base currency at each transfer's frozen rate.
  final Money saved;

  /// The default savings account's name.
  final String accountName;

  Money get remaining {
    final left = goal.target.milli - saved.milli;
    return left <= 0
        ? Money.zero(goal.target.currency)
        : Money(left, goal.target.currency);
  }

  double get ratio =>
      goal.target.milli == 0 ? 0 : saved.milli / goal.target.milli;

  bool get isReached => saved.milli >= goal.target.milli;

  /// Whole months from now until the target date, at least one.
  ///
  /// At least one because a goal due this month still needs its whole remainder
  /// this month — dividing by zero, or by a fraction, would understate it.
  int? monthsRemaining(DateTime now) {
    final date = goal.targetDate;
    if (date == null || isReached) return null;
    final months =
        (date.year - now.year) * 12 + (date.month - now.month);
    return months < 1 ? 1 : months;
  }

  /// What must be put aside each month to arrive on time.
  Money? requiredPerMonth(DateTime now) {
    final months = monthsRemaining(now);
    if (months == null) return null;
    return Money(remaining.milli ~/ months, goal.target.currency);
  }
}
