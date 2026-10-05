import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/analytics/date_range.dart';
import 'package:masrouf/l10n/app_localizations.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';
import 'package:masrouf/presentation/providers/range_providers.dart';

/// The window every figure on the tab is read over.
///
/// A horizontal strip rather than a dropdown: the presets are the feature, and
/// a menu would hide the one that makes this worth having — the pay period,
/// which is what most people mean by "this month" when payday is not the 1st.
class RangeSelector extends ConsumerWidget {
  const RangeSelector({super.key});

  static String labelFor(RangePreset preset, L10n l10n) => switch (preset) {
        RangePreset.thisMonth => l10n.rangeThisMonth,
        RangePreset.lastMonth => l10n.rangeLastMonth,
        RangePreset.last30Days => l10n.rangeLast30Days,
        RangePreset.last3Months => l10n.rangeLast3Months,
        RangePreset.last6Months => l10n.rangeLast6Months,
        RangePreset.yearToDate => l10n.rangeYearToDate,
        RangePreset.payPeriod => l10n.rangePayPeriod,
        RangePreset.custom => l10n.rangeCustom,
      };

  Future<void> _pickCustom(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final current = ref.read(analyticsRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      // The ledger cannot start before the app did, and a window ending in the
      // future would dilute every per-day figure read from it.
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: DateTimeRange(start: current.from, end: current.to),
    );
    if (picked == null) return;
    await ref
        .read(analyticsRangeSelectionProvider.notifier)
        .selectCustom(picked.start, picked.end);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selection = ref.watch(analyticsRangeSelectionProvider);
    final range = ref.watch(analyticsRangeProvider);
    final locale = ref.watch(localeCodeProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
          child: Row(
            children: <Widget>[
              for (final preset in RangePreset.values)
                Padding(
                  padding: const EdgeInsets.only(right: Gap.sm),
                  child: ChoiceChip(
                    label: Text(labelFor(preset, l10n)),
                    selected: selection.preset == preset,
                    onSelected: (_) {
                      if (preset == RangePreset.custom) {
                        _pickCustom(context, ref);
                        return;
                      }
                      ref
                          .read(analyticsRangeSelectionProvider.notifier)
                          .select(preset);
                    },
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
          // The dates spelled out, because "pay period" and "last 3 months"
          // name a rule rather than a window, and the rule depends on a payday
          // set on another screen.
          child: Text(
            '${_format(range, locale)}  ·  '
            '${l10n.analyticsRangeDays(range.dayCount)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  static String _format(DateRange range, String locale) {
    final sameYear = range.from.year == range.to.year;
    final from = DateFormat(sameYear ? 'd MMM' : 'd MMM y', locale);
    final to = DateFormat('d MMM y', locale);
    return '${from.format(range.from)} – ${to.format(range.to)}';
  }
}
