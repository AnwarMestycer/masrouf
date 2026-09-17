import 'package:masrouf/core/error/auth_error_mapper.dart';
import 'package:masrouf/core/error/failure.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/result/result.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';
import 'package:masrouf/domain/repositories/repositories.dart';

class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl({
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
  Stream<List<AccountWithBalance>> watchWithBalances({
    bool includeArchived = false,
  }) =>
      _db.accountDao
          .watchWithBalances(userId, includeArchived: includeArchived);

  @override
  Stream<List<Account>> watchAll({bool includeArchived = false}) =>
      _db.accountDao.watchAll(userId, includeArchived: includeArchived);

  @override
  Future<Account?> getById(String id) => _db.accountDao.getById(id);

  @override
  Future<Result<Account>> create(Account account) => _write(account);

  @override
  Future<Result<Account>> update(Account account) => _write(account);

  /// Writes locally, queues the push, and returns. The caller never waits on the
  /// network — that is the whole contract of the offline-first design.
  Future<Result<Account>> _write(Account account) => guard(
        () async {
          if (account.name.trim().isEmpty) {
            throw const Failure(
              FailureCode.validation,
              debugMessage: 'Account name is empty',
            );
          }
          final stamped = account.copyWith(updatedAt: DateTime.now());
          await _db.accountDao.upsert(userId, stamped);

          // The opening balance participates in the running balance, so changing
          // it has to be folded back in. A targeted rebuild is cheap and is the
          // only way to stay correct without tracking the previous value.
          await _db.transactionDao.rebuildAggregates(userId, base);

          await _db.syncQueueDao
              .enqueue(SyncEntity.accounts, stamped.id, SyncOp.upsert);
          _sync.requestSync();
          return stamped;
        },
        mapDataError,
      );

  @override
  Future<Result<void>> delete(String id) => guard(
        () async {
          await _db.accountDao.softDelete(id);
          await _db.transactionDao.rebuildAggregates(userId, base);
          await _db.syncQueueDao
              .enqueue(SyncEntity.accounts, id, SyncOp.delete);
          _sync.requestSync();
        },
        mapDataError,
      );

  @override
  Future<Result<void>> reorder(List<String> orderedIds) => guard(
        () async {
          await _db.accountDao.reorder(orderedIds);
          await _db.syncQueueDao
              .enqueueAll(SyncEntity.accounts, orderedIds, SyncOp.upsert);
          _sync.requestSync();
        },
        mapDataError,
      );
}
