import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/domain/entities/analytics/analytics.dart';
import 'package:masrouf/domain/entities/analytics/upcoming_week.dart';
import 'package:masrouf/domain/entities/planned_expense.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

void main() {
  const base = Currency.tnd;
  Money dt(num amount) => Money((amount * 1000).round(), base);
  final now = DateTime(2026, 10, 20, 12);

  UpcomingBill bill(String id, DateTime due, num amount) => UpcomingBill(
        ruleId: id,
        label: id,
        amount: dt(amount),
        dueDate: due,
      );

  PlannedExpenseView plan(
    String id,
    DateTime due,
    num amount, {
    PlannedStatus status = PlannedStatus.pending,
  }) =>
      PlannedExpenseView(
        plan: PlannedExpense(
          id: id,
          categoryId: null,
          accountId: null,
          amount: dt(amount),
          dueAt: due,
          note: id,
          status: status,
          transactionId: null,
          updatedAt: now,
        ),
        category: null,
      );

  List<String> ids({
    List<UpcomingBill> bills = const <UpcomingBill>[],
    List<PlannedExpenseView> plans = const <PlannedExpenseView>[],
  }) =>
      UpcomingWeek.from(
        bills: bills,
        plans: plans,
        now: now,
        planLabel: (v) => v.plan.note ?? '',
      ).map((i) => i.id).toList();

  test('covers today and the six days after it', () {
    expect(
      ids(bills: <UpcomingBill>[
        bill('yesterday', DateTime(2026, 10, 19), 1),
        bill('today', DateTime(2026, 10, 20), 1),
        bill('sixth', DateTime(2026, 10, 26), 1),
        bill('seventh', DateTime(2026, 10, 27), 1),
      ]),
      <String>['today', 'sixth'],
    );
  });

  /// The dashboard asks about a due plan in its own card; listing it here as
  /// well would make one plan read as two.
  test('leaves out a plan that is already due', () {
    expect(
      ids(plans: <PlannedExpenseView>[
        plan('this-morning', DateTime(2026, 10, 20, 8), 1),
        plan('tonight', DateTime(2026, 10, 20, 20), 1),
      ]),
      <String>['tonight'],
    );
  });

  test('leaves out a plan that is no longer pending', () {
    expect(
      ids(plans: <PlannedExpenseView>[
        plan('done', DateTime(2026, 10, 22), 1, status: PlannedStatus.done),
      ]),
      isEmpty,
    );
  });

  test('soonest first, and the larger first on the same day', () {
    expect(
      ids(
        bills: <UpcomingBill>[
          bill('small', DateTime(2026, 10, 22), 10),
          bill('later', DateTime(2026, 10, 24), 500),
        ],
        plans: <PlannedExpenseView>[
          plan('large', DateTime(2026, 10, 22, 9), 200),
        ],
      ),
      <String>['large', 'small', 'later'],
    );
  });
}
