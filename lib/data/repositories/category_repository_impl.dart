import 'package:masrouf/core/error/auth_error_mapper.dart';
import 'package:masrouf/core/error/failure.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/result/result.dart';
import 'package:masrouf/core/theme/app_colors.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/seed/default_categories.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/domain/repositories/repositories.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl({
    required AppDatabase db,
    required SyncEngine sync,
    required this.userId,
  })  : _db = db,
        _sync = sync;

  final AppDatabase _db;
  final SyncEngine _sync;
  final String userId;

  @override
  Stream<List<Category>> watchByKind(CategoryKind kind) =>
      _db.categoryDao.watchByKind(userId, kind);

  @override
  Stream<List<Category>> watchAll() => _db.categoryDao.watchAll(userId);

  @override
  Stream<List<Category>> watchQuickPicks(CategoryKind kind) =>
      _db.categoryDao.watchRecentlyUsed(userId, kind);

  @override
  Future<Result<Category>> create(Category category) => _write(category);

  @override
  Future<Result<Category>> update(Category category) => _write(category);

  Future<Result<Category>> _write(Category category) => guard(
        () async {
          if (category.name.trim().isEmpty) {
            throw const Failure(
              FailureCode.validation,
              debugMessage: 'Category name is empty',
            );
          }
          final stamped = category.copyWith(updatedAt: DateTime.now());
          await _db.categoryDao.upsert(userId, stamped);
          await _db.syncQueueDao
              .enqueue(SyncEntity.categories, stamped.id, SyncOp.upsert);
          _sync.requestSync();
          return stamped;
        },
        mapDataError,
      );

  @override
  Future<Result<void>> delete(String id) => guard(
        () async {
          // Soft delete only. Transactions keep their category_id and simply
          // render as uncategorised — deleting a label must not erase history.
          await _db.categoryDao.softDelete(id);
          await _db.syncQueueDao
              .enqueue(SyncEntity.categories, id, SyncOp.delete);
          _sync.requestSync();
        },
        mapDataError,
      );

  @override
  Future<Result<void>> reorder(List<String> orderedIds) => guard(
        () async {
          await _db.categoryDao.reorder(orderedIds);
          await _db.syncQueueDao
              .enqueueAll(SyncEntity.categories, orderedIds, SyncOp.upsert);
          _sync.requestSync();
        },
        mapDataError,
      );

  /// Seeds the starter set, once.
  ///
  /// Guarded on the live category count rather than a flag, so a device that
  /// signs into an existing account adopts that account's categories from the
  /// first pull instead of seeding a duplicate set.
  @override
  Future<Result<void>> seedDefaultsIfEmpty(
    Currency base, {
    Map<String, String> names = const <String, String>{},
  }) =>
      guard(
        () async {
          if (await _db.categoryDao.liveCount(userId) > 0) return;

          final palette = AppColors.categoryPalette
              .map((c) => c.toARGB32())
              .toList(growable: false);
          final categories = DefaultSeed.categories(palette, names: names);
          await _db.categoryDao.upsertAll(userId, categories);
          await _db.syncQueueDao.enqueueAll(
            SyncEntity.categories,
            categories.map((c) => c.id),
            SyncOp.upsert,
          );

          final accounts = await _db.accountDao.getAll(userId);
          if (accounts.isEmpty) {
            final cash = DefaultSeed.cashAccount(base, name: names['Cash']);
            await _db.accountDao.upsert(userId, cash);
            await _db.syncQueueDao
                .enqueue(SyncEntity.accounts, cash.id, SyncOp.upsert);
          }

          _sync.requestSync();
        },
        mapDataError,
      );
}
