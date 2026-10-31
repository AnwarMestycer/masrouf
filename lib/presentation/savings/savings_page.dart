import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/money/money_formatter.dart';
import 'package:masrouf/core/theme/app_colors.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/savings_goal.dart';
import 'package:masrouf/domain/entities/savings_plan.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/providers/analytics_providers.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';
import 'package:masrouf/presentation/providers/savings_providers.dart';
import 'package:masrouf/presentation/savings/widgets/goal_editor.dart';
import 'package:masrouf/presentation/savings/widgets/savings_sheets.dart';

/// Pay yourself first, a month at a time, and the goals it feeds.
///
/// Leads with what is still to put aside this month, because that is the
/// number safe-to-spend is holding back. Progress is real transfers into
/// savings accounts, so the bar here and the balance in the account agree.
class SavingsPage extends ConsumerWidget {
  const SavingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final formatter = ref.watch(moneyFormatterProvider);
    final locale = ref.watch(localeCodeProvider);
    final status = ref.watch(savingsStatusProvider).value;
    final goals = ref.watch(goalsProvider).value;
    final history =
        ref.watch(confirmedPeriodsProvider).value ?? const <SavingsPeriod>[];

    if (status == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.savingsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.savingsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: <Widget>[
          if (status.hasPlan)
            _ThisMonth(status: status, formatter: formatter, locale: locale)
          else
            _NoPlan(title: l10n.savingsNoPlan, hint: l10n.savingsNoPlanHint),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => SavingsMoveSheet.show(
                      context,
                      intoSavings: true,
                      amount: status.remaining.isPositive
                          ? status.remaining
                          : null,
                    ),
                    icon: const Icon(Icons.savings_outlined),
                    label: Text(l10n.savingsPutAside),
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        SavingsMoveSheet.show(context, intoSavings: false),
                    icon: const Icon(Icons.undo),
                    label: Text(l10n.savingsTakeBack),
                  ),
                ),
              ],
            ),
          ),
          if (status.ledger.isBehind)
            _Note(
              text: '${l10n.savingsOwed}: '
                  '${formatter.format(status.ledger.owed)}',
              colour: theme.colorScheme.error,
            )
          else if (status.ledger.ahead.isPositive)
            _Note(
              text: l10n.savingsAhead(formatter.format(status.ledger.ahead)),
              colour: theme.colorScheme.primary,
            ),
          const Divider(),
          _Header(
            title: l10n.goalsTitle,
            trailing: TextButton.icon(
              onPressed: () => GoalEditor.show(context, null),
              icon: const Icon(Icons.add),
              label: Text(l10n.goalsAdd),
            ),
          ),
          if (goals == null)
            const SizedBox(height: 80)
          else if (goals.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
              child: Text(
                l10n.goalsEmptyHint,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            for (final goal in goals) _GoalRow(progress: goal),
          if (history.isNotEmpty) ...<Widget>[
            const Divider(),
            _Header(title: l10n.savingsHistory),
            for (final period in history)
              _HistoryRow(period: period, formatter: formatter, locale: locale),
          ],
        ],
      ),
    );
  }
}

class _ThisMonth extends StatelessWidget {
  const _ThisMonth({
    required this.status,
    required this.formatter,
    required this.locale,
  });

  final SavingsStatus status;
  final MoneyFormatter formatter;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final catchUp = status.ledger.recoveryInstalment();
    final target = status.target;
    final ratio =
        target.isZero ? 0.0 : status.savedSoFar.milli / target.milli;
    final done = target.isPositive && !status.remaining.isPositive;

    return Padding(
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            // Only says "since" when the month did not start on the 1st, which
            // happens once: the month an older hand-confirmed period ended in.
            status.startedOn.day == 1
                ? DateFormat.yMMMM(locale).format(status.month.firstDay)
                : l10n.savingsSince(
                    DateFormat.yMMMd(locale).format(status.startedOn),
                  ),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Gap.sm),
          Text(l10n.savingsStillToSave, style: theme.textTheme.labelMedium),
          Text(
            formatter.format(status.remaining),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: Gap.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(Gap.radiusSm),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                done ? theme.money.income : theme.colorScheme.primary,
              ),
            ),
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
          _Line(
            label: l10n.savingsSavedSoFar,
            value: '${formatter.format(status.savedSoFar)} / '
                '${formatter.format(target)}',
          ),
          if (status.aheadThisMonth.isPositive)
            _Line(
              label: l10n.savingsAhead(
                formatter.format(status.aheadThisMonth),
              ),
              value: '',
            ),
        ],
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
              '${progress.accountName.isEmpty ? '' : ' · ${l10n.goalsAccount} ${progress.accountName}'}',
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
                  progress.isReached
                      ? theme.money.income
                      : theme.colorScheme.primary,
                ),
              ),
            ),
            if (progress.goal.targetDate != null ||
                status.isNotEmpty) ...<Widget>[
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
      trailing: IconButton(
        tooltip: l10n.savingsPutAside,
        icon: const Icon(Icons.add_circle_outline),
        onPressed: () => SavingsMoveSheet.show(
          context,
          intoSavings: true,
          goalId: progress.goal.id,
        ),
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

  /// A whole calendar month is named as one. Anything else is an older,
  /// hand-confirmed period and is shown as the days it covered.
  String _label() {
    final end = period.confirmedOn!;
    final month = period.month;
    final isWholeMonth = period.startedOn == month.firstDay &&
        end.year == month.lastDay.year &&
        end.month == month.lastDay.month &&
        end.day == month.lastDay.day;
    if (isWholeMonth) return DateFormat.yMMMM(locale).format(month.firstDay);
    final days = DateFormat.yMMMd(locale);
    return '${days.format(period.startedOn)} – ${days.format(end)}';
  }

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
    final label = _label();

    return ListTile(
      title: Text(label),
      subtitle: Text(
        '${formatter.format(saved)} / ${formatter.format(period.committed)}'
        ' · $note',
        style: TextStyle(color: colour),
      ),
      trailing: TextButton(
        onPressed: () => SavingsReviewSheet.show(context, period, label),
        child: Text(l10n.savingsReview),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.sm, Gap.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          ?trailing,
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

class _NoPlan extends StatelessWidget {
  const _NoPlan({required this.title, required this.hint});

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
