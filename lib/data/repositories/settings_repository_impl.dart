import 'package:drift/drift.dart';
import 'package:masrouf/core/error/auth_error_mapper.dart';
import 'package:masrouf/core/error/failure.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/result/result.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/daos/kv_dao.dart';
import 'package:masrouf/data/local/mappers.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/user_settings.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';
import 'package:masrouf/domain/repositories/repositories.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({
    required AppDatabase db,
    required SyncEngine sync,
    required this.userId,
  })  : _db = db,
        _sync = sync;

  final AppDatabase _db;
  final SyncEngine _sync;
  final String userId;

  @override
  Stream<UserSettings> watch() => (_db.select(_db.userSettingsRows)
        ..where((t) => t.userId.equals(userId)))
      .watchSingleOrNull()
      .map((row) => row?.toEntity() ?? UserSettings.fallback);

  @override
  Future<UserSettings> read() async {
    final row = await (_db.select(_db.userSettingsRows)
          ..where((t) => t.userId.equals(userId)))
        .getSingleOrNull();
    return row?.toEntity() ?? UserSettings.fallback;
  }

  @override
  Future<Result<void>> save(UserSettings settings) => guard(
        () async {
          await _db.into(_db.userSettingsRows).insert(
                UserSettingsRowsCompanion.insert(
                  // One settings row per user, so the user id is the natural key
                  // and there is no way to end up with two competing rows.
                  id: userId,
                  userId: userId,
                  baseCurrency: settings.baseCurrency.code,
                  locale: settings.locale,
                  themeMode: themeModeToWire(settings.themeMode),
                  paydayDayOfMonth: settings.paydayDayOfMonth,
                  updatedAt: DateTime.now(),
                ),
                mode: InsertMode.insertOrReplace,
              );

          // Aggregates are stored pre-converted into the base currency, so
          // changing it invalidates all of them.
          await _db.transactionDao
              .rebuildAggregates(userId, settings.baseCurrency);
          _sync.updateBaseCurrency(settings.baseCurrency);

          await _db.syncQueueDao
              .enqueue(SyncEntity.userSettings, userId, SyncOp.upsert);
          _sync.requestSync();
        },
        mapDataError,
      );

  @override
  Stream<List<ExchangeRate>> watchRates() => (_db.select(_db.exchangeRates)
        ..where((t) => t.userId.equals(userId)))
      .watch()
      .map((rows) => rows.map((r) => r.toEntity()).toList(growable: false));

  @override
  Future<Map<String, double>> ratesToBase() async {
    final rows = await (_db.select(_db.exchangeRates)
          ..where((t) => t.userId.equals(userId)))
        .get();
    return <String, double>{
      for (final row in rows) row.currency: row.rateToBase,
    };
  }

  @override
  Future<Result<void>> saveRate(Currency currency, double rateToBase) => guard(
        () async {
          if (rateToBase <= 0) {
            throw const Failure(
              FailureCode.validation,
              debugMessage: 'Exchange rate must be greater than zero',
            );
          }
          await _db.into(_db.exchangeRates).insert(
                ExchangeRatesCompanion.insert(
                  id: currency.code,
                  userId: userId,
                  currency: currency.code,
                  rateToBase: rateToBase,
                  updatedAt: DateTime.now(),
                ),
                mode: InsertMode.insertOrReplace,
              );
          await _db.syncQueueDao
              .enqueue(SyncEntity.exchangeRates, currency.code, SyncOp.upsert);
          _sync.requestSync();
        },
        mapDataError,
      );

  @override
  Future<String?> lastUsedAccountId() => _db.kvDao.get(KvDao.lastAccountId);

  @override
  Future<void> rememberAccount(String accountId) =>
      _db.kvDao.put(KvDao.lastAccountId, accountId);

  @override
  Stream<Money> watchTotalBalance() async* {
    final settings = await read();
    final rates = await ratesToBase();
    yield* _db.accountDao
        .watchTotalBalance(userId, settings.baseCurrency, rates);
  }
}
