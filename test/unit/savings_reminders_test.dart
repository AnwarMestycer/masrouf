import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/notifications/notification_service.dart';
import 'package:masrouf/core/notifications/savings_reminders.dart';

void main() {
  // A Wednesday.
  final wednesday = DateTime(2026, 10, 14, 9);

  List<SavingsReminder> plan({
    DateTime? now,
    bool hasPlan = true,
    bool stillToSave = true,
    bool review = true,
    bool nudge = true,
  }) =>
      SavingsReminders.plan(
        now: now ?? wednesday,
        hasPlan: hasPlan,
        stillToSave: stillToSave,
        reviewEnabled: review,
        nudgeEnabled: nudge,
      );

  group('the month-end review', () {
    test('fires mid-morning on the 1st of next month', () {
      expect(SavingsReminders.reviewAt(wednesday), DateTime(2026, 11, 1, 10));
    });

    test('crosses the year end', () {
      expect(
        SavingsReminders.reviewAt(DateTime(2026, 12, 31, 23)),
        DateTime(2027, 1, 1, 10),
      );
    });

    test('is not scheduled while its switch is off', () {
      expect(
        plan(review: false).map((r) => r.kind),
        <SavingsReminderKind>[SavingsReminderKind.weeklyNudge],
      );
    });
  });

  group('the weekly nudge', () {
    test('fires on the coming Friday evening', () {
      expect(SavingsReminders.nudgeAt(wednesday), DateTime(2026, 10, 16, 18));
    });

    test('on a Friday before the hour, fires that evening', () {
      expect(
        SavingsReminders.nudgeAt(DateTime(2026, 10, 16, 8)),
        DateTime(2026, 10, 16, 18),
      );
    });

    test('on a Friday after the hour, waits a week', () {
      expect(
        SavingsReminders.nudgeAt(DateTime(2026, 10, 16, 19)),
        DateTime(2026, 10, 23, 18),
      );
    });

    /// It quotes this month's figures, and by next month those are history.
    test('is not scheduled into next month', () {
      // Saturday the 31st: the next Friday is in November.
      expect(SavingsReminders.nudgeAt(DateTime(2026, 10, 31, 9)), isNull);
    });

    test('stops once the month has put aside everything it asked', () {
      expect(
        plan(stillToSave: false).map((r) => r.kind),
        <SavingsReminderKind>[SavingsReminderKind.monthReview],
      );
    });
  });

  test('without a plan, nothing is scheduled', () {
    expect(plan(hasPlan: false), isEmpty);
  });

  test('each reminder has its own fixed id', () {
    expect(
      plan().map((r) => r.id),
      <int>[NotificationIds.savingsReview, NotificationIds.savingsNudge],
    );
    expect(SavingsReminders.allIds.toSet(), hasLength(2));
  });
}
