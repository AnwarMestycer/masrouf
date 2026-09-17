import 'package:flutter/material.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/money/money_formatter.dart';
import 'package:masrouf/core/theme/app_colors.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/budget.dart';
import 'package:masrouf/domain/entities/analytics/analytics.dart';
import 'package:masrouf/domain/entities/analytics/forecast.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/l10n/app_localizations.dart';
import 'package:masrouf/presentation/budgets/widgets/budget_bar.dart';
import 'package:masrouf/presentation/common/category_icons.dart';
import 'package:masrouf/presentation/common/widgets/change_chip.dart';
import 'package:masrouf/presentation/common/feedback.dart';

/// Total balance across accounts.
class BalanceHeader extends StatelessWidget {
  const BalanceHeader({
    required this.total,
    required this.formatter,
    required this.l10n,
    required this.onTap,
    this.unavailable = false,
    super.key,
  });

  final Money total;
  final MoneyFormatter formatter;
  final L10n l10n;
  final VoidCallback onTap;

  /// True when the balance could not be read. The number is then not shown at
  /// all rather than shown as zero.
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(Gap.radiusMd)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.accountsTotalBalance,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.xs),
            Row(
              children: <Widget>[
                Expanded(
                  child: unavailable
                      ? Row(
                          children: <Widget>[
                            Text(
                              '—',
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: Gap.sm),
                            const ValueUnavailable(compact: true),
                          ],
                        )
                      : Text(
                          formatter.format(total),
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: total.isNegative ? theme.money.expense : null,
                          ),
                        ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// In / out / net for the selected month.
class MonthSummaryCard extends StatelessWidget {
  const MonthSummaryCard({
    required this.summary,
    required this.formatter,
    required this.l10n,
    super.key,
  });

  final MonthSummary summary;
  final MoneyFormatter formatter;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = theme.money;

    final burnRate = summary.burnRate;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _Stat(
                    label: l10n.dashboardIn,
                    value: formatter.format(summary.income),
                    color: money.income,
                    icon: Icons.south_west,
                  ),
                ),
                _Divider(),
                Expanded(
                  child: _Stat(
                    label: l10n.dashboardOut,
                    value: formatter.format(summary.expense),
                    color: money.expense,
                    icon: Icons.north_east,
                  ),
                ),
                _Divider(),
                Expanded(
                  child: _Stat(
                    label: l10n.dashboardNet,
                    value: formatter.formatSigned(summary.net),
                    color: summary.net.isNegative ? money.expense : money.income,
                    icon: Icons.trending_up,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            // The one number that says whether the month is going well. Read as
            // a footer rather than a fourth column so the three amounts keep
            // their width on a narrow phone.
            Text(
              burnRate == null
                  ? l10n.analyticsBurnRateNoIncome
                  : l10n.analyticsBurnRate('${(burnRate * 100).round()}%'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: burnRate != null && burnRate > 1
                    ? money.expense
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 36,
        color: Theme.of(context).colorScheme.outlineVariant,
      );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: Gap.xs),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: theme.textTheme.titleMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// The headline number: what is left after the bills that are already known.
class SafeToSpendCard extends StatelessWidget {
  const SafeToSpendCard({
    required this.safe,
    required this.formatter,
    required this.l10n,
    this.forecast,
    this.onForecastTap,
    super.key,
  });

  final SafeToSpend safe;
  final MoneyFormatter formatter;
  final L10n l10n;

  /// The projection, when it has been computed. Shown as one line here: this
  /// card already answers "until payday", and the months beyond it are the
  /// natural next question rather than a separate destination to discover.
  final Forecast? forecast;
  final VoidCallback? onForecastTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = theme.money;
    final negative = safe.amount.isNegative;
    final perDay = safe.perDay;

    return Card(
      color: negative ? money.negativeSurface : money.positiveSurface,
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  negative ? Icons.warning_amber_rounded : Icons.savings_outlined,
                  size: 18,
                  color: negative ? money.expense : money.income,
                ),
                const SizedBox(width: Gap.sm),
                Text(
                  l10n.dashboardSafeToSpend,
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(
              formatter.format(safe.amount),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: negative ? money.expense : money.income,
              ),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              l10n.dashboardSafeToSpendHint(
                '${safe.horizon.day}/${safe.horizon.month}',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (perDay != null && !negative) ...<Widget>[
              const SizedBox(height: Gap.sm),
              Text(
                '${formatter.format(perDay)} / ${safe.daysRemaining}d',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (safe.upcomingBills.isNotEmpty) ...<Widget>[
              const SizedBox(height: Gap.md),
              Divider(color: theme.colorScheme.outlineVariant),
              const SizedBox(height: Gap.sm),
              Text(
                l10n.dashboardUpcomingBills,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Gap.xs),
              // Capped: the card summarises, it is not the recurring screen.
              for (final bill in safe.upcomingBills.take(3))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          bill.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        formatter.format(bill.amount),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: money.expense,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (forecast?.totalSavings case final Money total) ...<Widget>[
              const SizedBox(height: Gap.sm),
              InkWell(
                onTap: onForecastTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gap.xs),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          total.isNegative
                              ? l10n.forecastShortfall(
                                  formatter.format(total.abs),
                                )
                              : l10n.forecastSavings(formatter.format(total)),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: total.isNegative
                                ? money.expense
                                : money.income,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Month stepper shared by the dashboard and the analytics tab.
class MonthStepper extends StatelessWidget {
  const MonthStepper({
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.canGoNext,
    super.key,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous month',
        ),
        SizedBox(
          width: 160,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
        IconButton(
          onPressed: canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next month',
        ),
      ],
    );
  }
}

/// Colour for a transaction direction, in one place so the list, the charts and
/// the add screen cannot drift apart.
Color colorForType(ThemeData theme, TxnType type) => switch (type) {
      TxnType.income => theme.money.income,
      TxnType.expense => theme.money.expense,
      TxnType.transfer => theme.money.transfer,
    };


/// Each account's balance, under the total.
///
/// The total answers "how much do I have"; this answers "where is it", which is
/// the question you actually act on — you cannot spend the total, you spend from
/// one account. Balances are shown in each account's own currency rather than
/// converted, because that is the number the bank app or the wallet will agree
/// with.
class AccountBalanceStrip extends StatelessWidget {
  const AccountBalanceStrip({
    required this.accounts,
    required this.formatter,
    required this.onTap,
    super.key,
  });

  final List<AccountWithBalance> accounts;
  final MoneyFormatter formatter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return SizedBox(
      // Horizontal rather than a vertical list: the dashboard's job is to be
      // read at a glance, and a wallet with five accounts would otherwise push
      // the month summary off the first screen.
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        itemCount: accounts.length,
        separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
        itemBuilder: (context, index) {
          final entry = accounts[index];
          final negative = entry.balance.isNegative;
          return InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.all(Radius.circular(Gap.radiusMd)),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: Gap.sm,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius:
                    const BorderRadius.all(Radius.circular(Gap.radiusMd)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    entry.account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatter.format(entry.balance),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: negative ? theme.money.expense : null,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Where this month's money went, and how each category is tracking.
///
/// Replaces the old budgets-only card, which filtered to budgets at 80%+ and
/// rendered nothing at all when everything was comfortable — so the first screen
/// of a spending tracker said nothing about spending for most of the month.
///
/// Everything here comes from providers the Analytics tab already drives; this
/// is a second rendering of the same numbers, not a second source of them.
class CategoryBreakdownCard extends StatelessWidget {
  const CategoryBreakdownCard({
    required this.slices,
    required this.budgets,
    required this.formatter,
    required this.l10n,
    required this.onTap,
    super.key,
  });

  final List<CategorySlice> slices;

  /// Caps by category id. Categories without one simply render no bar.
  final Map<String, BudgetProgress> budgets;

  final MoneyFormatter formatter;
  final L10n l10n;
  final VoidCallback onTap;

  /// Four fits above the fold beside the other cards. The full ranking lives one
  /// tap away on Analytics, which this card links to.
  static const int _maxRows = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (slices.isEmpty) return const SizedBox.shrink();

    // Over-budget categories first, then by amount. Keeps the warning the
    // budgets-only card used to give, without hiding everything else to do it.
    final ranked = <CategorySlice>[...slices]..sort((a, b) {
        final aOver = budgets[a.category?.id]?.isOver ?? false;
        final bOver = budgets[b.category?.id]?.isOver ?? false;
        if (aOver != bOver) return aOver ? -1 : 1;
        return b.total.milli.compareTo(a.total.milli);
      });
    final top = ranked.take(_maxRows).toList(growable: false);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Gap.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.analyticsByCategory,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              for (final slice in top) ...<Widget>[
                _CategoryRow(
                  slice: slice,
                  budget: budgets[slice.category?.id],
                  formatter: formatter,
                  l10n: l10n,
                ),
                if (slice != top.last) const SizedBox(height: Gap.md),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.slice,
    required this.budget,
    required this.formatter,
    required this.l10n,
  });

  final CategorySlice slice;
  final BudgetProgress? budget;
  final MoneyFormatter formatter;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = slice.changeRatio;
    final cap = budget;

    return Semantics(
      label: <String>[
        slice.category?.name ?? l10n.txnAll,
        formatter.format(slice.total),
        '${(slice.share * 100).round()}%',
      ].join(', '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                CategoryIcons.resolve(slice.category?.icon ?? 'category'),
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  slice.category?.name ?? l10n.txnAll,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              if (change != null) ...<Widget>[
                ChangeChip(ratio: change),
                const SizedBox(width: Gap.sm),
              ],
              Text(
                formatter.format(slice.total),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          // The share bar only appears where there is no cap: two bars on one
          // row would be read as one measurement and mean neither.
          if (cap != null)
            Padding(
              padding: const EdgeInsets.only(top: Gap.xs),
              child: BudgetBar(
                progress: cap,
                formatter: formatter,
                l10n: l10n,
                showCategory: false,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: Gap.xs),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: slice.share.clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
