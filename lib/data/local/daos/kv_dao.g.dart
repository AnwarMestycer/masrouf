// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kv_dao.dart';

// ignore_for_file: type=lint
mixin _$KvDaoMixin on DatabaseAccessor<AppDatabase> {
  $KvEntriesTable get kvEntries => attachedDatabase.kvEntries;
  KvDaoManager get managers => KvDaoManager(this);
}

class KvDaoManager {
  final _$KvDaoMixin _db;
  KvDaoManager(this._db);
  $$KvEntriesTableTableManager get kvEntries =>
      $$KvEntriesTableTableManager(_db.attachedDatabase, _db.kvEntries);
}
