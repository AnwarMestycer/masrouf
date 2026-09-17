import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/notifications/digest_scheduler.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/data/local/daos/kv_dao.dart';
import 'package:masrouf/l10n/app_localizations.dart';
import 'package:masrouf/presentation/providers/auth_providers.dart';
import 'package:masrouf/presentation/providers/core_providers.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

final digestSchedulerProvider = Provider<DigestScheduler>(
  (ref) => DigestScheduler(),
);

/// Whether the weekly summary is switched on, as stored on this device.
final digestEnabledProvider =
    FutureProvider<bool>((ref) async {
  final value = await ref.watch(appDatabaseProvider).kvDao.get(
        KvDao.weeklyDigest,
      );
  return value == 'true';
});

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

    final scheduler = _ref.read(digestSchedulerProvider);
    if (!enabled) {
      await scheduler.cancel();
      return;
    }
    await refresh();
  }

  /// Recomputes the message and reschedules. Called on launch and whenever the
  /// toggle changes, so the figure is never more than one session stale.
  Future<void> refresh() async {
    final db = _ref.read(appDatabaseProvider);
    if (await db.kvDao.get(KvDao.weeklyDigest) != 'true') return;

    final scheduler = _ref.read(digestSchedulerProvider);
    if (!await scheduler.hasPermission()) return;

    final userId = _ref.read(currentUserIdProvider);
    final base = _ref.read(baseCurrencyProvider);
    final l10n = await L10n.delegate.load(
      Locale(_ref.read(settingsProvider).locale),
    );

    final now = DateTime.now().dateOnly;
    final thisWeekStart = now.startOfWeek;
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    final thisWeek = await db.analyticsDao.expenseBetween(
      userId,
      thisWeekStart,
      now,
    );
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

    await scheduler.scheduleWeekly(title: l10n.digestTitle, body: body);
  }
}

final digestControllerProvider = Provider<DigestController>(
  DigestController.new,
);
