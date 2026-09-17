// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'planned_dao.dart';

// ignore_for_file: type=lint
mixin _$PlannedDaoMixin on DatabaseAccessor<AppDatabase> {
  $PlannedExpensesTable get plannedExpenses => attachedDatabase.plannedExpenses;
  $CategoriesTable get categories => attachedDatabase.categories;
  PlannedDaoManager get managers => PlannedDaoManager(this);
}

class PlannedDaoManager {
  final _$PlannedDaoMixin _db;
  PlannedDaoManager(this._db);
  $$PlannedExpensesTableTableManager get plannedExpenses =>
      $$PlannedExpensesTableTableManager(
        _db.attachedDatabase,
        _db.plannedExpenses,
      );
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
}
