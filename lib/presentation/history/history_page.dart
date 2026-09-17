import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:masrouf/core/config/app_config.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/router/routes.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/l10n/app_localizations.dart';
import 'package:masrouf/presentation/add/widgets/add_widgets.dart';
import 'package:masrouf/presentation/common/feedback.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/common/widgets/txn_tile.dart';
import 'package:masrouf/presentation/history/history_controller.dart';
import 'package:masrouf/presentation/history/widgets/filter_sheet.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

/// Searchable, filterable, lazily paged ledger.
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final _scroll = ScrollController();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  /// Loads the next page while the user is still 600px from the end, so the new
  /// rows are already in place by the time the scroll reaches them.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final remaining = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 600) {
      ref.read(historyControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _delete(TxnView view) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(transactionRepositoryProvider);

    final deleted = await repository.delete(view.id);
    if (!mounted) return;
    // Announcing "Deleted" for a delete that failed is worse than saying
    // nothing: the row is still there and the user has been told it is not.
    if (!deleted.report(context)) return;

    // Undo rather than a confirmation dialog: deleting is instantly reversible,
    // and a dialog on every delete is a tax on the common case.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.txnDeleted),
          duration: AppConfig.undoWindow,
          action: SnackBarAction(
            label: l10n.txnUndo,
            onPressed: () async {
              final restored = await repository.restore(view.id);
              if (mounted) restored.report(context);
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final formatter = ref.watch(moneyFormatterProvider);
    final base = ref.watch(baseCurrencyProvider);
    final locale = ref.watch(localeCodeProvider);
    final filter = ref.watch(historyFilterProvider);
    final state = ref.watch(historyControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.historyTitle),
        actions: <Widget>[
          IconButton(
            onPressed: () => FilterSheet.show(context),
            tooltip: l10n.historyFilter,
            icon: Badge(
              isLabelVisible: filter.activeFacetCount > 0,
              label: Text('${filter.activeFacetCount}'),
              child: const Icon(Icons.tune),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
            child: TextField(
              controller: _search,
              onChanged: ref.read(historyFilterProvider.notifier).search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.historySearchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          ref.read(historyFilterProvider.notifier).search('');
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyHint(
          icon: Icons.error_outline,
          title: l10n.errorUnknown,
          subtitle: error.toString(),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return EmptyHint(
              icon: filter.isActive
                  ? Icons.filter_alt_off_outlined
                  : Icons.receipt_long_outlined,
              title: filter.isActive ? l10n.historyNoResults : l10n.txnEmpty,
              subtitle: filter.isActive ? null : l10n.txnEmptyHint,
            );
          }

          final rows = _buildRows(page.items, base);

          return ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: 96),
            // Bounded item count with a builder: only the visible slice is ever
            // constructed, which is what keeps a multi-thousand-row ledger at
            // 60fps.
            itemCount: rows.length + (page.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= rows.length) {
                return const Padding(
                  padding: EdgeInsets.all(Gap.lg),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final row = rows[index];
              return switch (row) {
                _HeaderRow(:final date, :final total) => DateHeader(
                    label: _dayLabel(date, locale, l10n),
                    trailing: formatter.formatSigned(total),
                  ),
                _TxnRow(:final view) => Dismissible(
                    key: ValueKey<String>(view.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: AlignmentDirectional.centerEnd,
                      padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
                      color: theme.colorScheme.errorContainer,
                      child: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    onDismissed: (_) => _delete(view),
                    child: TxnTile(
                      view: view,
                      formatter: formatter,
                      onTap: () =>
                          context.push('${Routes.editTransaction}/${view.id}'),
                    ),
                  ),
              };
            },
          );
        },
      ),
    );
  }

  /// Flattens the page into headers plus rows, with each day's net precomputed.
  ///
  /// Done once per rebuild rather than inside `itemBuilder`, which would
  /// recompute a day's total every time its header scrolled back into view.
  static List<_Row> _buildRows(List<TxnView> items, Currency base) {
    final rows = <_Row>[];
    DateTime? currentDay;
    var dayTotal = 0;
    var headerIndex = -1;

    for (final view in items) {
      final day = view.txn.date;
      if (currentDay == null || !day.isSameDayAs(currentDay)) {
        if (headerIndex >= 0) {
          rows[headerIndex] =
              _HeaderRow(date: currentDay!, total: Money(dayTotal, base));
        }
        currentDay = day;
        dayTotal = 0;
        headerIndex = rows.length;
        rows.add(_HeaderRow(date: day, total: Money(0, base)));
      }
      if (!view.txn.isTransfer) {
        dayTotal += view.txn.type == TxnType.income
            ? view.baseAmount.milli
            : -view.baseAmount.milli;
      }
      rows.add(_TxnRow(view: view));
    }

    if (headerIndex >= 0 && currentDay != null) {
      rows[headerIndex] =
          _HeaderRow(date: currentDay, total: Money(dayTotal, base));
    }
    return rows;
  }

  static String _dayLabel(DateTime date, String locale, L10n l10n) {
    if (date.isToday) return l10n.actionToday;
    if (date.isYesterday) return l10n.actionYesterday;
    return DateFormat.MMMEd(locale).format(date);
  }
}

sealed class _Row {
  const _Row();
}

final class _HeaderRow extends _Row {
  const _HeaderRow({required this.date, required this.total});

  final DateTime date;
  final Money total;
}

final class _TxnRow extends _Row {
  const _TxnRow({required this.view});

  final TxnView view;
}
