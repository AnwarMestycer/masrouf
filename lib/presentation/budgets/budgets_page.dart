import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/budget.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/add/widgets/add_widgets.dart';
import 'package:masrouf/presentation/budgets/widgets/budget_bar.dart';
import 'package:masrouf/presentation/common/feedback.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/providers/analytics_providers.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

/// Monthly caps, one per expense category.
///
/// Every expense category is listed, capped or not, so setting a budget is one
/// tap from the same place you read them — rather than hiding uncapped
/// categories behind an "add" flow that has to re-ask which category you meant.
class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ym = ref.watch(selectedMonthProvider);

    final categories =
        ref.watch(categoriesOfKindProvider(CategoryKind.expense)).value ??
            const <Category>[];
    final progress = ref.watch(budgetProgressProvider(ym)).value ??
        const <BudgetProgress>[];

    final byCategory = <String, BudgetProgress>{
      for (final p in progress) p.budget.categoryId: p,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.budgetsTitle)),
      body: categories.isEmpty
          ? EmptyHint(
              icon: Icons.savings_outlined,
              title: l10n.budgetsEmpty,
              subtitle: l10n.budgetsEmptyHint,
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: Gap.sm),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final category = categories[index];
                return _BudgetRow(
                  category: category,
                  progress: byCategory[category.id],
                );
              },
            ),
    );
  }
}

class _BudgetRow extends ConsumerWidget {
  const _BudgetRow({required this.category, required this.progress});

  final Category category;
  final BudgetProgress? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final formatter = ref.watch(moneyFormatterProvider);
    final entry = progress;

    return ListTile(
      title: Text(category.name),
      subtitle: entry == null
          ? Text(
              l10n.budgetNone,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(top: Gap.xs),
              child: BudgetBar(
                progress: entry,
                formatter: formatter,
                l10n: l10n,
                showCategory: false,
              ),
            ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => BudgetEditor.show(context, category, entry?.budget),
    );
  }
}

/// Sets or clears one category's cap.
class BudgetEditor extends ConsumerStatefulWidget {
  const BudgetEditor({required this.category, required this.budget, super.key});

  final Category category;
  final Budget? budget;

  static Future<void> show(
    BuildContext context,
    Category category,
    Budget? budget,
  ) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: BudgetEditor(category: category, budget: budget),
        ),
      );

  @override
  ConsumerState<BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends ConsumerState<BudgetEditor> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.budget?.amount.toDecimalString() ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final base = ref.read(baseCurrencyProvider);
    final amount = Money.tryParse(_amount.text, base);

    if (amount == null || !amount.isPositive) {
      setState(() => _error = l10n.validationAmountPositive);
      return;
    }

    final result = await ref
        .read(budgetRepositoryProvider)
        .setForCategory(widget.category.id, amount);
    if (!mounted || !result.report(context)) return;
    Navigator.of(context).pop();
  }

  /// Removing a cap is not destructive — no transaction changes — so it asks
  /// once and says so, rather than either warning about nothing or removing
  /// silently.
  Future<void> _remove() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.budgetRemoveConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final removed = await ref
        .read(budgetRepositoryProvider)
        .remove(widget.budget!.id);
    if (!mounted || !removed.report(context)) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final base = ref.watch(baseCurrencyProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(widget.category.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: Gap.lg),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.budgetCap,
              suffixText: base.symbol,
              errorText: _error,
            ),
          ),
          const SizedBox(height: Gap.lg),
          FilledButton(onPressed: _save, child: Text(l10n.actionSave)),
          if (widget.budget != null) ...<Widget>[
            const SizedBox(height: Gap.sm),
            TextButton.icon(
              onPressed: _remove,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.actionDelete),
            ),
          ],
        ],
      ),
    );
  }
}
