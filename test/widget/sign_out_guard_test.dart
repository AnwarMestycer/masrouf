import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/data/sync/sync_status.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';

import '../helpers/app_harness.dart';

/// Signing out runs `clearUserData()`, which deletes the outbox along with every
/// other local row. A user who has been offline therefore loses those writes for
/// good — and the tile sits directly under the account row, one mis-tap away.
/// These tests pin the guard that stands between the two.
void main() {
  late AppDatabase db;
  late SyncEngine sync;
  late TestAuthRepository auth;

  setUp(() async {
    db = openSeededDatabase();
    sync = testSyncEngine(db);
    auth = TestAuthRepository();
    await seedMinimalLedger(db);
  });

  tearDown(() => db.close());

  Future<void> openSettingsAndTapSignOut(WidgetTester tester) async {
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
  }

  testWidgets('signing out asks first', (tester) async {
    await pumpApp(tester, db: db, sync: sync, auth: auth);
    await openSettingsAndTapSignOut(tester);

    expect(find.text('Sign out?'), findsOneWidget);
    expect(auth.signOutCalls, 0, reason: 'must not sign out on the tap alone');
  });

  testWidgets('cancelling leaves the session alone', (tester) async {
    await pumpApp(tester, db: db, sync: sync, auth: auth);
    await openSettingsAndTapSignOut(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsNothing);
    expect(auth.signOutCalls, 0);
  });

  testWidgets('confirming signs out', (tester) async {
    await pumpApp(tester, db: db, sync: sync, auth: auth);
    await openSettingsAndTapSignOut(tester);

    // The dialog's own destructive action, not the list tile behind it.
    await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
  });

  testWidgets('unsynced changes are counted in the warning', (tester) async {
    await pumpApp(
      tester,
      db: db,
      sync: sync,
      auth: auth,
      syncStatus: const SyncStatus(state: SyncState.offline, pending: 3),
    );
    await openSettingsAndTapSignOut(tester);

    expect(
      find.textContaining('3 changes have not reached the server'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Sync first'), findsOneWidget);
    expect(auth.signOutCalls, 0);
  });

  testWidgets('a clean outbox is not warned about', (tester) async {
    await pumpApp(
      tester,
      db: db,
      sync: sync,
      auth: auth,
      syncStatus: const SyncStatus(state: SyncState.idle),
    );
    await openSettingsAndTapSignOut(tester);

    expect(find.textContaining('have not reached the server'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Sync first'), findsNothing);
  });

  testWidgets('choosing to sync first does not sign out', (tester) async {
    await pumpApp(
      tester,
      db: db,
      sync: sync,
      auth: auth,
      syncStatus: const SyncStatus(state: SyncState.offline, pending: 2),
    );
    await openSettingsAndTapSignOut(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Sync first'));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 0);
  });
}
