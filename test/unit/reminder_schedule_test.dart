import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/notifications/notification_service.dart';
import 'package:masrouf/core/notifications/reminder_schedule.dart';
import 'package:masrouf/domain/entities/planned_expense.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

/// A reminder that fires at the wrong moment is worse than none: the user stops
/// trusting the ones that are right. These pin the three rules that decide
/// whether a plan gets one at all.
void main() {
  const base = Currency.tnd;

  PlannedExpense plan(
    String id,
    DateTime dueAt, {
    PlannedStatus status = PlannedStatus.pending,
  }) =>
      PlannedExpense(
        id: id,
        categoryId: 'cat-rent',
        accountId: 'acc-cash',
        amount: const Money(50000, base),
        dueAt: dueAt,
        note: null,
        status: status,
        transactionId: null,
        updatedAt: DateTime(2026, 10, 1),
      );

  final now = DateTime(2026, 10, 5, 12);

  test('a future plan is reminded on the morning of its due date', () {
    final reminders = ReminderSchedule.forPlans(
      <PlannedExpense>[plan('p1', DateTime(2026, 10, 9, 18))],
      now,
    );

    expect(reminders, hasLength(1));
    expect(reminders.single.fireAt, DateTime(2026, 10, 9, ReminderSchedule.hour));
    expect(reminders.single.plan.id, 'p1');
  });

  /// The time of day on the plan decides nothing about the reminder — only the
  /// calendar day does. A bill due at 23:00 is still a thing to be told about in
  /// the morning.
  test('the due time of day does not move the reminder', () {
    final early = ReminderSchedule.forPlans(
      <PlannedExpense>[plan('p1', DateTime(2026, 10, 9, 1))],
      now,
    );
    final late = ReminderSchedule.forPlans(
      <PlannedExpense>[plan('p1', DateTime(2026, 10, 9, 23, 59))],
      now,
    );

    expect(early.single.fireAt, late.single.fireAt);
  });

  /// The app is open right now and the Planned screen already lists anything
  /// due. Scheduling a past moment would either fire instantly — telling the
  /// user what is on their screen — or throw, depending on the OEM.
  test('a plan whose morning has passed is skipped', () {
    final reminders = ReminderSchedule.forPlans(
      <PlannedExpense>[
        // Today, but 08:00 is already behind us at the 12:00 "now".
        plan('today', DateTime(2026, 10, 5, 20)),
        plan('yesterday', DateTime(2026, 10, 4, 9)),
      ],
      now,
    );

    expect(reminders, isEmpty);
  });

  test('only pending plans are reminded', () {
    final reminders = ReminderSchedule.forPlans(
      <PlannedExpense>[
        plan('done', DateTime(2026, 10, 9), status: PlannedStatus.done),
        plan('cancelled', DateTime(2026, 10, 10),
            status: PlannedStatus.cancelled),
        plan('pending', DateTime(2026, 10, 11)),
      ],
      now,
    );

    expect(reminders.map((r) => r.plan.id), <String>['pending']);
  });

  test('reminders are ordered soonest first and numbered in firing order', () {
    final reminders = ReminderSchedule.forPlans(
      <PlannedExpense>[
        plan('late', DateTime(2026, 10, 20)),
        plan('soon', DateTime(2026, 10, 7)),
        plan('middle', DateTime(2026, 10, 12)),
      ],
      now,
    );

    expect(
      reminders.map((r) => r.plan.id),
      <String>['soon', 'middle', 'late'],
    );
    expect(
      reminders.map((r) => r.id),
      <int>[
        NotificationIds.plannedReminderBase,
        NotificationIds.plannedReminderBase + 1,
        NotificationIds.plannedReminderBase + 2,
      ],
    );
  });

  /// Android caps pending alarms per app, so the cap is not cosmetic. The ones
  /// that survive must be the soonest — they are the only ones that could fire
  /// before the next launch reschedules anyway.
  test('the cap keeps the soonest plans and drops the rest', () {
    final plans = <PlannedExpense>[
      for (var i = 0; i < ReminderSchedule.maxReminders + 10; i++)
        plan('p$i', DateTime(2026, 10, 6).add(Duration(days: i))),
    ];

    final reminders = ReminderSchedule.forPlans(plans, now);

    expect(reminders, hasLength(ReminderSchedule.maxReminders));
    expect(reminders.first.plan.id, 'p0');
    expect(
      reminders.last.plan.id,
      'p${ReminderSchedule.maxReminders - 1}',
      reason: 'the cap must drop the furthest-out plans, not the soonest',
    );
  });

  /// Every id the scheduler can occupy has to be cancellable, or a plan deleted
  /// between two launches leaves a notification that still fires.
  test('allIds covers every id the schedule can produce', () {
    final plans = <PlannedExpense>[
      for (var i = 0; i < ReminderSchedule.maxReminders; i++)
        plan('p$i', DateTime(2026, 10, 6).add(Duration(days: i))),
    ];

    final used = ReminderSchedule.forPlans(plans, now).map((r) => r.id).toSet();

    expect(used, isNotEmpty);
    expect(used.difference(ReminderSchedule.allIds.toSet()), isEmpty);
  });
}
