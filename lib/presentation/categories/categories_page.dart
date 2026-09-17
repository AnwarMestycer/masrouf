import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/core/ids.dart';
import 'package:masrouf/core/theme/app_colors.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/common/category_icons.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/domain/entities/budget.dart';
import 'package:masrouf/presentation/providers/analytics_providers.dart';
import 'package:masrouf/presentation/common/feedback.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

/// Category management, split by kind.
class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.categoriesTitle),
          bottom: TabBar(
            tabs: <Widget>[
              Tab(text: l10n.categoriesKindExpense),
              Tab(text: l10n.categoriesKindIncome),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            _CategoryList(kind: CategoryKind.expense),
            _CategoryList(kind: CategoryKind.income),
          ],
        ),
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.kind});

  final CategoryKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final categories = ref.watch(categoriesOfKindProvider(kind)).value;
    if (categories == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-${kind.wire}',
        onPressed: () => CategoryEditor.show(context, kind, null),
        icon: const Icon(Icons.add),
        label: Text(l10n.categoriesAdd),
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: categories.length,
        onReorderItem: (oldIndex, newIndex) {
          final ids = categories.map((c) => c.id).toList();
          ids.insert(newIndex, ids.removeAt(oldIndex));
          ref.read(categoryRepositoryProvider).reorder(ids);
        },
        itemBuilder: (context, index) {
          final category = categories[index];
          final color = AppColors.resolveCategoryColor(
            category.color,
            Theme.of(context).brightness,
          );
          return ListTile(
            key: ValueKey<String>(category.id),
            onTap: () => CategoryEditor.show(context, kind, category),
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.18),
              child: Icon(
                CategoryIcons.resolve(category.icon),
                size: 20,
                color: color,
              ),
            ),
            title: Text(category.name),
            trailing: const Icon(Icons.drag_handle),
          );
        },
      ),
    );
  }
}

/// Create/edit sheet for a category, including its icon and colour.
class CategoryEditor extends ConsumerStatefulWidget {
  const CategoryEditor({required this.kind, required this.category, super.key});

  final CategoryKind kind;
  final Category? category;

