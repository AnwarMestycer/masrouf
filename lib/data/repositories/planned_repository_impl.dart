import 'package:masrouf/core/error/auth_error_mapper.dart';
import 'package:masrouf/core/error/failure.dart';
import 'package:masrouf/core/ids.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/result/result.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/planned_expense.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/domain/repositories/repositories.dart';

class PlannedRepositoryImpl implements PlannedRepository {
  PlannedRepositoryImpl({
    required AppDatabase db,
    required SyncEngine sync,
    required TransactionRepository transactions,
    required this.userId,
    required this.base,
  })  : _db = db,
        _sync = sync,
        _transactions = transactions;

  final AppDatabase _db;
  final SyncEngine _sync;

  /// A confirmed plan becomes a transaction through the same repository the add
  /// screen uses, so it goes through one write path with one set of aggregate
  /// rules — rather than a second way to create money movements.
  final TransactionRepository _transactions;

  final String userId;
  final Currency base;

  @override
  Stream<List<PlannedExpenseView>> watchPending() =>
      _db.plannedDao.watchPending(userId, base);

  @override
  Stream<List<PlannedExpenseView>> watchBetween(DateTime from, DateTime to) =>
      _db.plannedDao.watchBetween(userId, from, to, base);

  @override
  Future<List<PlannedExpenseView>> between(DateTime from, DateTime to) =>
      _db.plannedDao.between(userId, from, to, base);

  @override
  Future<List<PlannedExpense>> pendingBefore(DateTime horizon) =>
      _db.plannedDao.pendingBefore(userId, horizon, base);

  @override
  Future<Result<PlannedExpense>> save(PlannedExpense plan) => guard(
        () async {
          if (!plan.amount.isPositive) {
            throw const Failure(
              FailureCode.validation,
              debugMessage: 'Planned amount must be greater than zero',
            );
          }
          final stamped = plan.copyWith(updatedAt: DateTime.now());
          await _db.plannedDao.upsert(userId, stamped);
          await _enqueue(stamped.id);
          return stamped;
        },
        mapDataError,
      );

  @override
  Future<Result<void>> remove(String id) => guard(
        () async {
          await _db.plannedDao.softDelete(id);
          await _db.syncQueueDao
              .enqueue(SyncEntity.plannedExpenses, id, SyncOp.delete);
          _sync.requestSync();
        },
        mapDataError,
      );

  @override
  Future<Result<void>> cancel(String id) => guard(
        () async {
          final plan = await _db.plannedDao.getById(id, base);
          if (plan == null) {
            throw const Failure(FailureCode.notFound);
          }
          await _db.plannedDao.upsert(
            userId,
            plan.copyWith(
              status: PlannedStatus.cancelled,
              updatedAt: DateTime.now(),
            ),
          );
          await _enqueue(id);
        },
        mapDataError,
      );

  /// Turns a plan into the transaction it was standing in for.
  ///
  /// The transaction is written first: if that fails the plan stays pending and
  /// the user can try again, whereas marking the plan done first would lose the
  /// commitment with nothing to show for it.
  @override
  Future<Result<void>> confirm(String id, {required String accountId}) => guard(
        () async {
          final plan = await _db.plannedDao.getById(id, base);
          if (plan == null) {
            throw const Failure(FailureCode.notFound);
          }
          if (!plan.isPending) {
            throw const Failure(
              FailureCode.validation,
              debugMessage: 'Only a pending plan can be confirmed',
            );
          }

          final now = DateTime.now();
          final txn = Txn(
            id: Ids.newId(),
            type: TxnType.expense,
            amount: plan.amount,
            // Same currency as the plan, so no conversion is invented here. A
            // plan in a foreign currency needs a rate at confirm time, which is
            // the add screen's job — hence base-currency plans only for now.
            fxRateToBase: 1,
            categoryId: plan.categoryId,
            accountId: accountId,
            transferAccountId: null,
            date: plan.dueAt,
            note: plan.note,
            tags: const <String>[],
            recurringRuleId: null,
            createdAt: now,
            updatedAt: now,
          );

          final written = await _transactions.add(txn);
          if (written.isErr) {
            throw written.failureOrNull!;
          }

          await _db.plannedDao.upsert(
            userId,
            plan.copyWith(
              status: PlannedStatus.done,
              transactionId: txn.id,
              updatedAt: DateTime.now(),
            ),
          );
          await _enqueue(id);
        },
        mapDataError,
      );

  Future<void> _enqueue(String id) async {
    await _db.syncQueueDao
        .enqueue(SyncEntity.plannedExpenses, id, SyncOp.upsert);
    _sync.requestSync();
  }
}
