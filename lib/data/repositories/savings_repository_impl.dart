import 'dart:async';

import 'package:masrouf/core/error/auth_error_mapper.dart';
import 'package:masrouf/core/error/failure.dart';
import 'package:masrouf/core/ids.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/result/result.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/core/time/ym.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/savings_goal.dart';
import 'package:masrouf/domain/entities/savings_plan.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/domain/repositories/repositories.dart';

class SavingsRepositoryImpl implements SavingsRepository {
  SavingsRepositoryImpl({
    required AppDatabase db,
    required SyncEngine sync,
    required TransactionRepository transactions,
    required AccountRepository accounts,
    required this.userId,
    required this.base,
    required this.plan,
    DateTime Function()? clock,
  })  : _db = db,
        _sync = sync,
        _transactions = transactions,
        _accounts = accounts,
        _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final SyncEngine _sync;
  final TransactionRepository _transactions;
  final AccountRepository _accounts;
  final String userId;
  final Currency base;
  final SavingsPlan plan;

  /// Injected so tests can walk across a month end.
  final DateTime Function() _clock;

  /// How many missed months [rollOver] will fill in at once. A phone left in a
  /// drawer for longer than this has bigger problems than its savings plan,
  /// and the bound keeps a wrong clock from writing centuries of rows.
  static const int _maxMonthsFilled = 24;

  // -------------------------------------------------------------- reading --

  @override
  Stream<SavingsStatus> watchStatus() {
    // The window depends on where the closed periods end, so the income and
    // saved streams are nested inside the totals rather than combined once.
    return _db.savingsDao.watchTotals(userId, base).asyncExpand((totals) {
      final today = _clock().dateOnly;
      final month = Ym.fromDate(today);
      final start = SavingsCalendar.windowStart(month, totals.lastCovered);
      final end = SavingsCalendar.windowEnd(month, start, today);
      final ledger = SavingsLedger(
        committed: totals.committed,
        saved: totals.saved,
        plan: plan,
      );
      return _combine(
        _db.analyticsDao.watchIncomeBetween(userId, start, end),
        _db.savingsDao.watchSavedBetween(userId, start, end, base),
      ).map(
        (pair) => SavingsStatus(
          plan: plan,
          month: month,
          startedOn: start,
          incomeSoFar: Money(pair.$1, base),
          savedSoFar: Money(pair.$2, base),
          ledger: ledger,
        ),
      );
    });
  }

  @override
  Stream<List<SavingsPeriod>> watchConfirmed() =>
      _db.savingsDao.watchConfirmed(userId);

  @override
  Stream<List<SavingsGoalProgress>> watchGoals() => _combine(
        _db.goalDao.watchGoals(userId, base),
        _db.savingsDao.watchGoalTotals(userId, base),
      ).map((pair) {
        final (goals, totals) = pair;
        return goals
            .map(
              (entry) => SavingsGoalProgress(
                goal: entry.goal,
                saved: Money(totals[entry.goal.id] ?? 0, base),
                accountName: entry.accountName,
              ),
            )
            .toList(growable: false);
      });

  // ------------------------------------------------------------- the month --

  @override
  Future<Result<void>> rollOver() => guard(
        () async {
          final now = _clock();
          final today = now.dateOnly;
          final current = Ym.fromDate(today);

          // Close what has ended. Normally that is last month's row, once.
          Ym? lastClosed;
          for (final open in await _db.savingsDao.openPeriods(userId)) {
            final month = open.month;
            if (month.value >= current.value) {
              // This month's own row stays open. A hand-opened period from
              // before months were the unit is closed as of yesterday, so the
              // monthly window can take over from today without both counting
              // the same days.
              if (open.id == _monthId(month)) continue;
              final yesterday = today.subtract(const Duration(days: 1));
              if (yesterday.isBefore(open.startedOn)) {
                // Opened today: it has counted nothing that needs keeping.
                await _db.savingsDao.softDelete(open.id);
                await _enqueuePeriod(open.id, SyncOp.delete);
              } else {
                await _close(open, yesterday, now);
              }
              continue;
            }
            await _close(open, month.lastDay, now);
            lastClosed = month;
          }

          if (plan.rate <= 0) return;

          // Months the app was never opened in still happened, so each is
          // closed with its own income and transfers and its share is still
          // asked for. Only after a month that was itself open, though: that
          // is what shows the plan was running. A plan switched back on after
          // a year off must not invent a year of commitments.
          if (lastClosed != null) {
            var month = lastClosed.next;
            var filled = 0;
            while (month.value < current.value && filled < _maxMonthsFilled) {
              final id = _monthId(month);
              if (!await _db.savingsDao.exists(id)) {
                final start = SavingsCalendar.windowStart(
                  month,
                  await _db.savingsDao.lastCoveredOn(userId),
                );
                await _close(_openRow(id, start, now), month.lastDay, now);
              }
              month = month.next;
              filled++;
            }
          }

          // And open this one.
          final id = _monthId(current);
          if (await _db.savingsDao.exists(id)) return;
          final start = SavingsCalendar.windowStart(
            current,
            await _db.savingsDao.lastCoveredOn(userId),
          );
          final period = _openRow(id, start, now);
          await _db.savingsDao.upsert(userId, period);
          await _enqueuePeriod(period.id, SyncOp.upsert);
        },
        mapDataError,
      );

