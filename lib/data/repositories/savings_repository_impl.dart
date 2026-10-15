import 'dart:async';

import 'package:masrouf/core/error/auth_error_mapper.dart';
import 'package:masrouf/core/error/failure.dart';
import 'package:masrouf/core/ids.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/result/result.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/savings_plan.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';
import 'package:masrouf/domain/repositories/repositories.dart';

class SavingsRepositoryImpl implements SavingsRepository {
  SavingsRepositoryImpl({
    required AppDatabase db,
    required SyncEngine sync,
    required this.userId,
    required this.base,
    required this.plan,
  })  : _db = db,
        _sync = sync;

  final AppDatabase _db;
  final SyncEngine _sync;
  final String userId;
  final Currency base;
  final SavingsPlan plan;

  /// The end of an open period's income window.
  ///
  /// Never earlier than the period's own start. A period that begins tomorrow —
  /// because the previous one was confirmed today — would otherwise be asked
  /// for income over an empty range and report a commitment of nothing.
  static DateTime _windowEnd(DateTime startedOn, DateTime now) {
    final today = now.dateOnly;
    return startedOn.isAfter(today) ? startedOn : today;
  }

  @override
  Stream<SavingsStatus> watchStatus() {
    final open = _db.savingsDao.watchOpen(userId);
    final totals = _db.savingsDao.watchTotals(userId, base);

    // The open period's income has to re-read whenever the period changes, so
    // the income stream is nested rather than combined once up front.
    return _combine(open, totals).asyncExpand((pair) {
      final (period, sums) = pair;
      final ledger = SavingsLedger(
        committed: sums.committed,
        saved: sums.saved,
        plan: plan,
      );
      if (period == null) {
        return Stream<SavingsStatus>.value(
          SavingsStatus(
            plan: plan,
            open: null,
            incomeSoFar: Money.zero(base),
            ledger: ledger,
          ),
        );
      }
      return _db.analyticsDao
          .watchIncomeBetween(
            userId,
            period.startedOn,
            _windowEnd(period.startedOn, DateTime.now()),
          )
          .map(
            (income) => SavingsStatus(
              plan: plan,
              open: period,
              incomeSoFar: Money(income, base),
              ledger: ledger,
            ),
          );
    });
  }

  @override
  Stream<List<SavingsPeriod>> watchConfirmed() =>
      _db.savingsDao.watchConfirmed(userId);

  /// Opens a period starting today.
  ///
  /// Refuses when one is already open: two open periods would both claim the
  /// same income and both reserve against the same balance.
  @override
  Future<Result<SavingsPeriod>> start() => guard(
        () async {
          if (await _db.savingsDao.openPeriod(userId) != null) {
            throw const Failure(
              FailureCode.validation,
              debugMessage: 'A savings period is already open',
            );
          }
          // A period starts the day after the last one was confirmed, never
          // on the same day. Transactions here carry a calendar day and no
          // time, so two periods sharing a start date would both count the
          // same income — the new one would claim what the closed one was
          // already confirmed against.
          final now = DateTime.now();
          final lastConfirmed = await _db.savingsDao.lastConfirmedOn(userId);
          final earliest = lastConfirmed == null
              ? now.dateOnly
              : lastConfirmed.dateOnly.add(const Duration(days: 1));
          final startedOn =
              earliest.isAfter(now.dateOnly) ? earliest : now.dateOnly;

          final period = SavingsPeriod(
            id: Ids.newId(),
            startedOn: startedOn,
            income: Money.zero(base),
            committed: Money.zero(base),
            confirmedOn: null,
            saved: null,
            updatedAt: now,
          );
          await _db.savingsDao.upsert(userId, period);
          await _enqueue(period.id);
          return period;
        },
        mapDataError,
      );

  /// Closes the open period with what was actually set aside.
  ///
  /// Income and the commitment are frozen onto the row here. Up to this moment
  /// both were derived from the ledger, so they tracked reality; from here the
  /// period is history and must not move when an old transaction is edited.
  @override
  Future<Result<SavingsPeriod>> confirm(Money saved) => guard(
        () async {
          if (saved.milli < 0) {
            throw const Failure(
              FailureCode.validation,
              debugMessage: 'Cannot confirm a negative amount',
            );
          }
          final open = await _db.savingsDao.openPeriod(userId);
          if (open == null) {
            throw const Failure(
              FailureCode.notFound,
              debugMessage: 'No savings period is open',
            );
          }

          final now = DateTime.now();
          final income = Money(
            await _db.analyticsDao.incomeBetween(
              userId,
              open.startedOn,
              _windowEnd(open.startedOn, now),
            ),
            base,
          );
          final closed = SavingsPeriod(
            id: open.id,
            startedOn: open.startedOn,
            income: income,
            committed: plan.commitmentFor(income),
            confirmedOn: now.dateOnly,
            saved: saved,
            updatedAt: now,
          );
          await _db.savingsDao.upsert(userId, closed);
          await _enqueue(closed.id);
          return closed;
        },
        mapDataError,
      );

  @override
  Future<Result<void>> remove(String id) => guard(
        () async {
          await _db.savingsDao.softDelete(id);
          await _db.syncQueueDao
              .enqueue(SyncEntity.savingsPeriods, id, SyncOp.delete);
          _sync.requestSync();
        },
        mapDataError,
      );

  Future<void> _enqueue(String id) async {
    await _db.syncQueueDao
        .enqueue(SyncEntity.savingsPeriods, id, SyncOp.upsert);
    _sync.requestSync();
  }

  /// Pairs the latest value of two streams, emitting once both have one.
  ///
  /// Hand-rolled rather than pulling in a combinator package for a single use.
  static Stream<(A, B)> _combine<A, B>(Stream<A> a, Stream<B> b) {
    late StreamController<(A, B)> controller;
    StreamSubscription<A>? subA;
    StreamSubscription<B>? subB;
    var hasA = false;
    var hasB = false;
    late A lastA;
    late B lastB;

    void emit() {
      if (hasA && hasB) controller.add((lastA, lastB));
    }

    controller = StreamController<(A, B)>(
      onListen: () {
        subA = a.listen((value) {
          lastA = value;
          hasA = true;
          emit();
        }, onError: controller.addError);
        subB = b.listen((value) {
          lastB = value;
          hasB = true;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await subA?.cancel();
        await subB?.cancel();
      },
    );
    return controller.stream;
  }
}
