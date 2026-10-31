import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/savings_goal.dart';
import 'package:masrouf/domain/entities/savings_plan.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/common/feedback.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/common/widgets/app_text_field.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';
import 'package:masrouf/presentation/providers/savings_providers.dart';

/// Moves money into a savings account, or back out of one.
///
/// Both directions are a plain transfer underneath, written through the same
/// path as one typed on the add screen. What this sheet adds is the choice of
/// which side is the savings account, and the goal the money is for.
class SavingsMoveSheet extends ConsumerStatefulWidget {
  const SavingsMoveSheet({
    required this.intoSavings,
    this.amount,
    this.fromAccountId,
    this.goalId,
    super.key,
  });

  final bool intoSavings;
  final Money? amount;
  final String? fromAccountId;
  final String? goalId;

  /// Opens the sheet. Returns whether a transfer was written.
  static Future<bool> show(
    BuildContext context, {
    required bool intoSavings,
    Money? amount,
    String? fromAccountId,
    String? goalId,
  }) async =>
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => SavingsMoveSheet(
          intoSavings: intoSavings,
          amount: amount,
          fromAccountId: fromAccountId,
          goalId: goalId,
        ),
      ) ??
      false;

  @override
  ConsumerState<SavingsMoveSheet> createState() => _SavingsMoveSheetState();
}