  String _monthId(Ym month) => Ids.savingsMonthId(userId, month.value);

  SavingsPeriod _openRow(String id, DateTime start, DateTime now) =>
      SavingsPeriod(
        id: id,
        startedOn: start,
        income: Money.zero(base),
        committed: Money.zero(base),
        confirmedOn: null,
        saved: null,
        updatedAt: now,
      );

  /// Freezes [period]'s income, share and savings over `startedOn..end`.
  ///
  /// The share uses the plan as it stands at closing: a rate changed on the
  /// 20th applies to that whole month.
  Future<void> _close(SavingsPeriod period, DateTime end, DateTime now) async {
    final income = Money(
      await _db.analyticsDao.incomeBetween(userId, period.startedOn, end),
      base,
    );
    final saved = Money(
      await _db.savingsDao.savedBetween(userId, period.startedOn, end, base),
      base,
    );
    final closed = SavingsPeriod(
      id: period.id,
      startedOn: period.startedOn,
      income: income,
      committed: plan.commitmentFor(income),
      confirmedOn: end,
      saved: saved,
      updatedAt: now,
    );
    await _db.savingsDao.upsert(userId, closed);
    await _enqueuePeriod(closed.id, SyncOp.upsert);
  }

  @override
  Future<Result<SavingsPeriod>> review(String periodId, Money saved) => guard(
        () async {
          if (saved.milli < 0) {
            throw const Failure(
              FailureCode.validation,
              debugMessage: 'Cannot record a negative amount saved',
            );
          }
          final period = await _db.savingsDao.getById(periodId);
          if (period == null) throw const Failure(FailureCode.notFound);
          if (period.isOpen) {
            throw const Failure(
              FailureCode.validation,
              debugMessage: 'A month is reviewed once it has closed',
            );
          }
          final reviewed = period.copyWith(saved: saved, updatedAt: _clock());
          await _db.savingsDao.upsert(userId, reviewed);
          await _enqueuePeriod(reviewed.id, SyncOp.upsert);
          return reviewed;
        },
        mapDataError,
      );

  @override
  Future<Result<void>> removePeriod(String id) => guard(
        () async {
          await _db.savingsDao.softDelete(id);
          await _enqueuePeriod(id, SyncOp.delete);
        },
        mapDataError,
      );

  // ------------------------------------------------------------ transfers --

  @override
  Future<Result<Txn>> putAside({
    required String fromAccountId,
    required String toAccountId,
    required Money amount,
    required double fxRateToBase,
    String? goalId,
    DateTime? date,
    String? note,
  }) =>
      _move(
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amount: amount,
        fxRateToBase: fxRateToBase,
        goalId: goalId,
        date: date,
        note: note,
        intoSavings: true,
      );

  @override
  Future<Result<Txn>> takeBack({
    required String fromAccountId,
    required String toAccountId,
    required Money amount,
    required double fxRateToBase,
    String? goalId,
    DateTime? date,
    String? note,
  }) =>
      _move(
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amount: amount,
        fxRateToBase: fxRateToBase,
        goalId: goalId,
        date: date,
        note: note,
        intoSavings: false,
      );

