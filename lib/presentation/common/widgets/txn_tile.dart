import 'package:flutter/material.dart';
import 'package:masrouf/core/money/money_formatter.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/common/category_icons.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/dashboard/widgets/dashboard_widgets.dart';

/// One row in a transaction list.
///
/// Const-constructible and free of provider lookups: the whole [TxnView] is
/// passed in already resolved, so a list of these rebuilds only the rows whose
/// data actually changed rather than every row on every ledger write.
class TxnTile extends StatelessWidget {
  const TxnTile({
    required this.view,
    required this.formatter,
    required this.onTap,
    this.onLongPress,
    this.selecting = false,
    this.selected = false,
    super.key,
  });

  final TxnView view;
  final MoneyFormatter formatter;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Selection-mode visuals: the leading icon swaps for a check circle so a
  /// long-press multi-select has an obvious state to toggle.
  final bool selecting;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final txn = view.txn;
    final color = colorForType(theme, txn.type);

    final title = txn.isTransfer
        ? '${view.account.name} → ${view.transferAccount?.name ?? ''}'
        : view.category?.name ?? '—';

    final subtitleParts = <String>[
      if (!txn.isTransfer) view.account.name,
      if (txn.note?.trim().isNotEmpty ?? false) txn.note!.trim(),
    ];

    return Semantics(
      // Merged so the row is announced as one item — "Groceries, Cash, minus
      // 25 dinars" — instead of four disconnected fragments. The direction is
      // spelled out in words too: the sign prefix is U+2212 MINUS SIGN, which
      // many screen readers do not voice at all, and colour alone carries it
      // otherwise.
      button: true,
      label: <String>[
        title,
        ...subtitleParts,
        switch (txn.type) {
          TxnType.income => l10n.txnIncome,
          TxnType.expense => l10n.txnExpense,
          TxnType.transfer => l10n.txnTransfer,
        },
        formatter.format(txn.amount),
      ].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: selecting
            ? Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 26,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              )
            : Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: txn.isTransfer
                ? color.withValues(alpha: 0.14)
                : Color(
                    view.category?.color ??
                        theme.colorScheme.outline.toARGB32(),
                  ).withValues(alpha: 0.14),
            borderRadius: const BorderRadius.all(Radius.circular(Gap.radiusSm)),
          ),
          child: Icon(
            txn.isTransfer
                ? Icons.swap_horiz
                : CategoryIcons.resolve(view.category?.icon ?? 'category'),
            size: 20,
            color: txn.isTransfer
                ? color
                : Color(view.category?.color ?? 0xFF888888),
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge,
        ),
        subtitle: subtitleParts.isEmpty
            ? null
            : Text(
                subtitleParts.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              _signed(txn.type, formatter.format(txn.amount)),
              style: theme.textTheme.titleSmall?.copyWith(color: color),
            ),
            // The base-currency equivalent only appears for foreign amounts, so a
            // single-currency user never sees a redundant second line.
            if (view.baseAmount.currency != txn.amount.currency)
              Text(
                formatter.format(view.baseAmount),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _signed(TxnType type, String formatted) => switch (type) {
    TxnType.income => '+$formatted',
    TxnType.expense => '−$formatted',
    TxnType.transfer => formatted,
  };
}

/// Sticky-ish date header for grouped lists.
class DateHeader extends StatelessWidget {
  const DateHeader({required this.label, required this.trailing, super.key});

  final String label;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            trailing,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
