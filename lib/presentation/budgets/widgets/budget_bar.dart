import 'package:flutter/material.dart';
import 'package:masrouf/core/money/money_formatter.dart';
import 'package:masrouf/core/theme/app_colors.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/budget.dart';
import 'package:masrouf/l10n/app_localizations.dart';

/// One budget's progress: a bar, the two amounts, and what is left.
///
/// Shared by the budgets screen, the dashboard card and the analytics list so
/// the same cap reads identically wherever it appears — three different renderings
/// of one number is how a user stops trusting any of them.
class BudgetBar extends StatelessWidget {
  const BudgetBar({
    required this.progress,
    required this.formatter,
    required this.l10n,
    this.showCategory = true,
    super.key,
  });

  final BudgetProgress progress;
  final MoneyFormatter formatter;
  final L10n l10n;

  /// False where the category name is already the row's title.
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = theme.money;

    // Over budget is the only state that earns the alarm colour. "Near the
    // limit" is still a normal month, so it gets emphasis without alarm —
    // otherwise every colour on the screen means the same thing by month end.
    final Color barColor;
    if (progress.isOver) {
      barColor = money.expense;
    } else if (progress.isNearLimit) {
      barColor = theme.colorScheme.tertiary;
    } else {
      barColor = theme.colorScheme.primary;
    }

    final trailing = progress.isOver
        ? l10n.budgetOver(formatter.format(progress.overspend))
        : l10n.budgetRemaining(formatter.format(progress.remaining));

    return Semantics(
      // The bar carries no text of its own, so without this a screen reader
      // hears two amounts and nothing about the relationship between them.
      label: '${progress.category?.name ?? l10n.txnAll}: $trailing',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (showCategory)
                Expanded(
                  child: Text(
                    progress.category?.name ?? l10n.txnAll,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              Text(
                l10n.budgetSpentOfCap(
                  formatter.format(progress.spent, showSymbol: false),
                  formatter.format(progress.cap),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(Gap.radiusSm),
            child: LinearProgressIndicator(
              // Clamped so an overspend fills the bar rather than overflowing it;
              // the amount beside it carries how far past the line it went.
              value: progress.ratio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            trailing,
            style: theme.textTheme.bodySmall?.copyWith(
              color: progress.isOver
                  ? money.expense
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
