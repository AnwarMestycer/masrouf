import 'package:drift/drift.dart';
import 'package:masrouf/core/config/app_config.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/mappers.dart';
import 'package:masrouf/data/local/tables/tables.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: <Type>[Categories, Transactions])
class CategoryDao extends DatabaseAccessor<AppDatabase> with _$CategoryDaoMixin {
  CategoryDao(super.db);

  Stream<List<Category>> watchByKind(String userId, CategoryKind kind) =>
      (select(categories)
            ..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.kind.equals(kind.wire) &
                  t.deletedAt.isNull(),
            )
            ..orderBy(<OrderClauseGenerator<$CategoriesTable>>[
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.name),
            ]))
          .watch()
          .map((rows) => rows.map((r) => r.toEntity()).toList(growable: false));

  Stream<List<Category>> watchAll(String userId) => (select(categories)
        ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
        ..orderBy(<OrderClauseGenerator<$CategoriesTable>>[
          (t) => OrderingTerm.asc(t.kind),
          (t) => OrderingTerm.asc(t.sortOrder),
        ]))
      .watch()
      .map((rows) => rows.map((r) => r.toEntity()).toList(growable: false));

  Future<List<Category>> getAll(String userId) async {
    final rows = await (select(categories)
          ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull()))
        .get();
    return rows.map((r) => r.toEntity()).toList(growable: false);
  }

  Future<int> liveCount(String userId) async {
    final count = categories.id.count();
    final row = await (selectOnly(categories)
          ..addColumns(<Expression<Object>>[count])
          ..where(categories.userId.equals(userId) & categories.deletedAt.isNull()))
        .getSingle();
    return row.read(count) ?? 0;
  }

  /// Categories ordered by how recently they were used, for the fast-add chips.
  ///
  /// This is the single most latency-sensitive query in the app — it runs while
  /// the add sheet is animating in — so it aggregates over the transaction index
  /// rather than joining the full history, and is capped to what fits on screen.
  Stream<List<Category>> watchRecentlyUsed(
    String userId,
    CategoryKind kind, {
    int limit = AppConfig.quickCategoryCount,
  }) {
    final lastUsed = transactions.dateYmd.max();
    final recent = selectOnly(transactions)
      ..addColumns(<Expression<Object>>[transactions.categoryId, lastUsed])
      ..where(
        transactions.userId.equals(userId) &
            transactions.type.equals(kind.asTxnType.wire) &
            transactions.deletedAt.isNull() &
            transactions.categoryId.isNotNull(),
      )
      ..groupBy(<Expression<Object>>[transactions.categoryId])
      ..orderBy(<OrderingTerm>[OrderingTerm.desc(lastUsed)])
      ..limit(limit);

    return recent.watch().asyncMap((rows) async {
      final recentIds = rows
          .map((r) => r.read(transactions.categoryId))
          .whereType<String>()
          .toList(growable: false);

      final all = await (select(categories)
            ..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.kind.equals(kind.wire) &
                  t.deletedAt.isNull(),
            )
            ..orderBy(<OrderClauseGenerator<$CategoriesTable>>[
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.name),
            ]))
          .get();

      final byId = <String, Category>{
        for (final row in all) row.id: row.toEntity(),
      };

      // Recently used first, then everything else in the user's own ordering, so
      // the chip strip is stable enough to build muscle memory against while
      // still surfacing what you actually use.
      final ordered = <Category>[
        for (final id in recentIds)
          if (byId.remove(id) case final Category c) c,
        ...byId.values,
      ];
      return ordered;
    });
  }

  Future<void> upsert(String userId, Category category) =>
      into(categories).insert(
        CategoriesCompanion.insert(
          id: category.id,
          userId: userId,
          name: category.name,
          kind: category.kind.wire,
          icon: category.icon,
          color: category.color,
          sortOrder: Value<int>(category.sortOrder),
          isDefault: Value<bool>(category.isDefault),
          createdAt: DateTime.now(),
          updatedAt: category.updatedAt,
        ),
        mode: InsertMode.insertOrReplace,
      );

  Future<void> upsertAll(String userId, List<Category> items) =>
      batch((Batch b) {
        b.insertAllOnConflictUpdate(
          categories,
          items
              .map(
                (category) => CategoriesCompanion.insert(
                  id: category.id,
                  userId: userId,
                  name: category.name,
                  kind: category.kind.wire,
                  icon: category.icon,
                  color: category.color,
                  sortOrder: Value<int>(category.sortOrder),
                  isDefault: Value<bool>(category.isDefault),
                  createdAt: DateTime.now(),
                  updatedAt: category.updatedAt,
                ),
              )
              .toList(growable: false),
        );
      });

  /// Soft delete. Transactions keep pointing at the id and simply render as
  /// uncategorised — deleting a category must never destroy spending history.
  Future<void> softDelete(String id) => (update(categories)
        ..where((t) => t.id.equals(id)))
      .write(
    CategoriesCompanion(
      deletedAt: Value<DateTime>(DateTime.now()),
      updatedAt: Value<DateTime>(DateTime.now()),
    ),
  );

  Future<void> reorder(List<String> orderedIds) => batch((Batch b) {
        final now = DateTime.now();
        for (var i = 0; i < orderedIds.length; i++) {
          b.update(
            categories,
            CategoriesCompanion(
              sortOrder: Value<int>(i),
              updatedAt: Value<DateTime>(now),
            ),
            where: ($CategoriesTable t) => t.id.equals(orderedIds[i]),
          );
        }
      });
}
