import 'package:drift/drift.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/mappers.dart';
import 'package:masrouf/data/remote/dto/remote_mappers.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';

/// Writes wire-format rows into the local mirror.
///
/// Extracted from [PullWorker] because restoring a backup needs exactly the same
/// translation: a backup file *is* a set of wire-format rows, so the alternative
/// was a second copy of this switch that would drift out of step with the first
/// the next time a column was added.
///
/// Deliberately opens no transaction of its own. The pull wraps one call per
/// entity; a restore wraps every entity in a single transaction so a failure
/// half-way cannot leave the ledger part-replaced. Nor does it filter by
/// conflict — the caller decides whether these rows win.
Future<void> applyRemoteRows(
  AppDatabase db,
  String userId,
  SyncEntity entity,
  List<Json> rows,
) async {
  if (rows.isEmpty) return;

  switch (entity) {
    case SyncEntity.accounts:
      await db.batch((Batch b) {
        b.insertAllOnConflictUpdate(
          db.accounts,
          rows.map((row) {
            final account = accountFromJson(row);
            return AccountsCompanion.insert(
              id: account.id,
              userId: userId,
              name: account.name,
              type: account.type.wire,
              currency: account.currency.code,
              openingBalanceMilli: Value<int>(account.openingBalance.milli),
              sortOrder: Value<int>(account.sortOrder),
              archived: Value<bool>(account.archived),
              createdAt: DateTime.now(),
              updatedAt: account.updatedAt,
              deletedAt: Value<DateTime?>(tombstoneOf(row)),
            );
          }).toList(growable: false),
        );
      });

    case SyncEntity.categories:
      await db.batch((Batch b) {
        b.insertAllOnConflictUpdate(
          db.categories,
          rows.map((row) {
            final category = categoryFromJson(row);
            return CategoriesCompanion.insert(
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
              deletedAt: Value<DateTime?>(tombstoneOf(row)),
            );
          }).toList(growable: false),
        );
      });

    case SyncEntity.transactions:
      await db.batch((Batch b) {
        b.insertAllOnConflictUpdate(
          db.transactions,
          rows.map((row) {
            final txn = txnFromJson(row);
            return TransactionsCompanion.insert(
              id: txn.id,
              userId: userId,
              type: txn.type.wire,
              amountMilli: txn.amount.milli,
              currency: txn.amount.currency.code,
              fxRateToBase: Value<double>(txn.fxRateToBase),
              categoryId: Value<String?>(txn.categoryId),
              accountId: txn.accountId,
              transferAccountId: Value<String?>(txn.transferAccountId),
              dateYmd: txn.date.ymd,
              note: Value<String?>(txn.note),
              tags: txn.tags,
              recurringRuleId: Value<String?>(txn.recurringRuleId),
              createdAt: txn.createdAt,
              updatedAt: txn.updatedAt,
              deletedAt: Value<DateTime?>(tombstoneOf(row)),
            );
          }).toList(growable: false),
        );
      });

    case SyncEntity.recurringRules:
      await db.batch((Batch b) {
        b.insertAllOnConflictUpdate(
          db.recurringRules,
          rows.map((row) {
            final rule = recurringFromJson(row);
            return RecurringRulesCompanion.insert(
              id: rule.id,
              userId: userId,
              type: rule.type.wire,
              amountMilli: rule.amount.milli,
              currency: rule.amount.currency.code,
              categoryId: Value<String?>(rule.categoryId),
              accountId: rule.accountId,
              transferAccountId: Value<String?>(rule.transferAccountId),
              note: Value<String?>(rule.note),
              cadence: rule.cadence.wire,
              dayOfMonth: Value<int?>(rule.dayOfMonth),
              dayOfWeek: Value<int?>(rule.dayOfWeek),
              nextRunYmd: rule.nextRunDate.ymd,
              lastRunYmd: Value<int?>(rule.lastRunDate?.ymd),
              active: Value<bool>(rule.active),
              createdAt: DateTime.now(),
              updatedAt: rule.updatedAt,
              deletedAt: Value<DateTime?>(tombstoneOf(row)),
            );
          }).toList(growable: false),
        );
      });

    case SyncEntity.budgets:
      await db.batch((Batch b) {
        b.insertAllOnConflictUpdate(
          db.budgets,
          rows.map((row) {
            final budget = budgetFromJson(row);
            return BudgetsCompanion.insert(
              id: budget.id,
              userId: userId,
              categoryId: budget.categoryId,
              amountMilli: budget.amount.milli,
              currency: budget.amount.currency.code,
              createdAt: DateTime.now(),
              updatedAt: budget.updatedAt,
              deletedAt: Value<DateTime?>(tombstoneOf(row)),
            );
          }).toList(growable: false),
        );
      });

    case SyncEntity.plannedExpenses:
      await db.batch((Batch b) {
        b.insertAllOnConflictUpdate(
          db.plannedExpenses,
          rows.map((row) {
            final plan = plannedFromJson(row);
            return PlannedExpensesCompanion.insert(
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
              deletedAt: Value<DateTime?>(tombstoneOf(row)),
            );
          }).toList(growable: false),
        );
      });

    case SyncEntity.savingsGoals:
      await db.batch((Batch b) {
        b.insertAllOnConflictUpdate(
          db.savingsGoals,
          rows.map((row) {
            final goal = goalFromJson(row);
            return SavingsGoalsCompanion.insert(
              id: goal.id,
              userId: userId,
              name: goal.name,
              targetMilli: goal.target.milli,
              currency: goal.target.currency.code,
              accountId: goal.accountId,
              targetDate: Value<DateTime?>(goal.targetDate),
              createdAt: DateTime.now(),
              updatedAt: goal.updatedAt,
              deletedAt: Value<DateTime?>(tombstoneOf(row)),
            );
          }).toList(growable: false),
        );
      });

    case SyncEntity.exchangeRates:
      await db.batch((Batch b) {
        b.insertAllOnConflictUpdate(
          db.exchangeRates,
          rows.map((row) {
            final rate = rateFromJson(row);
            return ExchangeRatesCompanion.insert(
              // Rates are keyed by currency on the server; the local table
              // needs a surrogate id, and the code is a natural stable one.
              id: rate.currency.code,
              userId: userId,
              currency: rate.currency.code,
              rateToBase: rate.rateToBase,
              updatedAt: rate.updatedAt,
            );
          }).toList(growable: false),
        );
      });

    case SyncEntity.userSettings:
      await db.batch((Batch b) {
        b.insertAllOnConflictUpdate(
          db.userSettingsRows,
          rows.map((row) {
            final settings = settingsFromJson(row);
            return UserSettingsRowsCompanion.insert(
              id: userId,
              userId: userId,
              baseCurrency: settings.baseCurrency.code,
              locale: settings.locale,
              themeMode: themeModeToWire(settings.themeMode),
              paydayDayOfMonth: settings.paydayDayOfMonth,
              updatedAt: rowUpdatedAt(row),
            );
          }).toList(growable: false),
        );
      });
  }
}