class _SavingsMoveSheetState extends ConsumerState<SavingsMoveSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.amount?.toDecimalString() ?? '',
  );
  String? _fromId;
  String? _toId;
  late String? _goalId = widget.goalId;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  bool _isSavings(Account a) => a.type == AccountType.savings;

  /// Picks sensible ends the first time the accounts are known: the account
  /// the money came from if the caller named one, and the goal's own savings
  /// account if a goal is chosen.
  void _defaults(List<Account> ordinary, List<Account> savings) {
    final sources = widget.intoSavings ? ordinary : savings;
    final targets = widget.intoSavings ? savings : ordinary;
    if (_fromId == null && sources.isNotEmpty) {
      _fromId = sources
          .firstWhere(
            (a) => a.id == widget.fromAccountId,
            orElse: () => sources.first,
          )
          .id;
    }
    if (_toId == null && targets.isNotEmpty) {
      _toId = targets.first.id;
    }
  }

  void _pickGoal(SavingsGoal? goal, List<Account> savings) {
    setState(() {
      _goalId = goal?.id;
      _error = null;
      if (goal == null) return;
      // A goal's money goes to, and comes back from, its own account by
      // default. Only a default: any savings account can hold it.
      final own = savings.where((a) => a.id == goal.accountId);
      if (own.isEmpty) return;
      if (widget.intoSavings) {
        _toId = own.first.id;
      } else {
        _fromId = own.first.id;
      }
    });
  }

  Future<void> _submit(
    List<Account> accounts,
    Map<String, SavingsGoalProgress> goals,
  ) async {
    final l10n = context.l10n;
    final repository = ref.read(savingsRepositoryProvider);
    final base = ref.read(baseCurrencyProvider);

    final from = accounts.where((a) => a.id == _fromId).firstOrNull;
    if (from == null) return;

    final amount = Money.tryParse(_amount.text, from.currency);
    if (amount == null || !amount.isPositive) {
      setState(() => _error = l10n.validationAmountPositive);
      return;
    }
    final rate =
        rateToBaseFor(from.currency, base, ref.read(ratesToBaseProvider));
    if (rate == null) {
      // Refused rather than written at 1.0: the rate is frozen on the row, so
      // a guess would be permanent.
      setState(() => _error = l10n.txnRateMissing(from.currency.code));
      return;
    }

    // Checked here as well as in the repository, so the user is told what the
    // goal holds rather than shown a generic failure.
    final goal = _goalId == null ? null : goals[_goalId];
    if (!widget.intoSavings && goal != null) {
      final inBase = amount.currency == base
          ? amount.milli
          : (amount.milli * rate).round();
      if (inBase > goal.saved.milli) {
        setState(
          () => _error = l10n.savingsGoalHolds(
            ref.read(moneyFormatterProvider).format(goal.saved),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);

    var toId = _toId;
    if (toId == null && widget.intoSavings) {
      final created = await repository
          .ensureSavingsAccount(l10n.savingsDefaultAccountName);
      if (!mounted) return;
      if (!created.report(context)) {
        setState(() => _saving = false);
        return;
      }
      toId = created.valueOrNull!.id;
    }
    if (toId == null) {
      setState(() => _saving = false);
      return;
    }

    final result = widget.intoSavings
        ? await repository.putAside(
            fromAccountId: from.id,
            toAccountId: toId,
            amount: amount,
            fxRateToBase: rate,
            goalId: _goalId,
          )
        : await repository.takeBack(
            fromAccountId: from.id,
            toAccountId: toId,
            amount: amount,
            fxRateToBase: rate,
            goalId: _goalId,
          );
    if (!mounted) return;
    if (!result.report(context)) {
      setState(() => _saving = false);
      return;
    }

    final formatted = ref.read(moneyFormatterProvider).format(amount);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(true);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            widget.intoSavings
                ? l10n.savingsPutAsideDone(formatted)
                : l10n.savingsTakeBackDone(formatted),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final formatter = ref.watch(moneyFormatterProvider);
    final accounts = (ref.watch(accountsProvider).value ??
            const <AccountWithBalance>[])
        .map((e) => e.account)
        .toList(growable: false);
    final goals =
        ref.watch(goalsProvider).value ?? const <SavingsGoalProgress>[];
    final goalsById = <String, SavingsGoalProgress>{
      for (final g in goals) g.goal.id: g,
    };

    final ordinary = accounts.where((a) => !_isSavings(a)).toList();
    final savings = accounts.where(_isSavings).toList();
    _defaults(ordinary, savings);

    final sources = widget.intoSavings ? ordinary : savings;
    final targets = widget.intoSavings ? savings : ordinary;

    final String? blocker;
    if (ordinary.isEmpty) {
      blocker = l10n.savingsNoOrdinaryAccount;
    } else if (!widget.intoSavings && savings.isEmpty) {
      blocker = l10n.savingsNothingToTakeBack;
    } else {
      blocker = null;
    }

    final selectedGoal = _goalId == null ? null : goalsById[_goalId];
    final from = sources.where((a) => a.id == _fromId).firstOrNull;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.lg,
        0,
        Gap.lg,
        MediaQuery.viewInsetsOf(context).bottom + Gap.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.intoSavings ? l10n.savingsPutAside : l10n.savingsTakeBack,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: Gap.lg),
            if (blocker != null)
              Text(blocker, style: theme.textTheme.bodyMedium)
            else ...<Widget>[
              AppTextField(
                controller: _amount,
                label: l10n.txnAmount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                errorText: _error,
                autofocus: widget.amount == null,
                textInputAction: TextInputAction.done,
                suffix: from == null ? null : Text(from.currency.symbol),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: Gap.lg),
              _AccountChoice(
                label: l10n.savingsFrom,
                accounts: sources,
                selected: _fromId,
                onSelected: (id) => setState(() => _fromId = id),
              ),
              const SizedBox(height: Gap.md),
              if (targets.isEmpty)
                // Only reachable when putting aside with no savings account.
                Text(
                  l10n.savingsNewAccount(l10n.savingsDefaultAccountName),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                )
              else
                _AccountChoice(
                  label: l10n.savingsTo,
                  accounts: targets,
                  selected: _toId,
                  onSelected: (id) => setState(() => _toId = id),
                ),
              if (goals.isNotEmpty) ...<Widget>[
                const SizedBox(height: Gap.md),
                Text(l10n.savingsForGoal, style: theme.textTheme.labelLarge),
                const SizedBox(height: Gap.sm),
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.xs,
                  children: <Widget>[
                    ChoiceChip(
                      label: Text(l10n.savingsNoGoal),
                      selected: _goalId == null,
                      onSelected: (_) => _pickGoal(null, savings),
                    ),
                    for (final g in goals)
                      ChoiceChip(
                        label: Text(g.goal.name),
                        selected: _goalId == g.goal.id,
                        onSelected: (_) => _pickGoal(g.goal, savings),
                      ),
                  ],
                ),
                if (!widget.intoSavings && selectedGoal != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Gap.xs),
                    child: Text(
                      l10n.savingsGoalHolds(
                        formatter.format(selectedGoal.saved),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: Gap.xl),
              FilledButton(
                onPressed: _saving || from == null
                    ? null
                    : () => _submit(accounts, goalsById),
                child: Text(
                  widget.intoSavings
                      ? l10n.savingsPutAside
                      : l10n.savingsTakeBack,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountChoice extends StatelessWidget {
  const _AccountChoice({
    required this.label,
    required this.accounts,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<Account> accounts;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.xs,
            children: <Widget>[
              for (final account in accounts)
                ChoiceChip(
                  label: Text(account.name),
                  selected: selected == account.id,
                  onSelected: (_) => onSelected(account.id),
                ),
            ],
          ),
        ],
      );
}

/// Corrects what a closed month put aside.
///
/// Prefilled with what the transfers said, because that is the common case.
/// Editable, for money saved somewhere the app cannot see — cash in a drawer,
/// a deposit at another bank.
class SavingsReviewSheet extends ConsumerStatefulWidget {
  const SavingsReviewSheet({
    required this.period,
    required this.monthLabel,
    super.key,
  });

  final SavingsPeriod period;
  final String monthLabel;

  static Future<void> show(
    BuildContext context,
    SavingsPeriod period,
    String monthLabel,
  ) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) =>
            SavingsReviewSheet(period: period, monthLabel: monthLabel),
      );

  @override
  ConsumerState<SavingsReviewSheet> createState() => _SavingsReviewSheetState();
}

class _SavingsReviewSheetState extends ConsumerState<SavingsReviewSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.period.saved?.toDecimalString() ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final parsed =
        Money.tryParse(_controller.text, widget.period.committed.currency);
    if (parsed == null) {
      setState(() => _error = l10n.validationAmountRequired);
      return;
    }
    if (parsed.milli < 0) {
      setState(() => _error = l10n.validationAmountPositive);
      return;
    }
    final result = await ref
        .read(savingsRepositoryProvider)
        .review(widget.period.id, parsed);
    if (!mounted || !result.report(context)) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.lg,
        0,
        Gap.lg,
        MediaQuery.viewInsetsOf(context).bottom + Gap.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.savingsReviewTitle(widget.monthLabel),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Gap.xs),
          Text(
            l10n.savingsReviewHint,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Gap.lg),
          AppTextField(
            controller: _controller,
            label: l10n.savingsSaved,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            errorText: _error,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: Gap.lg),
          FilledButton(onPressed: _submit, child: Text(l10n.actionSave)),
        ],
      ),
    );
  }
}
