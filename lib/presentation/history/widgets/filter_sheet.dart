import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/history/history_controller.dart';
import 'package:masrouf/presentation/providers/analytics_providers.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

/// Filter controls for the history list.
///
/// A bottom sheet rather than a separate route: filtering is a refinement of the
/// list behind it, and keeping that list visible makes the effect of each toggle
/// obvious.
class FilterSheet extends ConsumerWidget {
  const FilterSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const FilterSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final filter = ref.watch(historyFilterProvider);
    final notifier = ref.read(historyFilterProvider.notifier);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final tags = ref.watch(allTagsProvider).value ?? const <String>[];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.historyFilter,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (filter.isActive)
                TextButton(
                  onPressed: notifier.clear,
                  child: Text(l10n.historyClearFilters),
                ),
            ],
          ),
          const SizedBox(height: Gap.md),
          _Section(title: l10n.txnAll),
          Wrap(
            spacing: Gap.sm,
            children: <Widget>[
              for (final type in TxnType.values)
                FilterChip(
                  label: Text(type.localise(l10n)),
                  selected: filter.types.contains(type),
                  onSelected: (_) => notifier.toggleType(type),
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          _Section(title: l10n.txnAccount),
          Wrap(
            spacing: Gap.sm,
            children: <Widget>[
              for (final entry in accounts)
                FilterChip(
                  label: Text(entry.account.name),
                  selected: filter.accountIds.contains(entry.id),
                  onSelected: (_) => notifier.toggleAccount(entry.id),
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          _Section(title: l10n.txnCategory),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.xs,
            children: <Widget>[
              for (final category in categories)
                FilterChip(
                  label: Text(category.name),
                  selected: filter.categoryIds.contains(category.id),
                  onSelected: (_) => notifier.toggleCategory(category.id),
                ),
            ],
          ),
          // Only shown once something is tagged: an empty facet is a dead
          // section that makes the sheet look broken.
          if (tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: Gap.lg),
            _Section(title: l10n.txnTags),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.xs,
              children: <Widget>[
                for (final tag in tags)
                  FilterChip(
                    label: Text(tag),
                    selected: filter.tags.contains(tag),
                    onSelected: (_) => notifier.toggleTag(tag),
                  ),
              ],
            ),
          ],
          const SizedBox(height: Gap.lg),
          _Section(title: l10n.txnDate),
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range_outlined),
            label: Text(
              filter.from == null && filter.to == null
                  ? l10n.historyFilterAll
                  : '${_short(filter.from)} — ${_short(filter.to)}',
            ),
            onPressed: () async {
              final now = DateTime.now();
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 5),
                lastDate: now,
                initialDateRange: filter.from != null && filter.to != null
                    ? DateTimeRange(start: filter.from!, end: filter.to!)
                    : null,
              );
              notifier.setRange(range?.start, range?.end);
            },
          ),
          const SizedBox(height: Gap.lg),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionDone),
          ),
        ],
      ),
    );
  }

  static String _short(DateTime? date) =>
      date == null ? '…' : '${date.day}/${date.month}';
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.sm),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
}
