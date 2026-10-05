import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
// The generated part file references TagsConverter by name, so the converter has
// to be visible in this library rather than only inside the table definitions.
import 'package:masrouf/data/local/converters/tags_converter.dart';
import 'package:masrouf/data/local/daos/account_dao.dart';
import 'package:masrouf/data/local/daos/analytics_dao.dart';
import 'package:masrouf/data/local/daos/budget_dao.dart';
import 'package:masrouf/data/local/daos/goal_dao.dart';
import 'package:masrouf/data/local/daos/planned_dao.dart';
import 'package:masrouf/data/local/daos/category_dao.dart';
import 'package:masrouf/data/local/daos/kv_dao.dart';
import 'package:masrouf/data/local/daos/recurring_dao.dart';
import 'package:masrouf/data/local/daos/sync_queue_dao.dart';
import 'package:masrouf/data/local/daos/transaction_dao.dart';
import 'package:masrouf/data/local/tables/local_tables.dart';
import 'package:masrouf/data/local/tables/tables.dart';

part 'app_database.g.dart';

/// The local SQLite database — the app's source of truth for every read.
///
/// Nothing in the UI ever awaits the network: writes land here first and the sync
/// engine reconciles with Supabase afterwards. That is what makes the add flow
/// feel instant and the app fully usable offline.
@DriftDatabase(
  tables: <Type>[
    Accounts,
    Categories,
    Transactions,
    RecurringRules,
    Budgets,
    PlannedExpenses,
    SavingsGoals,
    ExchangeRates,
    UserSettingsRows,
    SyncQueueEntries,
    MonthlyCategoryTotals,
    DailyTotals,
    AccountBalances,
    KvEntries,
  ],
  daos: <Type>[
    AccountDao,
    CategoryDao,
    TransactionDao,
    RecurringDao,
    BudgetDao,
    PlannedDao,
    GoalDao,
    AnalyticsDao,
    SyncQueueDao,
    KvDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(
          executor ??
              driftDatabase(
                name: 'masrouf',
                native: const DriftNativeOptions(
                  // Opening on a background isolate keeps schema creation and
                  // every subsequent query off the UI thread, which is what holds
                  // the list at 60fps while a sync batch is writing.
                  shareAcrossIsolates: true,
                ),
              ),
        );

  /// In-memory instance for tests.
  AppDatabase.forTesting(super.executor);

  /// 1 -> 2: `budgets`. 2 -> 3: `planned_expenses`. 3 -> 4: `savings_goals`.
  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        // Every step is additive and re-runnable. Existing rows are the user's
        // only copy of anything written while offline, so a migration here may
        // create and backfill but must never drop or rewrite a column.
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(budgets);
          }
          if (from < 3) {
            await m.createTable(plannedExpenses);
          }
          if (from < 4) {
            await m.createTable(savingsGoals);
          }
        },
        beforeOpen: (OpeningDetails details) async {
          // WAL lets the sync engine write while the UI reads, instead of the two
          // blocking each other. NORMAL synchronous is the standard pairing: a
          // hard power loss can lose the last commit, which for a cache whose
          // authority is Supabase is an acceptable trade for the write latency.
          await customStatement('PRAGMA journal_mode = WAL');
          await customStatement('PRAGMA synchronous = NORMAL');
          await customStatement('PRAGMA foreign_keys = ON');
          // Keeps the temp b-trees used by GROUP BY off disk.
          await customStatement('PRAGMA temp_store = MEMORY');
        },
      );

  /// Wipes the synced tables and everything derived from them, leaving the KV
  /// store intact.
  ///
  /// Distinct from [clearUserData], which also drops KV. A restore replaces the
  /// ledger but must not take the notification switches and backup bookkeeping
  /// with it — those describe this phone, not the account being restored.
  Future<void> clearSyncedData() => transaction(() async {
        await batch((Batch b) {
          b.deleteWhere(transactions, (_) => const Constant<bool>(true));
          b.deleteWhere(budgets, (_) => const Constant<bool>(true));
          b.deleteWhere(plannedExpenses, (_) => const Constant<bool>(true));
          b.deleteWhere(savingsGoals, (_) => const Constant<bool>(true));
          b.deleteWhere(recurringRules, (_) => const Constant<bool>(true));
          // Accounts and categories last: transactions reference them, and
          // `PRAGMA foreign_keys = ON` rejects the delete while a child row is
          // still pointing at them.
          b.deleteWhere(accounts, (_) => const Constant<bool>(true));
          b.deleteWhere(categories, (_) => const Constant<bool>(true));
          b.deleteWhere(exchangeRates, (_) => const Constant<bool>(true));
          b.deleteWhere(userSettingsRows, (_) => const Constant<bool>(true));
          b.deleteWhere(syncQueueEntries, (_) => const Constant<bool>(true));
          b.deleteWhere(monthlyCategoryTotals, (_) => const Constant<bool>(true));
          b.deleteWhere(dailyTotals, (_) => const Constant<bool>(true));
          b.deleteWhere(accountBalances, (_) => const Constant<bool>(true));
        });
      });

  /// Wipes every user-scoped row. Called on sign-out so a second account on the
  /// same device never sees the first one's ledger.
  Future<void> clearUserData() => transaction(() async {
        await batch((Batch b) {
          b.deleteWhere(accounts, (_) => const Constant<bool>(true));
          b.deleteWhere(categories, (_) => const Constant<bool>(true));
          b.deleteWhere(transactions, (_) => const Constant<bool>(true));
          b.deleteWhere(recurringRules, (_) => const Constant<bool>(true));
          b.deleteWhere(budgets, (_) => const Constant<bool>(true));
          b.deleteWhere(plannedExpenses, (_) => const Constant<bool>(true));
          b.deleteWhere(savingsGoals, (_) => const Constant<bool>(true));
          b.deleteWhere(exchangeRates, (_) => const Constant<bool>(true));
          b.deleteWhere(userSettingsRows, (_) => const Constant<bool>(true));
          b.deleteWhere(syncQueueEntries, (_) => const Constant<bool>(true));
          b.deleteWhere(monthlyCategoryTotals, (_) => const Constant<bool>(true));
          b.deleteWhere(dailyTotals, (_) => const Constant<bool>(true));
          b.deleteWhere(accountBalances, (_) => const Constant<bool>(true));
          b.deleteWhere(kvEntries, (_) => const Constant<bool>(true));
        });
      });
}
