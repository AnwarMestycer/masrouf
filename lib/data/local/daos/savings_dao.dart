import 'package:drift/drift.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/mappers.dart';
import 'package:masrouf/data/local/tables/tables.dart';
import 'package:masrouf/domain/entities/savings_plan.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

part 'savings_dao.g.dart';

/// Savings periods, and the transfers that fill them.
///
/// Nothing here stores what is owed, what a month has saved so far, or what a
/// goal holds. Owed is `max(0, sum(committed) - sum(saved))` over closed
/// periods; the other two are sums over transfers between ordinary and savings
/// accounts. All three are derived on read, so an edited transfer or period
/// cannot leave a stale total behind.
@DriftAccessor(tables: <Type>[SavingsPeriods, Transactions, Accounts])
class SavingsDao extends DatabaseAccessor<AppDatabase> with _$SavingsDaoMixin {
  SavingsDao(super.db);

  Future<SavingsPeriod?> getById(String id) async {
    final row = await (select(savingsPeriods)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toEntity();
  }

  /// Whether a row with [id] exists at all, tombstoned or not.
  ///
  /// A month whose period was deleted must stay deleted; re-creating it under
  /// the same derived id would quietly undo the delete.
  Future<bool> exists(String id) async =>
      await (select(savingsPeriods)..where((t) => t.id.equals(id)))
          .getSingleOrNull() !=
      null;

  /// Periods still open, oldest first. Normally just the current month; more
  /// only when the app was not opened across a month end, or for a period
  /// opened by hand before months were the unit.
  Future<List<SavingsPeriod>> openPeriods(String userId) async {
    final rows = await (select(savingsPeriods)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.deletedAt.isNull() &
                t.confirmedOn.isNull(),
          )
          ..orderBy(<OrderClauseGenerator<$SavingsPeriodsTable>>[
            (t) => OrderingTerm.asc(t.startedOn),
          ]))
        .get();
    return rows.map((r) => r.toEntity()).toList(growable: false);
  }

  /// The last day any closed period covers, or null if none has closed.
  Future<DateTime?> lastCoveredOn(String userId) async {
    final last = savingsPeriods.confirmedOn.max();
    final row = await (selectOnly(savingsPeriods)
          ..addColumns(<Expression<Object>>[last])
          ..where(
            savingsPeriods.userId.equals(userId) &
                savingsPeriods.deletedAt.isNull() &
                savingsPeriods.confirmedOn.isNotNull(),
          ))
        .getSingle();
    return row.read(last);
  }

