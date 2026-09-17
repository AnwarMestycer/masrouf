import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/budget.dart';
import 'package:masrouf/domain/entities/planned_expense.dart';
import 'package:masrouf/domain/entities/savings_goal.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/entities/recurring_rule.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/entities/user_settings.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:flutter/material.dart' show ThemeMode;

/// Drift row -> domain entity.
///
/// Read paths hand domain entities straight out of the DAOs rather than passing
/// row objects up to be re-wrapped in the repository: on a scrolling history list
/// the second allocation per row is pure waste.
extension AccountRowX on AccountRow {
  Account toEntity() => Account(
        id: id,
        name: name,
        type: AccountType.fromWire(type),
        currency: Currency.fromCode(currency),
        openingBalance: Money(openingBalanceMilli, Currency.fromCode(currency)),
        sortOrder: sortOrder,
        archived: archived,
        updatedAt: updatedAt,
      );
}

extension CategoryRowX on CategoryRow {
  Category toEntity() => Category(
        id: id,
        name: name,
        kind: CategoryKind.fromWire(kind),
        icon: icon,
        color: color,
        sortOrder: sortOrder,
        isDefault: isDefault,
        updatedAt: updatedAt,
      );
}

extension BudgetRowX on BudgetRow {
  /// [base] rather than the stored code: caps are held in the base currency, and
  /// passing it in keeps the entity consistent with the aggregates it is
  /// compared against even if the base changed after the row was written.
  Budget toEntity(Currency base) => Budget(
        id: id,
        categoryId: categoryId,
        amount: Money(amountMilli, base),
        updatedAt: updatedAt,
      );
}

extension PlannedExpenseRowX on PlannedExpenseRow {
  PlannedExpense toEntity(Currency base) => PlannedExpense(
        id: id,
        categoryId: categoryId,
        accountId: accountId,
        // Stored in whatever currency it was planned in; converted only where a
        // total is needed, exactly like UpcomingBill.
        amount: Money(amountMilli, Currency.fromCode(currency)),
        dueAt: dueAt,
        note: note,
        status: PlannedStatus.fromWire(status),
        transactionId: transactionId,
        updatedAt: updatedAt,
      );
}

extension SavingsGoalRowX on SavingsGoalRow {
  SavingsGoal toEntity(Currency base) => SavingsGoal(
        id: id,
        name: name,
        target: Money(targetMilli, Currency.fromCode(currency)),
        accountId: accountId,
        targetDate: targetDate,
        updatedAt: updatedAt,
      );
}

extension TransactionRowX on TxnRow {
  Txn toEntity() {
    final money = Currency.fromCode(currency);
    return Txn(
      id: id,
      type: TxnType.fromWire(type),
      amount: Money(amountMilli, money),
      fxRateToBase: fxRateToBase,
      categoryId: categoryId,
      accountId: accountId,
      transferAccountId: transferAccountId,
      date: ymdToDate(dateYmd),
      note: note,
      tags: tags,
      recurringRuleId: recurringRuleId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// The row's amount expressed in the base currency, using the rate frozen on
  /// the row. The aggregate tables store exactly this value, so they and the
  /// per-row display can never drift apart.
  int baseMilliIn(Currency base) => currency == base.code
      ? amountMilli
      : (amountMilli * fxRateToBase).round();
}

extension RecurringRuleRowX on RecurringRuleRow {
  RecurringRule toEntity() => RecurringRule(
        id: id,
        type: TxnType.fromWire(type),
        amount: Money(amountMilli, Currency.fromCode(currency)),
        categoryId: categoryId,
        accountId: accountId,
        transferAccountId: transferAccountId,
        note: note,
        cadence: Cadence.fromWire(cadence),
        dayOfMonth: dayOfMonth,
        dayOfWeek: dayOfWeek,
        nextRunDate: ymdToDate(nextRunYmd),
        lastRunDate: lastRunYmd == null ? null : ymdToDate(lastRunYmd!),
        active: active,
        updatedAt: updatedAt,
      );
}

extension ExchangeRateRowX on ExchangeRateRow {
  ExchangeRate toEntity() => ExchangeRate(
        currency: Currency.fromCode(currency),
        rateToBase: rateToBase,
        updatedAt: updatedAt,
      );
}

extension UserSettingsRowX on UserSettingsRow {
  UserSettings toEntity() => UserSettings(
        baseCurrency: Currency.fromCode(baseCurrency),
        locale: locale,
        themeMode: switch (themeMode) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        paydayDayOfMonth: paydayDayOfMonth,
      );
}

String themeModeToWire(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };

/// `yyyyMMdd` -> local midnight.
DateTime ymdToDate(int ymd) =>
    DateTime(ymd ~/ 10000, (ymd ~/ 100) % 100, ymd % 100);

int dateToYmd(DateTime date) => date.ymd;
