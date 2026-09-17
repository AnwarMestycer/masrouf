import 'package:flutter/material.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/money/money_formatter.dart';
import 'package:masrouf/core/theme/app_colors.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/l10n/app_localizations.dart';
import 'package:masrouf/presentation/common/category_icons.dart';

/// The large running amount at the top of the add screen.
///
/// Renders the typed digits directly rather than formatting a [Money], so a
/// half-typed `2,` shows the separator the user just pressed instead of snapping
/// back to `2`.
class AmountDisplay extends StatelessWidget {
  const AmountDisplay({
    required this.whole,
    required this.fraction,
    required this.symbol,
    required this.separator,
    required this.type,
    super.key,
  });

  final String whole;

  /// Null until the decimal key is pressed.
  final String? fraction;

  final String symbol;
  final String separator;
  final TxnType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = theme.money;
    final color = switch (type) {
      TxnType.income => money.income,
      TxnType.expense => money.expense,
      TxnType.transfer => money.transfer,
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              fraction == null ? whole : '$whole$separator$fraction',
              maxLines: 1,
              style: theme.textTheme.displayMedium?.copyWith(color: color),
            ),
          ),
        ),
        const SizedBox(width: Gap.sm),
        Text(
          symbol,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Income / expense / transfer selector.
class TypeSelector extends StatelessWidget {
  const TypeSelector({
    required this.value,
    required this.onChanged,
    required this.l10n,
    super.key,
  });

  final TxnType value;
  final ValueChanged<TxnType> onChanged;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TxnType>(
      segments: <ButtonSegment<TxnType>>[
        ButtonSegment<TxnType>(
          value: TxnType.expense,
          label: Text(l10n.txnExpense),
          icon: const Icon(Icons.south_west, size: 18),
        ),
        ButtonSegment<TxnType>(
          value: TxnType.income,
          label: Text(l10n.txnIncome),
          icon: const Icon(Icons.north_east, size: 18),
        ),
        ButtonSegment<TxnType>(
          value: TxnType.transfer,
          label: Text(l10n.txnTransfer),
          icon: const Icon(Icons.swap_horiz, size: 18),
        ),
      ],
      selected: <TxnType>{value},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

/// Horizontally scrolling category picker, recent-first.
///
/// A [ListView.builder] rather than a Wrap: the list is bounded by the number of
/// categories but the builder keeps offscreen chips unbuilt, which is what stops
/// the strip from costing a frame when the sheet opens.
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<Category> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        itemCount: categories.length,
        // Keys let Flutter reuse element state when the recent-first ordering
        // reshuffles after a save, instead of rebuilding every chip.
        separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
        itemBuilder: (context, index) {
          final category = categories[index];
          return _CategoryChip(
            key: ValueKey<String>(category.id),
            category: category,
            selected: category.id == selectedId,
            onTap: () => onSelected(category),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(category.color);

    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(
        CategoryIcons.resolve(category.icon),
        size: 18,
        color: selected ? theme.colorScheme.onPrimaryContainer : color,
      ),
      label: Text(category.name),
      selectedColor: color.withValues(alpha: 0.22),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}

/// Account selector. Preselects the last account used, so the common case needs
/// no interaction at all.
class AccountStrip extends StatelessWidget {
  const AccountStrip({
    required this.accounts,
    required this.selectedId,
    required this.onSelected,
    required this.formatter,
    super.key,
  });

  final List<AccountWithBalance> accounts;
  final String? selectedId;
  final ValueChanged<AccountWithBalance> onSelected;
  final MoneyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        itemCount: accounts.length,
        separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
        itemBuilder: (context, index) {
          final entry = accounts[index];
          final selected = entry.id == selectedId;
          return ChoiceChip(
            key: ValueKey<String>(entry.id),
            selected: selected,
            onSelected: (_) => onSelected(entry),
            avatar: Icon(
              switch (entry.account.type) {
                AccountType.cash => AccountIcons.cash,
                AccountType.bank => AccountIcons.bank,
                AccountType.savings => AccountIcons.savings,
                AccountType.foreign => AccountIcons.foreign,
              },
              size: 18,
            ),
            label: Text(
              '${entry.account.name} · ${formatter.formatCompact(entry.balance)}',
            ),
          );
        },
      ),
    );
  }
}

/// Date row: today and yesterday as one-tap chips, anything else via the picker.
///
/// Those two cover almost every entry, and making them chips means the common
/// case never opens a dialog.
class DateRow extends StatelessWidget {
  const DateRow({
    required this.date,
    required this.onChanged,
    required this.l10n,
    super.key,
  });

  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().dateOnly;
    final yesterday = today.subtract(const Duration(days: 1));

    return Row(
      children: <Widget>[
        const SizedBox(width: Gap.lg),
        ChoiceChip(
          selected: date.isSameDayAs(today),
          onSelected: (_) => onChanged(today),
          label: Text(l10n.actionToday),
        ),
        const SizedBox(width: Gap.sm),
        ChoiceChip(
          selected: date.isSameDayAs(yesterday),
          onSelected: (_) => onChanged(yesterday),
          label: Text(l10n.actionYesterday),
        ),
        const SizedBox(width: Gap.sm),
        ActionChip(
          avatar: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(
            date.isSameDayAs(today) || date.isSameDayAs(yesterday)
                ? l10n.txnDate
                : '${date.day}/${date.month}/${date.year}',
          ),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(today.year - 5),
              // No future-dated entries: this is a ledger of what happened, and
              // a future row would corrupt "this month" totals.
              lastDate: today,
            );
            if (picked != null) onChanged(picked);
          },
        ),
        const SizedBox(width: Gap.lg),
      ],
    );
  }
}

