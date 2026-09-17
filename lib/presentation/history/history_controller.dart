import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/core/config/app_config.dart';
import 'package:masrouf/domain/entities/history_filter.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/providers/analytics_providers.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';
import 'package:meta/meta.dart';

/// The history screen's filter.
class HistoryFilterNotifier extends Notifier<HistoryFilter> {
  Timer? _debounce;

  @override
  HistoryFilter build() {
    ref.onDispose(() => _debounce?.cancel());
    return HistoryFilter.none;
  }

  /// Debounced, because every keystroke would otherwise re-run a LIKE scan and
  /// throw away the result before it rendered.
  void search(String term) {
    _debounce?.cancel();
    _debounce = Timer(AppConfig.searchDebounce, () {
      state = state.copyWith(search: term);
    });
  }

  void toggleType(TxnType type) {
    final types = Set<TxnType>.from(state.types);
    if (!types.remove(type)) types.add(type);
    state = state.copyWith(types: types);
  }

  void toggleCategory(String id) {
    final ids = Set<String>.from(state.categoryIds);
    if (!ids.remove(id)) ids.add(id);
    state = state.copyWith(categoryIds: ids);
  }

  void toggleAccount(String id) {
    final ids = Set<String>.from(state.accountIds);
    if (!ids.remove(id)) ids.add(id);
    state = state.copyWith(accountIds: ids);
  }

  void toggleTag(String tag) {
    final tags = Set<String>.from(state.tags);
    if (!tags.remove(tag)) tags.add(tag);
    state = state.copyWith(tags: tags);
  }

  void setRange(DateTime? from, DateTime? to) {
    state = from == null && to == null
        ? state.copyWith(clearDates: true)
        : state.copyWith(from: from, to: to);
  }

  void clear() {
    _debounce?.cancel();
    state = HistoryFilter.none;
  }
}

final historyFilterProvider =
    NotifierProvider<HistoryFilterNotifier, HistoryFilter>(
  HistoryFilterNotifier.new,
);

@immutable
class HistoryPageState {
  const HistoryPageState({
    required this.items,
    required this.hasMore,
    required this.loadingMore,
  });

  final List<TxnView> items;

  /// False once a page came back short, which is the only reliable end signal
  /// without a separate count query.
  final bool hasMore;

  final bool loadingMore;

  HistoryPageState copyWith({
    List<TxnView>? items,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      HistoryPageState(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// Paged history.
///
/// Not a stream: the list is windowed, and re-emitting every loaded page on each
/// ledger write would defeat the paging and rebuild the whole list. Instead it
/// watches a cheap revision counter and reloads only the first page, which is
/// where a new entry lands.
class HistoryController extends AsyncNotifier<HistoryPageState> {
  int _offset = 0;

  @override
  Future<HistoryPageState> build() async {
    final filter = ref.watch(historyFilterProvider);

    // Re-runs `build` on any ledger change, discarding loaded pages. Acceptable
    // because a change almost always means a new row at the top, and reloading
    // one page of 50 from SQLite is sub-millisecond.
    ref.watch(ledgerRevisionProvider);

    final repository = ref.watch(transactionRepositoryProvider);
    final first = await repository.page(filter, offset: 0);
    _offset = first.length;

    return HistoryPageState(
      items: first,
      hasMore: first.length == AppConfig.historyPageSize,
      loadingMore: false,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncValue<HistoryPageState>.data(
      current.copyWith(loadingMore: true),
    );

    final filter = ref.read(historyFilterProvider);
    final next = await ref
        .read(transactionRepositoryProvider)
        .page(filter, offset: _offset);
    _offset += next.length;

    state = AsyncValue<HistoryPageState>.data(
      HistoryPageState(
        items: <TxnView>[...current.items, ...next],
        hasMore: next.length == AppConfig.historyPageSize,
        loadingMore: false,
      ),
    );
  }
}

final historyControllerProvider =
    AsyncNotifierProvider.autoDispose<HistoryController, HistoryPageState>(
  HistoryController.new,
);
