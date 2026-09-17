import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/money/money_formatter.dart';
import 'package:masrouf/core/theme/app_colors.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/analytics/analytics.dart';
import 'package:masrouf/l10n/app_localizations.dart';

/// Money in and money out over the month.
///
/// Two series, one axis: both are amounts in the same currency, so they share a
/// scale. A second y-axis would let the eye read a crossing that does not exist.
class CashflowChart extends StatelessWidget {
  const CashflowChart({
    required this.points,
    required this.granularity,
    required this.formatter,
    required this.locale,
    required this.l10n,
    super.key,
  });

  final List<CashflowPoint> points;
  final CashflowGranularity granularity;
  final MoneyFormatter formatter;
  final String locale;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = theme.money;

    final maxMilli = points.fold<int>(
      0,
      (max, p) => <int>[max, p.income.milli, p.expense.milli]
          .reduce((a, b) => a > b ? a : b),
    );

    if (points.isEmpty || maxMilli == 0) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            l10n.analyticsNoData,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Headroom so the tallest bar never touches the top gridline.
    final maxY = maxMilli * 1.15;
    final labelEvery = (points.length / 5).ceil().clamp(1, points.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // A legend is always present for two or more series.
        _Legend(
          entries: <(Color, String)>[
            (money.income, l10n.dashboardIn),
            (money.expense, l10n.dashboardOut),
          ],
        ),
        const SizedBox(height: Gap.md),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceBetween,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final point = points[group.x];
                    return BarTooltipItem(
                      '${_tooltipDate(point.start)}\n'
                      '${l10n.dashboardIn}: ${formatter.formatCompact(point.income)}\n'
                      '${l10n.dashboardOut}: ${formatter.formatCompact(point.expense)}',
                      TextStyle(
                        color: theme.colorScheme.onInverseSurface,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maxY / 3,
                // Recessive grid: present enough to read a value against,
                // never competing with the bars.
                getDrawingHorizontalLine: (_) => FlLine(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 46,
                    interval: maxY / 3,
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsetsDirectional.only(end: Gap.xs),
                      child: Text(
                        formatter.formatCompact(
                          Money(value.round(), points.first.income.currency),
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      // Selective labels: one every few buckets, never a label
                      // per bar.
                      if (index % labelEvery != 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        _axisDate(points[index].start),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: <BarChartGroupData>[
                for (var i = 0; i < points.length; i++)
                  BarChartGroupData(
                    x: i,
                    // 2px between the paired rods keeps them legible when both
                    // are tall.
                    barsSpace: 2,
                    barRods: <BarChartRodData>[
                      BarChartRodData(
                        toY: points[i].income.milli.toDouble(),
                        color: money.income,
                        width: _rodWidth,
                        // 4px rounded data-end, anchored square to the baseline.
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: points[i].expense.milli.toDouble(),
                        color: money.expense,
                        width: _rodWidth,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double get _rodWidth =>
      granularity == CashflowGranularity.weekly ? 14 : 4;

  String _axisDate(DateTime date) => granularity == CashflowGranularity.weekly
      ? '${date.day}/${date.month}'
      : '${date.day}';

  String _tooltipDate(DateTime date) => DateFormat.MMMd(locale).format(date);
}

/// Income by source across the last months.
class IncomeBreakdownChart extends StatelessWidget {
  const IncomeBreakdownChart({
    required this.breakdown,
    required this.formatter,
    required this.locale,
    required this.l10n,
    super.key,
  });

  final IncomeBreakdown breakdown;
  final MoneyFormatter formatter;
  final String locale;
  final L10n l10n;

  /// Same cap as the donut, same reason.
  static const int _maxSeries = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    if (breakdown.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            l10n.analyticsNoData,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final series = breakdown.series.take(_maxSeries).toList(growable: false);
    final colors = <Color>[
      for (final s in series)
        AppColors.resolveCategoryColor(
          s.category?.color ?? theme.colorScheme.outline.toARGB32(),
          brightness,
        ),
    ];

    final maxY = _maxStackHeight(series) * 1.15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Legend(
          entries: <(Color, String)>[
            for (var i = 0; i < series.length; i++)
              (colors[i], series[i].category?.name ?? l10n.txnIncome),
          ],
        ),
        const SizedBox(height: Gap.md),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: maxY <= 0 ? 1 : maxY,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                      BarTooltipItem(
                    formatter.formatCompact(
                      Money(rod.toY.round(), _currencyOf(series)),
                    ),
                    TextStyle(
                      color: theme.colorScheme.onInverseSurface,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: (maxY <= 0 ? 1 : maxY) / 3,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= breakdown.months.length) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        DateFormat.MMM(locale)
                            .format(breakdown.months[index].firstDay),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: <BarChartGroupData>[
                for (var month = 0; month < breakdown.months.length; month++)
                  BarChartGroupData(
                    x: month,
                    barRods: <BarChartRodData>[
                      BarChartRodData(
                        toY: _stackTotal(series, month),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        rodStackItems: _stackItems(series, colors, month),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Currency _currencyOf(List<IncomeSeries> series) =>
      series.first.totals.first.currency;

  static double _stackTotal(List<IncomeSeries> series, int month) =>
      series.fold<double>(
        0,
        (sum, s) => sum + (month < s.totals.length ? s.totals[month].milli : 0),
      );

  static double _maxStackHeight(List<IncomeSeries> series) {
    final months = series.isEmpty ? 0 : series.first.totals.length;
    var max = 0.0;
    for (var month = 0; month < months; month++) {
      final total = _stackTotal(series, month);
      if (total > max) max = total;
    }
    return max;
  }

  /// Stack segments separated by a 2px surface gap, so adjacent bands stay
  /// distinguishable even when two categories sit close in hue.
  static List<BarChartRodStackItem> _stackItems(
    List<IncomeSeries> series,
    List<Color> colors,
    int month,
  ) {
    final items = <BarChartRodStackItem>[];
    var cursor = 0.0;
    for (var i = 0; i < series.length; i++) {
      final value = month < series[i].totals.length
          ? series[i].totals[month].milli.toDouble()
          : 0.0;
      if (value <= 0) continue;
      items.add(BarChartRodStackItem(cursor, cursor + value, colors[i]));
      cursor += value + 2;
    }
    return items;
  }
}

/// Swatch-plus-name legend. Always shown for two or more series.
class _Legend extends StatelessWidget {
  const _Legend({required this.entries});

  final List<(Color, String)> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: Gap.lg,
      runSpacing: Gap.xs,
      children: <Widget>[
        for (final (color, label) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.all(Radius.circular(3)),
                ),
              ),
              const SizedBox(width: Gap.xs),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
