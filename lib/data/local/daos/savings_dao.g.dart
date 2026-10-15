// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'savings_dao.dart';

// ignore_for_file: type=lint
mixin _$SavingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SavingsPeriodsTable get savingsPeriods => attachedDatabase.savingsPeriods;
  SavingsDaoManager get managers => SavingsDaoManager(this);
}

class SavingsDaoManager {
  final _$SavingsDaoMixin _db;
  SavingsDaoManager(this._db);
  $$SavingsPeriodsTableTableManager get savingsPeriods =>
      $$SavingsPeriodsTableTableManager(
        _db.attachedDatabase,
        _db.savingsPeriods,
      );
}