/// A dimmed placeholder shown when there is nothing to display.
class EmptyHint extends StatelessWidget {
  const EmptyHint({required this.icon, required this.title, this.subtitle, super.key});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 44, color: theme.colorScheme.outline),
            const SizedBox(height: Gap.md),
            Text(title, style: theme.textTheme.titleMedium),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: Gap.xs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Money text with the semantic colour for its direction.
class MoneyText extends StatelessWidget {
  const MoneyText({
    required this.amount,
    required this.formatter,
    this.type,
    this.style,
    this.signed = false,
    super.key,
  });

  final Money amount;
  final MoneyFormatter formatter;
  final TxnType? type;
  final TextStyle? style;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = theme.money;
    final color = switch (type) {
      TxnType.income => money.income,
      TxnType.expense => money.expense,
      TxnType.transfer => money.transfer,
      null => amount.isNegative ? money.expense : null,
    };

    return Text(
      signed ? formatter.formatSigned(amount) : formatter.format(amount),
      style: (style ?? theme.textTheme.titleMedium)?.copyWith(color: color),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Free-text tags for a transaction.
///
/// A second axis of grouping next to categories: a transaction is filed under
/// exactly one category, but "ramadan" or "trip-tunis" cuts across all of them.
/// The column, the converter and the search predicate already existed — this is
/// the input that was missing, so nothing could ever put a tag in.
class TagInput extends StatefulWidget {
  const TagInput({
    required this.tags,
    required this.onChanged,
    required this.l10n,
    super.key,
  });

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  final L10n l10n;

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Normalised so "Gym", "gym " and "gym" are one tag rather than three.
  void _commit() {
    final tag = _controller.text.trim().toLowerCase();
    _controller.clear();
    if (tag.isEmpty || widget.tags.contains(tag)) return;
    widget.onChanged(<String>[...widget.tags, tag]);
  }

  void _remove(String tag) => widget.onChanged(
        widget.tags.where((t) => t != tag).toList(growable: false),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: widget.l10n.txnTagsHint,
              prefixIcon: const Icon(Icons.label_outline),
              isDense: true,
            ),
            // Committed on blur as well as on submit, so a tag typed and then
            // dismissed is not silently dropped.
            onSubmitted: (_) => _commit(),
            onTapOutside: (_) {
              _commit();
              FocusManager.instance.primaryFocus?.unfocus();
            },
          ),
          if (widget.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: Gap.xs),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.xs,
              children: <Widget>[
                for (final tag in widget.tags)
                  InputChip(
                    label: Text(tag),
                    onDeleted: () => _remove(tag),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
