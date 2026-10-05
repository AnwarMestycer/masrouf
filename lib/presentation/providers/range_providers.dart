import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/data/local/daos/kv_dao.dart';
import 'package:masrouf/domain/entities/analytics/date_range.dart';
import 'package:masrouf/domain/entities/analytics/range_report.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/providers/auth_providers.dart';
import 'package:masrouf/presentation/providers/core_providers.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';
import 'package:meta/meta.dart';

/// The chosen window, before it is resolved against a clock.
///
/// A preset plus the dates a custom span was last set to, so switching away
/// from custom and back does not lose what was picked.
@immutable
class AnalyticsRangeSelection {
  const AnalyticsRangeSelection({required this.preset, this.customFrom, this.customTo});

  final RangePreset preset;
  final DateTime? customFrom;
  final DateTime? customTo;

  AnalyticsRangeSelection copyWith({
    RangePreset? preset,
    DateTime? customFrom,
    DateTime? customTo,
  }) =>
      AnalyticsRangeSelection(
        preset: preset ?? this.preset,
        customFrom: customFrom ?? this.customFrom,
        customTo: customTo ?? this.customTo,
      );
}

/// Holds the selection and writes it back to the device.
///
/// Starts on the default and restores asynchronously rather than exposing an
/// `AsyncValue`: every analytics widget needs a window to read, and threading a
/// loading state through all of them to cover one KV read would put a spinner
/// on the whole tab for a value that is one local row deep.
class AnalyticsRange extends Notifier<AnalyticsRangeSelection> {
  @override
  AnalyticsRangeSelection build() {
    unawaited(_restore());
    return const AnalyticsRangeSelection(preset: RangePreset.thisMonth);
  }

  Future<void> _restore() async {
    final kv = ref.read(appDatabaseProvider).kvDao;
    final stored = await kv.get(KvDao.analyticsPreset);
    if (stored == null) return;

    final preset = RangePreset.values
        .where((p) => p.name == stored)
        .firstOrNull;
    if (preset == null) return;

    final from = await kv.getTimestamp(KvDao.analyticsCustomFrom);
    final to = await kv.getTimestamp(KvDao.analyticsCustomTo);
    // A custom selection with no stored dates would resolve to the default
    // window while claiming to be custom.
    if (preset == RangePreset.custom && (from == null || to == null)) return;

    state = AnalyticsRangeSelection(
      preset: preset,
      customFrom: from?.toLocal(),
      customTo: to?.toLocal(),
    );
  }

  Future<void> select(RangePreset preset) async {
    state = state.copyWith(preset: preset);
    await ref
        .read(appDatabaseProvider)
        .kvDao
        .put(KvDao.analyticsPreset, preset.name);
  }

  Future<void> selectCustom(DateTime from, DateTime to) async {
    state = AnalyticsRangeSelection(
      preset: RangePreset.custom,
      customFrom: from.dateOnly,
      customTo: to.dateOnly,
    );
    final kv = ref.read(appDatabaseProvider).kvDao;
    await kv.put(KvDao.analyticsPreset, RangePreset.custom.name);
    await kv.putTimestamp(KvDao.analyticsCustomFrom, from.dateOnly);
    await kv.putTimestamp(KvDao.analyticsCustomTo, to.dateOnly);
  }
}

final analyticsRangeSelectionProvider =
    NotifierProvider<AnalyticsRange, AnalyticsRangeSelection>(
  AnalyticsRange.new,
);

/// The selection resolved against the clock and the user's payday.
final analyticsRangeProvider = Provider<DateRange>((ref) {
  final selection = ref.watch(analyticsRangeSelectionProvider);
  final payday = ref.watch(settingsProvider.select((s) => s.paydayDayOfMonth));

  return Ranges.resolve(
    selection.preset,
    now: DateTime.now(),
    payday: payday,
    custom: selection.customFrom != null && selection.customTo != null
        ? DateRange(
            from: selection.customFrom!,
            to: selection.customTo!,
            preset: RangePreset.custom,
            payday: payday,
          )
        : null,
  );
});

/// The report for the current window, for one side of the ledger.
final rangeReportProvider =
    StreamProvider.family<RangeReport, TxnType>((ref, type) {
  final db = ref.watch(appDatabaseProvider);
  return db.analyticsDao.watchRangeReport(
    ref.watch(currentUserIdProvider),
    ref.watch(analyticsRangeProvider),
    ref.watch(baseCurrencyProvider),
    sliceType: type,
  );
});