  /// Closed periods, newest first.
  Stream<List<SavingsPeriod>> watchConfirmed(String userId) =>
      (select(savingsPeriods)
            ..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.deletedAt.isNull() &
                  t.confirmedOn.isNotNull(),
            )
            ..orderBy(<OrderClauseGenerator<$SavingsPeriodsTable>>[
              (t) => OrderingTerm.desc(t.startedOn),
            ]))
          .watch()
          .map(
            (rows) => rows.map((r) => r.toEntity()).toList(growable: false),
          );

  /// Totals across closed periods, which is everything [SavingsLedger] needs,
  /// plus the last day they cover — where the open month starts counting.
  /// Summed in SQL rather than by reading every row back.
  Stream<({Money committed, Money saved, DateTime? lastCovered})> watchTotals(
    String userId,
    Currency base,
  ) {
    final committed = savingsPeriods.committedMilli.sum();
    final saved = savingsPeriods.savedMilli.sum();
    final last = savingsPeriods.confirmedOn.max();
    return (selectOnly(savingsPeriods)
          ..addColumns(<Expression<Object>>[committed, saved, last])
          ..where(
            savingsPeriods.userId.equals(userId) &
                savingsPeriods.deletedAt.isNull() &
                savingsPeriods.confirmedOn.isNotNull(),
          ))
        .watchSingle()
        .map(
          (row) => (
            committed: Money(row.read(committed) ?? 0, base),
            saved: Money(row.read(saved) ?? 0, base),
            lastCovered: row.read(last),
          ),
        );
  }

  /// A transfer's amount in the base currency, at the rate frozen on the row.
  ///
  /// The same rounding as `TxnRow.baseMilliIn`, so a transfer counts the same
  /// here as it does in the account balances.
  static const String _baseAmount =
      'CASE WHEN t.currency = ?1 THEN t.amount_milli '
      'ELSE CAST(ROUND(t.amount_milli * t.fx_rate_to_base) AS INTEGER) END';

  /// Transfers between an ordinary account and a savings account, with both
  /// ends resolved. A transfer between two savings accounts, or two ordinary
  /// ones, moves nothing in or out of savings and is left out by the join.
  static final String _savingsTransfers = '''
    FROM transactions t
    JOIN accounts src ON src.id = t.account_id
    JOIN accounts dst ON dst.id = t.transfer_account_id
    WHERE t.user_id = ?2
      AND t.deleted_at IS NULL
      AND t.type = '${TxnType.transfer.wire}'
      AND (src.type = '${AccountType.savings.wire}')
          <> (dst.type = '${AccountType.savings.wire}')
  ''';

  /// Moved *into* savings accounts on days `from..to`, in the base currency.
  ///
  /// Money in only. Taking money back out does not undo what a month set
  /// aside; it only makes that money spendable again, which the balance
  /// already shows.
  Stream<int> watchSavedBetween(
    String userId,
    DateTime from,
    DateTime to,
    Currency base,
  ) =>
      _savedBetween(userId, from, to, base)
          .watchSingle()
          .map((row) => row.read<int>('total'));

  Future<int> savedBetween(
    String userId,
    DateTime from,
    DateTime to,
    Currency base,
  ) async =>
      (await _savedBetween(userId, from, to, base).getSingle())
          .read<int>('total');

  Selectable<QueryRow> _savedBetween(
    String userId,
    DateTime from,
    DateTime to,
    Currency base,
  ) =>
      customSelect(
        'SELECT COALESCE(SUM($_baseAmount), 0) AS total '
        '$_savingsTransfers '
        "AND dst.type = '${AccountType.savings.wire}' "
        'AND t.date_ymd BETWEEN ?3 AND ?4',
        variables: <Variable<Object>>[
          Variable<String>(base.code),
          Variable<String>(userId),
          Variable<int>(from.ymd),
          Variable<int>(to.ymd),
        ],
        readsFrom: <ResultSetImplementation<HasResultSet, dynamic>>{
          transactions,
          accounts,
        },
      );

  /// What each goal holds: earmarked transfers in, minus earmarked transfers
  /// back out, in the base currency. Goals with nothing earmarked are absent.
  Stream<Map<String, int>> watchGoalTotals(String userId, Currency base) =>
      _goalTotals(userId, base).watch().map(_goalMap);

  Future<Map<String, int>> goalTotals(String userId, Currency base) async =>
      _goalMap(await _goalTotals(userId, base).get());

  Selectable<QueryRow> _goalTotals(String userId, Currency base) =>
      customSelect(
        'SELECT t.goal_id AS goal_id, '
        "SUM(CASE WHEN dst.type = '${AccountType.savings.wire}' "
        'THEN $_baseAmount ELSE -($_baseAmount) END) AS total '
        '$_savingsTransfers '
        'AND t.goal_id IS NOT NULL '
        'GROUP BY t.goal_id',
        variables: <Variable<Object>>[
          Variable<String>(base.code),
          Variable<String>(userId),
        ],
        readsFrom: <ResultSetImplementation<HasResultSet, dynamic>>{
          transactions,
          accounts,
        },
      );

  static Map<String, int> _goalMap(List<QueryRow> rows) => <String, int>{
        for (final row in rows)
          row.read<String>('goal_id'): row.read<int>('total'),
      };

  Future<void> upsert(String userId, SavingsPeriod period) =>
      into(savingsPeriods).insert(
        SavingsPeriodsCompanion.insert(
          id: period.id,
          userId: userId,
          startedOn: period.startedOn,
          incomeMilli: Value<int>(period.income.milli),
          committedMilli: Value<int>(period.committed.milli),
          confirmedOn: Value<DateTime?>(period.confirmedOn),
          savedMilli: Value<int?>(period.saved?.milli),
          currency: period.committed.currency.code,
          createdAt: DateTime.now(),
          updatedAt: period.updatedAt,
        ),
        mode: InsertMode.insertOrReplace,
      );

  /// Soft delete, so the removal reaches the user's other devices.
  Future<void> softDelete(String id) =>
      (update(savingsPeriods)..where((t) => t.id.equals(id))).write(
        SavingsPeriodsCompanion(
          deletedAt: Value<DateTime>(DateTime.now()),
          updatedAt: Value<DateTime>(DateTime.now()),
        ),
      );
}
