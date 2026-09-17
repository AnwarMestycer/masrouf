import 'package:drift/drift.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/mappers.dart';
import 'package:masrouf/data/local/tables/local_tables.dart';
import 'package:masrouf/data/local/tables/tables.dart';
import 'package:masrouf/domain/entities/account.dart';

part 'account_dao.g.dart';

@DriftAccessor(tables: <Type>[Accounts, AccountBalances])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(super.db);

  /// Live accounts with their running balances, ready for the balance header.
  ///
  /// One joined query rather than a balance lookup per account: the join is what
  /// keeps the header O(1) round trips as the account list grows, and drift
  /// re-emits it only when one of the two tables actually changes.
  Stream<List<AccountWithBalance>> watchWithBalances(
    String userId, {
    bool includeArchived = false,
  }) {
    final query = select(accounts).join(<Join<HasResultSet, dynamic>>[
      leftOuterJoin(
        accountBalances,
        accountBalances.accountId.equalsExp(accounts.id) &
            accountBalances.userId.equalsExp(accounts.userId),
      ),
    ])
      ..where(accounts.userId.equals(userId) & accounts.deletedAt.isNull());

    if (!includeArchived) {
      query.where(accounts.archived.equals(false));
    }
    query.orderBy(<OrderingTerm>[
      OrderingTerm.asc(accounts.sortOrder),
      OrderingTerm.asc(accounts.name),
    ]);

    return query.watch().map(
          (rows) => rows.map((row) {
            final account = row.readTable(accounts).toEntity();
            final balance = row.readTableOrNull(accountBalances);
            return AccountWithBalance(
              account: account,
              // A missing balance row means "no transactions yet", which is the
              // opening balance exactly — not zero.
              balance: Money(
                balance?.balanceMilli ?? account.openingBalance.milli,
                account.currency,
              ),
            );
          }).toList(growable: false),
        );
  }

  Stream<List<Account>> watchAll(String userId, {bool includeArchived = false}) {
    final query = select(accounts)
      ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull());
    if (!includeArchived) {
      query.where((t) => t.archived.equals(false));
    }
    query.orderBy(<OrderClauseGenerator<$AccountsTable>>[
      (t) => OrderingTerm.asc(t.sortOrder),
      (t) => OrderingTerm.asc(t.name),
    ]);
    return query.watch().map(
          (rows) => rows.map((r) => r.toEntity()).toList(growable: false),
        );
  }

  Future<List<Account>> getAll(String userId, {bool includeArchived = true}) async {
    final query = select(accounts)
      ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull());
    if (!includeArchived) {
      query.where((t) => t.archived.equals(false));
    }
    final rows = await query.get();
    return rows.map((r) => r.toEntity()).toList(growable: false);
  }

  Future<Account?> getById(String id) async {
    final row = await (select(accounts)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    return row?.toEntity();
  }

  /// Writes the account and makes sure it has a balance row.
  ///
  /// Seeding the balance eagerly rather than on the account's first transaction
  /// keeps the incrementally maintained table identical to what a full rebuild
  /// would produce — otherwise a brand-new account has no row until it is used,
  /// and the two paths disagree about a set that should be equal.
  Future<void> upsert(String userId, Account account) => transaction(() async {
        await _upsertRow(userId, account);
        await customInsert(
          'INSERT OR IGNORE INTO account_balances '
          '(user_id, account_id, balance_milli) '
          'SELECT user_id, id, opening_balance_milli FROM accounts WHERE id = ?',
          variables: <Variable<Object>>[Variable<String>(account.id)],
          updates: {accountBalances},
        );
      });

  Future<void> _upsertRow(String userId, Account account) =>
      into(accounts).insert(
        AccountsCompanion.insert(
          id: account.id,
          userId: userId,
          name: account.name,
          type: account.type.wire,
          currency: account.currency.code,
          openingBalanceMilli: Value<int>(account.openingBalance.milli),
          sortOrder: Value<int>(account.sortOrder),
          archived: Value<bool>(account.archived),
          createdAt: DateTime.now(),
          updatedAt: account.updatedAt,
        ),
        mode: InsertMode.insertOrReplace,
      );

  /// Soft delete. The tombstone is what lets the deletion reach the server and,
  /// from there, the user's other devices.
  Future<void> softDelete(String id) => (update(accounts)
        ..where((t) => t.id.equals(id)))
      .write(
    AccountsCompanion(
      deletedAt: Value<DateTime>(DateTime.now()),
      updatedAt: Value<DateTime>(DateTime.now()),
    ),
  );

  Future<void> reorder(List<String> orderedIds) => batch((Batch b) {
        for (var i = 0; i < orderedIds.length; i++) {
          b.update(
            accounts,
            AccountsCompanion(
              sortOrder: Value<int>(i),
              updatedAt: Value<DateTime>(DateTime.now()),
            ),
            where: ($AccountsTable t) => t.id.equals(orderedIds[i]),
          );
        }
      });

  /// Total across accounts, converted into [base].
  ///
  /// Reads from the maintained balance table, so it stays a scan of at most a
  /// handful of rows no matter how long the ledger gets.
  Stream<Money> watchTotalBalance(
    String userId,
    Currency base,
    Map<String, double> ratesToBase,
  ) =>
      watchWithBalances(userId).map((list) {
        var totalMilli = 0;
        for (final entry in list) {
          final code = entry.account.currency.code;
          final rate = code == base.code ? 1.0 : (ratesToBase[code] ?? 0.0);
          totalMilli += (entry.balance.milli * rate).round();
        }
        return Money(totalMilli, base);
      });
}
