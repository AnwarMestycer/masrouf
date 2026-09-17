import 'package:drift/drift.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/time/ym.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/mappers.dart';
import 'package:masrouf/data/local/tables/local_tables.dart';
import 'package:masrouf/data/local/tables/tables.dart';
import 'package:masrouf/domain/entities/budget.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

part 'budget_dao.g.dart';

/// Budgets, and the month's spend against them.
///
/// Progress reads the maintained `monthly_category_totals` rather than the
/// ledger, so showing a dozen budgets costs a dozen row reads no matter how long
/// the history is. Everything here goes through drift's query builder — a raw
/// `customStatement` would not register the tables it touches and the dashboard
/// would silently stop updating.
@DriftAccessor(tables: <Type>[Budgets, Categories, MonthlyCategoryTotals])
class BudgetDao extends DatabaseAccessor<AppDatabase> with _$BudgetDaoMixin {
  BudgetDao(super.db);

  Stream<List<Budget>> watchAll(String userId, Currency base) =>
      (select(budgets)
            ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull()))
          .watch()
          .map(
            (rows) => rows.map((r) => r.toEntity(base)).toList(growable: false),
          );

  Future<Budget?> getForCategory(String userId, String categoryId) async {
    final row = await (select(budgets)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.categoryId.equals(categoryId) &
                t.deletedAt.isNull(),
          )
          ..limit(1))
        .getSingleOrNull();
    return row?.toEntity(Currency.fromCode(row.currency));
  }

  /// Every budget with what [ym] has spent against it, worst first.
  ///
  /// Worst first because the list exists to answer "what is about to go wrong",
  /// and a budget comfortably under its cap needs no attention.
  Stream<List<BudgetProgress>> watchProgress(
    String userId,
    Ym ym,
    Currency base,
  ) {
    final query = select(budgets).join(<Join<HasResultSet, dynamic>>[
      leftOuterJoin(
        categories,
        categories.id.equalsExp(budgets.categoryId),
      ),
      // Left join, not inner: a category with a budget and no spending this
      // month must still appear, at zero.
      leftOuterJoin(
        monthlyCategoryTotals,
        monthlyCategoryTotals.categoryId.equalsExp(budgets.categoryId) &
            monthlyCategoryTotals.userId.equalsExp(budgets.userId) &
            monthlyCategoryTotals.ym.equals(ym.value) &
            monthlyCategoryTotals.type.equals(TxnType.expense.wire),
      ),
    ])
      ..where(budgets.userId.equals(userId) & budgets.deletedAt.isNull());

    return query.watch().map((rows) {
      final progress = <BudgetProgress>[];
      for (final row in rows) {
        final budget = row.readTable(budgets).toEntity(base);
        final category = row.readTableOrNull(categories);
        final total = row.readTableOrNull(monthlyCategoryTotals);
        progress.add(
          BudgetProgress(
            budget: budget,
            category: category != null && category.deletedAt == null
                ? category.toEntity()
                : null,
            spent: Money(total?.totalMilli ?? 0, base),
          ),
        );
      }
      return progress
        ..sort((a, b) => b.ratio.compareTo(a.ratio));
    });
  }

  Future<void> upsert(String userId, Budget budget) =>
      into(budgets).insert(
        BudgetsCompanion.insert(
          id: budget.id,
          userId: userId,
          categoryId: budget.categoryId,
          amountMilli: budget.amount.milli,
          currency: budget.amount.currency.code,
          createdAt: DateTime.now(),
          updatedAt: budget.updatedAt,
        ),
        mode: InsertMode.insertOrReplace,
      );

  /// Soft delete, so the removal reaches the user's other devices.
  Future<void> softDelete(String id) =>
      (update(budgets)..where((t) => t.id.equals(id))).write(
        BudgetsCompanion(
          deletedAt: Value<DateTime>(DateTime.now()),
          updatedAt: Value<DateTime>(DateTime.now()),
        ),
      );
}
