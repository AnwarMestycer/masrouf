// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_dao.dart';

// ignore_for_file: type=lint
mixin _$AnalyticsDaoMixin on DatabaseAccessor<AppDatabase> {
  $MonthlyCategoryTotalsTable get monthlyCategoryTotals =>
      attachedDatabase.monthlyCategoryTotals;
  $DailyTotalsTable get dailyTotals => attachedDatabase.dailyTotals;
  $CategoriesTable get categories => attachedDatabase.categories;
  $TransactionsTable get transactions => attachedDatabase.transactions;
  AnalyticsDaoManager get managers => AnalyticsDaoManager(this);
}

class AnalyticsDaoManager {
  final _$AnalyticsDaoMixin _db;
  AnalyticsDaoManager(this._db);
  $$MonthlyCategoryTotalsTableTableManager get monthlyCategoryTotals =>
      $$MonthlyCategoryTotalsTableTableManager(
        _db.attachedDatabase,
        _db.monthlyCategoryTotals,
      );
  $$DailyTotalsTableTableManager get dailyTotals =>
      $$DailyTotalsTableTableManager(_db.attachedDatabase, _db.dailyTotals);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db.attachedDatabase, _db.transactions);
}
