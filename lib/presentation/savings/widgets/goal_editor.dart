import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:masrouf/core/ids.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/savings_goal.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/common/feedback.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';
import 'package:masrouf/presentation/providers/savings_providers.dart';

/// Create/edit sheet for a savings goal.
///
/// The account chosen here is only where the goal's money goes by default;
/// progress comes from the transfers earmarked for it. Only savings accounts
/// are offered, and one is created on save if there are none yet.
class GoalEditor extends ConsumerStatefulWidget {
  const GoalEditor({required this.goal, super.key});

  final SavingsGoal? goal;

  static Future<void> show(BuildContext context, SavingsGoal? goal) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: GoalEditor(goal: goal),
        ),
      );

  @override
  ConsumerState<GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends ConsumerState<GoalEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.goal?.name ?? '');
  late final TextEditingController _target = TextEditingController(
    text: widget.goal?.target.toDecimalString() ?? '',
  );
  late String? _accountId = widget.goal?.accountId;
  late DateTime? _targetDate = widget.goal?.targetDate;
  String? _nameError;
  String? _targetError;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime(now.year, now.month + 6, now.day),
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null && mounted) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final base = ref.read(baseCurrencyProvider);
    final target = Money.tryParse(_target.text, base);
    setState(() {
      _nameError =
          _name.text.trim().isEmpty ? l10n.validationNameRequired : null;
      _targetError = target == null || !target.isPositive
          ? l10n.validationAmountPositive
          : null;
    });
    if (target == null || !target.isPositive || _nameError != null) return;

    final repository = ref.read(savingsRepositoryProvider);
    var accountId = _accountId;
    if (accountId == null) {
      final created = await repository
          .ensureSavingsAccount(l10n.savingsDefaultAccountName);
      if (!mounted || !created.report(context)) return;
      accountId = created.valueOrNull!.id;
    }

    final result = await repository.saveGoal(
          SavingsGoal(
            id: widget.goal?.id ?? Ids.newId(),
            name: _name.text.trim(),
            target: target,
            accountId: accountId,
            targetDate: _targetDate,
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
        content: Text(l10n.goalsRemoveConfirm),
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

    final result =
        await ref.read(savingsRepositoryProvider).removeGoal(widget.goal!.id);
    if (!mounted || !result.report(context)) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final base = ref.watch(baseCurrencyProvider);
    final locale = ref.watch(localeCodeProvider);
    final accounts = (ref.watch(accountsProvider).value ??
            const <AccountWithBalance>[])
        .where((e) => e.account.type == AccountType.savings)
        .toList(growable: false);
    // Pre-selected rather than left for the user to tap: with one savings
    // account there is nothing to choose.
    _accountId ??= accounts.firstOrNull?.id;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.goal == null ? l10n.goalsAdd : l10n.actionEdit,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: Gap.lg),
            TextField(
              controller: _name,
              autofocus: widget.goal == null,
              decoration: InputDecoration(
                labelText: l10n.categoriesName,
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: Gap.lg),
            TextField(
              controller: _target,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.goalsTarget,
                suffixText: base.symbol,
                errorText: _targetError,
              ),
            ),
            const SizedBox(height: Gap.lg),
            Text(l10n.goalsAccount, style: theme.textTheme.labelLarge),
            const SizedBox(height: Gap.sm),
            if (accounts.isEmpty)
              Text(
                l10n.savingsNewAccount(l10n.savingsDefaultAccountName),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            else
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.xs,
                children: <Widget>[
                  for (final entry in accounts)
                    ChoiceChip(
                      label: Text(entry.account.name),
                      selected: _accountId == entry.id,
                      onSelected: (_) =>
                          setState(() => _accountId = entry.id),
                    ),
                ],
              ),
            const SizedBox(height: Gap.lg),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _targetDate == null
                    ? l10n.historyFilterAll
                    : l10n.goalsBy(
                        DateFormat.yMMM(locale).format(_targetDate!),
                      ),
              ),
            ),
            const SizedBox(height: Gap.lg),
            FilledButton(onPressed: _save, child: Text(l10n.actionSave)),
            if (widget.goal != null) ...<Widget>[
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
