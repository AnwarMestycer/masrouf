import 'package:flutter/material.dart';
import 'package:masrouf/core/money/money_formatter.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/analytics/range_report.dart';
import 'package:masrouf/l10n/app_localizations.dart';
import 'package:masrouf/presentation/common/widgets/change_chip.dart';

/// What the window cost, and what it cost on an ordinary day.
///
/// The two are not the same number and conflating them is the main way a
/// spending figure misleads: one tuition bill in a window of coffees sets a
/// total that describes no week, and a per-day rate that no day resembles. The
/// large payments are named rather than merely subtracted, so the headline can
/// be reconciled against them instead of taken on trust.
class RangeHeadline extends StatelessWidget {
  const RangeHeadline({
    required this.report,
    required this.formatter,
    required this.l10n,
    required this.label,
    super.key,
  });

  final RangeReport report;
  final MoneyFormatter formatter;
  final L10n l10n;

  /// "Out" or "In" — the headline serves both sides of the ledger.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpense = report.expense.milli != 0 || report.income.isZero;
    final total = isExpense ? report.expense : report.income;
    final change =
        isExpense ? report.expenseChangeRatio : report.incomeChangeRatio;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Gap.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: Text(
                  formatter.format(total),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineMedium,
                ),
              ),
              if (change != null) ...<Widget>[
                const SizedBox(width: Gap.sm),
                ChangeChip(ratio: change),
              ],
            ],
          ),
          if (change != null)
            Padding(
              padding: const EdgeInsets.only(top: Gap.xs),
              child: Text(
                l10n.analyticsComparedTo(
                  l10n.analyticsRangeDays(report.range.previous.dayCount),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          // What the spending cost as a share of what came in. Stated outright
          // when there was no income, rather than as a 0% that is not true.
          Padding(
            padding: const EdgeInsets.only(top: Gap.xs),
            child: Text(
              report.burnRate == null
                  ? l10n.analyticsBurnRateNoIncomeRange
                  : l10n.analyticsBurnRate(
                      '${(report.burnRate! * 100).round()}%',
                    ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: report.burnRate != null && report.burnRate! > 1
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (report.large.isNotEmpty) ...<Widget>[
            const SizedBox(height: Gap.md),
            _Everyday(report: report, formatter: formatter, l10n: l10n),
          ] else if (!report.isEmpty) ...<Widget>[
            const SizedBox(height: Gap.sm),
            Text(
              '${l10n.analyticsPerDay(formatter.format(report.everydayPerDay))}'
              '  ·  '
              '${l10n.analyticsTypicalPurchase(formatter.format(report.medianTxn))}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Everyday extends StatelessWidget {
  const _Everyday({
    required this.report,
    required this.formatter,
    required this.l10n,
  });

  final RangeReport report;
  final MoneyFormatter formatter;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(l10n.analyticsEveryday, style: theme.textTheme.labelMedium),
              const Spacer(),
              Text(
                formatter.format(report.everyday),
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(
            '${l10n.analyticsPerDay(formatter.format(report.everydayPerDay))}'
            '  ·  '
            '${l10n.analyticsTypicalPurchase(formatter.format(report.medianTxn))}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Divider(height: Gap.lg),
          Text(
            l10n.analyticsSetAside(report.large.length),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Gap.xs),
          for (final payment in report.large)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      payment.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    formatter.format(payment.amount),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
