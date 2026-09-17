import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:meta/meta.dart';

/// The history screen's query, as a value.
///
/// Being a value object means the filter is the provider's argument: changing it
/// swaps to a different query rather than mutating a controller, so Riverpod can
/// cache each distinct filter's results and dispose the ones nobody is watching.
@immutable
class HistoryFilter {
  const HistoryFilter({
    this.search = '',
    this.types = const <TxnType>{},
    this.categoryIds = const <String>{},
    this.accountIds = const <String>{},
    this.tags = const <String>{},
    this.from,
    this.to,
  });

  static const HistoryFilter none = HistoryFilter();

  /// Matched against note text and tags, case-insensitively.
  final String search;

  /// Empty means "all" for each of these — an empty set reads naturally as "no
  /// restriction" and avoids a nullable-set-versus-empty-set ambiguity.
  final Set<TxnType> types;
  final Set<String> categoryIds;
  final Set<String> accountIds;

  /// Matched as "carries every one of these tags", not "any of" — narrowing is
  /// what a second selected tag is for.
  final Set<String> tags;

  final DateTime? from;
  final DateTime? to;

  bool get isEmpty =>
      search.isEmpty &&
      types.isEmpty &&
      categoryIds.isEmpty &&
      accountIds.isEmpty &&
      tags.isEmpty &&
      from == null &&
      to == null;

  bool get isActive => !isEmpty;

  int get activeFacetCount => <bool>[
        search.isNotEmpty,
        types.isNotEmpty,
        categoryIds.isNotEmpty,
        accountIds.isNotEmpty,
        tags.isNotEmpty,
        from != null || to != null,
      ].where((active) => active).length;

  HistoryFilter copyWith({
    String? search,
    Set<TxnType>? types,
    Set<String>? categoryIds,
    Set<String>? accountIds,
    Set<String>? tags,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
  }) =>
      HistoryFilter(
        search: search ?? this.search,
        types: types ?? this.types,
        categoryIds: categoryIds ?? this.categoryIds,
        accountIds: accountIds ?? this.accountIds,
        tags: tags ?? this.tags,
        from: clearDates ? null : (from ?? this.from),
        to: clearDates ? null : (to ?? this.to),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryFilter &&
          other.search == search &&
          _setEquals(other.types, types) &&
          _setEquals(other.categoryIds, categoryIds) &&
          _setEquals(other.accountIds, accountIds) &&
          _setEquals(other.tags, tags) &&
          other.from == from &&
          other.to == to);

  @override
  int get hashCode => Object.hash(
        search,
        Object.hashAllUnordered(types),
        Object.hashAllUnordered(categoryIds),
        Object.hashAllUnordered(accountIds),
        Object.hashAllUnordered(tags),
        from,
        to,
      );
}

bool _setEquals<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);
