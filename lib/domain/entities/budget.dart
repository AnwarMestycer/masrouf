import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:meta/meta.dart';

/// A monthly spending cap for one category.
///
/// Recurring rather than per-month: the cap applies every month until changed.
/// See the `Budgets` table for why a per-month cap is deliberately not v1.
@immutable
class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.updatedAt,
  });

  final String id;
  final String categoryId;

  /// Always in the base currency, like every other aggregate figure. A cap in a
  /// foreign currency would have to be re-converted whenever the rate changed,
  /// which would silently move the line the user set.
  final Money amount;

  final DateTime updatedAt;

  Budget copyWith({Money? amount, DateTime? updatedAt}) => Budget(
        id: id,
        categoryId: categoryId,
        amount: amount ?? this.amount,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Budget &&
          other.id == id &&
          other.categoryId == categoryId &&
          other.amount == amount);

  @override
  int get hashCode => Object.hash(id, categoryId, amount);
}

/// A budget with the month's spend against it.
///
/// The spend comes from the maintained monthly totals, so building this costs a
/// join rather than a scan of the ledger.
@immutable
class BudgetProgress {
  const BudgetProgress({
    required this.budget,
    required this.category,
    required this.spent,
  });

  final Budget budget;

  /// Null when the category has been deleted but its budget has not — the row is
  /// still shown so the user can see why a cap they do not recognise exists.
  final Category? category;

  final Money spent;

  Money get cap => budget.amount;

  /// What is left, floored at zero. Overspend is reported by [overspend] rather
  /// than as a negative remainder, so no caller has to decide what a negative
  /// "remaining" means.
  Money get remaining {
    final left = cap.milli - spent.milli;
    return left <= 0 ? Money.zero(cap.currency) : Money(left, cap.currency);
  }

  Money get overspend {
    final over = spent.milli - cap.milli;
    return over <= 0 ? Money.zero(cap.currency) : Money(over, cap.currency);
  }

  /// Spend as a fraction of the cap. Uncapped, so the caller can decide whether
  /// to clamp the bar at 1.0 while still showing "140%".
  double get ratio => cap.milli == 0 ? 0 : spent.milli / cap.milli;

  bool get isOver => spent.milli > cap.milli;

  /// At or past four fifths of the cap — the point at which telling the user is
  /// still actionable rather than an obituary.
  bool get isNearLimit => !isOver && ratio >= 0.8;
}
