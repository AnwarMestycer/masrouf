import 'package:drift/drift.dart';
import 'package:masrouf/core/config/app_config.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/mappers.dart';
import 'package:masrouf/data/local/tables/local_tables.dart';
import 'package:masrouf/data/local/tables/tables.dart';
import 'package:masrouf/domain/entities/history_filter.dart';
import 'package:masrouf/domain/entities/txn.dart';

part 'transaction_dao.g.dart';

@DriftAccessor(
  tables: <Type>[
    Transactions,
    Categories,
    Accounts,
    MonthlyCategoryTotals,
    DailyTotals,
    AccountBalances,
  ],
)
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  // ---------------------------------------------------------------- writes --

  /// Writes a transaction and folds it into the aggregate tables atomically.
  ///
  /// The row and the derived totals move together inside one drift transaction:
  /// if the aggregate update failed independently the dashboard would silently
  /// disagree with the ledger, and nothing would ever detect it.
  Future<void> insertTxn(String userId, Txn txn, Currency base) =>
      transaction(() async {
        await into(transactions).insert(_toCompanion(userId, txn));
        await _applyDelta(userId, txn, base, 1);
      });

  /// Replaces a transaction, reversing the old row's contribution first.
  ///
  /// [previous] is required rather than re-read here so the caller — which
  /// already had it in hand to build the edit form — does not pay for a second
  /// lookup, and so the reversal cannot race a concurrent write.
  Future<void> updateTxn(
    String userId,
    Txn previous,
    Txn next,
    Currency base,
  ) =>
      transaction(() async {
        await _applyDelta(userId, previous, base, -1);
        await into(transactions)
            .insert(_toCompanion(userId, next), mode: InsertMode.insertOrReplace);
        await _applyDelta(userId, next, base, 1);
      });

  Future<void> softDeleteTxn(String userId, Txn txn, Currency base) =>
      transaction(() async {
        await _applyDelta(userId, txn, base, -1);
        await (update(transactions)..where((t) => t.id.equals(txn.id))).write(
          TransactionsCompanion(
            deletedAt: Value<DateTime>(DateTime.now()),
            updatedAt: Value<DateTime>(DateTime.now()),
          ),
        );
      });

  /// Restores a soft-deleted row — the "Undo" path.
  Future<void> restoreTxn(String userId, Txn txn, Currency base) =>
      transaction(() async {
        await (update(transactions)..where((t) => t.id.equals(txn.id))).write(
          TransactionsCompanion(
            deletedAt: const Value<DateTime?>(null),
            updatedAt: Value<DateTime>(DateTime.now()),
          ),
        );
        await _applyDelta(userId, txn, base, 1);
      });

  /// Bulk insert used by recurring materialisation and the initial pull.
  Future<void> insertAllFromSync(
    String userId,
    List<Txn> items,
    Currency base,
  ) =>
      transaction(() async {
        await batch((Batch b) {
          b.insertAllOnConflictUpdate(
            transactions,
            items.map((t) => _toCompanion(userId, t)).toList(growable: false),
          );
        });
        // A pull can rewrite arbitrary history, so incremental deltas would need
        // every prior version to reverse against. A full rebuild is both simpler
        // and, at personal-ledger scale, faster than tracking that.
        await rebuildAggregates(userId, base);
      });

  // ----------------------------------------------------------------- reads --

  Future<Txn?> getById(String id) async {
    final row =
        await (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.toEntity();
  }

  /// One page of history, fully joined.
  ///
  /// Categories and both account sides are resolved in the same statement so a
  /// scrolling list never issues a lookup per row. Paging is offset-based: with
  /// the `(userId, dateYmd)` index the skip is an index walk, and at the scale a
  /// personal ledger reaches the difference against keyset paging is unmeasurable
  /// while the code stays filterable.
  Future<List<TxnView>> history(
    String userId,
    HistoryFilter filter,
    Currency base, {
    int limit = AppConfig.historyPageSize,
    int offset = 0,
  }) async {
    final targetAccounts = alias(accounts, 'target_account');

    final query = select(transactions).join(<Join<HasResultSet, dynamic>>[
      leftOuterJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      innerJoin(accounts, accounts.id.equalsExp(transactions.accountId)),
      leftOuterJoin(
        targetAccounts,
        targetAccounts.id.equalsExp(transactions.transferAccountId),
      ),
    ])
      ..where(_predicate(userId, filter))
      ..orderBy(<OrderingTerm>[
        OrderingTerm.desc(transactions.dateYmd),
        // Tiebreaker so two entries on the same day keep a stable order across
        // pages; without it the same row can appear twice or be skipped.
        OrderingTerm.desc(transactions.createdAt),
        OrderingTerm.desc(transactions.id),
      ])
      ..limit(limit, offset: offset);

    final rows = await query.get();
    return rows.map((row) {
      final txnRow = row.readTable(transactions);
      return TxnView(
        txn: txnRow.toEntity(),
        category: row.readTableOrNull(categories)?.toEntity(),
        account: row.readTable(accounts).toEntity(),
        transferAccount: row.readTableOrNull(targetAccounts)?.toEntity(),
        baseAmount: Money(txnRow.baseMilliIn(base), base),
      );
    }).toList(growable: false);
  }

  /// Live view of the most recent entries, for the dashboard's short list.
  Stream<List<TxnView>> watchRecent(
    String userId,
    Currency base, {
    int limit = 5,
  }) {
    final targetAccounts = alias(accounts, 'target_account');
    final query = select(transactions).join(<Join<HasResultSet, dynamic>>[
      leftOuterJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      innerJoin(accounts, accounts.id.equalsExp(transactions.accountId)),
      leftOuterJoin(
        targetAccounts,
        targetAccounts.id.equalsExp(transactions.transferAccountId),
      ),
    ])
      ..where(transactions.userId.equals(userId) & transactions.deletedAt.isNull())
      ..orderBy(<OrderingTerm>[
        OrderingTerm.desc(transactions.dateYmd),
        OrderingTerm.desc(transactions.createdAt),
      ])
      ..limit(limit);

    return query.watch().map(
          (rows) => rows.map((row) {
            final txnRow = row.readTable(transactions);
            return TxnView(
              txn: txnRow.toEntity(),
              category: row.readTableOrNull(categories)?.toEntity(),
              account: row.readTable(accounts).toEntity(),
              transferAccount: row.readTableOrNull(targetAccounts)?.toEntity(),
              baseAmount: Money(txnRow.baseMilliIn(base), base),
            );
          }).toList(growable: false),
        );
  }

  /// Emits whenever the ledger changes, without carrying any rows.
  ///
  /// Screens that only need to know "something changed" watch this instead of a
  /// full result set, so an insert does not deserialise a list nobody reads.
  Stream<void> watchChanges(String userId) {
    final count = transactions.id.count();
    final maxUpdated = transactions.updatedAt.max();
    return (selectOnly(transactions)
          ..addColumns(<Expression<Object>>[count, maxUpdated])
          ..where(transactions.userId.equals(userId)))
        .watchSingle();
  }

  /// Every tag currently in use, sorted.
  ///
  /// Derived from the rows rather than kept in its own table: a tag exists
  /// exactly as long as something carries it, so a separate table would only
  /// create a set that can disagree with the ledger.
  Stream<List<String>> watchAllTags(String userId) {
    final query = selectOnly(transactions, distinct: true)
      ..addColumns(<Expression<Object>>[transactions.tags])
      ..where(
        transactions.userId.equals(userId) & transactions.deletedAt.isNull(),
      );

    return query.watch().map((rows) {
      final tags = <String>{};
      for (final row in rows) {
        tags.addAll(
          row.readWithConverter(transactions.tags) ?? const <String>[],
        );
      }
      return tags.toList(growable: false)..sort();
    });
  }

  Future<List<Txn>> allForExport(String userId) async {
    final rows = await (select(transactions)
          ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
          ..orderBy(<OrderClauseGenerator<$TransactionsTable>>[
            (t) => OrderingTerm.desc(t.dateYmd),
          ]))
        .get();
    return rows.map((r) => r.toEntity()).toList(growable: false);
  }

  Future<bool> hasAnyForRule(String ruleId, int ymd) async {
    final row = await (select(transactions)
          ..where(
            (t) => t.recurringRuleId.equals(ruleId) & t.dateYmd.equals(ymd),
          )
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  // ------------------------------------------------------------ aggregates --

  /// Folds one transaction into (or, with [sign] `-1`, out of) the derived tables.
  ///
  /// Transfers deliberately touch balances only. Moving money between your own
  /// accounts is not income or spending, and letting it reach the category and
  /// daily totals would inflate both sides of every report.
  Future<void> _applyDelta(
    String userId,
    Txn txn,
    Currency base,
    int sign,
  ) async {
    final baseMilli = txn.amount.currency == base
        ? txn.amount.milli
        : (txn.amount.milli * txn.fxRateToBase).round();

    if (!txn.isTransfer) {
      await customInsert(
        'INSERT INTO monthly_category_totals '
        '(user_id, ym, type, category_id, total_milli, txn_count) '
        'VALUES (?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(user_id, ym, type, category_id) DO UPDATE SET '
        'total_milli = total_milli + excluded.total_milli, '
        'txn_count = txn_count + excluded.txn_count',
        variables: <Variable<Object>>[
          Variable<String>(userId),
          Variable<int>(txn.date.year * 100 + txn.date.month),
          Variable<String>(txn.type.wire),
          Variable<String>(txn.categoryId ?? ''),
          Variable<int>(sign * baseMilli),
          Variable<int>(sign),
        ],
        updates: {monthlyCategoryTotals},
      );

      await customInsert(
        'INSERT INTO daily_totals (user_id, ymd, type, total_milli) '
        'VALUES (?, ?, ?, ?) '
        'ON CONFLICT(user_id, ymd, type) DO UPDATE SET '
        'total_milli = total_milli + excluded.total_milli',
        variables: <Variable<Object>>[
          Variable<String>(userId),
          Variable<int>(txn.date.ymd),
          Variable<String>(txn.type.wire),
          Variable<int>(sign * baseMilli),
        ],
        updates: {dailyTotals},
      );
    }

    // Balances live in each account's own currency, so the untouched
    // `txn.amount.milli` is the right figure here, not the converted one.
    await _adjustBalance(
      userId,
      txn.accountId,
      sign * txn.type.balanceSign * txn.amount.milli,
    );

    final target = txn.transferAccountId;
    if (target != null) {
      await _adjustBalance(userId, target, sign * txn.amount.milli);
    }

    if (sign < 0 && !txn.isTransfer) {
      await _pruneEmptyAggregates(userId, txn);
    }
  }

  /// Drops aggregate rows a reversal emptied.
  ///
  /// Only reversals can empty a row, so this is skipped on the insert path. It
  /// matters for more than tidiness: a full rebuild produces no row for a month
  /// with no transactions, so leaving a zeroed one behind would make the
  /// incremental and rebuilt tables disagree — and a moved transaction would
  /// leave a permanent empty bucket in its old month.
  Future<void> _pruneEmptyAggregates(String userId, Txn txn) async {
    await (delete(monthlyCategoryTotals)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.ym.equals(txn.date.year * 100 + txn.date.month) &
                t.type.equals(txn.type.wire) &
                t.categoryId.equals(txn.categoryId ?? '') &
                t.txnCount.isSmallerOrEqualValue(0),
          ))
        .go();

    // Amounts are always strictly positive, so a zero daily total can only mean
    // the bucket is empty.
    await (delete(dailyTotals)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.ymd.equals(txn.date.ymd) &
                t.type.equals(txn.type.wire) &
                t.totalMilli.equals(0),
          ))
        .go();
  }

  /// Adds [deltaMilli] to an account's running balance, seeding the row from the
  /// account's opening balance the first time it is touched.
  Future<void> _adjustBalance(
    String userId,
    String accountId,
    int deltaMilli,
  ) async {
    await customInsert(
      'INSERT OR IGNORE INTO account_balances (user_id, account_id, balance_milli) '
      'SELECT user_id, id, opening_balance_milli FROM accounts WHERE id = ?',
      variables: <Variable<Object>>[Variable<String>(accountId)],
      updates: {accountBalances},
    );
    await customUpdate(
      'UPDATE account_balances SET balance_milli = balance_milli + ? '
      'WHERE user_id = ? AND account_id = ?',
      variables: <Variable<Object>>[
        Variable<int>(deltaMilli),
        Variable<String>(userId),
        Variable<String>(accountId),
      ],
      updates: {accountBalances},
      updateKind: UpdateKind.update,
    );
  }

  /// Recomputes every derived table from the ledger.
  ///
  /// The safety net behind the incremental path: called after a pull, after a
  /// base-currency change, and available from settings. Because the aggregates
  /// are pure functions of `transactions` + `accounts`, this can always restore
  /// consistency without touching user data.
  Future<void> rebuildAggregates(String userId, Currency base) =>
      transaction(() async {
        await (delete(monthlyCategoryTotals)
              ..where((t) => t.userId.equals(userId)))
            .go();
        await (delete(dailyTotals)..where((t) => t.userId.equals(userId))).go();
        await (delete(accountBalances)..where((t) => t.userId.equals(userId)))
            .go();

        // Start every account from its opening balance, including accounts that
        // have no transactions at all.
        await customInsert(
          'INSERT INTO account_balances (user_id, account_id, balance_milli) '
          'SELECT user_id, id, opening_balance_milli FROM accounts '
          'WHERE user_id = ? AND deleted_at IS NULL',
          variables: <Variable<Object>>[Variable<String>(userId)],
          updates: {accountBalances},
        );

        const baseMilliExpr =
            'CAST(ROUND(CASE WHEN currency = ? THEN amount_milli '
            'ELSE amount_milli * fx_rate_to_base END) AS INTEGER)';

        await customInsert(
          'INSERT INTO monthly_category_totals '
          '(user_id, ym, type, category_id, total_milli, txn_count) '
          'SELECT user_id, (date_ymd / 100), type, COALESCE(category_id, \'\'), '
          'SUM($baseMilliExpr), COUNT(*) '
          'FROM transactions '
          "WHERE user_id = ? AND deleted_at IS NULL AND type != 'transfer' "
          'GROUP BY user_id, (date_ymd / 100), type, COALESCE(category_id, \'\')',
          variables: <Variable<Object>>[
            Variable<String>(base.code),
            Variable<String>(userId),
          ],
          updates: {monthlyCategoryTotals},
        );

        await customInsert(
          'INSERT INTO daily_totals (user_id, ymd, type, total_milli) '
          'SELECT user_id, date_ymd, type, SUM($baseMilliExpr) '
          'FROM transactions '
          "WHERE user_id = ? AND deleted_at IS NULL AND type != 'transfer' "
          'GROUP BY user_id, date_ymd, type',
          variables: <Variable<Object>>[
            Variable<String>(base.code),
            Variable<String>(userId),
          ],
          updates: {dailyTotals},
        );

        // Outflows and inflows on the source side.
        await customUpdate(
          'UPDATE account_balances SET balance_milli = balance_milli + COALESCE(('
          '  SELECT SUM(CASE WHEN t.type = \'income\' THEN t.amount_milli '
          '              ELSE -t.amount_milli END) '
          '  FROM transactions t '
          '  WHERE t.account_id = account_balances.account_id '
          '    AND t.user_id = account_balances.user_id '
          '    AND t.deleted_at IS NULL'
          '), 0) WHERE user_id = ?',
          variables: <Variable<Object>>[Variable<String>(userId)],
          updates: {accountBalances},
          updateKind: UpdateKind.update,
        );

        // The credit side of transfers.
        await customUpdate(
          'UPDATE account_balances SET balance_milli = balance_milli + COALESCE(('
          '  SELECT SUM(t.amount_milli) FROM transactions t '
          '  WHERE t.transfer_account_id = account_balances.account_id '
          '    AND t.user_id = account_balances.user_id '
          '    AND t.deleted_at IS NULL'
          '), 0) WHERE user_id = ?',
          variables: <Variable<Object>>[Variable<String>(userId)],
          updates: {accountBalances},
          updateKind: UpdateKind.update,
        );
      });

  // ------------------------------------------------------------- internals --

  Expression<bool> _predicate(String userId, HistoryFilter filter) {
    var predicate =
        transactions.userId.equals(userId) & transactions.deletedAt.isNull();

    if (filter.types.isNotEmpty) {
      predicate = predicate &
          transactions.type
              .isIn(filter.types.map((t) => t.wire).toList(growable: false));
    }
    if (filter.categoryIds.isNotEmpty) {
      predicate =
          predicate & transactions.categoryId.isIn(filter.categoryIds.toList());
    }
    if (filter.accountIds.isNotEmpty) {
      final ids = filter.accountIds.toList();
      // A transfer belongs to both of its accounts, so filtering by account has
      // to match either side or transfers vanish from a filtered view.
      predicate = predicate &
          (transactions.accountId.isIn(ids) |
              transactions.transferAccountId.isIn(ids));
    }
    if (filter.from case final DateTime from) {
      predicate =
          predicate & transactions.dateYmd.isBiggerOrEqualValue(from.ymd);
    }
    if (filter.to case final DateTime to) {
      predicate = predicate & transactions.dateYmd.isSmallerOrEqualValue(to.ymd);
    }
    for (final tag in filter.tags) {
      // Tags are a JSON array in a TEXT column, so an exact element match is a
      // LIKE against the quoted form — '"gym"' cannot collide with '"gymnase"'.
      predicate = predicate &
          transactions.tags.like('%"${tag.toLowerCase()}"%');
    }
    if (filter.search.trim().isNotEmpty) {
      final term = '%${filter.search.trim().toLowerCase()}%';
      predicate = predicate &
          (transactions.note.lower().like(term) |
              transactions.tags.lower().like(term));
    }
    return predicate;
  }

  TransactionsCompanion _toCompanion(String userId, Txn txn) =>
      TransactionsCompanion.insert(
        id: txn.id,
        userId: userId,
        type: txn.type.wire,
        amountMilli: txn.amount.milli,
        currency: txn.amount.currency.code,
        fxRateToBase: Value<double>(txn.fxRateToBase),
        categoryId: Value<String?>(txn.categoryId),
        accountId: txn.accountId,
        transferAccountId: Value<String?>(txn.transferAccountId),
        dateYmd: txn.date.ymd,
        note: Value<String?>(txn.note),
        tags: txn.tags,
        recurringRuleId: Value<String?>(txn.recurringRuleId),
        createdAt: txn.createdAt,
        updatedAt: txn.updatedAt,
      );
}
