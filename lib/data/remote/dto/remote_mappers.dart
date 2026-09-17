import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/data/local/mappers.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/budget.dart';
import 'package:masrouf/domain/entities/planned_expense.dart';
import 'package:masrouf/domain/entities/savings_goal.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/entities/recurring_rule.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/entities/user_settings.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:flutter/material.dart' show ThemeMode;

/// Domain <-> Supabase JSON.
///
/// Hand-written rather than generated: the wire format has to match the SQL
/// migration exactly, and a hand-written mapper next to the schema is easier to
/// keep honest than an annotation three files away. `numeric` columns travel as
/// decimal strings so no amount is ever routed through a double.
typedef Json = Map<String, dynamic>;

// ------------------------------------------------------------------ shared --

DateTime _readTimestamp(Object? value) =>
    value == null ? DateTime.now().toUtc() : DateTime.parse(value.toString()).toUtc();

DateTime? _readNullableTimestamp(Object? value) =>
    value == null ? null : DateTime.parse(value.toString()).toUtc();

double _readDouble(Object? value, double fallback) => switch (value) {
      null => fallback,
      final num n => n.toDouble(),
      _ => double.tryParse(value.toString()) ?? fallback,
    };

/// Whether a pulled row is a tombstone.
bool isTombstone(Json row) => row['deleted_at'] != null;

/// The value identifying a pulled row, per entity.
///
/// Most tables carry a surrogate `id`, but two do not: `user_settings` is keyed
/// by `user_id` and `exchange_rates` by `(user_id, currency)`. Reading `id` off
/// those returns null, and the cast then throws — which would kill the whole pull
/// the moment the user changed a setting or set an exchange rate.
///
/// The local mirror gives both tables a synthetic primary key — the user id and
/// the currency code respectively — so what this returns must match exactly what
/// the pull worker writes into drift, or the conflict check would compare against
/// a row it never finds.
String rowKeyFor(SyncEntity entity, Json row) => switch (entity) {
      SyncEntity.userSettings => row['user_id'] as String,
      SyncEntity.exchangeRates => row['currency'] as String,
      SyncEntity.accounts ||
      SyncEntity.categories ||
      SyncEntity.transactions ||
      SyncEntity.recurringRules ||
      SyncEntity.budgets ||
      SyncEntity.plannedExpenses ||
      SyncEntity.savingsGoals =>
        row['id'] as String,
    };

DateTime rowUpdatedAt(Json row) => _readTimestamp(row['updated_at']);

// ---------------------------------------------------------------- accounts --

Json accountToJson(String userId, Account account, {DateTime? deletedAt}) => <String, dynamic>{
      'id': account.id,
      'user_id': userId,
      'name': account.name,
      'type': account.type.wire,
      'currency': account.currency.code,
      'opening_balance': account.openingBalance.toDecimalString(),
      'sort_order': account.sortOrder,
      'archived': account.archived,
      'updated_at': account.updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };

Account accountFromJson(Json row) {
  final currency = Currency.fromCode(row['currency'] as String);
  return Account(
    id: row['id'] as String,
    name: row['name'] as String,
    type: AccountType.fromWire(row['type'] as String),
    currency: currency,
    openingBalance: Money.fromJson(row['opening_balance'], currency),
    sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
    archived: row['archived'] as bool? ?? false,
    updatedAt: _readTimestamp(row['updated_at']),
  );
}

// -------------------------------------------------------------- categories --

Json categoryToJson(String userId, Category category, {DateTime? deletedAt}) => <String, dynamic>{
      'id': category.id,
      'user_id': userId,
      'name': category.name,
      'kind': category.kind.wire,
      'icon': category.icon,
      'color': category.color,
      'sort_order': category.sortOrder,
      'is_default': category.isDefault,
      'updated_at': category.updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };

