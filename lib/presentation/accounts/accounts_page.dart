import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/core/ids.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/add/widgets/add_widgets.dart';
import 'package:masrouf/presentation/common/category_icons.dart';
import 'package:masrouf/presentation/common/feedback.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

/// Accounts and their live balances.
class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final formatter = ref.watch(moneyFormatterProvider);
    final accounts = ref.watch(accountsProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AccountEditor.show(context, ref, null),
        icon: const Icon(Icons.add),
        label: Text(l10n.accountsAdd),
      ),
      body: accounts == null
          ? const Center(child: CircularProgressIndicator())
          : accounts.isEmpty
              ? EmptyHint(
                  icon: Icons.account_balance_wallet_outlined,
                  title: l10n.accountsTitle,
                  subtitle: l10n.accountsAdd,
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: accounts.length,
                  // onReorderItem, unlike the deprecated onReorder, already
                  // accounts for the dragged item's removal, so newIndex needs
                  // no off-by-one correction.
                  onReorderItem: (oldIndex, newIndex) {
                    final ids = accounts.map((a) => a.id).toList();
                    ids.insert(newIndex, ids.removeAt(oldIndex));
                    ref.read(accountRepositoryProvider).reorder(ids);
                  },
                  itemBuilder: (context, index) {
                    final entry = accounts[index];
                    return _AccountTile(
                      key: ValueKey<String>(entry.id),
                      entry: entry,
                      subtitle: entry.account.type.localise(l10n),
                      balance: formatter.format(entry.balance),
                      onTap: () =>
                          AccountEditor.show(context, ref, entry.account),
                    );
                  },
                ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.entry,
    required this.subtitle,
    required this.balance,
    required this.onTap,
    super.key,
  });

  final AccountWithBalance entry;
  final String subtitle;
  final String balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: Icon(
        switch (entry.account.type) {
          AccountType.cash => AccountIcons.cash,
          AccountType.bank => AccountIcons.bank,
          AccountType.savings => AccountIcons.savings,
          AccountType.foreign => AccountIcons.foreign,
        },
      ),
      title: Text(entry.account.name),
      subtitle: Text('$subtitle · ${entry.account.currency.code}'),
      trailing: Text(
        balance,
        style: theme.textTheme.titleSmall?.copyWith(
          color: entry.balance.isNegative ? theme.colorScheme.error : null,
        ),
      ),
    );
  }
}

/// Create/edit sheet for an account.
class AccountEditor extends ConsumerStatefulWidget {
  const AccountEditor({required this.account, super.key});

  final Account? account;

  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    Account? account,
  ) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => Padding(
          // Lifts the sheet above the keyboard so the fields stay visible.
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: AccountEditor(account: account),
        ),
      );

  @override
  ConsumerState<AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends ConsumerState<AccountEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.account?.name ?? '');
  late final TextEditingController _opening = TextEditingController(
    text: widget.account == null
        ? ''
        : widget.account!.openingBalance.toDecimalString(),
  );

  late AccountType _type = widget.account?.type ?? AccountType.cash;
  late Currency _currency = widget.account?.currency ?? Currency.tnd;
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  /// Deleting an account silently changed every balance on screen: no
  /// confirmation, no undo, and no check for the transactions still pointing at
  /// it. Categories got a dialog for exactly this reason; the reasoning simply
  /// was never carried across.
  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.actionDelete),
        content: Text(l10n.accountsDeleteWarning),
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

    final result =
        await ref.read(accountRepositoryProvider).delete(widget.account!.id);
    if (!mounted || !result.report(context)) return;
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = context.l10n.validationNameRequired);
      return;
    }
    final opening =
        Money.tryParse(_opening.text, _currency) ?? Money.zero(_currency);

    final account = Account(
      id: widget.account?.id ?? Ids.newId(),
      name: _name.text.trim(),
      type: _type,
      currency: _currency,
      openingBalance: opening,
      sortOrder: widget.account?.sortOrder ?? 999,
      archived: widget.account?.archived ?? false,
      updatedAt: DateTime.now(),
    );

    final repository = ref.read(accountRepositoryProvider);
    final result = widget.account == null
        ? await repository.create(account)
        : await repository.update(account);

    if (!mounted || !result.report(context)) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.account == null ? l10n.accountsAdd : l10n.actionEdit,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: Gap.lg),
          TextField(
            controller: _name,
            autofocus: widget.account == null,
            decoration: InputDecoration(
              labelText: l10n.accountsName,
              errorText: _nameError,
            ),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: Gap.lg),
          Wrap(
            spacing: Gap.sm,
            children: <Widget>[
              for (final type in AccountType.values)
                ChoiceChip(
                  label: Text(type.localise(l10n)),
                  selected: _type == type,
                  onSelected: (_) => setState(() => _type = type),
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Wrap(
            spacing: Gap.sm,
            children: <Widget>[
              for (final currency in Currency.known)
                ChoiceChip(
                  label: Text(currency.code),
                  selected: _currency == currency,
                  onSelected: (_) => setState(() => _currency = currency),
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          TextField(
            controller: _opening,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.accountsOpeningBalance,
              suffixText: _currency.symbol,
            ),
          ),
          const SizedBox(height: Gap.xl),
          FilledButton(onPressed: _save, child: Text(l10n.actionSave)),
          if (widget.account != null) ...<Widget>[
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
    );
  }
}
