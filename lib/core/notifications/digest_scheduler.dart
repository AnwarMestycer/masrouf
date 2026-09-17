import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules the weekly spending summary.
///
/// The only part of this app that runs while it is closed, which shapes every
/// decision here:
///
/// - The message is composed and scheduled *while the app is open*, from data
///   already on the device. Nothing wakes up to compute anything, so there is no
///   background job to get wrong and nothing to keep alive.
/// - It reschedules on every launch, so the figure is never more than one
///   session stale. A notification quoting last month's spending would be worse
///   than none.
/// - Every call is wrapped: a device that refuses notifications, or a
///   manufacturer that has broken exact alarms, must not stop the app starting.
class DigestScheduler {
  DigestScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const int _weeklyId = 1001;
  static const String _channelId = 'masrouf_weekly_digest';

  /// Sunday evening: the week is over and the next one has not started, which
  /// is the only moment the comparison is actually actionable.
  static const int _weekday = DateTime.sunday;
  static const int _hour = 20;

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
  }) async {
    if (!await initialise()) return;
    try {
      await _plugin.zonedSchedule(
        id: _weeklyId,
        title: title,
        body: body,
        scheduledDate: _nextOccurrence(),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Weekly summary',
            channelDescription: 'A weekly recap of what you spent.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
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

  Future<void> cancel() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _weeklyId);
    } on Object catch (error) {
      debugPrint('could not cancel digest: $error');
    }
  }

  /// The next Sunday at 20:00 local time, strictly in the future.
  static tz.TZDateTime _nextOccurrence() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      _hour,
    );
    while (scheduled.weekday != _weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
