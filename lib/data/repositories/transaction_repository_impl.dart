import 'package:csv/csv.dart';
import 'package:masrouf/core/config/app_config.dart';
import 'package:masrouf/core/error/auth_error_mapper.dart';
import 'package:masrouf/core/error/failure.dart';
import 'package:masrouf/core/ids.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/result/result.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/daos/kv_dao.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/history_filter.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/domain/repositories/repositories.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl({
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
  Stream<List<TxnView>> watchRecent({int limit = 5}) =>
      _db.transactionDao.watchRecent(userId, base, limit: limit);

  @override
  Future<List<TxnView>> page(HistoryFilter filter, {required int offset}) =>
      _db.transactionDao.history(
        userId,
        filter,
        base,
        limit: AppConfig.historyPageSize,
        offset: offset,
      );

  @override
  Stream<void> watchChanges() => _db.transactionDao.watchChanges(userId);

  @override
  Stream<List<String>> watchTags() => _db.transactionDao.watchAllTags(userId);

  @override
  Future<Txn?> getById(String id) => _db.transactionDao.getById(id);

  /// The hot path of the whole app.
  ///
  /// One local transaction writes the row and folds it into the aggregate
  /// tables; the sync request that follows is fire-and-forget. Nothing here
  /// awaits the network, so the add sheet can close the moment this returns.
  @override
  Future<Result<Txn>> add(Txn txn) => guard(
        () async {
          _validate(txn);
          await _db.transactionDao.insertTxn(userId, txn, base);
          await _db.kvDao.put(KvDao.lastAccountId, txn.accountId);
          await _db.syncQueueDao
              .enqueue(SyncEntity.transactions, txn.id, SyncOp.upsert);
          _sync.requestSync();
          return txn;
        },
        mapDataError,
      );

  @override
  Future<Result<Txn>> update(Txn txn) => guard(
        () async {
          _validate(txn);
          final previous = await _db.transactionDao.getById(txn.id);
          if (previous == null) {
            throw const Failure(
              FailureCode.notFound,
              debugMessage: 'Transaction disappeared before the edit landed',
            );
          }
          final stamped = txn.copyWith(updatedAt: DateTime.now());
          await _db.transactionDao.updateTxn(userId, previous, stamped, base);
          await _db.syncQueueDao
              .enqueue(SyncEntity.transactions, stamped.id, SyncOp.upsert);
          _sync.requestSync();
          return stamped;
        },
        mapDataError,
      );

  @override
  Future<Result<void>> delete(String id) => guard(
        () async {
          final existing = await _db.transactionDao.getById(id);
          if (existing == null) return;
          await _db.transactionDao.softDeleteTxn(userId, existing, base);
          await _db.syncQueueDao
              .enqueue(SyncEntity.transactions, id, SyncOp.delete);
          _sync.requestSync();
        },
        mapDataError,
      );

  @override
  Future<Result<void>> restore(String id) => guard(
        () async {
          final existing = await _db.transactionDao.getById(id);
          if (existing == null) {
            throw const Failure(FailureCode.notFound);
          }
          await _db.transactionDao.restoreTxn(userId, existing, base);
          await _db.syncQueueDao
              .enqueue(SyncEntity.transactions, id, SyncOp.upsert);
          _sync.requestSync();
        },
        mapDataError,
      );

  @override
  Future<Result<Txn>> duplicate(String id) => guard(
        () async {
          final original = await _db.transactionDao.getById(id);
          if (original == null) {
            throw const Failure(FailureCode.notFound);
          }
          final now = DateTime.now();
          final copy = Txn(
            id: Ids.newId(),
            type: original.type,
            amount: original.amount,
            fxRateToBase: original.fxRateToBase,
            categoryId: original.categoryId,
            accountId: original.accountId,
            transferAccountId: original.transferAccountId,
            date: original.date,
            note: original.note,
            tags: original.tags,
            // The copy was typed by hand, not generated: keeping the source's
            // rule link would make it look like a materialised occurrence.
            recurringRuleId: null,
            createdAt: now,
            updatedAt: now,
          );
          await _db.transactionDao.insertTxn(userId, copy, base);
          await _db.syncQueueDao
              .enqueue(SyncEntity.transactions, copy.id, SyncOp.upsert);
          _sync.requestSync();
          return copy;
        },
        mapDataError,
      );

  /// Runs [action] over each listed transaction inside one drift transaction.
  ///
  /// Row-by-row rather than a bulk UPDATE because the DAO's aggregate tables are
  /// maintained incrementally per write, and one transaction keeps the ledger
  /// and the aggregates consistent even if the process dies midway. [action]
  /// receives whether the row is currently tombstoned — the domain [Txn] does
  /// not carry that, and applying a delete/restore delta twice would corrupt
  /// the aggregates. It returns false to skip a row; the count is the rows
  /// changed.
  Future<int> _forEachId(
    List<String> ids,
    Future<bool> Function(Txn txn, bool deleted) action,
  ) =>
      _db.transaction(() async {
        var changed = 0;
        for (final id in ids) {
          final txn = await _db.transactionDao.getById(id);
          if (txn == null) continue;
          final row = await (_db.select(_db.transactions)
                ..where((t) => t.id.equals(id)))
              .getSingle();
          if (await action(txn, row.deletedAt != null)) changed++;
        }
        return changed;
      });

  @override
  Future<Result<int>> recategorize(List<String> ids, String categoryId) =>
      guard(
        () async {
          final row = await (_db.select(_db.categories)
                ..where((t) => t.id.equals(categoryId)))
              .getSingleOrNull();
          if (row == null) {
            throw const Failure(
              FailureCode.notFound,
              debugMessage: 'Category does not exist',
            );
          }
          final kind = CategoryKind.fromWire(row.kind);

          final changed = await _forEachId(ids, (txn, deleted) async {
            // An expense category on an income row would poison every
            // per-kind aggregate, so mismatched rows are left untouched.
            final matches = switch (kind) {
              CategoryKind.expense => txn.type == TxnType.expense,
              CategoryKind.income => txn.type == TxnType.income,
            };
            if (deleted || !matches || txn.categoryId == categoryId) {
              return false;
            }
            final stamped = txn.copyWith(
              categoryId: categoryId,
              updatedAt: DateTime.now(),
            );
            await _db.transactionDao.updateTxn(userId, txn, stamped, base);
            await _db.syncQueueDao
                .enqueue(SyncEntity.transactions, txn.id, SyncOp.upsert);
            return true;
          });

          _sync.requestSync();
          return changed;
        },
        mapDataError,
      );

  @override
  Future<Result<int>> addTag(List<String> ids, String tag) => guard(
        () async {
          final normalised = tag.trim().toLowerCase();
          if (normalised.isEmpty) {
            throw const Failure(
              FailureCode.validation,
              debugMessage: 'Tag is blank',
            );
          }

          final changed = await _forEachId(ids, (txn, deleted) async {
            if (deleted || txn.tags.contains(normalised)) return false;
            final stamped = txn.copyWith(
              tags: [...txn.tags, normalised],
              updatedAt: DateTime.now(),
            );
            await _db.transactionDao.updateTxn(userId, txn, stamped, base);
            await _db.syncQueueDao
                .enqueue(SyncEntity.transactions, txn.id, SyncOp.upsert);
            return true;
          });

          _sync.requestSync();
          return changed;
        },
        mapDataError,
      );

  @override
  Future<Result<int>> deleteMany(List<String> ids) => guard(
        () async {
          final changed = await _forEachId(ids, (txn, deleted) async {
            if (deleted) return false;
            await _db.transactionDao.softDeleteTxn(userId, txn, base);
            await _db.syncQueueDao
                .enqueue(SyncEntity.transactions, txn.id, SyncOp.delete);
            return true;
          });

          _sync.requestSync();
          return changed;
        },
        mapDataError,
      );

  @override
  Future<Result<int>> restoreMany(List<String> ids) => guard(
        () async {
          final changed = await _forEachId(ids, (txn, deleted) async {
            if (!deleted) return false;
            await _db.transactionDao.restoreTxn(userId, txn, base);
            await _db.syncQueueDao
                .enqueue(SyncEntity.transactions, txn.id, SyncOp.upsert);
            return true;
          });

          _sync.requestSync();
          return changed;
        },
        mapDataError,
      );

  /// Renders the full ledger as CSV.
  ///
  /// Amounts are written as plain decimal strings with a dot separator rather
  /// than locale-formatted, so the file imports cleanly into a spreadsheet
  /// regardless of the app's display language.
  @override
  Future<Result<String>> exportCsv() => guard(
        () async {
          final rows = await _db.transactionDao.allForExport(userId);
          final accounts = <String, String>{
            for (final a in await _db.accountDao.getAll(userId)) a.id: a.name,
          };
          final categories = <String, String>{
            for (final c in await _db.categoryDao.getAll(userId)) c.id: c.name,
          };

          final table = <List<String>>[
            <String>[
              'date',
              'type',
              'amount',
              'currency',
              'amount_in_${base.code.toLowerCase()}',
              'category',
              'account',
              'transfer_account',
              'note',
              'tags',
            ],
            for (final txn in rows)
              <String>[
                txn.date.toIsoDate(),
                txn.type.wire,
                txn.amount.toDecimalString(),
                txn.amount.currency.code,
                (txn.amount.currency == base
                        ? txn.amount
                        : txn.amount.convertTo(base, txn.fxRateToBase))
                    .toDecimalString(),
                txn.categoryId == null ? '' : categories[txn.categoryId] ?? '',
                accounts[txn.accountId] ?? '',
                txn.transferAccountId == null
                    ? ''
                    : accounts[txn.transferAccountId] ?? '',
                txn.note ?? '',
                txn.tags.join(' '),
              ],
          ];

          return const CsvEncoder().convert(table);
        },
        mapDataError,
      );

  /// Invariants the database cannot express on its own.
  ///
  /// Enforced here rather than in the UI so a transaction created by recurring
  /// materialisation is held to the same rules as one typed by hand.
  void _validate(Txn txn) {
    if (!txn.amount.isPositive) {
      throw const Failure(
        FailureCode.validation,
        debugMessage: 'Amount must be greater than zero',
      );
    }
    if (txn.isTransfer) {
      if (txn.transferAccountId == null ||
          txn.transferAccountId == txn.accountId) {
        throw const Failure(
          FailureCode.validation,
          debugMessage: 'A transfer needs a distinct destination account',
        );
      }
    } else if (txn.categoryId == null) {
      throw const Failure(
        FailureCode.validation,
        debugMessage: 'Income and expenses must be categorised',
      );
    }
  }
}
