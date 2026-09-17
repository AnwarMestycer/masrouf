import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:meta/meta.dart';

/// Money the user intends to spend, on a date, that has not moved yet.
///
/// The distinction from a transaction is the whole point: a plan changes no
/// balance and no aggregate. It only reserves — see `SafeToSpend` — so the
/// number the user spends against already accounts for what is promised.
///
/// The distinction from a recurring rule is that a plan is a single dated
/// commitment the user made once, and it never materialises itself. A rule
/// repeats and generates real transactions on its own schedule.
@immutable
class PlannedExpense {
  const PlannedExpense({
    required this.id,
    required this.categoryId,
    required this.accountId,
    required this.amount,
    required this.dueAt,
    required this.note,
    required this.status,
    required this.transactionId,
    required this.updatedAt,
  });

  final String id;
  final String? categoryId;

  /// Which account it is expected to come out of. Optional: at planning time
  /// the user often knows the bill but not yet where they will pay it from.
  final String? accountId;

  final Money amount;

  /// Date *and* time. The time is what makes a reminder worth showing.
  final DateTime dueAt;

  final String? note;
  final PlannedStatus status;

  /// The transaction this plan became, once confirmed.
  final String? transactionId;

  final DateTime updatedAt;

  bool get isPending => status == PlannedStatus.pending;

  /// Pending and its moment has passed — the app should ask whether it happened.
  bool isDue(DateTime now) => isPending && !dueAt.isAfter(now);

  PlannedExpense copyWith({
    String? categoryId,
    String? accountId,
    Money? amount,
    DateTime? dueAt,
    String? note,
    PlannedStatus? status,
    String? transactionId,
    DateTime? updatedAt,
    bool clearNote = false,
  }) =>
      PlannedExpense(
        id: id,
        categoryId: categoryId ?? this.categoryId,
        accountId: accountId ?? this.accountId,
        amount: amount ?? this.amount,
        dueAt: dueAt ?? this.dueAt,
        note: clearNote ? null : (note ?? this.note),
        status: status ?? this.status,
        transactionId: transactionId ?? this.transactionId,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlannedExpense &&
          other.id == id &&
          other.amount == amount &&
          other.dueAt == dueAt &&
          other.status == status);

  @override
  int get hashCode => Object.hash(id, amount, dueAt, status);
}

/// A plan with its category resolved, for lists that show one.
@immutable
class PlannedExpenseView {
  const PlannedExpenseView({required this.plan, required this.category});

  final PlannedExpense plan;

  /// Null when uncategorised, or when the category was deleted after planning.
  final Category? category;

  String get id => plan.id;
}