  static Future<void> show(
    BuildContext context,
    CategoryKind kind,
    Category? category,
  ) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: CategoryEditor(kind: kind, category: category),
        ),
      );

  @override
  ConsumerState<CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends ConsumerState<CategoryEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.category?.name ?? '');
  late String _icon = widget.category?.icon ?? 'category';
  late int _color =
      widget.category?.color ?? AppColors.categoryPalette.first.toARGB32();
  final TextEditingController _budget = TextEditingController();
  String? _nameError;
  String? _budgetError;

  /// The cap this sheet opened with, so saving can tell "left blank" from
  /// "cleared", and only write when the user actually changed something.
  Budget? _existingBudget;
  bool _budgetLoaded = false;

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  /// Loads the existing cap once the budget list is available.
  ///
  /// Read from the already-watched list rather than a fresh query: the sheet
  /// opens over a screen that is usually watching budgets anyway, and a second
  /// round trip would leave the field briefly blank on top of a real value —
  /// which reads as "there is no cap" at exactly the wrong moment.
  /// [budgets] is null until the stream has emitted. Latching on that null —
  /// treating "not loaded yet" as "no budgets" — is what left the field blank on
  /// top of a real cap, which would then have been read as a deliberate clear
  /// and removed the budget on save.
  void _loadBudget(List<Budget>? budgets) {
    if (_budgetLoaded || budgets == null || widget.category == null) return;
    _budgetLoaded = true;
    for (final budget in budgets) {
      if (budget.categoryId == widget.category!.id) {
        _existingBudget = budget;
        _budget.text = budget.amount.toDecimalString();
        return;
      }
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = context.l10n.validationNameRequired);
      return;
    }

    final category = Category(
      id: widget.category?.id ?? Ids.newId(),
      name: _name.text.trim(),
      kind: widget.kind,
      icon: _icon,
      color: _color,
      sortOrder: widget.category?.sortOrder ?? 999,
      isDefault: widget.category?.isDefault ?? false,
      updatedAt: DateTime.now(),
    );

    final base = ref.read(baseCurrencyProvider);
    final text = _budget.text.trim();
    final cap = text.isEmpty ? null : Money.tryParse(text, base);
    if (text.isNotEmpty && (cap == null || !cap.isPositive)) {
      setState(() => _budgetError = context.l10n.validationAmountPositive);
      return;
    }

    final repository = ref.read(categoryRepositoryProvider);
    final result = widget.category == null
        ? await repository.create(category)
        : await repository.update(category);
    if (!mounted || !result.report(context)) return;

    // The cap is written after the category, because a budget references a
    // category that has to exist first — and it is skipped entirely when the
    // field was left as it was found, so saving an unrelated edit does not
    // rewrite a budget's updatedAt and lose a newer one from another device.
    final budgets = ref.read(budgetRepositoryProvider);
    if (cap != null && cap != _existingBudget?.amount) {
      await budgets.setForCategory(category.id, cap);
    } else if (cap == null && _existingBudget != null) {
      await budgets.remove(_existingBudget!.id);
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.actionDelete),
        // Deleting a category is the one destructive action here that is not
        // trivially undoable from a snackbar, so it confirms — and says exactly
        // what happens to the transactions that referenced it.
        content: Text(l10n.categoriesDeleteWarning),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(categoryRepositoryProvider).delete(widget.category!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brightness = Theme.of(context).brightness;
    _loadBudget(ref.watch(budgetsProvider).value);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.category == null ? l10n.categoriesAdd : l10n.actionEdit,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Gap.lg),
            TextField(
              controller: _name,
              autofocus: widget.category == null,
              decoration: InputDecoration(
                labelText: l10n.categoriesName,
                errorText: _nameError,
              ),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            if (widget.kind == CategoryKind.expense) ...<Widget>[
              const SizedBox(height: Gap.lg),
              TextField(
                controller: _budget,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.budgetCap,
                  // Optional, and says so: most categories never get a cap, and
                  // an unlabelled empty amount field reads as a required one.
                  hintText: l10n.budgetOptional,
                  suffixText: ref.watch(baseCurrencyProvider).symbol,
                  errorText: _budgetError,
                ),
                onChanged: (_) {
                  if (_budgetError != null) {
                    setState(() => _budgetError = null);
                  }
                },
              ),
            ],
            const SizedBox(height: Gap.lg),
            Text(l10n.categoriesColor,
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: Gap.sm),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: <Widget>[
                for (final color in AppColors.categoryPalette)
                  _Swatch(
                    color: AppColors.resolveCategoryColor(
                      color.toARGB32(),
                      brightness,
                    ),
                    selected: _color == color.toARGB32(),
                    onTap: () => setState(() => _color = color.toARGB32()),
                  ),
              ],
            ),
            const SizedBox(height: Gap.lg),
            Text(l10n.categoriesIcon,
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: Gap.sm),
            SizedBox(
              height: 108,
              child: GridView.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: Gap.sm,
                  crossAxisSpacing: Gap.sm,
                ),
                itemCount: CategoryIcons.keys.length,
                itemBuilder: (context, index) {
                  final key = CategoryIcons.keys[index];
                  final selected = key == _icon;
                  return InkWell(
                    onTap: () => setState(() => _icon = key),
                    borderRadius:
                        const BorderRadius.all(Radius.circular(Gap.radiusSm)),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(Gap.radiusSm),
                        ),
                      ),
                      child: Icon(CategoryIcons.resolve(key), size: 20),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: Gap.xl),
            FilledButton(onPressed: _save, child: Text(l10n.actionSave)),
            if (widget.category != null) ...<Widget>[
              const SizedBox(height: Gap.sm),
              TextButton.icon(
                onPressed: _delete,
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

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: selected
                ? Border.all(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 2.5,
                  )
                : null,
          ),
          child: selected
              ? const Icon(Icons.check, size: 18, color: Colors.white)
              : null,
        ),
      );
}
