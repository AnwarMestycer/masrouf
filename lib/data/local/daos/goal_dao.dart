import 'package:drift/drift.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/mappers.dart';
import 'package:masrouf/data/local/tables/local_tables.dart';
import 'package:masrouf/data/local/tables/tables.dart';
import 'package:masrouf/domain/entities/savings_goal.dart';

part 'goal_dao.g.dart';

/// Savings goals and the account balances backing them.
///
/// Progress is read from `account_balances` — the same maintained aggregate the
/// dashboard uses — rather than stored on the goal. A goal cannot drift out of
/// step with the ledger because it holds no copy of it.
@DriftAccessor(tables: <Type>[SavingsGoals, Accounts, AccountBalances])
class GoalDao extends DatabaseAccessor<AppDatabase> with _$GoalDaoMixin {
  GoalDao(super.db);

  Stream<List<SavingsGoalProgress>> watchProgress(
    String userId,
    Currency base,
  ) {
    final query = select(savingsGoals).join(<Join<HasResultSet, dynamic>>[
      leftOuterJoin(accounts, accounts.id.equalsExp(savingsGoals.accountId)),
      leftOuterJoin(
        accountBalances,
        accountBalances.accountId.equalsExp(savingsGoals.accountId) &
            accountBalances.userId.equalsExp(savingsGoals.userId),
      ),
    ])
      ..where(
        savingsGoals.userId.equals(userId) & savingsGoals.deletedAt.isNull(),
      )
      ..orderBy(<OrderingTerm>[OrderingTerm.asc(savingsGoals.createdAt)]);

    return query.watch().map(
          (rows) => rows.map((row) {
            final goal = row.readTable(savingsGoals).toEntity(base);
            final account = row.readTableOrNull(accounts);
            final balance = row.readTableOrNull(accountBalances);
            return SavingsGoalProgress(
              goal: goal,
              // A missing balance row means the account has no transactions
              // yet, which is its opening balance exactly — not zero.
              saved: Money(
                balance?.balanceMilli ??
                    account?.openingBalanceMilli ??
                    0,
                goal.target.currency,
              ),
              accountName: account?.name ?? '',
            );
          }).toList(growable: false),
        );
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
