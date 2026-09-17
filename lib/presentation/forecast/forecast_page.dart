import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:masrouf/core/money/money_formatter.dart';
import 'package:masrouf/core/theme/app_colors.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/analytics/forecast.dart';
import 'package:masrouf/l10n/app_localizations.dart';
import 'package:masrouf/presentation/common/feedback.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/providers/analytics_providers.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

/// What the coming months are likely to cost, and what is likely to be left.
///
/// Every month is shown as its three parts rather than one number, because a
/// projection the user cannot take apart is a number they cannot argue with —
/// and the first time it looks wrong, they stop trusting the whole screen.
class ForecastPage extends ConsumerWidget {
  const ForecastPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final formatter = ref.watch(moneyFormatterProvider);
    final locale = ref.watch(localeCodeProvider);
    final async = ref.watch(forecastProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.forecastTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ValueUnavailable(
          onRetry: () => ref.invalidate(forecastProvider),
        ),
        data: (forecast) {
          final total = forecast.totalSavings;
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (total != null)
                      Text(
                        total.isNegative
                            ? l10n.forecastShortfall(
                                formatter.format(total.abs),
                              )
                            : l10n.forecastSavings(formatter.format(total)),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: total.isNegative
                              ? theme.money.expense
                              : theme.money.income,
                        ),
                      ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      l10n.forecastExplains,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (forecast.isProvisional) ...<Widget>[
                      const SizedBox(height: Gap.sm),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: theme.colorScheme.tertiary,
                          ),
                          const SizedBox(width: Gap.sm),
                          Expanded(
                            child: Text(
                              l10n.forecastProvisional,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.tertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(),
              for (final month in forecast.months)
                _MonthRow(
                  month: month,
                  formatter: formatter,
                  locale: locale,
                  l10n: l10n,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.month,
    required this.formatter,
    required this.locale,
    required this.l10n,
  });

  final MonthForecast month;
  final MoneyFormatter formatter;
  final String locale;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = month.projectedExpense.milli;
    final savings = month.projectedSavings;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: Gap.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  DateFormat.yMMMM(locale).format(month.ym.firstDay),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                formatter.formatSigned(savings),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: savings.isNegative
                      ? theme.money.expense
                      : theme.money.income,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          // One bar split three ways, so the parts are read as shares of the
          // same month rather than three unrelated figures.
          ClipRRect(
            borderRadius: BorderRadius.circular(Gap.radiusSm),
            child: SizedBox(
              height: 8,
              child: total == 0
                  ? ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const SizedBox.expand(),
                    )
                  : Row(
                      children: <Widget>[
                        _Segment(
                          flex: month.typical.milli,
                          color: theme.colorScheme.primary,
                        ),
                        _Segment(
                          flex: month.committed.milli,
                          color: theme.colorScheme.tertiary,
                        ),
                        _Segment(
                          flex: month.planned.milli,
                          color: theme.colorScheme.secondary,
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: Gap.xs),
          Wrap(
            spacing: Gap.md,
            children: <Widget>[
              _Legend(
                label: l10n.forecastTypical,
                value: formatter.format(month.typical),
                color: theme.colorScheme.primary,
              ),
              _Legend(
                label: l10n.forecastCommitted,
                value: formatter.format(month.committed),
                color: theme.colorScheme.tertiary,
              ),
              _Legend(
                label: l10n.forecastPlanned,
                value: formatter.format(month.planned),
                color: theme.colorScheme.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.flex, required this.color});

  final int flex;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Expanded rejects a zero flex, and a part that is genuinely zero should
    // take no width at all rather than a sliver.
    if (flex <= 0) return const SizedBox.shrink();
    return Expanded(flex: flex, child: ColoredBox(color: color));
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.all(Radius.circular(2)),
          ),
        ),
        const SizedBox(width: Gap.xs),
        Text(
          '$label $value',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
