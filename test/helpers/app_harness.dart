import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:masrouf/core/connectivity/connectivity_service.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/result/result.dart';
import 'package:masrouf/core/router/app_router.dart';
import 'package:masrouf/core/theme/app_theme.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/remote/api/sync_api.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/entities/user_settings.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/domain/repositories/auth_repository.dart';
import 'package:masrouf/l10n/app_localizations.dart';
import 'package:masrouf/presentation/providers/auth_providers.dart';
import 'package:masrouf/data/sync/sync_status.dart';
import 'package:masrouf/presentation/providers/core_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'test_database.dart';

/// Boots the real router, the real screens and a real (in-memory) database.
///
/// Everything below the UI is genuine — the only fakes are the two things a test
/// process cannot have: a Supabase session and a network. That is deliberate:
/// the gaps these tests exist to catch live in the wiring between a widget and a
/// repository, which a mocked repository would hide.
const testUser = AppUser(id: 'u1', email: 'a@b.com', emailConfirmed: true);

/// A repository that is simply already signed in, and counts sign-outs.
class TestAuthRepository implements AuthRepository {
  int signOutCalls = 0;

  @override
  Stream<AppUser?> get authStateChanges => const Stream<AppUser?>.empty();

  @override
  AppUser? get currentUser => testUser;

  @override
  Future<Result<AppUser>> signIn({
    required String email,
    required String password,
  }) async =>
      const Ok<AppUser>(testUser);

  @override
  Future<Result<SignUpOutcome>> signUp({
    required String email,
    required String password,
  }) async =>
      const Ok<SignUpOutcome>(SignUpOutcome.confirmationRequired);

  @override
  Future<Result<void>> signOut() async {
    signOutCalls++;
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> sendPasswordReset(String email) async =>
      const Ok<void>(null);

  @override
  Future<Result<void>> resendConfirmation(String email) async =>
      const Ok<void>(null);

  @override
  Future<Result<void>> refreshSession() async => const Ok<void>(null);
}

/// Never connected, so nothing in a test can reach for a network.
class OfflineConnectivity implements ConnectivityService {
  @override
  Stream<bool> get onStatusChange => const Stream<bool>.empty();

  @override
  Future<bool> isOnline() async => false;
}

/// A sync engine wired to an unreachable host. It is never started in tests, so
/// the client is only ever constructed, never called.
SyncEngine testSyncEngine(AppDatabase db) => SyncEngine(
      db: db,
      api: SyncApi(SupabaseClient('http://localhost:1', 'test-anon-key')),
      connectivity: OfflineConnectivity(),
    );

/// The minimum a user needs before the add flow will accept anything: one
/// account to spend from and one category to file it under.
Future<void> seedMinimalLedger(
  AppDatabase db, {
  Currency currency = Currency.tnd,
  int openingMilli = 100000,
}) async {
  await db.accountDao.upsert(
    testUser.id,
    Account(
      id: 'acc-cash',
      name: 'Cash',
      type: AccountType.cash,
      currency: currency,
      openingBalance: Money(openingMilli, currency),
      sortOrder: 0,
      archived: false,
      updatedAt: DateTime.now(),
    ),
  );
  await db.categoryDao.upsertAll(testUser.id, <Category>[
    Category(
      id: 'cat-groceries',
      name: 'Groceries',
      kind: CategoryKind.expense,
      icon: 'groceries',
      color: 0xFF2A78D6,
      sortOrder: 0,
      isDefault: true,
      updatedAt: DateTime.now(),
    ),
  ]);
}

/// Pumps the whole app, signed in, on the real router.
///
/// Returns the [GoRouter] so a test can assert on location as well as on what is
/// rendered. English and LTR unless [locale] says otherwise.
///
/// Overrides are named parameters rather than a caller-supplied list because
/// Riverpod 3 does not export the `Override` type, so a list of them cannot be
/// spelled in a helper's signature.
Future<GoRouter> pumpApp(
  WidgetTester tester, {
  required AppDatabase db,
  required SyncEngine sync,
  AuthRepository? auth,
  SyncStatus? syncStatus,
  Locale locale = const Locale('en'),
}) async {
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      syncEngineProvider.overrideWithValue(sync),
      authRepositoryProvider.overrideWithValue(auth ?? TestAuthRepository()),
      connectivityServiceProvider.overrideWithValue(OfflineConnectivity()),
      if (syncStatus != null)
        syncStatusProvider.overrideWith(
          (ref) => Stream<SyncStatus>.value(syncStatus),
        ),
    ],
  );
  addTearDown(container.dispose);

  final router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light,
        locale: locale,
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// Opens an in-memory database seeded for UI tests.
AppDatabase openSeededDatabase() => openTestDatabase();

/// Opens a row on the Settings tab by its label.
///
/// Drags the settings list rather than calling `ensureVisible`: that list is a
/// lazy `ListView`, so a row below the fold has no element to make visible yet —
/// which is how adding one entry to Settings broke every test that navigated
/// past it.
Future<void> openSettingsItem(WidgetTester tester, String label) async {
  await tester.tap(find.text('Settings'));
  await tester.pumpAndSettle();

  final target = find.text(label);
  if (target.evaluate().isEmpty) {
    await tester.dragUntilVisible(
      target,
      find.byType(Scrollable).last,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
  }
  // Built is not the same as hit-testable: the lazy list builds a little past
  // the fold, so a row can be findable and still be un-tappable.
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}
