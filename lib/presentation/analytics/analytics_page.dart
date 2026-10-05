import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/analytics/analytics.dart';
import 'package:masrouf/core/time/ym.dart';
import 'package:masrouf/domain/entities/budget.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/analytics/widgets/cashflow_chart.dart';
import 'package:masrouf/presentation/analytics/widgets/category_donut.dart';
import 'package:masrouf/presentation/analytics/widgets/range_headline.dart';
import 'package:masrouf/presentation/analytics/widgets/range_selector.dart';
import 'package:masrouf/presentation/common/feedback.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/providers/analytics_providers.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';
import 'package:masrouf/presentation/providers/range_providers.dart';

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
    final formatter = ref.watch(moneyFormatterProvider);
    final base = ref.watch(baseCurrencyProvider);
    final locale = ref.watch(localeCodeProvider);
    final range = ref.watch(analyticsRangeProvider);

    final reportAsync = ref.watch(rangeReportProvider(_sliceType));
    final cashflowAsync = ref.watch(cashflowProvider(_granularity));
    final report = reportAsync.value;
    final cashflow = cashflowAsync.value;
    final slices = report?.slices;

    // An empty chart and a failed query look identical, so a failure here read
    // as "you spent nothing this month" — which for a spending tracker is a
    // wrong answer presented as a fact.
    final analyticsFailed = reportAsync.hasError || cashflowAsync.hasError;

    // Budgets and the income trend stay monthly on purpose: a cap is a monthly
    // commitment and the trend is a month-by-month series, so neither means
    // anything read over an arbitrary window. The month they use is the one the
    // range ends in.
    final ym = Ym.fromDate(range.to);
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
          const SizedBox(height: Gap.sm),
          const RangeSelector(),
          if (report != null)
            RangeHeadline(
              report: report,
              formatter: formatter,
              l10n: l10n,
              label: _sliceType == TxnType.income
                  ? l10n.dashboardIn
                  : l10n.dashboardOut,
            ),
          const SizedBox(height: Gap.xl),

          if (analyticsFailed)
            ValueUnavailable(
              onRetry: () {
                ref.invalidate(rangeReportProvider(_sliceType));
                ref.invalidate(cashflowProvider(_granularity));
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
                    ? report?.income
                    : report?.expense) ??
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
