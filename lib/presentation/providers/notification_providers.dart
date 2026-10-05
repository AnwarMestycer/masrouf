import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/money/money_formatter.dart';
import 'package:masrouf/core/notifications/budget_alert.dart';
import 'package:masrouf/core/notifications/notification_service.dart';
import 'package:masrouf/core/notifications/reminder_schedule.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/core/time/ym.dart';
import 'package:masrouf/data/local/daos/kv_dao.dart';
import 'package:masrouf/domain/entities/budget.dart';
import 'package:masrouf/l10n/app_localizations.dart';
import 'package:masrouf/presentation/providers/analytics_providers.dart';
import 'package:masrouf/presentation/providers/auth_providers.dart';
import 'package:masrouf/presentation/providers/core_providers.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

/// One service for all three notification kinds, so the plugin is initialised
/// once and the permission state is shared rather than queried three times.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

// ------------------------------------------------------------- device flags --

/// The three switches, as stored on this device.
///
/// Device-local rather than synced: a notification schedule belongs to the phone
/// it fires on, not to the account. Signing in on a tablet should not start
/// buzzing it about bills.
final digestEnabledProvider = FutureProvider<bool>(
  (ref) async =>
      await ref.watch(appDatabaseProvider).kvDao.get(KvDao.weeklyDigest) ==
      'true',
);

final remindersEnabledProvider = FutureProvider<bool>(
  (ref) async =>
      ref.watch(appDatabaseProvider).kvDao.getFlag(KvDao.plannedReminders),
);

final budgetAlertsEnabledProvider = FutureProvider<bool>(
  (ref) async =>
      ref.watch(appDatabaseProvider).kvDao.getFlag(KvDao.budgetAlerts),
);

/// Loads the user's chosen language outside the widget tree.
///
/// These controllers run from providers during sign-in and after writes, before
/// any screen that could supply a `BuildContext` — and a notification must not
/// wait for a frame to be able to name a category.
Future<L10n> _l10nFor(Ref ref) =>
    L10n.delegate.load(Locale(ref.read(settingsProvider).locale));

// ------------------------------------------------------------ weekly digest --

/// Composes this week's message and schedules it.
///
/// Everything is computed here, while the app is open, from data already on the
/// device — the notification itself carries a finished string. Nothing has to
/// wake up and query anything, which is what keeps this feature from needing a
/// background worker at all.
class DigestController {
  DigestController(this._ref);

  final Ref _ref;

  Future<void> setEnabled({required bool enabled}) async {
    final db = _ref.read(appDatabaseProvider);
    await db.kvDao.put(KvDao.weeklyDigest, enabled ? 'true' : 'false');
    _ref.invalidate(digestEnabledProvider);

    if (!enabled) {
      await _ref
          .read(notificationServiceProvider)
          .cancel(NotificationIds.weeklyDigest);
      return;
    }
    await refresh();
  }

  /// Recomputes the message and reschedules. Called on launch and whenever the
  /// toggle changes, so the figure is never more than one session stale.
  Future<void> refresh() async {
    final db = _ref.read(appDatabaseProvider);
    if (await db.kvDao.get(KvDao.weeklyDigest) != 'true') return;

    final service = _ref.read(notificationServiceProvider);
    if (!await service.hasPermission()) return;

    final userId = _ref.read(currentUserIdProvider);
    final base = _ref.read(baseCurrencyProvider);
    final l10n = await _l10nFor(_ref);

    final now = DateTime.now().dateOnly;
    final thisWeekStart = now.startOfWeek;
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    final thisWeek =
        await db.analyticsDao.expenseBetween(userId, thisWeekStart, now);
    final lastWeek = await db.analyticsDao.expenseBetween(
      userId,
      lastWeekStart,
      thisWeekStart.subtract(const Duration(days: 1)),
    );

    final formatter = _ref.read(moneyFormatterProvider);
    final amount = formatter.format(Money(thisWeek, base));

    final String body;
    if (lastWeek == 0) {
      // No comparison is possible, so none is claimed.
      body = l10n.digestBodyFlat(amount);
    } else {
      final ratio = (thisWeek - lastWeek) / lastWeek;
      final percent = '${(ratio.abs() * 100).round()}%';
      // Under 1% is noise; saying "0% more" implies a precision that is not
      // there and reads as a bug.
      body = ratio.abs() < 0.01
          ? l10n.digestBodyFlat(amount)
          : ratio > 0
              ? l10n.digestBodyUp(amount, percent)
              : l10n.digestBodyDown(amount, percent);
    }

    await service.scheduleWeekly(
      title: l10n.digestTitle,
      body: body,
      channelName: l10n.channelDigestName,
      channelDescription: l10n.channelDigestDescription,
    );
  }
}

