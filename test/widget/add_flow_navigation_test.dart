import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/presentation/add/fast_add_page.dart';
import 'package:masrouf/presentation/settings/exchange_rates_page.dart';
import 'package:masrouf/presentation/settings/settings_page.dart';

import '../helpers/app_harness.dart';

void main() {
  late AppDatabase db;
  late SyncEngine sync;

  setUp(() async {
    db = openSeededDatabase();
    sync = testSyncEngine(db);
    await seedMinimalLedger(db);
  });

  tearDown(() => db.close());

  /// Opens the add screen from [tab] and saves a minimal expense.
  Future<void> addFromTab(WidgetTester tester, String tab) async {
    await tester.tap(find.text(tab));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(FastAddPage), findsOneWidget);

    await tester.tap(find.widgetWithText(InkWell, '2').first);
    await tester.pump();
    await tester.tap(find.widgetWithText(InkWell, '5').first);
    await tester.pump();
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.byType(FastAddPage), findsNothing, reason: 'save should close');
  }

  const tabs = <String, int>{
    'Home': 0,
    'History': 1,
    'Analytics': 2,
    'Settings': 3,
  };

  for (final entry in tabs.entries) {
    testWidgets('saving from ${entry.key} returns to ${entry.key}',
        (tester) async {
      await pumpApp(tester, db: db, sync: sync);
      await addFromTab(tester, entry.key);
      expect(_shellIndex(tester), entry.value);
    });
  }

  testWidgets('each add in a sequence returns to its own tab', (tester) async {
    await pumpApp(tester, db: db, sync: sync);
    for (final tab in const <String>['Home', 'Settings', 'Home', 'History']) {
      await addFromTab(tester, tab);
      expect(_shellIndex(tester), tabs[tab], reason: 'after adding from $tab');
    }
  });

  /// Exchange rates is the one screen that nests inside a tab rather than
  /// covering it, so the add button stays reachable from a location one level
  /// below a branch root. Saving has to come back to that location, not to the
  /// branch root.
  testWidgets('saving from a nested page returns to that page', (tester) async {
    await pumpApp(tester, db: db, sync: sync);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Exchange rates'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exchange rates'));
    await tester.pumpAndSettle();
    expect(find.byType(ExchangeRatesPage), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(InkWell, '2').first);
    await tester.pump();
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(ExchangeRatesPage), findsOneWidget);
    expect(find.byType(SettingsPage), findsNothing);
  });
}

int _shellIndex(WidgetTester tester) =>
    tester
        .widget<StatefulNavigationShell>(find.byType(StatefulNavigationShell))
        .currentIndex;
