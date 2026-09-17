import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:masrouf/core/ids.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/domain/entities/recurring_rule.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/add/widgets/add_widgets.dart';
import 'package:masrouf/presentation/common/feedback.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/providers/analytics_providers.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

/// Recurring rules — rent, salary, subscriptions.
///
/// Occurrences are materialised locally on launch, so the ledger is correct even
/// if the phone has been offline all month.
class RecurringPage extends ConsumerWidget {
  const RecurringPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeCodeProvider);
    final formatter = ref.watch(moneyFormatterProvider);
    final rules = ref.watch(recurringRulesProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.recurringTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => RecurringEditor.show(context, null),
        icon: const Icon(Icons.add),
        label: Text(l10n.recurringAdd),
      ),
      body: rules == null
          ? const Center(child: CircularProgressIndicator())
          : rules.isEmpty
              ? EmptyHint(
                  icon: Icons.repeat,
                  title: l10n.recurringTitle,
                  subtitle: l10n.recurringAdd,
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: rules.length,
                  itemBuilder: (context, index) {
                    final rule = rules[index];
                    // A ListTile with a trailing Switch rather than a
                    // SwitchListTile: the latter spends the whole row on the
                    // toggle, which left the editor — and with it any way to
                    // correct or remove a rule — unreachable.
                    return ListTile(
                      key: ValueKey<String>(rule.id),
                      onTap: () => RecurringEditor.show(context, rule),
                      leading: Icon(
                        rule.type == TxnType.income
                            ? Icons.north_east
                            : Icons.south_west,
                      ),
                      title: Text(
                        rule.note?.trim().isNotEmpty ?? false
                            ? rule.note!.trim()
                            : formatter.format(rule.amount),
                      ),
                      subtitle: Text(
                        '${rule.cadence.localise(l10n)} · '
                        '${l10n.recurringNextRun(DateFormat.MMMd(locale).format(rule.nextRunDate))}',
                      ),
                      trailing: Switch(
                        value: rule.active,
                        onChanged: (active) => ref
                            .read(recurringRepositoryProvider)
                            .setActive(rule.id, active: active),
                      ),
                    );
                  },
                ),
    );
  }
}

/// Create/edit sheet for a recurring rule.
///
/// [rule] is null when creating. Reached from the list row's tap, which is the
/// only way to correct an amount or remove a cancelled subscription.
class RecurringEditor extends ConsumerStatefulWidget {
  const RecurringEditor({required this.rule, super.key});

  final RecurringRule? rule;

  static Future<void> show(BuildContext context, RecurringRule? rule) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: RecurringEditor(rule: rule),
        ),
      );

  @override
  ConsumerState<RecurringEditor> createState() => _RecurringEditorState();
}

