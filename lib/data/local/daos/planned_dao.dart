import 'package:drift/drift.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/mappers.dart';
import 'package:masrouf/data/local/tables/tables.dart';
import 'package:masrouf/domain/entities/planned_expense.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

part 'planned_dao.g.dart';

/// Planned expenses — commitments that have not moved money yet.
///
/// Note what is absent: nothing here writes to `account_balances`,
/// `monthly_category_totals` or `daily_totals`. A plan is not a transaction and
/// must never reach the aggregates; that separation is the feature.
@DriftAccessor(tables: <Type>[PlannedExpenses, Categories])
class PlannedDao extends DatabaseAccessor<AppDatabase> with _$PlannedDaoMixin {
  PlannedDao(super.db);

  /// Every plan that has not been resolved, soonest first.
  Stream<List<PlannedExpenseView>> watchPending(String userId, Currency base) {
    final query = select(plannedExpenses).join(
      <Join<HasResultSet, dynamic>>[
        leftOuterJoin(
          categories,
          categories.id.equalsExp(plannedExpenses.categoryId),
        ),
      ],
    )
      ..where(
        plannedExpenses.userId.equals(userId) &
            plannedExpenses.deletedAt.isNull() &
            plannedExpenses.status.equals(PlannedStatus.pending.wire),
      )
      ..orderBy(<OrderingTerm>[OrderingTerm.asc(plannedExpenses.dueAt)]);

    return query.watch().map(
          (rows) => rows.map((row) {
            final category = row.readTableOrNull(categories);
            return PlannedExpenseView(
              plan: row.readTable(plannedExpenses).toEntity(base),
              category: category != null && category.deletedAt == null
                  ? category.toEntity()
                  : null,
            );
          }).toList(growable: false),
        );
  }

  /// Everything, resolved or not, for the history view and the calendar.
  Stream<List<PlannedExpenseView>> watchBetween(
    String userId,
    DateTime from,
    DateTime to,
    Currency base,
  ) {
    final query = select(plannedExpenses).join(
      <Join<HasResultSet, dynamic>>[
        leftOuterJoin(
          categories,
          categories.id.equalsExp(plannedExpenses.categoryId),
        ),
      ],
    )
      ..where(
        plannedExpenses.userId.equals(userId) &
            plannedExpenses.deletedAt.isNull() &
            plannedExpenses.dueAt.isBiggerOrEqualValue(from) &
            plannedExpenses.dueAt.isSmallerOrEqualValue(to),
      )
      ..orderBy(<OrderingTerm>[OrderingTerm.asc(plannedExpenses.dueAt)]);

    return query.watch().map(
          (rows) => rows.map((row) {
            final category = row.readTableOrNull(categories);
            return PlannedExpenseView(
              plan: row.readTable(plannedExpenses).toEntity(base),
              category: category != null && category.deletedAt == null
                  ? category.toEntity()
                  : null,
            );
          }).toList(growable: false),
        );
  }

  /// One-shot read of the plans in a window, for callers that are Futures.
  Future<List<PlannedExpenseView>> between(
    String userId,
    DateTime from,
    DateTime to,
    Currency base,
  ) async {
    final rows = await (select(plannedExpenses).join(
      <Join<HasResultSet, dynamic>>[
        leftOuterJoin(
          categories,
          categories.id.equalsExp(plannedExpenses.categoryId),
        ),
      ],
    )
          ..where(
            plannedExpenses.userId.equals(userId) &
                plannedExpenses.deletedAt.isNull() &
                plannedExpenses.dueAt.isBiggerOrEqualValue(from) &
                plannedExpenses.dueAt.isSmallerOrEqualValue(to),
          ))
        .get();

    return rows.map((row) {
      final category = row.readTableOrNull(categories);
      return PlannedExpenseView(
        plan: row.readTable(plannedExpenses).toEntity(base),
        category: category != null && category.deletedAt == null
            ? category.toEntity()
            : null,
      );
    }).toList(growable: false);
  }

  /// Pending plans due on or before [horizon] — what `SafeToSpend` reserves.
  ///
  /// A one-shot read rather than a stream, matching how `safeToSpend()` reads
  /// balances and bills.
  Future<List<PlannedExpense>> pendingBefore(
    String userId,
    DateTime horizon,
    Currency base,
  ) async {
    final rows = await (select(plannedExpenses)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.deletedAt.isNull() &
                t.status.equals(PlannedStatus.pending.wire) &
                t.dueAt.isSmallerOrEqualValue(horizon),
          ))
        .get();
    return rows.map((r) => r.toEntity(base)).toList(growable: false);
  }

  Future<PlannedExpense?> getById(String id, Currency base) async {
    final row = await (select(plannedExpenses)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toEntity(base);
  }

  Future<void> upsert(String userId, PlannedExpense plan) =>
      into(plannedExpenses).insert(
        PlannedExpensesCompanion.insert(
          id: plan.id,
          userId: userId,
          categoryId: Value<String?>(plan.categoryId),
          accountId: Value<String?>(plan.accountId),
          amountMilli: plan.amount.milli,
          currency: plan.amount.currency.code,
          dueAt: plan.dueAt,
          note: Value<String?>(plan.note),
          status: plan.status.wire,
          transactionId: Value<String?>(plan.transactionId),
          createdAt: DateTime.now(),
          updatedAt: plan.updatedAt,
        ),
        mode: InsertMode.insertOrReplace,
      );

  /// Soft delete, so the removal reaches the user's other devices.
  Future<void> softDelete(String id) =>
      (update(plannedExpenses)..where((t) => t.id.equals(id))).write(
        PlannedExpensesCompanion(
          deletedAt: Value<DateTime>(DateTime.now()),
          updatedAt: Value<DateTime>(DateTime.now()),
        ),
      );
}