final digestControllerProvider = Provider<DigestController>(
  DigestController.new,
);

// -------------------------------------------------------- planned reminders --

/// Rebuilds the planned-expense reminder schedule.
///
/// The whole block is cancelled and re-created rather than diffed. A plan can be
/// edited, confirmed, cancelled or deleted, and each would need its own
/// bookkeeping to keep a diff honest; rebuilding thirty inexact alarms costs
/// nothing and cannot drift out of step with the table.
class ReminderController {
  ReminderController(this._ref);

  final Ref _ref;

  Future<void> setEnabled({required bool enabled}) async {
    final db = _ref.read(appDatabaseProvider);
    await db.kvDao.setFlag(KvDao.plannedReminders, value: enabled);
    _ref.invalidate(remindersEnabledProvider);

    if (!enabled) {
      await _ref
          .read(notificationServiceProvider)
          .cancelIds(ReminderSchedule.allIds);
      return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    final db = _ref.read(appDatabaseProvider);
    final service = _ref.read(notificationServiceProvider);

    if (!await db.kvDao.getFlag(KvDao.plannedReminders)) return;
    if (!await service.hasPermission()) return;

    // Cancel first: a plan that was deleted or confirmed since the last pass has
    // no entry in the new schedule, so only an explicit cancel removes it.
    await service.cancelIds(ReminderSchedule.allIds);

    final now = DateTime.now();
    // A reminder can only fire on its due date, so a plan further out than the
    // cap can reach is not worth reading from the database.
    final horizon = now.add(const Duration(days: 400));
    final plans = await _ref
        .read(plannedRepositoryProvider)
        .pendingBefore(horizon);

    final reminders = ReminderSchedule.forPlans(plans, now);
    if (reminders.isEmpty) return;

    final l10n = await _l10nFor(_ref);
    final formatter = _ref.read(moneyFormatterProvider);
    final categories = _ref.read(categoriesByIdProvider);

    for (final reminder in reminders) {
      final plan = reminder.plan;
      final amount = formatter.format(plan.amount);
      final category =
          plan.categoryId == null ? null : categories[plan.categoryId]?.name;

      await service.scheduleAt(
        id: reminder.id,
        channel: NotificationChannel.plannedReminder,
        when: reminder.fireAt,
        title: l10n.reminderTitle,
        body: category == null
            ? l10n.reminderBody(amount)
            : l10n.reminderBodyWithCategory(category, amount),
        channelName: l10n.channelRemindersName,
        channelDescription: l10n.channelRemindersDescription,
      );
    }
  }
}

final reminderControllerProvider = Provider<ReminderController>(
  ReminderController.new,
);

/// Rebuilds the reminder schedule whenever the pending plans change.
///
/// A listener rather than a call in each of save / remove / cancel / confirm.
/// All four already write the table this stream watches, and `fireImmediately`
/// covers launch — so there is no mutation path that can forget to reschedule.
final plannedReminderWatcherProvider = Provider<void>((ref) {
  ref.listen(
    pendingPlansProvider,
    (previous, next) {
      if (next.value == null) return;
      unawaited(ref.read(reminderControllerProvider).refresh());
    },
    fireImmediately: true,
  );
});

// ------------------------------------------------------------ budget alerts --

/// Fires budget alerts for crossings the user has not been told about yet.
///
/// Evaluated against [BudgetAlerts], which owns the crossing and deduplication
/// rules; this class only reads the flags, shows what it is told to, and writes
/// the flags back.
class BudgetAlertController {
  BudgetAlertController(this._ref);

  final Ref _ref;

