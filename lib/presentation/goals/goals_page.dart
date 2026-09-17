import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:masrouf/core/ids.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/theme/app_colors.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/savings_goal.dart';
import 'package:masrouf/presentation/add/widgets/add_widgets.dart';
import 'package:masrouf/presentation/common/feedback.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/providers/analytics_providers.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

/// Savings targets, each backed by a real account.
///
/// Progress is that account's balance, never a number kept here. A goal is a
/// lens on money the user already has, not a second place it is recorded.
class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final goals = ref.watch(goalsProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.goalsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => GoalEditor.show(context, null),
        icon: const Icon(Icons.add),
        label: Text(l10n.goalsAdd),
      ),
      body: goals == null
          ? const Center(child: CircularProgressIndicator())
          : goals.isEmpty
              ? EmptyHint(
                  icon: Icons.flag_outlined,
                  title: l10n.goalsEmpty,
                  subtitle: l10n.goalsEmptyHint,
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: goals.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _GoalRow(progress: goals[index]),
                ),
    );
  }
}

class _GoalRow extends ConsumerWidget {
  const _GoalRow({required this.progress});

  final SavingsGoalProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final formatter = ref.watch(moneyFormatterProvider);
    final locale = ref.watch(localeCodeProvider);
    final now = DateTime.now();

    final perMonth = progress.requiredPerMonth(now);
    // The forecast is what turns "you need 250 a month" into "and you are on
    // course for that" — without it the requirement is a demand with no answer.
    final projected = ref.watch(forecastProvider).value;
    final monthlySavings = projected == null || projected.months.isEmpty
        ? null
        : Money(
            projected.months
                    .map((m) => m.projectedSavings.milli)
                    .reduce((a, b) => a + b) ~/
                projected.months.length,
            progress.goal.target.currency,
          );

    final String status;
    final Color statusColor;
    if (progress.isReached) {
      status = l10n.goalsReached;
      statusColor = theme.money.income;
    } else if (perMonth != null && monthlySavings != null) {
      final onTrack = monthlySavings.milli >= perMonth.milli;
      status = onTrack ? l10n.goalsOnTrack : l10n.goalsBehind;
      statusColor = onTrack ? theme.money.income : theme.colorScheme.tertiary;
    } else {
      status = '';
      statusColor = theme.colorScheme.onSurfaceVariant;
    }

    return ListTile(
      onTap: () => GoalEditor.show(context, progress.goal),
      title: Text(progress.goal.name),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: Gap.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${formatter.format(progress.saved)} / '
              '${formatter.format(progress.goal.target)}'
              ' · ${l10n.goalsAccount} ${progress.accountName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(Gap.radiusSm),
              child: LinearProgressIndicator(
                value: progress.ratio.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress.isReached ? theme.money.income : theme.colorScheme.primary,
                ),
              ),
            ),
            if (progress.goal.targetDate != null || status.isNotEmpty) ...<Widget>[
              const SizedBox(height: Gap.xs),
              Text(
                <String>[
                  if (progress.goal.targetDate != null)
                    l10n.goalsBy(
                      DateFormat.yMMM(locale)
                          .format(progress.goal.targetDate!),
                    ),
                  if (perMonth != null)
                    l10n.goalsPerMonth(formatter.format(perMonth)),
                  if (status.isNotEmpty) status,
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(color: statusColor),
              ),
            ],
          ],
        ),
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

/// Create/edit sheet for a savings goal.
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
  String? _accountError;

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
    final accountId = _accountId;

    setState(() {
      _nameError =
          _name.text.trim().isEmpty ? l10n.validationNameRequired : null;
      _targetError = target == null || !target.isPositive
          ? l10n.validationAmountPositive
          : null;
      _accountError =
          accountId == null ? l10n.validationAccountRequired : null;
    });
    if (target == null || accountId == null || _nameError != null) return;

    final result = await ref.read(goalRepositoryProvider).save(
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
        await ref.read(goalRepositoryProvider).remove(widget.goal!.id);
    if (!mounted || !result.report(context)) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final base = ref.watch(baseCurrencyProvider);
    final locale = ref.watch(localeCodeProvider);
    final accounts =
        ref.watch(accountsProvider).value ?? const <AccountWithBalance>[];

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
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.xs,
              children: <Widget>[
                for (final entry in accounts)
                  ChoiceChip(
                    label: Text(entry.account.name),
                    selected: _accountId == entry.id,
                    onSelected: (_) => setState(() {
                      _accountId = entry.id;
                      _accountError = null;
                    }),
                  ),
              ],
            ),
            if (_accountError != null)
              Padding(
                padding: const EdgeInsets.only(top: Gap.xs),
                child: Text(
                  _accountError!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
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
