import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/analytics/analytics.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/domain/entities/budget.dart';
import 'package:masrouf/core/router/routes.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/presentation/add/widgets/add_widgets.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/common/widgets/txn_tile.dart';
import 'package:masrouf/presentation/dashboard/widgets/dashboard_widgets.dart';
import 'package:masrouf/presentation/planned/planned_page.dart';
import 'package:masrouf/presentation/providers/analytics_providers.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

/// Home. Answers "how am I doing this month" without any interaction.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final formatter = ref.watch(moneyFormatterProvider);
    final base = ref.watch(baseCurrencyProvider);
    final ym = ref.watch(selectedMonthProvider);
    final locale = ref.watch(localeCodeProvider);

    // Deliberately kept as an AsyncValue: a failed balance must render as an
    // error, not as a confident 0.000 DT.
    final totalAsync = ref.watch(totalBalanceProvider);
    final accounts = ref.watch(accountsProvider).value ??
        const <AccountWithBalance>[];
    final summary = ref.watch(monthSummaryProvider(ym)).value;
    final safe = ref.watch(safeToSpendProvider).value;
    final recent = ref.watch(recentTransactionsProvider).value;
    final duePlans = ref.watch(duePlansProvider);
    final slices =
        ref.watch(categorySlicesProvider((ym, TxnType.expense))).value ??
            const <CategorySlice>[];
    final budgetsByCategory = <String, BudgetProgress>{
      for (final p in ref.watch(budgetProgressProvider(ym)).value ??
          const <BudgetProgress>[])
        p.budget.categoryId: p,
    };

    final monthLabel = DateFormat.yMMMM(locale).format(ym.firstDay);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: RefreshIndicator(
        // Pull-to-refresh forces a sync rather than a reload: the local data is
        // already current, so the only thing worth refreshing is the server.
        onRefresh: () async {
          ref.invalidate(safeToSpendProvider);
          await ref.read(analyticsRepositoryProvider).rebuild();
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: <Widget>[
            BalanceHeader(
              total: totalAsync.value ?? Money.zero(base),
              unavailable: totalAsync.hasError,
              formatter: formatter,
              l10n: l10n,
              onTap: () => context.push(Routes.accounts),
            ),
            AccountBalanceStrip(
              accounts: accounts,
              formatter: formatter,
              onTap: () => context.push(Routes.accounts),
            ),
            const SizedBox(height: Gap.md),
            // Asked before anything else: an unanswered plan is still reserving
            // money, so the numbers below it are not yet settled.
            for (final view in duePlans)
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
                child: DuePlanCard(view: view),
              ),
            MonthStepper(
              label: monthLabel,
              onPrevious: ref.read(selectedMonthProvider.notifier).previous,
              onNext: ref.read(selectedMonthProvider.notifier).next,
              canGoNext: !ref.read(selectedMonthProvider.notifier).isCurrent,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              child: Column(
                children: <Widget>[
                  if (summary != null)
                    MonthSummaryCard(
                      summary: summary,
                      formatter: formatter,
                      l10n: l10n,
                    ),
                  const SizedBox(height: Gap.md),
                  if (safe != null)
                    SafeToSpendCard(
                      safe: safe,
                      formatter: formatter,
                      l10n: l10n,
                      forecast: ref.watch(forecastProvider).value,
                      onForecastTap: () => context.push(Routes.forecast),
                    ),
                  if (slices.isNotEmpty) const SizedBox(height: Gap.md),
                  CategoryBreakdownCard(
                    slices: slices,
                    budgets: budgetsByCategory,
                    formatter: formatter,
                    l10n: l10n,
                    // Analytics, not Budgets: the card is about where money went,
                    // and the caps on it are context rather than the subject.
                    onTap: () =>
                        StatefulNavigationShell.of(context).goBranch(2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.txnRecent,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    // goBranch, not go: `go` rebuilds the History branch from
                    // its root and throws away its stack and scroll position.
                    onPressed: () =>
                        StatefulNavigationShell.of(context).goBranch(1),
                    child: Text(l10n.txnAll),
                  ),
                ],
              ),
            ),
            if (recent == null)
              const SizedBox(height: 120)
            else if (recent.isEmpty)
              EmptyHint(
                icon: Icons.receipt_long_outlined,
                title: l10n.txnEmpty,
                subtitle: l10n.txnEmptyHint,
              )
            else
              for (final view in recent)
                TxnTile(
                  key: ValueKey<String>(view.id),
                  view: view,
                  formatter: formatter,
                  onTap: () =>
                      context.push('${Routes.editTransaction}/${view.id}'),
                ),
          ],
        ),
      ),
    );
  }
}
