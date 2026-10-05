import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// The three things this app is allowed to interrupt someone for.
///
/// Separate Android channels rather than one: the system settings screen lets a
/// user silence budget alerts while keeping bill reminders, and a single channel
/// would make that an all-or-nothing choice. Android caches a channel's name and
/// importance at first use, so renaming one later has no effect on a device that
/// has already seen it — the ids below must stay stable.
enum NotificationChannel {
  weeklyDigest('masrouf_weekly_digest', Importance.defaultImportance),

  /// A bill that falls due today. Worth a heads-up notification: the whole point
  /// is to be seen before the money is needed.
  plannedReminder('masrouf_planned_reminders', Importance.high),

  /// A budget crossing 80% or 100%. Deliberately quieter than a bill reminder —
  /// it is information, not a deadline.
  budgetAlert('masrouf_budget_alerts', Importance.defaultImportance);

  const NotificationChannel(this.id, this.importance);

  final String id;
  final Importance importance;
}

/// Notification ids, allocated in blocks so one feature can clear its own
/// without touching another's.
abstract final class NotificationIds {
  static const int weeklyDigest = 1001;

  /// Planned-expense reminders occupy `2000..2000 + maxPlannedReminders - 1`.
  /// Index-based rather than derived from the plan id, because the whole block is
  /// cancelled and rebuilt on every reschedule — so an id only has to be unique
  /// within one pass, and a dense block is cheap to clear.
  static const int plannedReminderBase = 2000;

  /// Budget alerts are shown immediately rather than scheduled, so their id only
  /// decides whether a new alert replaces an existing one in the shade. A hash
  /// collision therefore costs at worst one replaced notification, which is why
  /// `hashCode` — stable within a run, not across runs — is good enough here.
  static int budgetAlert(String budgetId, int levelPercent) =>
      3000 + (budgetId.hashCode.abs() % 450) * 2 + (levelPercent >= 100 ? 1 : 0);
}

/// Local notifications: scheduling, cancelling and immediate display.
///
/// The only part of this app that runs while it is closed, which shapes every
/// decision here:
///
/// - Every message is composed and scheduled *while the app is open*, from data
///   already on the device. Nothing wakes up to compute anything, so there is no
///   background job to get wrong and nothing to keep alive.
/// - Schedules are rebuilt on every launch, so a figure or a due date is never
///   more than one session stale.
/// - Every call is wrapped: a device that refuses notifications, or a
///   manufacturer that has broken exact alarms, must not stop the app starting.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  /// Sunday evening: the week is over and the next one has not started, which
  /// is the only moment the comparison is actually actionable.
  static const int _digestWeekday = DateTime.sunday;
  static const int _digestHour = 20;

  Future<bool> initialise() async {
    if (_ready) return true;
    try {
      tz_data.initializeTimeZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _plugin.initialize(settings: settings);
      _ready = true;
      return true;
    } on Object catch (error, stackTrace) {
      debugPrint('notifications unavailable: $error\n$stackTrace');
      return false;
    }
  }

  /// Asks for permission. Returns false when the user says no, or when the
  /// platform has no answer for us — both mean "do not schedule".
  Future<bool> requestPermission() async {
    if (!await initialise()) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      return await android.requestNotificationsPermission() ?? false;
    } on Object catch (error) {
      debugPrint('notification permission request failed: $error');
      return false;
    }
  }

  Future<bool> hasPermission() async {
    if (!await initialise()) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    } on Object {
      return false;
    }
  }

  /// Schedules [body] for the next Sunday evening, replacing any previous one.
  Future<void> scheduleWeekly({
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    if (!await initialise()) return;
    try {
      await _plugin.zonedSchedule(
        id: NotificationIds.weeklyDigest,
        title: title,
        body: body,
        scheduledDate: _nextDigestOccurrence(),
        notificationDetails: _detailsFor(
          NotificationChannel.weeklyDigest,
          channelName,
          channelDescription,
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } on Object catch (error, stackTrace) {
      // Inexact scheduling needs no special permission, but OEM battery
      // managers still refuse it on some devices. A missed summary is not worth
      // a crash on launch.
      debugPrint('weekly digest not scheduled: $error\n$stackTrace');
    }
  }

  /// Schedules a one-off notification for [when] in local time.
  ///
  /// Silently does nothing when [when] is not in the future: a past schedule
  /// either fires instantly or throws depending on the OEM, and neither is what
  /// a caller rebuilding a schedule wants.
  Future<void> scheduleAt({
    required int id,
    required NotificationChannel channel,
    required DateTime when,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    if (!await initialise()) return;

    final scheduled = tz.TZDateTime.from(when, tz.local);
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) return;

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails:
            _detailsFor(channel, channelName, channelDescription),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } on Object catch (error, stackTrace) {
      debugPrint('could not schedule $id: $error\n$stackTrace');
    }
  }

  /// Posts a notification now.
  ///
  /// Used by budget alerts, which are evaluated in response to a write the user
  /// just made rather than against a clock — there is nothing to schedule.
  Future<void> showNow({
    required int id,
    required NotificationChannel channel,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    if (!await initialise()) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails:
            _detailsFor(channel, channelName, channelDescription),
      );
    } on Object catch (error, stackTrace) {
      debugPrint('could not show $id: $error\n$stackTrace');
    }
  }

  Future<void> cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: id);
    } on Object catch (error) {
      debugPrint('could not cancel $id: $error');
    }
  }

  /// Clears a whole block, used before rebuilding the planned-expense schedule.
  Future<void> cancelIds(Iterable<int> ids) async {
    if (!_ready) return;
    for (final id in ids) {
      await cancel(id);
    }
  }

  NotificationDetails _detailsFor(
    NotificationChannel channel,
    String channelName,
    String channelDescription,
  ) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channelName,
          channelDescription: channelDescription,
          importance: channel.importance,
          priority: channel.importance == Importance.high
              ? Priority.high
              : Priority.defaultPriority,
        ),
      );

  /// The next Sunday at 20:00 local time, strictly in the future.
  static tz.TZDateTime _nextDigestOccurrence() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      _digestHour,
    );
    while (scheduled.weekday != _digestWeekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
