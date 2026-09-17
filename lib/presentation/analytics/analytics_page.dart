import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/analytics/analytics.dart';
import 'package:masrouf/domain/entities/budget.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/analytics/widgets/cashflow_chart.dart';
import 'package:masrouf/presentation/analytics/widgets/category_donut.dart';
import 'package:masrouf/presentation/common/feedback.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/dashboard/widgets/dashboard_widgets.dart';
import 'package:masrouf/presentation/providers/analytics_providers.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  CashflowGranularity _granularity = CashflowGranularity.daily;

  /// Which side of the ledger the category donut is showing.
  ///
  /// The query has always taken a type; only the UI was fixed to expenses, so
  /// "where did the money come from" was unanswerable despite the data being
  /// one parameter away.
  TxnType _sliceType = TxnType.expense;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final formatter = ref.watch(moneyFormatterProvider);
    final base = ref.watch(baseCurrencyProvider);
    final locale = ref.watch(localeCodeProvider);
    final ym = ref.watch(selectedMonthProvider);

    final summaryAsync = ref.watch(monthSummaryProvider(ym));
    final slicesAsync = ref.watch(categorySlicesProvider((ym, _sliceType)));
    final cashflowAsync = ref.watch(cashflowProvider((ym, _granularity)));
    final summary = summaryAsync.value;
    final slices = slicesAsync.value;
    final cashflow = cashflowAsync.value;

    // An empty chart and a failed query look identical, so a failure here read
    // as "you spent nothing this month" — which for a spending tracker is a
    // wrong answer presented as a fact.
    final analyticsFailed = summaryAsync.hasError ||
        slicesAsync.hasError ||
        cashflowAsync.hasError;
    final income = ref.watch(incomeBreakdownProvider(ym)).value;
    final budgetsByCategory = <String, BudgetProgress>{
      for (final p in ref.watch(budgetProgressProvider(ym)).value ??
          const <BudgetProgress>[])
        p.budget.categoryId: p,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.analyticsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: <Widget>[
          MonthStepper(
            label: DateFormat.yMMMM(locale).format(ym.firstDay),
            onPrevious: ref.read(selectedMonthProvider.notifier).previous,
            onNext: ref.read(selectedMonthProvider.notifier).next,
            canGoNext: !ref.read(selectedMonthProvider.notifier).isCurrent,
          ),
          if (summary != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              child: MonthSummaryCard(
                summary: summary,
                formatter: formatter,
                l10n: l10n,
              ),
            ),
          const SizedBox(height: Gap.xl),

          if (analyticsFailed)
            ValueUnavailable(
              onRetry: () {
                ref.invalidate(monthSummaryProvider(ym));
                ref.invalidate(categorySlicesProvider((ym, _sliceType)));
                ref.invalidate(cashflowProvider((ym, _granularity)));
              },
            ),
          _SectionTitle(
            title: _sliceType == TxnType.income
                ? l10n.analyticsIncomeByCategory
                : l10n.analyticsByCategory,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
            child: SegmentedButton<TxnType>(
              segments: <ButtonSegment<TxnType>>[
                ButtonSegment<TxnType>(
                  value: TxnType.expense,
                  label: Text(l10n.txnExpense),
                ),
                ButtonSegment<TxnType>(
                  value: TxnType.income,
                  label: Text(l10n.txnIncome),
                ),
              ],
              selected: <TxnType>{_sliceType},
              onSelectionChanged: (selection) =>
                  setState(() => _sliceType = selection.first),
              showSelectedIcon: false,
            ),
          ),
          const SizedBox(height: Gap.md),
          CategoryDonut(
            slices: slices ?? const <CategorySlice>[],
            total: (_sliceType == TxnType.income
                    ? summary?.income
                    : summary?.expense) ??
                Money.zero(base),
            formatter: formatter,
            l10n: l10n,
            totalLabel: _sliceType == TxnType.income
                ? l10n.dashboardIn
                : l10n.dashboardOut,
            // Caps only apply to spending, so the income view carries none.
            budgets: _sliceType == TxnType.expense
                ? budgetsByCategory
                : const <String, BudgetProgress>{},
          ),

          const SizedBox(height: Gap.xl),
          _SectionTitle(
            title: l10n.analyticsCashflow,
            trailing: SegmentedButton<CashflowGranularity>(
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: <ButtonSegment<CashflowGranularity>>[
                ButtonSegment<CashflowGranularity>(
                  value: CashflowGranularity.daily,
                  label: Text(l10n.analyticsDaily),
                ),
                ButtonSegment<CashflowGranularity>(
                  value: CashflowGranularity.weekly,
                  label: Text(l10n.analyticsWeekly),
                ),
              ],
              selected: <CashflowGranularity>{_granularity},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => _granularity = selection.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
            child: CashflowChart(
              points: cashflow ?? const <CashflowPoint>[],
              granularity: _granularity,
              formatter: formatter,
              locale: locale,
              l10n: l10n,
            ),
          ),

          const SizedBox(height: Gap.xl),
          _SectionTitle(title: l10n.analyticsIncomeBreakdown),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
            child: income == null
                ? const SizedBox(height: 180)
                : IncomeBreakdownChart(
                    breakdown: income,
                    formatter: formatter,
                    locale: locale,
                    l10n: l10n,
                  ),
          ),

          const SizedBox(height: Gap.xl),
          if (summary != null) _MonthComparison(current: summary, theme: theme),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ?trailing,
          ],
        ),
      );
}

/// Current versus previous month, as a plain readout.
///
/// A two-row comparison rather than a chart: with exactly two values there is
/// nothing for a chart to reveal that the numbers do not already say.
class _MonthComparison extends ConsumerWidget {
  const _MonthComparison({required this.current, required this.theme});

  final MonthSummary current;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final formatter = ref.watch(moneyFormatterProvider);
    final previous = ref.watch(monthSummaryProvider(current.ym.previous)).value;
    if (previous == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.analyticsPreviousMonth,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Gap.sm),
              _ComparisonRow(
                label: l10n.dashboardOut,
                now: formatter.format(current.expense),
                then: formatter.format(previous.expense),
                theme: theme,
              ),
              const SizedBox(height: Gap.xs),
              _ComparisonRow(
                label: l10n.dashboardIn,
                now: formatter.format(current.income),
                then: formatter.format(previous.income),
                theme: theme,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.now,
    required this.then,
    required this.theme,
  });

  final String label;
  final String now;
  final String then;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(now, style: theme.textTheme.bodyMedium),
          const SizedBox(width: Gap.md),
          Text(
            then,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
}
