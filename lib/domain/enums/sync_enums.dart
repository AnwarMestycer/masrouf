/// Tables that participate in sync.
///
/// The sync engine is table-agnostic and drives everything off this enum, so
/// adding a synced table is one entry here plus a handler registration — there is
/// no per-table branch scattered through the push/pull workers.
enum SyncEntity {
  accounts('accounts'),
  categories('categories'),
  transactions('transactions'),
  recurringRules('recurring_rules'),
  budgets('budgets'),
  plannedExpenses('planned_expenses'),
  savingsGoals('savings_goals'),
  exchangeRates('exchange_rates'),
  userSettings('user_settings');

  const SyncEntity(this.table);

  final String table;

  static SyncEntity fromTable(String value) =>
      SyncEntity.values.firstWhere((e) => e.table == value);

  /// Whether the table carries a `deleted_at` tombstone.
  ///
  /// `user_settings` and `exchange_rates` have no such column: settings are
  /// overwritten rather than removed, and a rate is edited rather than deleted.
  /// A delete pushed against either would be a 400 from PostgREST.
  bool get hasTombstones => switch (this) {
        SyncEntity.userSettings || SyncEntity.exchangeRates => false,
        SyncEntity.accounts ||
        SyncEntity.categories ||
        SyncEntity.transactions ||
        SyncEntity.recurringRules ||
        SyncEntity.budgets ||
        SyncEntity.plannedExpenses ||
        SyncEntity.savingsGoals =>
          true,
      };
}

/// What the local change did. Only `delete` needs distinguishing at push time:
/// insert and update both resolve to the same server-side upsert, and collapsing
/// them means a row created then edited offline pushes exactly once.
enum SyncOp {
  upsert('upsert'),
  delete('delete');

  const SyncOp(this.wire);

  final String wire;

  static SyncOp fromWire(String value) =>
      value == 'delete' ? SyncOp.delete : SyncOp.upsert;
}

enum SyncState { idle, syncing, offline, failed }
