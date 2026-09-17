import 'package:masrouf/core/error/auth_error_mapper.dart';
import 'package:masrouf/core/error/failure.dart';
import 'package:masrouf/core/ids.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/result/result.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/analytics/analytics.dart';
import 'package:masrouf/domain/entities/recurring_rule.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';
import 'package:masrouf/domain/repositories/repositories.dart';

class RecurringRepositoryImpl implements RecurringRepository {
  RecurringRepositoryImpl({
    required AppDatabase db,
    required SyncEngine sync,
    required this.userId,
    required this.base,
  })  : _db = db,
        _sync = sync;

  final AppDatabase _db;
  final SyncEngine _sync;
  final String userId;
  final Currency base;

  /// Ceiling on how many occurrences one rule can backfill in a single run.
  ///
  /// A weekly rule left dormant for two years would otherwise materialise a
  /// hundred rows at launch. The cap keeps startup bounded; the remainder is
  /// generated on subsequent runs.
  static const int _maxBackfillPerRule = 24;

  @override
  Stream<List<RecurringRule>> watchAll() => _db.recurringDao.watchAll(userId);

  @override
  Future<List<RecurringRule>> all() => _db.recurringDao.getAll(userId);

  @override
  Future<Result<RecurringRule>> create(RecurringRule rule) => _write(rule);

  @override
  Future<Result<RecurringRule>> update(RecurringRule rule) => _write(rule);

  Future<Result<RecurringRule>> _write(RecurringRule rule) => guard(
        () async {
          if (!rule.amount.isPositive) {
            throw const Failure(
              FailureCode.validation,
              debugMessage: 'Recurring amount must be greater than zero',
            );
          }
          final stamped = rule.copyWith(updatedAt: DateTime.now());
          await _db.recurringDao.upsert(userId, stamped);
          await _db.syncQueueDao
              .enqueue(SyncEntity.recurringRules, stamped.id, SyncOp.upsert);
          _sync.requestSync();
          return stamped;
        },
        mapDataError,
      );

  @override
  Future<Result<void>> delete(String id) => guard(
        () async {
          await _db.recurringDao.softDelete(id);
          await _db.syncQueueDao
              .enqueue(SyncEntity.recurringRules, id, SyncOp.delete);
          _sync.requestSync();
        },
        mapDataError,
      );

  @override
  Future<Result<void>> setActive(String id, {required bool active}) => guard(
        () async {
          await _db.recurringDao.setActive(id, active: active);
          await _db.syncQueueDao
              .enqueue(SyncEntity.recurringRules, id, SyncOp.upsert);
          _sync.requestSync();
        },
        mapDataError,
      );

  /// Generates every occurrence that has come due.
  ///
  /// Runs entirely on-device so this month's rent exists even if the phone has
  /// been offline all week. Idempotency comes from `(rule_id, date)`: a
  /// materialised row is checked for before each insert, so re-running on the
  /// same day — or on two devices — cannot double-charge.
  @override
  Future<Result<int>> materialiseDue() => guard(
        () async {
          final today = DateTime.now().dateOnly;
          final due = await _db.recurringDao.due(userId, today);
          if (due.isEmpty) return 0;

          final created = <Txn>[];

          for (final rule in due) {
            var cursor = rule.nextRunDate.dateOnly;
            var lastRun = rule.lastRunDate;
            var generated = 0;

            while (!cursor.isAfter(today) && generated < _maxBackfillPerRule) {
              final already =
                  await _db.transactionDao.hasAnyForRule(rule.id, cursor.ymd);
              if (!already) {
                created.add(
                  Txn(
                    id: Ids.newId(),
                    type: rule.type,
                    amount: rule.amount,
                    fxRateToBase: 1,
                    categoryId: rule.categoryId,
                    accountId: rule.accountId,
                    transferAccountId: rule.transferAccountId,
                    date: cursor,
                    note: rule.note,
                    tags: const <String>[],
                    recurringRuleId: rule.id,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                );
              }
              lastRun = cursor;
              cursor = rule.advanceFrom(cursor);
              generated++;
            }

            await _db.recurringDao.advance(rule.id, cursor, lastRun ?? today);
            await _db.syncQueueDao
                .enqueue(SyncEntity.recurringRules, rule.id, SyncOp.upsert);
          }

          if (created.isNotEmpty) {
            await _db.transactionDao.insertAllFromSync(userId, created, base);
            await _db.syncQueueDao.enqueueAll(
              SyncEntity.transactions,
              created.map((t) => t.id),
              SyncOp.upsert,
            );
          }

          _sync.requestSync();
          return created.length;
        },
        mapDataError,
      );

  @override
  Future<List<UpcomingBill>> upcomingBefore(DateTime horizon) async {
    final rules = await _db.recurringDao.upcomingBetween(
      userId,
      DateTime.now().dateOnly,
      horizon,
    );
    final categories = <String, String>{
      for (final c in await _db.categoryDao.getAll(userId)) c.id: c.name,
    };

    return rules
        // Only outflows reduce what is safe to spend; an expected salary is not
        // a bill, and counting it would inflate the figure.
        .where((rule) => rule.type.balanceSign < 0)
        .map(
          (rule) => UpcomingBill(
            ruleId: rule.id,
            label: rule.note?.trim().isNotEmpty ?? false
                ? rule.note!.trim()
                : categories[rule.categoryId] ?? '',
            amount: rule.amount,
            dueDate: rule.nextRunDate,
          ),
        )
        .toList(growable: false);
  }
}
