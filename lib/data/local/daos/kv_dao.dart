import 'package:drift/drift.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/tables/local_tables.dart';

part 'kv_dao.g.dart';

/// Device-local scratch state: pull cursors, the seeded flag, add-flow defaults.
///
/// Lives in the database rather than SharedPreferences so it participates in the
/// same transaction as the data it describes — a pull cursor advanced outside the
/// transaction that wrote the rows could skip records after a crash.
@DriftAccessor(tables: <Type>[KvEntries])
class KvDao extends DatabaseAccessor<AppDatabase> with _$KvDaoMixin {
  KvDao(super.db);

  static const String seededFlag = 'defaults_seeded';
  static const String lastAccountId = 'last_account_id';
  static const String lastCategoryIdPrefix = 'last_category_id.';

  /// The notification switches. Device-local rather than synced: a notification
  /// schedule belongs to the phone it fires on, not to the account.
  static const String weeklyDigest = 'weekly_digest_enabled';
  static const String plannedReminders = 'planned_reminders_enabled';
  static const String budgetAlerts = 'budget_alerts_enabled';

  static String pullCursor(String entity) => 'pull_cursor.$entity';

  Future<String?> get(String key) async {
    final row = await (select(kvEntries)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> put(String key, String value) => into(kvEntries).insert(
        KvEntriesCompanion.insert(key: key, value: value),
        mode: InsertMode.insertOrReplace,
      );

  Future<void> remove(String key) =>
      (delete(kvEntries)..where((t) => t.key.equals(key))).go();

  Future<bool> getFlag(String key) async => await get(key) == '1';

  Future<void> setFlag(String key, {required bool value}) =>
      put(key, value ? '1' : '0');

  Future<DateTime?> getTimestamp(String key) async {
    final raw = await get(key);
    if (raw == null) return null;
    final millis = int.tryParse(raw);
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  Future<void> putTimestamp(String key, DateTime value) =>
      put(key, value.toUtc().millisecondsSinceEpoch.toString());

  Stream<String?> watch(String key) =>
      (select(kvEntries)..where((t) => t.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value);
}
