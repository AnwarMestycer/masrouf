import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:masrouf/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/domain/entities/user_settings.dart';
import 'package:masrouf/presentation/providers/analytics_providers.dart';
import 'package:masrouf/presentation/providers/auth_providers.dart';
import 'package:masrouf/presentation/providers/core_providers.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';
import 'package:masrouf/presentation/providers/digest_providers.dart';

/// Everything that has to happen when a user signs in, and be undone when they
/// sign out.
///
/// Kept out of the widget tree so it runs exactly once per session rather than
/// once per rebuild of whatever screen happened to host it, and so sign-out
/// cleanup cannot be skipped by a widget being disposed first.
class SessionLifecycle extends Notifier<void> {
  String? _activeUserId;

  @override
  void build() {
    ref.listen<AppUser?>(
      currentUserProvider,
      (previous, next) {
        final previousId = previous?.id;
        final nextId = next?.id;
        if (previousId == nextId) return;

        if (nextId == null) {
          unawaited(_tearDown());
        } else {
          unawaited(_start(nextId));
        }
      },
      fireImmediately: true,
    );
  }

  Future<void> _start(String userId) async {
    if (_activeUserId == userId) return;
    _activeUserId = userId;

    final db = ref.read(appDatabaseProvider);
    final engine = ref.read(syncEngineProvider);
    final base = ref.read(baseCurrencyProvider);

    // Sync first so a returning user's existing categories arrive before the
    // seeder decides whether this account is empty. Without that ordering a
    // reinstall would create a duplicate starter set.
    //
    // Guarded, though: everything after this line has to run even when the
    // network does not. Previously a throw here escaped into the `unawaited`
    // call that started this, so a failed first sync left the user with no
    // categories, no account, and a Save button that could never enable —
    // a dead app with nothing on screen to explain it.
    try {
      await engine.start(userId, base);
    } on Object catch (error, stackTrace) {
      debugPrint('sync start failed, continuing offline: $error\n$stackTrace');
    }

    await ref
        .read(categoryRepositoryProvider)
        .seedDefaultsIfEmpty(base, names: await _seedNames());

    // Generate anything the schedule owes. Runs on every launch because the
    // device may have been closed across several due dates; it is idempotent.
    await ref.read(recurringRepositoryProvider).materialiseDue();

    // The aggregates are recomputable derived state; a rebuild at launch costs
    // one scan of a personal-sized ledger and guarantees the dashboard agrees
    // with the rows even if a previous run was killed mid-write.
    await db.transactionDao.rebuildAggregates(userId, base);

    ref.invalidate(safeToSpendProvider);

    // Recomposed every launch so the summary quotes this week, not whichever
    // week the app was last opened in.
    unawaited(ref.read(digestControllerProvider).refresh());
  }

  /// The starter set's labels in the user's language.
  ///
  /// Loads the bundle directly rather than reaching for a `BuildContext`: this
  /// runs from a provider during sign-in, before any screen that could supply
  /// one, and seeding must not wait for the first frame.
  Future<Map<String, String>> _seedNames() async {
    final locale = ref.read(settingsProvider).locale;
    final l10n = await L10n.delegate.load(Locale(locale));
    return <String, String>{
      'Salary': l10n.seedSalary,
      'Freelance': l10n.seedFreelance,
      'Reimbursement': l10n.seedReimbursement,
      'Gift': l10n.seedGift,
      'Other': l10n.seedOther,
      'Groceries': l10n.seedGroceries,
      'Eating Out': l10n.seedEatingOut,
      'Transport': l10n.seedTransport,
      'Rent': l10n.seedRent,
      'Utilities': l10n.seedUtilities,
      'Subscriptions': l10n.seedSubscriptions,
      'Health': l10n.seedHealth,
      'Family': l10n.seedFamily,
      'Shopping': l10n.seedShopping,
      'Gym': l10n.seedGym,
      'Savings/Zakat': l10n.seedSavingsZakat,
      'Cash': l10n.seedCash,
    };
  }

  Future<void> _tearDown() async {
    _activeUserId = null;
    final db = ref.read(appDatabaseProvider);
    final engine = ref.read(syncEngineProvider);

    // Cursors go with the data: the next user on this device must perform a
    // complete first pull rather than resume someone else's position.
    await engine.reset();
    await db.clearUserData();
  }
}

final sessionLifecycleProvider =
    NotifierProvider<SessionLifecycle, void>(SessionLifecycle.new);

/// Refreshes the session when the app returns to the foreground.
///
/// supabase_flutter refreshes on a timer, which does not fire while the process
/// is suspended; without this a phone left closed overnight surfaces a 401 on
/// the first sync instead of quietly renewing.
class AppLifecycleWatcher with WidgetsBindingObserver {
  AppLifecycleWatcher(this._ref);

  final Ref _ref;

  void attach() => WidgetsBinding.instance.addObserver(this);
  void detach() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_ref.read(currentUserProvider) == null) return;

    unawaited(_ref.read(authRepositoryProvider).refreshSession());
    _ref.read(syncEngineProvider).requestSync();
  }
}

final appLifecycleProvider = Provider<AppLifecycleWatcher>((ref) {
  final watcher = AppLifecycleWatcher(ref)..attach();
  ref.onDispose(watcher.detach);
  return watcher;
});
