import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:masrouf/core/router/routes.dart';
import 'package:masrouf/core/ids.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/money/money_formatter.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/entities/planned_expense.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/add/widgets/add_widgets.dart';
import 'package:masrouf/presentation/common/category_icons.dart';
import 'package:masrouf/presentation/common/feedback.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/providers/analytics_providers.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

/// Money the user has committed to but not yet spent.
///
/// The header states the total set aside, because that is the number that
/// explains why Safe to spend is lower than the balance. Without it the gap
/// looks like a bug.
class PlannedPage extends ConsumerWidget {
  const PlannedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final formatter = ref.watch(moneyFormatterProvider);
    final base = ref.watch(baseCurrencyProvider);
    final locale = ref.watch(localeCodeProvider);
    final plans = ref.watch(pendingPlansProvider).value;

    final reserved = Money(
      (plans ?? const <PlannedExpenseView>[]).fold<int>(
        0,
        (sum, v) => sum + v.plan.amount.milli,
      ),
      base,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.plannedTitle),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: l10n.calendarTitle,
            onPressed: () => context.push(Routes.calendar),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => PlannedEditor.show(context, null),
        icon: const Icon(Icons.add),
        label: Text(l10n.plannedAdd),
      ),
      body: plans == null
          ? const Center(child: CircularProgressIndicator())
          : plans.isEmpty
          ? EmptyHint(
              icon: Icons.event_outlined,
              title: l10n.plannedEmpty,
              subtitle: l10n.plannedEmptyHint,
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.lg,
                    Gap.md,
                    Gap.lg,
                    Gap.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.plannedReserved(formatter.format(reserved)),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: Gap.xs),
                      Text(
                        l10n.plannedNotCounted,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                for (final view in plans)
                  _PlannedRow(view: view, locale: locale, formatter: formatter),
              ],
            ),
    );
  }
}

class _PlannedRow extends ConsumerWidget {
  const _PlannedRow({
    required this.view,
    required this.locale,
    required this.formatter,
  });

  final PlannedExpenseView view;
  final String locale;
  final MoneyFormatter formatter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final plan = view.plan;
    final due = plan.isDue(DateTime.now());

    return ListTile(
      key: ValueKey<String>(plan.id),
      onTap: () => PlannedEditor.show(context, plan),
      leading: Icon(
        CategoryIcons.resolve(view.category?.icon ?? 'category'),
        color: due
            ? theme.colorScheme.error
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        plan.note?.trim().isNotEmpty ?? false
            ? plan.note!.trim()
            : view.category?.name ?? l10n.txnAll,
      ),
      subtitle: Text(
        DateFormat.MMMEd(locale).add_Hm().format(plan.dueAt),
        style: theme.textTheme.bodySmall?.copyWith(
          color: due
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Text(
        formatter.format(plan.amount),
        style: theme.textTheme.titleSmall,
      ),
    );
  }
}

/// Create/edit sheet for a planned expense.
class PlannedEditor extends ConsumerStatefulWidget {
  const PlannedEditor({required this.plan, super.key});

  final PlannedExpense? plan;

  static Future<void> show(BuildContext context, PlannedExpense? plan) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: PlannedEditor(plan: plan),
        ),
      );

  @override
  ConsumerState<PlannedEditor> createState() => _PlannedEditorState();
}

