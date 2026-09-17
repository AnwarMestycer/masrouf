// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_dao.dart';

// ignore_for_file: type=lint
mixin _$TransactionDaoMixin on DatabaseAccessor<AppDatabase> {
  $TransactionsTable get transactions => attachedDatabase.transactions;
  $CategoriesTable get categories => attachedDatabase.categories;
  $AccountsTable get accounts => attachedDatabase.accounts;
  $MonthlyCategoryTotalsTable get monthlyCategoryTotals =>
      attachedDatabase.monthlyCategoryTotals;
  $DailyTotalsTable get dailyTotals => attachedDatabase.dailyTotals;
  $AccountBalancesTable get accountBalances => attachedDatabase.accountBalances;
  TransactionDaoManager get managers => TransactionDaoManager(this);
}

class TransactionDaoManager {
  final _$TransactionDaoMixin _db;
  TransactionDaoManager(this._db);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db.attachedDatabase, _db.transactions);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$MonthlyCategoryTotalsTableTableManager get monthlyCategoryTotals =>
      $$MonthlyCategoryTotalsTableTableManager(
        _db.attachedDatabase,
        _db.monthlyCategoryTotals,
      );
  $$DailyTotalsTableTableManager get dailyTotals =>
      $$DailyTotalsTableTableManager(_db.attachedDatabase, _db.dailyTotals);
  $$AccountBalancesTableTableManager get accountBalances =>
      $$AccountBalancesTableTableManager(
        _db.attachedDatabase,
        _db.accountBalances,
      );
}
