import 'package:masrouf/core/error/auth_error_mapper.dart';
import 'package:masrouf/core/error/failure.dart';
import 'package:masrouf/core/ids.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/result/result.dart';
import 'package:masrouf/core/time/ym.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/budget.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';
import 'package:masrouf/domain/repositories/repositories.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  BudgetRepositoryImpl({
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
  Stream<List<Budget>> watchAll() => _db.budgetDao.watchAll(userId, base);

  @override
  Stream<List<BudgetProgress>> watchProgress(Ym ym) =>
      _db.budgetDao.watchProgress(userId, ym, base);

  /// Sets the cap for a category, replacing any existing one.
  ///
  /// Keyed on the category rather than taking a budget id, because "one cap per
  /// category" is the invariant. Letting the caller mint ids would make two
  /// competing budgets for one category representable, and every reader would
  /// then have to decide which of them wins.
  @override
  Future<Result<Budget>> setForCategory(String categoryId, Money amount) =>
      guard(
        () async {
          if (!amount.isPositive) {
            throw const Failure(
              FailureCode.validation,
              debugMessage: 'Budget must be greater than zero',
            );
          }

          final existing =
              await _db.budgetDao.getForCategory(userId, categoryId);
          final budget = Budget(
            id: existing?.id ?? Ids.newId(),
            categoryId: categoryId,
            amount: amount,
            updatedAt: DateTime.now(),
          );

          await _db.budgetDao.upsert(userId, budget);
          await _db.syncQueueDao
              .enqueue(SyncEntity.budgets, budget.id, SyncOp.upsert);
          _sync.requestSync();
          return budget;
        },
        mapDataError,
      );

  @override
  Future<Result<void>> remove(String id) => guard(
        () async {
          await _db.budgetDao.softDelete(id);
          await _db.syncQueueDao
              .enqueue(SyncEntity.budgets, id, SyncOp.delete);
          _sync.requestSync();
        },
        mapDataError,
      );
}
