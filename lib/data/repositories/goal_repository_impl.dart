import 'package:masrouf/core/error/auth_error_mapper.dart';
import 'package:masrouf/core/error/failure.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/result/result.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/savings_goal.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';
import 'package:masrouf/domain/repositories/repositories.dart';

class GoalRepositoryImpl implements GoalRepository {
  GoalRepositoryImpl({
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

  @override
  Stream<List<SavingsGoalProgress>> watchProgress() =>
      _db.goalDao.watchProgress(userId, base);

  @override
  Future<Result<SavingsGoal>> save(SavingsGoal goal) => guard(
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
          final stamped = goal.copyWith(updatedAt: DateTime.now());
          await _db.goalDao.upsert(userId, stamped);
          await _db.syncQueueDao
              .enqueue(SyncEntity.savingsGoals, stamped.id, SyncOp.upsert);
          _sync.requestSync();
          return stamped;
        },
        mapDataError,
      );

  /// Removes the goal only. The account it pointed at, and every dinar in it,
  /// are untouched — the goal was a lens on that balance, never a holder of it.
  @override
  Future<Result<void>> remove(String id) => guard(
        () async {
          await _db.goalDao.softDelete(id);
          await _db.syncQueueDao
              .enqueue(SyncEntity.savingsGoals, id, SyncOp.delete);
          _sync.requestSync();
        },
        mapDataError,
      );
}
