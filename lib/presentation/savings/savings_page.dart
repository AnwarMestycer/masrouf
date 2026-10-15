import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/money/money_formatter.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/savings_plan.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/common/widgets/app_text_field.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';
import 'package:masrouf/presentation/providers/savings_providers.dart';

/// Pay yourself first: commit a share of what arrives, then confirm what was
/// actually set aside.
///
/// The screen leads with the target rather than with progress. Nothing has been
/// saved until it is confirmed, so a progress bar here would be claiming
/// something the ledger does not know.
class SavingsPage extends ConsumerWidget {
  const SavingsPage({super.key});

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final failure = (await ref.read(savingsRepositoryProvider).start())
        .failureOrNull;
    if (failure == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failure.localise(l10n))));
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    SavingsStatus status,
  ) async {
    final saved = await showModalBottomSheet<Money>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ConfirmSheet(status: status),
    );
    if (saved == null || !context.mounted) return;

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final failure =
        (await ref.read(savingsRepositoryProvider).confirm(saved)).failureOrNull;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            failure == null ? l10n.savingsPlanSaved : failure.localise(l10n),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final formatter = ref.watch(moneyFormatterProvider);
    final locale = ref.watch(localeCodeProvider);
    final status = ref.watch(savingsStatusProvider).value;
    final history =
        ref.watch(confirmedPeriodsProvider).value ?? const <SavingsPeriod>[];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.savingsTitle)),
      body: status == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: <Widget>[
                if (!status.hasPlan)
                  _Empty(title: l10n.savingsNoPlan, hint: l10n.savingsNoPlanHint)
                else if (!status.isOpen) ...<Widget>[
                  _Empty(
                    title: l10n.savingsNoPeriod,
                    hint: l10n.savingsNoPeriodHint,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _start(context, ref),
                        child: Text(l10n.savingsStart),
                      ),
                    ),
                  ),
                ] else
                  _OpenPeriod(
                    status: status,
                    formatter: formatter,
                    locale: locale,
                    onConfirm: () => _confirm(context, ref, status),
                  ),

                if (status.ledger.isBehind)
                  _Note(
                    text: '${l10n.savingsOwed}: '
                        '${formatter.format(status.ledger.owed)}',
                    colour: theme.colorScheme.error,
                  )
                else if (status.ledger.ahead.isPositive)
                  _Note(
                    text: l10n.savingsAhead(
                      formatter.format(status.ledger.ahead),
                    ),
                    colour: theme.colorScheme.primary,
                  ),

                if (history.isNotEmpty) ...<Widget>[
                  const Divider(),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xs),
                    child: Text(
                      l10n.savingsHistory,
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ),
                  for (final period in history)
                    _HistoryRow(
                      period: period,
                      formatter: formatter,
                      locale: locale,
                    ),
                ],
              ],
            ),
    );
  }
}

class _OpenPeriod extends StatelessWidget {
  const _OpenPeriod({
    required this.status,
    required this.formatter,
    required this.locale,
    required this.onConfirm,
  });

  final SavingsStatus status;
  final MoneyFormatter formatter;
  final String locale;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final period = status.open!;
    final catchUp = status.ledger.recoveryInstalment();

    return Padding(
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.savingsSince(DateFormat.yMMMd(locale).format(period.startedOn)),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Gap.sm),
          Text(l10n.savingsTarget, style: theme.textTheme.labelMedium),
          Text(
            formatter.format(status.target),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: Gap.md),
          _Line(
            label: l10n.savingsIncomeSoFar,
            value: formatter.format(status.incomeSoFar),
          ),
          _Line(
            label: l10n.savingsCommitment,
            value: formatter.format(status.commitment),
          ),
          if (catchUp.isPositive)
            _Line(
              label: l10n.savingsCatchUp,
              value: formatter.format(catchUp),
              emphasise: true,
            ),
          const SizedBox(height: Gap.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onConfirm,
              child: Text(l10n.savingsConfirm),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.colour});

  final String text;
  final Color colour;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colour),
        ),
      );
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = emphasise ? theme.colorScheme.error : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: colour),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(color: colour),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.period,
    required this.formatter,
    required this.locale,
  });

  final SavingsPeriod period;
  final MoneyFormatter formatter;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final saved = period.saved ?? Money.zero(period.committed.currency);
    final delta = saved - period.committed;

    final (String note, Color colour) = delta.isZero
        ? (l10n.savingsOnTarget, theme.colorScheme.onSurfaceVariant)
        : delta.isPositive
            ? (
                l10n.savingsOverBy(formatter.format(delta)),
                theme.colorScheme.primary,
              )
            : (
                l10n.savingsShortBy(formatter.format(-delta)),
                theme.colorScheme.error,
              );

    return ListTile(
      title: Text(DateFormat.yMMMd(locale).format(period.startedOn)),
      subtitle: Text(note, style: TextStyle(color: colour)),
      trailing: Text(
        formatter.format(saved),
        style: theme.textTheme.titleSmall,
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(Gap.xl),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.savings_outlined,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: Gap.md),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: Gap.xs),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Asks what was actually set aside, prefilled with the target.
///
/// Prefilled because meeting the target is the common case — but editable,
/// because what is typed here is what the ledger believes, not what the plan
/// hoped for.
class _ConfirmSheet extends StatefulWidget {
  const _ConfirmSheet({required this.status});

  final SavingsStatus status;

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<_ConfirmSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.status.target.isZero
        ? ''
        : widget.status.target.toDecimalString(),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    final parsed =
        Money.tryParse(_controller.text, widget.status.target.currency);
    if (parsed == null) {
      setState(() => _error = l10n.validationAmountRequired);
      return;
    }
    if (parsed.milli < 0) {
      setState(() => _error = l10n.validationAmountPositive);
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.lg,
        Gap.lg,
        Gap.lg,
        MediaQuery.viewInsetsOf(context).bottom + Gap.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.savingsConfirmTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: Gap.xs),
          Text(
            l10n.savingsConfirmHint,
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
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              child: Text(l10n.actionSave),
            ),
          ),
        ],
      ),
    );
  }
}