Category categoryFromJson(Json row) => Category(
      id: row['id'] as String,
      name: row['name'] as String,
      kind: CategoryKind.fromWire(row['kind'] as String),
      icon: row['icon'] as String? ?? 'category',
      color: (row['color'] as num).toInt(),
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      isDefault: row['is_default'] as bool? ?? false,
      updatedAt: _readTimestamp(row['updated_at']),
    );

// ------------------------------------------------------------ transactions --

Json txnToJson(String userId, Txn txn, {DateTime? deletedAt}) => <String, dynamic>{
      'id': txn.id,
      'user_id': userId,
      'type': txn.type.wire,
      'amount': txn.amount.toDecimalString(),
      'currency': txn.amount.currency.code,
      'fx_rate_to_base': txn.fxRateToBase,
      'category_id': txn.categoryId,
      'account_id': txn.accountId,
      'transfer_account_id': txn.transferAccountId,
      'date': txn.date.toIsoDate(),
      'note': txn.note,
      'tags': txn.tags,
      'recurring_rule_id': txn.recurringRuleId,
      'created_at': txn.createdAt.toUtc().toIso8601String(),
      'updated_at': txn.updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };

Txn txnFromJson(Json row) {
  final currency = Currency.fromCode(row['currency'] as String);
  return Txn(
    id: row['id'] as String,
    type: TxnType.fromWire(row['type'] as String),
    amount: Money.fromJson(row['amount'], currency),
    fxRateToBase: _readDouble(row['fx_rate_to_base'], 1),
    categoryId: row['category_id'] as String?,
    accountId: row['account_id'] as String,
    transferAccountId: row['transfer_account_id'] as String?,
    date: parseIsoDate(row['date'] as String),
    note: row['note'] as String?,
    tags: (row['tags'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(growable: false) ??
        const <String>[],
    recurringRuleId: row['recurring_rule_id'] as String?,
    createdAt: _readTimestamp(row['created_at']),
    updatedAt: _readTimestamp(row['updated_at']),
  );
}

// ---------------------------------------------------------- recurring rules --

Json recurringToJson(String userId, RecurringRule rule, {DateTime? deletedAt}) => <String, dynamic>{
      'id': rule.id,
      'user_id': userId,
      'type': rule.type.wire,
      'amount': rule.amount.toDecimalString(),
      'currency': rule.amount.currency.code,
      'category_id': rule.categoryId,
      'account_id': rule.accountId,
      'transfer_account_id': rule.transferAccountId,
      'note': rule.note,
      'cadence': rule.cadence.wire,
      'day_of_month': rule.dayOfMonth,
      'day_of_week': rule.dayOfWeek,
      'next_run_date': rule.nextRunDate.toIsoDate(),
      'last_run_date': rule.lastRunDate?.toIsoDate(),
      'active': rule.active,
      'updated_at': rule.updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };

RecurringRule recurringFromJson(Json row) {
  final currency = Currency.fromCode(row['currency'] as String);
  return RecurringRule(
    id: row['id'] as String,
    type: TxnType.fromWire(row['type'] as String),
    amount: Money.fromJson(row['amount'], currency),
    categoryId: row['category_id'] as String?,
    accountId: row['account_id'] as String,
    transferAccountId: row['transfer_account_id'] as String?,
    note: row['note'] as String?,
    cadence: Cadence.fromWire(row['cadence'] as String),
    dayOfMonth: (row['day_of_month'] as num?)?.toInt(),
    dayOfWeek: (row['day_of_week'] as num?)?.toInt(),
    nextRunDate: parseIsoDate(row['next_run_date'] as String),
    lastRunDate: row['last_run_date'] == null
        ? null
        : parseIsoDate(row['last_run_date'] as String),
    active: row['active'] as bool? ?? true,
    updatedAt: _readTimestamp(row['updated_at']),
  );
}

// ----------------------------------------------------------------- budgets --

Json budgetToJson(String userId, Budget budget, {DateTime? deletedAt}) =>
    <String, dynamic>{
      'id': budget.id,
      'user_id': userId,
      'category_id': budget.categoryId,
      'amount': budget.amount.toDecimalString(),
      'currency': budget.amount.currency.code,
      'updated_at': budget.updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };

Budget budgetFromJson(Json row) => Budget(
      id: row['id'] as String,
      categoryId: row['category_id'] as String,
      amount: Money.fromJson(
        row['amount'],
        Currency.fromCode(row['currency'] as String),
      ),
      updatedAt: _readTimestamp(row['updated_at']),
    );

// -------------------------------------------------------- planned expenses --

Json plannedToJson(
  String userId,
  PlannedExpense plan, {
  DateTime? deletedAt,
}) =>
    <String, dynamic>{
      'id': plan.id,
      'user_id': userId,
      'category_id': plan.categoryId,
      'account_id': plan.accountId,
      'amount': plan.amount.toDecimalString(),
      'currency': plan.amount.currency.code,
      // Full timestamp, not a date: a plan carries a time of day.
      'due_at': plan.dueAt.toUtc().toIso8601String(),
      'note': plan.note,
      'status': plan.status.wire,
      'transaction_id': plan.transactionId,
      'updated_at': plan.updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };

PlannedExpense plannedFromJson(Json row) => PlannedExpense(
      id: row['id'] as String,
      categoryId: row['category_id'] as String?,
      accountId: row['account_id'] as String?,
      amount: Money.fromJson(
        row['amount'],
        Currency.fromCode(row['currency'] as String),
      ),
      dueAt: _readTimestamp(row['due_at']),
      note: row['note'] as String?,
      status: PlannedStatus.fromWire(row['status'] as String? ?? 'pending'),
      transactionId: row['transaction_id'] as String?,
      updatedAt: _readTimestamp(row['updated_at']),
    );

// ------------------------------------------------------------ savings goals --

Json goalToJson(String userId, SavingsGoal goal, {DateTime? deletedAt}) =>
    <String, dynamic>{
      'id': goal.id,
      'user_id': userId,
      'name': goal.name,
      'target': goal.target.toDecimalString(),
      'currency': goal.target.currency.code,
      'account_id': goal.accountId,
      'target_date': goal.targetDate?.toIsoDate(),
      'updated_at': goal.updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };

SavingsGoal goalFromJson(Json row) => SavingsGoal(
      id: row['id'] as String,
      name: row['name'] as String,
      target: Money.fromJson(
        row['target'],
        Currency.fromCode(row['currency'] as String),
      ),
      accountId: row['account_id'] as String,
      targetDate: row['target_date'] == null
          ? null
          : parseIsoDate(row['target_date'] as String),
      updatedAt: _readTimestamp(row['updated_at']),
    );

// ------------------------------------------- settings and exchange rates --

Json settingsToJson(String userId, UserSettings settings) => <String, dynamic>{
      'user_id': userId,
      'base_currency': settings.baseCurrency.code,
      'locale': settings.locale,
      'theme_mode': themeModeToWire(settings.themeMode),
      'payday_day_of_month': settings.paydayDayOfMonth,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

UserSettings settingsFromJson(Json row) => UserSettings(
      baseCurrency: Currency.fromCode(row['base_currency'] as String? ?? 'TND'),
      locale: row['locale'] as String? ?? 'fr',
      themeMode: switch (row['theme_mode'] as String?) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      paydayDayOfMonth: (row['payday_day_of_month'] as num?)?.toInt() ?? 25,
    );

Json rateToJson(String userId, ExchangeRate rate) => <String, dynamic>{
      'user_id': userId,
      'currency': rate.currency.code,
      'rate_to_base': rate.rateToBase,
      'updated_at': rate.updatedAt.toUtc().toIso8601String(),
    };

ExchangeRate rateFromJson(Json row) => ExchangeRate(
      currency: Currency.fromCode(row['currency'] as String),
      rateToBase: _readDouble(row['rate_to_base'], 1),
      updatedAt: _readTimestamp(row['updated_at']),
    );

DateTime? tombstoneOf(Json row) => _readNullableTimestamp(row['deleted_at']);