  /// Writes the transfer through the transaction repository, so it takes the
  /// same path — validation, aggregates, outbox — as one typed on the add
  /// screen. The only thing added here is the direction check and the goal.
  Future<Result<Txn>> _move({
    required String fromAccountId,
    required String toAccountId,
    required Money amount,
    required double fxRateToBase,
    required String? goalId,
    required DateTime? date,
    required String? note,
    required bool intoSavings,
  }) async {
    final checked = await guard(
      () async {
        final from = await _db.accountDao.getById(fromAccountId);
        final to = await _db.accountDao.getById(toAccountId);
        if (from == null || to == null) {
          throw const Failure(FailureCode.notFound);
        }
        final fromSavings = from.type == AccountType.savings;
        final toSavings = to.type == AccountType.savings;
        // Exactly one end a savings account, and the right one. Anything else
        // moves nothing into or out of savings, and would be counted as
        // neither by the month nor by a goal.
        if (fromSavings == toSavings || toSavings != intoSavings) {
          throw const Failure(
            FailureCode.validation,
            debugMessage: 'A saving moves money between an ordinary and a '
                'savings account',
          );
        }
        if (goalId != null) {
          final goal = await _db.goalDao.getById(goalId, base);
          if (goal == null) throw const Failure(FailureCode.notFound);
          if (!intoSavings) {
            final held = (await _db.savingsDao.goalTotals(userId, base))[goalId];
            final inBase = amount.currency == base
                ? amount.milli
                : (amount.milli * fxRateToBase).round();
            if (inBase > (held ?? 0)) {
              throw const Failure(
                FailureCode.validation,
                debugMessage: 'Cannot take back more than the goal holds',
              );
            }
          }
        }
      },
      mapDataError,
    );
    if (checked case Err<void>(:final failure)) return Err<Txn>(failure);

    final now = _clock();
    return _transactions.add(
      Txn(
        id: Ids.newId(),
        type: TxnType.transfer,
        amount: amount,
        fxRateToBase: fxRateToBase,
        categoryId: null,
        accountId: fromAccountId,
        transferAccountId: toAccountId,
        date: (date ?? now).dateOnly,
        note: note == null || note.trim().isEmpty ? null : note.trim(),
        tags: const <String>[],
        recurringRuleId: null,
        createdAt: now,
        updatedAt: now,
        goalId: goalId,
      ),
    );
  }

  @override
  Future<Result<Account>> ensureSavingsAccount(String name) async {
    // A one-off read, not the first value of a watch: a write path has no
    // business holding a stream subscription open while it decides.
    final existing =
        await _db.accountDao.getAll(userId, includeArchived: false);
    for (final account in existing) {
      if (account.type == AccountType.savings) return Ok<Account>(account);
    }
    return _accounts.create(
      Account(
        id: Ids.newId(),
        name: name,
        type: AccountType.savings,
        currency: base,
        openingBalance: Money.zero(base),
        sortOrder: existing.length,
        archived: false,
        updatedAt: _clock(),
      ),
    );
  }

  // ---------------------------------------------------------------- goals --

  @override
  Future<Result<SavingsGoal>> saveGoal(SavingsGoal goal) => guard(
        () async {
          if (goal.name.trim().isEmpty) {
            throw const Failure(
              FailureCode.validation,
              debugMessage: 'Goal name is empty',
            );
          }
          if (!goal.target.isPositive) {
            throw const Failure(
              FailureCode.validation,
              debugMessage: 'Goal target must be greater than zero',
            );
          }
          final stamped = goal.copyWith(updatedAt: _clock());
          await _db.goalDao.upsert(userId, stamped);
          await _db.syncQueueDao
              .enqueue(SyncEntity.savingsGoals, stamped.id, SyncOp.upsert);
          _sync.requestSync();
          return stamped;
        },
        mapDataError,
      );

  @override
  Future<Result<void>> removeGoal(String id) => guard(
        () async {
          await _db.goalDao.softDelete(id);
          await _db.syncQueueDao
              .enqueue(SyncEntity.savingsGoals, id, SyncOp.delete);
          _sync.requestSync();
        },
        mapDataError,
      );

  Future<void> _enqueuePeriod(String id, SyncOp op) async {
    await _db.syncQueueDao.enqueue(SyncEntity.savingsPeriods, id, op);
    _sync.requestSync();
  }

  /// Pairs the latest value of two streams, emitting once both have one.
  ///
  /// Hand-rolled rather than pulling in a combinator package for two uses.
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