class _RecurringEditorState extends ConsumerState<RecurringEditor> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.rule?.amount.toDecimalString() ?? '',
  );
  late final TextEditingController _note =
      TextEditingController(text: widget.rule?.note ?? '');

  late TxnType _type = widget.rule?.type ?? TxnType.expense;
  late Cadence _cadence = widget.rule?.cadence ?? Cadence.monthly;
  late int _dayOfMonth = widget.rule?.dayOfMonth ?? DateTime.now().day;
  late int _dayOfWeek = widget.rule?.dayOfWeek ?? DateTime.now().weekday;
  String? _categoryId;
  String? _accountId;
  /// One message per field. Previously every failure rendered inside the
  /// amount box, so forgetting to pick an account put the word "Account" under
  /// the amount and pointed the user at the wrong control.
  String? _amountError;
  String? _accountError;
  String? _categoryError;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.rule?.categoryId;
    _accountId = widget.rule?.accountId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final base = ref.read(baseCurrencyProvider);
    final amount = Money.tryParse(_amount.text, base);
    final accountId = _accountId;

    // Report every problem at once rather than one per tap.
    setState(() {
      _amountError = amount == null || !amount.isPositive
          ? l10n.validationAmountPositive
          : null;
      _accountError =
          accountId == null ? l10n.validationAccountRequired : null;
      _categoryError =
          _categoryId == null ? l10n.validationCategoryRequired : null;
    });
    if (amount == null || accountId == null || _categoryId == null) return;

    final now = DateTime.now().dateOnly;
    final nextRun = _cadence == Cadence.monthly
        ? _nextMonthlyRun(now)
        : _nextWeeklyRun(now);

    final rule = RecurringRule(
      id: widget.rule?.id ?? Ids.newId(),
      type: _type,
      amount: amount,
      categoryId: _categoryId,
      accountId: accountId,
      transferAccountId: null,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      cadence: _cadence,
      dayOfMonth: _cadence == Cadence.monthly ? _dayOfMonth : null,
      dayOfWeek: _cadence == Cadence.weekly ? _dayOfWeek : null,
      nextRunDate: nextRun,
      lastRunDate: widget.rule?.lastRunDate,
      active: widget.rule?.active ?? true,
      updatedAt: DateTime.now(),
    );

    final repository = ref.read(recurringRepositoryProvider);
    final result = widget.rule == null
        ? await repository.create(rule)
        : await repository.update(rule);

    if (!mounted || !result.report(context)) return;
    Navigator.of(context).pop();
  }

  /// Deleting a rule stops future occurrences; it does not touch the
  /// transactions it already created, which is worth saying before the tap.
  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.recurringDeleteConfirm),
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

    await ref.read(recurringRepositoryProvider).delete(widget.rule!.id);
    if (mounted) Navigator.of(context).pop();
  }

  /// First occurrence strictly in the future, so creating a rule does not
  /// immediately materialise a transaction for a bill already paid this month.
  DateTime _nextMonthlyRun(DateTime from) {
    final thisMonth = dayOfMonthIn(from.year, from.month, _dayOfMonth);
    if (thisMonth.isAfter(from)) return thisMonth;
    final next = from.addMonthsClamped(1);
    return dayOfMonthIn(next.year, next.month, _dayOfMonth);
  }

  DateTime _nextWeeklyRun(DateTime from) {
    var delta = (_dayOfWeek - from.weekday) % 7;
    if (delta <= 0) delta += 7;
    return from.add(Duration(days: delta));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final base = ref.watch(baseCurrencyProvider);
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final categories = ref
            .watch(
              categoriesOfKindProvider(
                _type == TxnType.income
                    ? CategoryKind.income
                    : CategoryKind.expense,
              ),
            )
            .value ??
        const [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.recurringAdd,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Gap.lg),
            SegmentedButton<TxnType>(
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
              selected: <TxnType>{_type},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: Gap.lg),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.txnAmount,
                suffixText: base.symbol,
                errorText: _amountError,
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
            if (_categoryError != null) _FieldError(message: _categoryError!),
            const SizedBox(height: Gap.lg),
            Wrap(
              spacing: Gap.sm,
              children: <Widget>[
                for (final entry in accounts)
                  ChoiceChip(
                    label: Text(entry.account.name),
                    selected: _accountId == entry.id,
                    onSelected: (_) => setState(() => _accountId = entry.id),
                  ),
              ],
            ),
            if (_accountError != null) _FieldError(message: _accountError!),
            const SizedBox(height: Gap.lg),
            SegmentedButton<Cadence>(
              segments: <ButtonSegment<Cadence>>[
                ButtonSegment<Cadence>(
                  value: Cadence.monthly,
                  label: Text(l10n.recurringCadenceMonthly),
                ),
                ButtonSegment<Cadence>(
                  value: Cadence.weekly,
                  label: Text(l10n.recurringCadenceWeekly),
                ),
              ],
              selected: <Cadence>{_cadence},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _cadence = s.first),
            ),
            const SizedBox(height: Gap.md),
            if (_cadence == Cadence.monthly)
              Slider(
                value: _dayOfMonth.toDouble(),
                min: 1,
                max: 31,
                divisions: 30,
                label: '$_dayOfMonth',
                onChanged: (v) => setState(() => _dayOfMonth = v.round()),
              )
            else
              Slider(
                value: _dayOfWeek.toDouble(),
                min: 1,
                max: 7,
                divisions: 6,
                label: DateFormat.E(ref.watch(localeCodeProvider))
                    .format(DateTime(2024, 1, _dayOfWeek)),
                onChanged: (v) => setState(() => _dayOfWeek = v.round()),
              ),
            const SizedBox(height: Gap.lg),
            FilledButton(onPressed: _save, child: Text(l10n.actionSave)),
            if (widget.rule != null) ...<Widget>[
              const SizedBox(height: Gap.sm),
              TextButton.icon(
                onPressed: _confirmDelete,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
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

/// A validation message under the control it belongs to.
class _FieldError extends StatelessWidget {
  const _FieldError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Gap.xs),
      child: Text(
        message,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.error),
      ),
    );
  }
}
