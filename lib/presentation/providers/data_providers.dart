import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/money/money_formatter.dart';
import 'package:masrouf/data/repositories/account_repository_impl.dart';
import 'package:masrouf/data/repositories/analytics_repository_impl.dart';
import 'package:masrouf/data/repositories/budget_repository_impl.dart';
import 'package:masrouf/data/repositories/category_repository_impl.dart';
import 'package:masrouf/data/repositories/goal_repository_impl.dart';
import 'package:masrouf/data/repositories/planned_repository_impl.dart';
import 'package:masrouf/data/repositories/recurring_repository_impl.dart';
import 'package:masrouf/data/repositories/settings_repository_impl.dart';
import 'package:masrouf/data/repositories/transaction_repository_impl.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/entities/user_settings.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/domain/repositories/repositories.dart';
import 'package:masrouf/presentation/providers/auth_providers.dart';
import 'package:masrouf/presentation/providers/core_providers.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(
    db: ref.watch(appDatabaseProvider),
    sync: ref.watch(syncEngineProvider),
    userId: ref.watch(currentUserIdProvider),
  ),
);

/// User settings, always resolved.
///
/// Falls back to defaults rather than exposing an `AsyncValue`: every screen
/// needs a currency to format with, and threading a loading state for a value
/// that is one local row deep would add a spinner to the entire app for nothing.
final userSettingsProvider = StreamProvider<UserSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);

final settingsProvider = Provider<UserSettings>(
  (ref) =>
      ref.watch(userSettingsProvider).value ?? UserSettings.fallback,
);

/// Narrow selectors, so a payday change does not rebuild every amount on screen.
final baseCurrencyProvider = Provider<Currency>(
  (ref) => ref.watch(settingsProvider.select((s) => s.baseCurrency)),
);

final localeCodeProvider = Provider<String>(
  (ref) => ref.watch(settingsProvider.select((s) => s.locale)),
);

/// One formatter per locale, cached for the lifetime of that locale.
///
/// [MoneyFormatter] holds `NumberFormat` instances whose construction parses
/// locale data — far too expensive to repeat inside a list item's build.
final moneyFormatterProvider = Provider<MoneyFormatter>((ref) {
  return MoneyFormatter(ref.watch(localeCodeProvider));
});

final exchangeRatesProvider = StreamProvider<List<ExchangeRate>>(
  (ref) => ref.watch(settingsRepositoryProvider).watchRates(),
);

/// Null until the rate table has been read at least once.
///
/// The distinction matters: an empty map means "this user has set no rates",
/// while null means "we do not know yet". Collapsing the two is how a foreign
/// amount ends up frozen at rate 1.0 — see [rateToBaseFor].
final ratesToBaseProvider = Provider<Map<String, double>?>((ref) {
  final rates = ref.watch(exchangeRatesProvider).value;
  if (rates == null) return null;
  return <String, double>{
    for (final rate in rates) rate.currency.code: rate.rateToBase,
  };
});

/// The rate to convert [currency] into the base currency, or null when there is
/// no answer yet.
///
/// Null is not a value to fall back from. Every caller that writes a rate onto a
/// transaction must refuse to write rather than substitute 1.0: the rate is
/// frozen at write time and editing it later never rewrites history, so a
/// wrong 1.0 is permanent and invisible.
double? rateToBaseFor(
  Currency currency,
  Currency base,
  Map<String, double>? ratesToBase,
) {
  if (currency == base) return 1;
  return ratesToBase?[currency.code];
}

// ------------------------------------------------------------ repositories --

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepositoryImpl(
    db: ref.watch(appDatabaseProvider),
    sync: ref.watch(syncEngineProvider),
    userId: ref.watch(currentUserIdProvider),
    base: ref.watch(baseCurrencyProvider),
  ),
);

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepositoryImpl(
    db: ref.watch(appDatabaseProvider),
    sync: ref.watch(syncEngineProvider),
    userId: ref.watch(currentUserIdProvider),
  ),
);

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepositoryImpl(
    db: ref.watch(appDatabaseProvider),
    sync: ref.watch(syncEngineProvider),
    userId: ref.watch(currentUserIdProvider),
    base: ref.watch(baseCurrencyProvider),
  ),
);

final recurringRepositoryProvider = Provider<RecurringRepository>(
  (ref) => RecurringRepositoryImpl(
    db: ref.watch(appDatabaseProvider),
    sync: ref.watch(syncEngineProvider),
    userId: ref.watch(currentUserIdProvider),
    base: ref.watch(baseCurrencyProvider),
  ),
);

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepositoryImpl(
    db: ref.watch(appDatabaseProvider),
    sync: ref.watch(syncEngineProvider),
    userId: ref.watch(currentUserIdProvider),
    base: ref.watch(baseCurrencyProvider),
  ),
);

final plannedRepositoryProvider = Provider<PlannedRepository>(
  (ref) => PlannedRepositoryImpl(
    db: ref.watch(appDatabaseProvider),
    sync: ref.watch(syncEngineProvider),
    transactions: ref.watch(transactionRepositoryProvider),
    userId: ref.watch(currentUserIdProvider),
    base: ref.watch(baseCurrencyProvider),
  ),
);

final goalRepositoryProvider = Provider<GoalRepository>(
  (ref) => GoalRepositoryImpl(
    db: ref.watch(appDatabaseProvider),
    sync: ref.watch(syncEngineProvider),
    userId: ref.watch(currentUserIdProvider),
    base: ref.watch(baseCurrencyProvider),
  ),
);

final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepositoryImpl(
    db: ref.watch(appDatabaseProvider),
    recurring: ref.watch(recurringRepositoryProvider),
    planned: ref.watch(plannedRepositoryProvider),
    userId: ref.watch(currentUserIdProvider),
    base: ref.watch(baseCurrencyProvider),
    paydayDayOfMonth: ref.watch(settingsProvider.select((s) => s.paydayDayOfMonth)),
    // Analytics is display-only and re-reads when the rates arrive, so an
    // unknown rate here is safe to treat as "no rate yet".
    ratesToBase: ref.watch(ratesToBaseProvider) ?? const <String, double>{},
  ),
);

// -------------------------------------------------------------- shared reads --

final accountsProvider = StreamProvider<List<AccountWithBalance>>(
  (ref) => ref.watch(accountRepositoryProvider).watchWithBalances(),
);

/// Includes archived accounts — used when editing an old transaction that still
/// points at one.
final allAccountsProvider = StreamProvider<List<Account>>(
  (ref) => ref.watch(accountRepositoryProvider).watchAll(includeArchived: true),
);

final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchAll(),
);

/// Indexed lookup for list items, so rendering a transaction row does not scan
/// the category list.
final categoriesByIdProvider = Provider<Map<String, Category>>((ref) {
  final categories = ref.watch(categoriesProvider).value;
  if (categories == null) return const <String, Category>{};
  return <String, Category>{for (final c in categories) c.id: c};
});

final categoriesOfKindProvider =
    StreamProvider.family<List<Category>, CategoryKind>(
  (ref, kind) => ref.watch(categoryRepositoryProvider).watchByKind(kind),
);

final quickPickCategoriesProvider =
    StreamProvider.family<List<Category>, CategoryKind>(
  (ref, kind) => ref.watch(categoryRepositoryProvider).watchQuickPicks(kind),
);

final totalBalanceProvider = StreamProvider<Money>(
  (ref) => ref.watch(settingsRepositoryProvider).watchTotalBalance(),
);
