import 'dart:async';

import 'package:masrouf/core/config/app_config.dart';
import 'package:masrouf/core/connectivity/connectivity_service.dart';
import 'package:masrouf/core/error/auth_error_mapper.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/remote/api/sync_api.dart';
import 'package:masrouf/data/sync/pull_worker.dart';
import 'package:masrouf/data/sync/push_worker.dart';
import 'package:masrouf/data/sync/sync_status.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';

/// Coordinates background reconciliation with Supabase.
///
/// Nothing here is ever awaited by the UI. Writes land in SQLite and return
/// immediately; this engine catches up afterwards, and its only visible effect is
/// the status chip in settings. That separation is what makes the app fully
/// usable with no connection.
class SyncEngine {
  SyncEngine({
    required AppDatabase db,
    required SyncApi api,
    required ConnectivityService connectivity,
  })  : _db = db,
        // `connectivity:` reads better at the call site than the underscore-named
        // parameter an initializing formal would force.
        // ignore: prefer_initializing_formals
        _connectivity = connectivity,
        _pull = PullWorker(db: db, api: api),
        _push = PushWorker(db: db, api: api);

  final AppDatabase _db;
  final ConnectivityService _connectivity;
  final PullWorker _pull;
  final PushWorker _push;

  final StreamController<SyncStatus> _status =
      StreamController<SyncStatus>.broadcast();

  StreamSubscription<bool>? _connectivitySub;
  StreamSubscription<int>? _pendingSub;
  Timer? _periodic;

  String? _userId;
  Currency _base = Currency.tnd;

  /// Guards against overlapping runs. Two concurrent syncs would race on the
  /// pull cursor and could apply the same page twice.
  bool _running = false;

  /// Set when a sync is requested while one is already in flight, so the change
  /// that triggered it is not left unsynced until the next timer tick.
  bool _rerunRequested = false;

  SyncStatus _current = SyncStatus.idle;

  /// Whether a sync has run to completion since [start].
  ///
  /// Read by sign-in before it decides whether this account is empty. False
  /// means "we do not know what the server has", which is a different thing
  /// from "the server has nothing" — and seeding on the first is what mints a
  /// duplicate starter set.
  bool _hasCompletedSync = false;

  bool get hasCompletedSync => _hasCompletedSync;

  Stream<SyncStatus> get status => _status.stream;
  SyncStatus get currentStatus => _current;

  /// Begins syncing for a signed-in user, and awaits the first run.
  ///
  /// The await is load-bearing. Sign-in seeds a starter set when the account
  /// looks empty, and "looks empty" can only be judged once the first pull has
  /// landed. This used to fire the initial sync with `unawaited`, so the seeder
  /// always won the race against the network, saw zero categories and seeded —
  /// and the pull then delivered the account's real ones alongside the copies.
  Future<void> start(String userId, Currency base) async {
    if (_userId == userId && _periodic != null) {
      _base = base;
      return;
    }
    await stop();
    _userId = userId;
    _base = base;

    // Reconnecting is the single most valuable moment to sync, so the queue's
    // backoff is cleared and a run kicked off immediately rather than waiting
    // out a timer that was counting down against a dead network.
    _connectivitySub = _connectivity.onStatusChange.listen((online) async {
      if (!online) {
        _emit(_current.copyWith(state: SyncState.offline));
        return;
      }
      await _db.syncQueueDao.resetBackoff();
      unawaited(syncNow());
    });

    _pendingSub = _db.syncQueueDao.watchPendingCount().listen((pending) {
      _emit(_current.copyWith(pending: pending));
    });

    _periodic = Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(syncNow()),
    );

    await syncNow();
  }

  Future<void> stop() async {
    _hasCompletedSync = false;
    await _connectivitySub?.cancel();
    await _pendingSub?.cancel();
    _connectivitySub = null;
    _pendingSub = null;
    _periodic?.cancel();
    _periodic = null;
    _userId = null;
    _emit(SyncStatus.idle);
  }

  void updateBaseCurrency(Currency base) => _base = base;

  /// Push then pull.
  ///
  /// Pushing first means local work reaches the server before anything can
  /// overwrite it, and the pull that follows immediately confirms it landed. The
  /// conflict resolver still protects any row queued in between.
  Future<void> syncNow() async {
    final userId = _userId;
    if (userId == null) return;

    if (_running) {
      _rerunRequested = true;
      return;
    }
    _running = true;

    try {
      if (!await _connectivity.isOnline()) {
        _emit(_current.copyWith(state: SyncState.offline));
        return;
      }

      _emit(_current.copyWith(state: SyncState.syncing, clearError: true));

      final outcome = await _push.pushBatch(userId);
      if (outcome.isTransientlyBlocked) {
        _emit(_current.copyWith(state: SyncState.offline));
        return;
      }

      await _pull.pullAll(userId, _base);

      // A full outbox drains over several batches; keep going while work remains
      // rather than waiting five minutes per batch.
      //
      // Deliberately `dueCount`, not `pendingCount`: an entry that just failed
      // has been pushed into the future by its backoff and is not work this run
      // can do. Counting it here means the rerun fires immediately, finds
      // nothing due, and schedules itself again — a hot loop that hammers the
      // network for as long as one row stays unpushable. Requiring progress too,
      // so a batch that pushed nothing cannot spin.
      if (outcome.pushed > 0 && await _db.syncQueueDao.dueCount() > 0) {
        _rerunRequested = true;
      }

      _hasCompletedSync = true;
      _emit(
        _current.copyWith(
          state: SyncState.idle,
          lastSyncedAt: DateTime.now(),
          clearError: true,
        ),
      );
    } on Object catch (error, stackTrace) {
      final failure = mapDataError(error, stackTrace);
      _emit(
        _current.copyWith(
          state: failure.isTransient ? SyncState.offline : SyncState.failed,
          lastError: failure.debugMessage ?? failure.code.name,
        ),
      );
    } finally {
      _running = false;
      if (_rerunRequested) {
        _rerunRequested = false;
        unawaited(syncNow());
      }
    }
  }

  /// Nudges the engine after a local write. Debounced by the running flag, so a
  /// burst of quick entries results in one sync rather than one per entry.
  void requestSync() => unawaited(syncNow());

  /// Full reset used on sign-out: clears cursors along with the data, so the next
  /// user on this device performs a complete first pull instead of resuming
  /// someone else's cursor.
  Future<void> reset() async {
    await stop();
    for (final entity in SyncEntity.values) {
      await _db.kvDao.remove(KvDaoKeys.pullCursor(entity));
    }
  }

  Future<void> dispose() async {
    await stop();
    await _status.close();
  }

  void _emit(SyncStatus status) {
    _current = status;
    if (!_status.isClosed) _status.add(status);
  }

  /// Exposed for the settings screen's manual "sync now" affordance.
  static Duration get retryCeiling => AppConfig.syncMaxBackoff;
}
