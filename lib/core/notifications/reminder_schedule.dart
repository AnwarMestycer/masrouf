import 'package:masrouf/core/notifications/notification_service.dart';
import 'package:masrouf/domain/entities/planned_expense.dart';
import 'package:meta/meta.dart';

/// One planned expense, and the moment its reminder should fire.
@immutable
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.plan,
    required this.fireAt,
  });

  final int id;
  final PlannedExpense plan;
  final DateTime fireAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduledReminder &&
          other.id == id &&
          other.plan.id == plan.id &&
          other.fireAt == fireAt);

  @override
  int get hashCode => Object.hash(id, plan.id, fireAt);

  @override
  String toString() => 'ScheduledReminder($id, ${plan.id}, $fireAt)';
}

/// Decides which planned expenses get a reminder, and when.
///
/// Pure, so the rules below are unit-tested without a notification plugin, a
/// device clock or a timezone database in play.
abstract final class ReminderSchedule {
  /// Local hour the reminder fires on the due date.
  ///
  /// The morning of, not the night before: the useful moment is while the user
  /// still has the day to act, and a reminder the evening before competes with
  /// the one thing the app already does at that hour — the weekly digest.
  static const int hour = 8;

  /// Hard cap on outstanding reminders.
  ///
  /// Android imposes its own ceiling on pending alarms per app, and a user with
  /// a hundred plans does not want a hundred notifications queued. The soonest
  /// thirty are the only ones that could plausibly fire before the next launch
  /// rebuilds the schedule anyway.
  static const int maxReminders = 30;

  /// The reminders to schedule for [plans], given the current time.
  ///
  /// Only pending plans qualify — a confirmed or cancelled plan is settled.
  /// A plan whose morning has already passed is skipped rather than fired
  /// immediately: the app is open right now, and the Planned screen already
  /// surfaces anything due. Firing a notification for it would tell the user
  /// something the screen in front of them is already saying.
  static List<ScheduledReminder> forPlans(
    Iterable<PlannedExpense> plans,
    DateTime now,
  ) {
    final due = <ScheduledReminder>[];

    for (final plan in plans) {
      if (!plan.isPending) continue;
      final fireAt = DateTime(
        plan.dueAt.year,
        plan.dueAt.month,
        plan.dueAt.day,
        hour,
      );
      if (!fireAt.isAfter(now)) continue;
      // id is assigned after sorting, so it reflects firing order.
      due.add(ScheduledReminder(id: 0, plan: plan, fireAt: fireAt));
    }

    due.sort((a, b) => a.fireAt.compareTo(b.fireAt));

    final capped = due.take(maxReminders).toList(growable: false);
    return <ScheduledReminder>[
      for (var i = 0; i < capped.length; i++)
        ScheduledReminder(
          id: NotificationIds.plannedReminderBase + i,
          plan: capped[i].plan,
          fireAt: capped[i].fireAt,
        ),
    ];
  }

  /// Every id the reminder block can occupy, for cancelling before a rebuild.
  static List<int> get allIds => <int>[
        for (var i = 0; i < maxReminders; i++)
          NotificationIds.plannedReminderBase + i,
      ];
}
