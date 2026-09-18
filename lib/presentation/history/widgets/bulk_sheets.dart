import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/common/category_icons.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/providers/analytics_providers.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

/// Sheets behind the history selection bar's re-categorize and tag actions.

/// Category picker for a bulk re-categorize. Pops with the chosen [Category];
/// the repository applies it only to rows whose type matches the category's
/// kind, so the sheet can offer both kinds without guarding here.
class BulkCategorySheet extends ConsumerWidget {
  const BulkCategorySheet({super.key});

  static Future<Category?> show(BuildContext context) =>
      showModalBottomSheet<Category>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const BulkCategorySheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
        children: <Widget>[
          Text(l10n.bulkPickCategory, style: theme.textTheme.titleLarge),
          const SizedBox(height: Gap.sm),
          for (final kind in CategoryKind.values) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(top: Gap.md, bottom: Gap.xs),
              child: Text(
                switch (kind) {
                  CategoryKind.expense => l10n.txnExpense,
                  CategoryKind.income => l10n.txnIncome,
                },
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final category in categories.where((c) => c.kind == kind))
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(category.color).withValues(alpha: 0.14),
                    borderRadius:
                        const BorderRadius.all(Radius.circular(Gap.radiusSm)),
                  ),
                  child: Icon(
                    CategoryIcons.resolve(category.icon),
                    size: 18,
                    color: Color(category.color),
                  ),
                ),
                title: Text(category.name),
                onTap: () => Navigator.of(context).pop(category),
              ),
          ],
        ],
      ),
    );
  }
}

/// Tag input for a bulk tag. Pops with the raw text; the repository does the
/// trimming/lowercasing, so what the user typed is what comes back.
class BulkTagSheet extends ConsumerStatefulWidget {
  const BulkTagSheet({super.key});

  static Future<String?> show(BuildContext context) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const BulkTagSheet(),
      );

  @override
  ConsumerState<BulkTagSheet> createState() => _BulkTagSheetState();
}

class _BulkTagSheetState extends ConsumerState<BulkTagSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final existing = ref.watch(allTagsProvider).value ?? const <String>[];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.bulkTagHint,
                prefixIcon: const Icon(Icons.label_outline),
              ),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
            if (existing.isNotEmpty) ...<Widget>[
              const SizedBox(height: Gap.md),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: <Widget>[
                  for (final tag in existing)
                    ActionChip(
                      label: Text(tag),
                      onPressed: () {
                        _controller.text = tag;
                        Navigator.of(context).pop(tag);
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: Gap.md),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_controller.text),
              child: Text(l10n.actionSave),
            ),
          ],
        ),
      ),
    );
  }
}
