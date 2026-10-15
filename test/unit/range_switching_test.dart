import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/domain/entities/analytics/date_range.dart';
import 'package:masrouf/domain/entities/analytics/range_report.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/providers/auth_providers.dart';
import 'package:masrouf/presentation/providers/core_providers.dart';
import 'package:masrouf/presentation/providers/range_providers.dart';

import '../helpers/app_harness.dart';
import '../helpers/test_database.dart';

/// Picking a different window has to change what is shown. The figures are the
/// whole feature, so a selector that moves while the numbers stay put is worse
/// than no selector at all.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  const base = Currency.tnd;

  var seq = 0;
  Txn expense(DateTime date, int milli) => Txn(
        id: 't${seq++}',
        type: TxnType.expense,
        amount: Money(milli, base),
        fxRateToBase: 1,
        categoryId: 'cat-groceries',
        accountId: 'acc-cash',
        transferAccountId: null,
        date: date,
        note: null,
        tags: const <String>[],
        recurringRuleId: null,
        createdAt: date,
        updatedAt: date,
      );

  setUp(() async {
    seq = 0;
    db = openTestDatabase();
    await seedMinimalLedger(db);

    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    final lastMonth = DateTime(now.year, now.month - 1, 15);
    final threeMonthsAgo = DateTime(now.year, now.month - 3, 10);

    // Distinct amounts so a report can be attributed to its window on sight.
    await db.transactionDao.insertTxn(testUser.id, expense(thisMonth, 11000), base);
    await db.transactionDao.insertTxn(testUser.id, expense(lastMonth, 220000), base);
    await db.transactionDao
        .insertTxn(testUser.id, expense(threeMonthsAgo, 3300000), base);

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        syncEngineProvider.overrideWithValue(testSyncEngine(db)),
        authRepositoryProvider.overrideWithValue(TestAuthRepository()),
        connectivityServiceProvider.overrideWithValue(OfflineConnectivity()),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() => db.close());

  /// Keeps the stream provider alive for the length of a test. Without a
  /// listener Riverpod disposes it before the first value arrives, and the
  /// future completes with "disposed during loading state".
  void keepAlive() {
    container.listen(
      rangeReportProvider(TxnType.expense),
      (_, _) {},
      fireImmediately: true,
    );
  }

  Future<RangeReport> reportFor(RangePreset preset) async {
    await container
        .read(analyticsRangeSelectionProvider.notifier)
        .select(preset);
    keepAlive();
    return container.read(rangeReportProvider(TxnType.expense).future);
  }

  test('the resolved window changes when the preset does', () async {
    final seen = <RangePreset, DateRange>{};
    for (final preset in <RangePreset>[
      RangePreset.thisMonth,
      RangePreset.lastMonth,
      RangePreset.last30Days,
      RangePreset.last3Months,
      RangePreset.yearToDate,
      RangePreset.payPeriod,
    ]) {
      await container
          .read(analyticsRangeSelectionProvider.notifier)
          .select(preset);
      seen[preset] = container.read(analyticsRangeProvider);
    }

    expect(
      seen.values.map((r) => '${r.from}..${r.to}').toSet(),
      hasLength(greaterThan(4)),
      reason: 'distinct presets must resolve to distinct windows',
    );
  });

  test('the report changes when the preset does', () async {
    final thisMonth = await reportFor(RangePreset.thisMonth);
    final lastMonth = await reportFor(RangePreset.lastMonth);
    final threeMonths = await reportFor(RangePreset.last3Months);

    expect(thisMonth.expense, const Money(11000, base));
    expect(
      lastMonth.expense,
      const Money(220000, base),
      reason: 'switching to last month must re-read the window',
    );
    expect(
      threeMonths.expense.milli,
      greaterThan(220000),
      reason: 'a three month window contains all three months of spending',
    );
  });

  test('a custom window is honoured', () async {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 15);

    await container.read(analyticsRangeSelectionProvider.notifier).selectCustom(
          lastMonth.subtract(const Duration(days: 2)),
          lastMonth.add(const Duration(days: 2)),
        );

    final range = container.read(analyticsRangeProvider);
    expect(range.preset, RangePreset.custom);
    expect(range.dayCount, 5);

    keepAlive();
    final report =
        await container.read(rangeReportProvider(TxnType.expense).future);
    expect(
      report.expense,
      const Money(220000, base),
      reason: 'only the single transaction inside the custom window',
    );
  });

  /// Switching away from custom and back must not lose the picked dates, and
  /// must not leave a stale window behind either.
  test('custom survives a round trip through a preset', () async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month - 1, 13);
    final to = DateTime(now.year, now.month - 1, 17);

    await container
        .read(analyticsRangeSelectionProvider.notifier)
        .selectCustom(from, to);
    expect(container.read(analyticsRangeProvider).dayCount, 5);

    await container
        .read(analyticsRangeSelectionProvider.notifier)
        .select(RangePreset.thisMonth);
    expect(container.read(analyticsRangeProvider).preset, RangePreset.thisMonth);

    await container
        .read(analyticsRangeSelectionProvider.notifier)
        .select(RangePreset.custom);
    final back = container.read(analyticsRangeProvider);
    expect(back.preset, RangePreset.custom);
    expect(back.from, from);
    expect(back.to, to);
  });
}
