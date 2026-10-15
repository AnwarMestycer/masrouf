import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:masrouf/core/money/money_formatter.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/analytics/range_report.dart';
import 'package:masrouf/l10n/app_localizations.dart';

/// The window in numbers.
///
/// Each pair is here because one figure alone misleads. Per day against per
/// active day separates steady spending from bursty; average against typical
/// separates a ledger carried by a few large payments from an even one. Showing
/// either half on its own would invite exactly the wrong reading.
class RangeStats extends StatelessWidget {
  const RangeStats({
    required this.report,
    required this.formatter,
    required this.l10n,
    required this.locale,
    super.key,
  });

  final RangeReport report;
  final MoneyFormatter formatter;
  final L10n l10n;
  final String locale;

  @override
  Widget build(BuildContext context) {
    if (report.isEmpty) return const SizedBox.shrink();

    final busiest = report.busiestDay;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      child: Column(
        children: <Widget>[
          _Row(
            label: l10n.analyticsPerDayLabel,
            value: formatter.format(report.perDay),
          ),
          _Row(
            label: l10n.analyticsPerActiveDayLabel,
            value: formatter.format(report.perActiveDay),
            note: l10n.analyticsActiveDaysOf(
              report.activeDays,
              report.range.dayCount,
            ),
          ),
          _Row(
            label: l10n.analyticsAveragePurchaseLabel,
            value: formatter.format(report.meanTxn),
            note: l10n.analyticsTransactionsCount(report.txnCount),
          ),
          _Row(
            label: l10n.analyticsTypicalPurchaseLabel,
            value: formatter.format(report.medianTxn),
          ),
          if (busiest != null)
            _Row(
              label: l10n.analyticsBusiestDayLabel,
              value: formatter.format(report.busiestDayTotal),
              note: DateFormat.MMMEd(locale).format(busiest),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(value, style: theme.textTheme.titleSmall),
              if (note != null)
                Text(
                  note!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
