import 'package:flutter/material.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/money/money_formatter.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/analytics/analytics.dart';
import 'package:masrouf/l10n/app_localizations.dart';
import 'package:masrouf/presentation/common/category_icons.dart';

/// What actually moved between this window and the comparable one.
///
/// The ranked list answers "where does the money go"; this answers "what
/// changed", which is the question a comparison is for. Ranked by the size of
/// the swing in money rather than in percent: a category that went from 2 DT to
/// 6 DT tripled, and tells you nothing next to one that rose by 300.
class TopMovers extends StatelessWidget {
  const TopMovers({
    required this.slices,
    required this.formatter,
    required this.l10n,
    this.limit = 5,
    super.key,
  });

  final List<CategorySlice> slices;
  final MoneyFormatter formatter;
  final L10n l10n;
  final int limit;

  /// Categories whose spending moved, biggest swing first.
  ///
  /// A category absent from one side of the comparison still counts — appearing
  /// from nothing or stopping altogether is the largest change there is, and
  /// the slice carries a zero for the side it is missing from.
  List<CategorySlice> get _moved {
    final moved = slices
        .where((s) => s.total.milli != s.previousTotal.milli)
        .toList()
      ..sort((a, b) {
        final da = (a.total.milli - a.previousTotal.milli).abs();
        final db = (b.total.milli - b.previousTotal.milli).abs();
        return db.compareTo(da);
      });
    return moved.take(limit).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final movers = _moved;
    if (movers.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final slice in movers)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.lg,
              vertical: Gap.sm,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  CategoryIcons.resolve(slice.category?.icon ?? 'category'),
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    slice.category?.name ?? l10n.txnAll,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                _Delta(
                  from: slice.previousTotal,
                  to: slice.total,
                  formatter: formatter,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Delta extends StatelessWidget {
  const _Delta({
    required this.from,
    required this.to,
    required this.formatter,
  });

  final Money from;
  final Money to;
  final MoneyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = to.milli - from.milli;
    final rose = delta > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '${formatter.format(from)} → ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          formatter.format(to),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(width: Gap.sm),
        // Direction is carried by the arrow as well as the colour: more spending
        // is not universally bad, and red alone would be the only cue.
        Icon(
          rose ? Icons.north_east : Icons.south_east,
          size: 14,
          color: rose ? theme.colorScheme.error : theme.colorScheme.primary,
        ),
      ],
    );
  }
}
