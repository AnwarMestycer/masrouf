import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/l10n/app_localizations.dart';
import 'package:masrouf/presentation/add/controllers/fast_add_controller.dart';
import 'package:masrouf/presentation/add/widgets/add_widgets.dart';
import 'package:masrouf/presentation/add/widgets/numpad.dart';
import 'package:masrouf/presentation/common/feedback.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

/// The fast-add screen: amount first, then one tap for category, then save.
///
/// Every element below the amount is a chip strip rather than a dropdown or a
/// dialog, so the whole flow is reachable one-handed without ever leaving the
/// screen. The write is optimistic — there is no spinner, because the repository
/// commits locally and the sync happens afterwards.
class FastAddPage extends ConsumerStatefulWidget {
  const FastAddPage({this.editingId, super.key});

  final String? editingId;

  @override
  ConsumerState<FastAddPage> createState() => _FastAddPageState();
}

class _FastAddPageState extends ConsumerState<FastAddPage> {
  final _note = TextEditingController();
  bool _initialised = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Seeds the controller once the async defaults are available.
  ///
  /// Done here rather than in the controller's `build` because it depends on the
  /// account list, which arrives a frame or two later on a cold start; seeding in
  /// `build` would either block the first frame or be overwritten.
  Future<void> _initialise(List<AccountWithBalance> accounts) async {
    if (_initialised || accounts.isEmpty) return;
    _initialised = true;

    final controller = ref.read(fastAddControllerProvider.notifier);

    if (widget.editingId != null) {
      final txn = await ref
          .read(transactionRepositoryProvider)
          .getById(widget.editingId!);
      if (txn != null && mounted) {
        controller.loadForEdit(txn);
        _note.text = txn.note ?? '';
        return;
      }
    }

    final lastId =
        await ref.read(settingsRepositoryProvider).lastUsedAccountId();
    final preferred = accounts.firstWhere(
      (a) => a.id == lastId,
      orElse: () => accounts.first,
    );
    if (!mounted) return;

    controller.setAccount(
      preferred.id,
      preferred.account.currency,
      rateToBaseFor(
        preferred.account.currency,
        ref.read(baseCurrencyProvider),
        ref.read(ratesToBaseProvider),
      ),
    );
  }

  Future<void> _save() async {
    final result = await ref.read(fastAddControllerProvider.notifier).save();
    if (!mounted) return;
    final saved = result.report(context);

    if (saved) {
      unawaited(HapticFeedback.lightImpact());
      final l10n = context.l10n;
      context.pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.txnSaved),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(fastAddControllerProvider);
    final controller = ref.read(fastAddControllerProvider.notifier);
    final formatter = ref.watch(moneyFormatterProvider);
    final accounts = ref.watch(accountsProvider).value ?? const <AccountWithBalance>[];
    final base = ref.watch(baseCurrencyProvider);

    // The rate table is read asynchronously, so on a cold start the account is
    // chosen before its rate exists. Adopt the rate the moment it lands rather
    // than leaving the entry blocked until the account is re-tapped.
    ref.listen<Map<String, double>?>(ratesToBaseProvider, (previous, next) {
      final current = ref.read(fastAddControllerProvider);
      controller.setRate(rateToBaseFor(current.currency, base, next));
    });

    // Fire-and-forget: safe to call every build because it self-guards.
    unawaited(_initialise(accounts));

    final categoriesAsync = state.type.isTransfer
        ? null
        : ref.watch(
            quickPickCategoriesProvider(
              state.type == TxnType.income
                  ? CategoryKind.income
                  : CategoryKind.expense,
            ),
          );

    final separator = ref.watch(localeCodeProvider) == 'en' ? '.' : ',';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: context.pop,
          tooltip: l10n.actionCancel,
        ),
        title: Text(state.isEditing ? l10n.actionEdit : l10n.navAdd),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.lg),
              child: TypeSelector(
                value: state.type,
                onChanged: controller.setType,
                l10n: l10n,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
              child: AmountDisplay(
                whole: state.displayWhole,
                fraction: state.displayFraction,
                symbol: state.currency.symbol,
                separator: separator,
                type: state.type,
              ),
            ),
            const SizedBox(height: Gap.lg),

            // The scrollable middle keeps the numpad pinned to the bottom even on
            // a short screen, so the keys never move between entries.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                children: <Widget>[
                  if (categoriesAsync != null)
                    categoriesAsync.when(
                      data: (categories) => categories.isEmpty
                          ? const SizedBox.shrink()
                          : CategoryChips(
                              categories: categories,
                              selectedId: state.categoryId,
                              onSelected: (c) => controller.setCategory(c.id),
                            ),
                      loading: () => const SizedBox(height: 44),
                      error: (_, _) => const SizedBox(height: 44),
                    ),
                  const SizedBox(height: Gap.md),
                  AccountStrip(
                    accounts: accounts,
                    selectedId: state.accountId,
                    formatter: formatter,
                    onSelected: (entry) => controller.setAccount(
                      entry.id,
                      entry.account.currency,
                      rateToBaseFor(
                        entry.account.currency,
                        base,
                        ref.read(ratesToBaseProvider),
                      ),
                    ),
                  ),
                  if (state.type.isTransfer) ...<Widget>[
                    const SizedBox(height: Gap.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                      child: Text(
                        '→ ${l10n.txnAccount}',
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(height: Gap.xs),
                    AccountStrip(
                      accounts: accounts
                          .where((a) => a.id != state.accountId)
                          .toList(growable: false),
                      selectedId: state.transferAccountId,
                      formatter: formatter,
                      onSelected: (entry) =>
                          controller.setTransferAccount(entry.id),
                    ),
                  ],
                  const SizedBox(height: Gap.md),
                  DateRow(
                    date: state.date,
                    onChanged: controller.setDate,
                    l10n: l10n,
                  ),
                  const SizedBox(height: Gap.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                    child: TextField(
                      controller: _note,
                      onChanged: controller.setNote,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: l10n.txnNoteHint,
                        prefixIcon: const Icon(Icons.notes_outlined),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  TagInput(
                    tags: state.tags,
                    onChanged: controller.setTags,
                    l10n: l10n,
                  ),
                ],
              ),
            ),

            Numpad(
              onDigit: controller.pressDigit,
              onDecimal: controller.pressDecimal,
              onBackspace: controller.backspace,
              onClear: controller.clearAmount,
              decimalSeparator: separator,
            ),
            if (state.rateMissing)
              _MissingRateNotice(currency: state.currency, l10n: l10n),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
              child: FilledButton.icon(
                onPressed: state.canSave ? _save : null,
                icon: const Icon(Icons.check),
                label: Text(l10n.actionSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Why the save button is disabled for a foreign-currency account.
///
/// Stated rather than left to a greyed-out button: the amount is fine, the
/// category is fine, and without this the screen looks broken. Saving anyway
/// would freeze a 1.0 rate onto the row, and nothing downstream could ever tell
/// that the number was wrong.
class _MissingRateNotice extends StatelessWidget {
  const _MissingRateNotice({required this.currency, required this.l10n});

  final Currency currency;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.error_outline,
            size: 18,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.txnRateMissing(currency.code),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
                Text(
                  l10n.txnRateMissingHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
