import 'package:masrouf/core/money/money.dart';
import 'package:meta/meta.dart';

/// A savings target, held in a real account.
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

  /// Whose balance is the progress. The goal stores no total of its own.
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

/// A goal with the balance that is actually backing it.
@immutable
class SavingsGoalProgress {
  const SavingsGoalProgress({
    required this.goal,
    required this.saved,
    required this.accountName,
  });

  final SavingsGoal goal;

  /// The linked account's real balance, converted to the goal's currency.
  final Money saved;

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
