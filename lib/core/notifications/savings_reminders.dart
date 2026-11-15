import 'package:masrouf/core/notifications/notification_service.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:meta/meta.dart';

enum SavingsReminderKind {
  /// On the 1st: last month has closed, check what it put aside.
  monthReview,

  /// Once a week while this month still has something to put aside.
  weeklyNudge,
}

@immutable
class SavingsReminder {
  const SavingsReminder({
    required this.id,
    required this.kind,
    required this.fireAt,
  });

  final int id;
  final SavingsReminderKind kind;
  final DateTime fireAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavingsReminder &&
          other.id == id &&
          other.kind == kind &&
          other.fireAt == fireAt);

  @override
  int get hashCode => Object.hash(id, kind, fireAt);

  @override
  String toString() => 'SavingsReminder($kind, $fireAt)';
}

/// Decides which savings reminders to schedule, and when.
///
/// Pure, so the rules are unit-tested without a plugin, a device clock or a
/// database in play. Both reminders are one-offs rebuilt whenever the month's
/// figures change, rather than repeating alarms: each carries numbers composed
/// while the app is open, and a repeating alarm would keep quoting stale ones.
abstract final class SavingsReminders {
  /// Mid-morning on the 1st. Not midnight, which is when the month closes but
  /// nobody is reading.
  static const int reviewHour = 10;

  /// Friday evening: the week's spending is mostly done, and the weekend has
  /// not started yet.
  static const int nudgeWeekday = DateTime.friday;
  static const int nudgeHour = 18;

  static const List<int> allIds = <int>[
    NotificationIds.savingsReview,
    NotificationIds.savingsNudge,
  ];

  static List<SavingsReminder> plan({
    required DateTime now,
    required bool hasPlan,
    required bool stillToSave,
    required bool reviewEnabled,
    required bool nudgeEnabled,
  }) {
    if (!hasPlan) return const <SavingsReminder>[];
    return <SavingsReminder>[
      if (reviewEnabled)
        SavingsReminder(
          id: NotificationIds.savingsReview,
          kind: SavingsReminderKind.monthReview,
          fireAt: reviewAt(now),
        ),
      if (nudgeEnabled && stillToSave)
        if (nudgeAt(now) case final at?)
          SavingsReminder(
            id: NotificationIds.savingsNudge,
            kind: SavingsReminderKind.weeklyNudge,
            fireAt: at,
          ),
    ];
  }

  /// The 1st of next month, mid-morning. Always in the future.
  static DateTime reviewAt(DateTime now) =>
      DateTime(now.year, now.month + 1, 1, reviewHour);

  /// The next Friday evening after [now], or null when that falls in the next
  /// month.
  ///
  /// Null rather than next month's Friday: the nudge quotes this month's
  /// figures, and by then this month is closed and the review covers it.
  static DateTime? nudgeAt(DateTime now) {
    final today = now.dateOnly;
    var days = (nudgeWeekday - today.weekday) % 7;
    var at = DateTime(today.year, today.month, today.day + days, nudgeHour);
    if (!at.isAfter(now)) {
      days += 7;
      at = DateTime(today.year, today.month, today.day + days, nudgeHour);
    }
    return at.month == now.month && at.year == now.year ? at : null;
  }
}