class _PlannedEditorState extends ConsumerState<PlannedEditor> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.plan?.amount.toDecimalString() ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.plan?.note ?? '',
  );

  /// Defaults to this time tomorrow: a plan for the past is not a plan, and
  /// making the user pick a date before they can save one is friction on the
  /// common case.
  late DateTime _dueAt =
      widget.plan?.dueAt ?? DateTime.now().add(const Duration(days: 1));

  late String? _categoryId = widget.plan?.categoryId;
  String? _amountError;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      // Forward only. A planned expense in the past would reserve money for
      // something that has already either happened or not.
      firstDate: now.dateOnly,
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
    );
    if (!mounted) return;

    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _dueAt.hour,
        time?.minute ?? _dueAt.minute,
      );
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final base = ref.read(baseCurrencyProvider);
    final amount = Money.tryParse(_amount.text, base);

    if (amount == null || !amount.isPositive) {
      setState(() => _amountError = l10n.validationAmountPositive);
      return;
    }

    final result = await ref
        .read(plannedRepositoryProvider)
        .save(
          PlannedExpense(
            id: widget.plan?.id ?? Ids.newId(),
            categoryId: _categoryId,
            accountId: widget.plan?.accountId,
            amount: amount,
            dueAt: _dueAt,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            status: widget.plan?.status ?? PlannedStatus.pending,
            transactionId: widget.plan?.transactionId,
            updatedAt: DateTime.now(),
          ),
        );
    if (!mounted || !result.report(context)) return;
    Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.plannedRemoveConfirm),
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
    if (confirmed != true || !mounted) return;

    final result = await ref
        .read(plannedRepositoryProvider)
        .remove(widget.plan!.id);
    if (!mounted || !result.report(context)) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final base = ref.watch(baseCurrencyProvider);
    final locale = ref.watch(localeCodeProvider);
    final categories =
        ref.watch(categoriesOfKindProvider(CategoryKind.expense)).value ??
        const <Category>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.plan == null ? l10n.plannedAdd : l10n.actionEdit,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: Gap.lg),
            TextField(
              controller: _amount,
              autofocus: widget.plan == null,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.txnAmount,
                suffixText: base.symbol,
                errorText: _amountError,
              ),
              onChanged: (_) {
                if (_amountError != null) setState(() => _amountError = null);
              },
            ),
            const SizedBox(height: Gap.lg),
            OutlinedButton.icon(
              onPressed: _pickWhen,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                '${l10n.plannedWhen}: '
                '${DateFormat.yMMMEd(locale).add_Hm().format(_dueAt)}',
              ),
            ),
            const SizedBox(height: Gap.lg),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: l10n.txnNoteHint),
            ),
            const SizedBox(height: Gap.lg),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.xs,
              children: <Widget>[
                for (final category in categories)
                  ChoiceChip(
                    label: Text(category.name),
                    selected: _categoryId == category.id,
                    onSelected: (_) =>
                        setState(() => _categoryId = category.id),
                  ),
              ],
            ),
            const SizedBox(height: Gap.md),
            Text(
              l10n.plannedNotCounted,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.lg),
            FilledButton(onPressed: _save, child: Text(l10n.actionSave)),
            if (widget.plan != null) ...<Widget>[
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
      ),
    );
  }
}

/// "Did this happen?" — shown on the dashboard once a plan's moment has passed.
///
/// It asks rather than logging. A plan records what the user intended, which is
/// not evidence that the money moved; auto-converting would put a transaction in
/// the ledger that nobody confirmed.
class DuePlanCard extends ConsumerWidget {
  const DuePlanCard({required this.view, super.key});

  final PlannedExpenseView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final formatter = ref.watch(moneyFormatterProvider);
    final locale = ref.watch(localeCodeProvider);
    final accounts =
        ref.watch(accountsProvider).value ?? const <AccountWithBalance>[];
    final plan = view.plan;

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.plannedDueTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: Gap.xs),
            Text(
              '${plan.note?.trim().isNotEmpty ?? false ? plan.note!.trim() : view.category?.name ?? l10n.txnAll}'
              ' · ${formatter.format(plan.amount)}',
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              l10n.plannedDueOn(DateFormat.MMMEd(locale).format(plan.dueAt)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.sm),
            // Both actions are Expanded because the app's theme gives
            // FilledButton `Size.fromHeight`, i.e. an infinite minimum width.
            // Dropped into a plain Row that asserts during layout.
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final result = await ref
                          .read(plannedRepositoryProvider)
                          .cancel(plan.id);
                      if (context.mounted) result.report(context);
                    },
                    child: Text(l10n.plannedSkip),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: FilledButton(
                    // Disabled with no account: confirming writes a real
                    // transaction, which has to come out of somewhere.
                    onPressed: accounts.isEmpty
                        ? null
                        : () async {
                            final result = await ref
                                .read(plannedRepositoryProvider)
                                .confirm(
                                  plan.id,
                                  accountId:
                                      plan.accountId ?? accounts.first.id,
                                );
                            if (context.mounted) result.report(context);
                          },
                    child: Text(l10n.plannedLogIt),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
