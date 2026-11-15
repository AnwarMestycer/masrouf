import 'package:drift/drift.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/mappers.dart';
import 'package:masrouf/data/local/tables/tables.dart';
import 'package:masrouf/domain/entities/savings_goal.dart';

part 'goal_dao.g.dart';

/// Savings goals, with the name of the account each one saves into.
///
/// Progress is not read here. It is the transfers earmarked for each goal,
/// summed by `SavingsDao.watchGoalTotals`; a goal row holds no total of its
/// own, so it cannot drift out of step with the ledger.
@DriftAccessor(tables: <Type>[SavingsGoals, Accounts])
class GoalDao extends DatabaseAccessor<AppDatabase> with _$GoalDaoMixin {
  GoalDao(super.db);

  Stream<List<({SavingsGoal goal, String accountName})>> watchGoals(
    String userId,
    Currency base,
  ) {
    final query = select(savingsGoals).join(<Join<HasResultSet, dynamic>>[
      leftOuterJoin(accounts, accounts.id.equalsExp(savingsGoals.accountId)),
    ])
      ..where(
        savingsGoals.userId.equals(userId) & savingsGoals.deletedAt.isNull(),
      )
      ..orderBy(<OrderingTerm>[OrderingTerm.asc(savingsGoals.createdAt)]);

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => (
                  goal: row.readTable(savingsGoals).toEntity(base),
                  accountName: row.readTableOrNull(accounts)?.name ?? '',
                ),
              )
              .toList(growable: false),
        );
  }

  Future<SavingsGoal?> getById(String id, Currency base) async {
    final row = await (select(savingsGoals)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toEntity(base);
  }

  Future<void> upsert(String userId, SavingsGoal goal) =>
      into(savingsGoals).insert(
        SavingsGoalsCompanion.insert(
          id: goal.id,
          userId: userId,
          name: goal.name,
          targetMilli: goal.target.milli,
          currency: goal.target.currency.code,
          accountId: goal.accountId,
          targetDate: Value<DateTime?>(goal.targetDate),
          createdAt: DateTime.now(),
          updatedAt: goal.updatedAt,
        ),
        mode: InsertMode.insertOrReplace,
      );

  Future<void> softDelete(String id) =>
      (update(savingsGoals)..where((t) => t.id.equals(id))).write(
        SavingsGoalsCompanion(
          deletedAt: Value<DateTime>(DateTime.now()),
          updatedAt: Value<DateTime>(DateTime.now()),
        ),
      );
}