  Future<void> setEnabled({required bool enabled}) async {
    final db = _ref.read(appDatabaseProvider);
    await db.kvDao.setFlag(KvDao.budgetAlerts, value: enabled);
    _ref.invalidate(budgetAlertsEnabledProvider);
  }

  /// Checks [progress] for [ym] and fires anything newly crossed.
  ///
  /// Takes the progress rather than reading it, because the caller is a listener
  /// on the budget-progress stream — re-querying here would mean the check ran
  /// against a different snapshot than the one that triggered it.
  Future<void> check(List<BudgetProgress> progress, Ym ym) async {
    if (progress.isEmpty) return;

    final db = _ref.read(appDatabaseProvider);
    if (!await db.kvDao.getFlag(KvDao.budgetAlerts)) return;

    // Read every flag this evaluation could consult, before deciding anything.
    final keys = <String>{
      for (final entry in progress)
        for (final level in BudgetAlertLevel.values)
          BudgetAlerts.flagKey(entry.budget.id, ym, level),
    };
    final fired = <String>{};
    for (final key in keys) {
      if (await db.kvDao.getFlag(key)) fired.add(key);
    }

    final decision = BudgetAlerts.evaluate(
      progress: progress,
      firedKeys: fired,
      ym: ym,
    );
    if (decision.isEmpty) return;

    // Flags are written whether or not the notification can actually be shown.
    // A user who has revoked the permission should not accumulate a backlog that
    // all fires the moment they grant it again.
    for (final key in decision.toMark) {
      await db.kvDao.setFlag(key, value: true);
    }
    for (final key in decision.toClear) {
      await db.kvDao.remove(key);
    }

    if (decision.toFire.isEmpty) return;

    final service = _ref.read(notificationServiceProvider);
    if (!await service.hasPermission()) return;

    final l10n = await _l10nFor(_ref);
    final formatter = _ref.read(moneyFormatterProvider);

    for (final alert in decision.toFire) {
      await service.showNow(
        id: NotificationIds.budgetAlert(alert.budgetId, alert.level.percent),
        channel: NotificationChannel.budgetAlert,
        title: _title(l10n, alert),
        body: _body(l10n, formatter, alert),
        channelName: l10n.channelBudgetsName,
        channelDescription: l10n.channelBudgetsDescription,
      );
    }
  }

  /// `category` is non-null here: [BudgetAlerts.evaluate] drops budgets whose
  /// category has been deleted.
  String _title(L10n l10n, BudgetAlert alert) {
    final name = alert.progress.category!.name;
    return switch (alert.level) {
      BudgetAlertLevel.nearLimit => l10n.budgetAlertNearTitle(name),
      BudgetAlertLevel.overspent => l10n.budgetAlertOverTitle(name),
    };
  }

  String _body(L10n l10n, MoneyFormatter formatter, BudgetAlert alert) {
    final progress = alert.progress;
    final spent = formatter.format(progress.spent);
    final cap = formatter.format(progress.cap);
    return switch (alert.level) {
      BudgetAlertLevel.nearLimit => l10n.budgetAlertNearBody(
          spent,
          cap,
          formatter.format(progress.remaining),
        ),
      BudgetAlertLevel.overspent => l10n.budgetAlertOverBody(
          spent,
          cap,
          formatter.format(progress.overspend),
        ),
    };
  }
}

final budgetAlertControllerProvider = Provider<BudgetAlertController>(
  BudgetAlertController.new,
);

/// Runs the budget check whenever this month's progress changes.
///
/// A listener rather than a call at each write site. Every ledger write updates
/// `monthly_category_totals` in the same transaction, which this stream already
/// watches — so a transaction added, edited, deleted, restored, bulk-recategorised
/// or pulled from the server all arrive here without the five call sites that
/// would otherwise each have to remember to ask.
final budgetAlertWatcherProvider = Provider<void>((ref) {
  final ym = Ym.current();
  ref.listen(
    budgetProgressProvider(ym),
    (previous, next) {
      final progress = next.value;
      if (progress == null) return;
      unawaited(ref.read(budgetAlertControllerProvider).check(progress, ym));
    },
    fireImmediately: true,
  );
});
