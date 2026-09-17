import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/money/money_formatter.dart';
import 'package:masrouf/core/theme/app_colors.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/domain/entities/analytics/analytics.dart';
import 'package:masrouf/domain/entities/budget.dart';
import 'package:masrouf/l10n/app_localizations.dart';
import 'package:masrouf/presentation/common/category_icons.dart';
import 'package:masrouf/presentation/common/widgets/change_chip.dart';

/// Spending by category: a donut over a ranked list.
///
/// The donut caps at [_maxSlices] real slices and folds the tail into a neutral
/// "Other" — a categorical palette is only separable for a handful of hues, and
/// a fifteen-slice ring is unreadable regardless of colour choice.
///
/// The ranked list underneath is not decoration: it is the required relief for a
/// palette whose lighter slots fall below 3:1 on a light surface. Every category
/// is named next to its swatch, so identity is never carried by colour alone.
class CategoryDonut extends StatefulWidget {
  const CategoryDonut({
    required this.slices,
    required this.total,
    required this.formatter,
    required this.l10n,
    this.totalLabel,
    this.budgets = const <String, BudgetProgress>{},
    super.key,
  });

  final List<CategorySlice> slices;
  final Money total;
  final MoneyFormatter formatter;
  final L10n l10n;

  /// What the centre reads when no slice is focused. Defaults to "Out", which
  /// is wrong once the donut can also show income.
  final String? totalLabel;

  /// Caps by category id. Rows without one render exactly as before — a budget
  /// line under every row would turn a composition chart into a second budgets
  /// screen.
  final Map<String, BudgetProgress> budgets;

  static const int _maxSlices = 6;

  @override
  State<CategoryDonut> createState() => _CategoryDonutState();
}

class _CategoryDonutState extends State<CategoryDonut> {
  /// Index of the slice under the finger, or null. Drives both the ring
  /// highlight and the centre readout — the touch equivalent of a hover tooltip.
  ///
  /// Only ever holds a valid index. fl_chart reports -1 for a touch that landed
  /// in the centre hole or in the gap between two arcs, which is a real thing to
  /// do on a donut with a 62px hole — storing it and indexing with it later is
  /// what threw `RangeError: not in inclusive range 0..6: -1`.
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    if (widget.slices.isEmpty) {
      return _EmptyChart(message: widget.l10n.analyticsNoData);
    }

    final grouped = _group(widget.slices, brightness, theme);
    // Bounds-checked on both sides: the slice count also shrinks when the month
    // changes under a held selection.
    final touched = _touched;
    final focused = touched != null && touched >= 0 && touched < grouped.length
        ? grouped[touched]
        : null;

    return Column(
      children: <Widget>[
        // The chart itself is a painted arc with no text in it, so to a screen
        // reader the whole Analytics tab was silent. The ranked list below is
        // the accessible equivalent; this states the same thing for the ring.
        Semantics(
          label: <String>[
            widget.totalLabel ?? widget.l10n.dashboardOut,
            widget.formatter.format(widget.total),
            for (final slice in grouped)
              '${slice.label} ${(slice.share * 100).round()}%',
          ].join(', '),
          excludeSemantics: true,
          child: SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                PieChart(
                  PieChartData(
                    sectionsSpace: 2, // 2px surface gap between adjacent fills
                    centerSpaceRadius: 62,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        final index =
                            response?.touchedSection?.touchedSectionIndex;
                        setState(() {
                          _touched =
                              event.isInterestedForInteractions &&
                                  index != null &&
                                  index >= 0
                              ? index
                              : null;
                        });
                      },
                    ),
                    sections: <PieChartSectionData>[
                      for (var i = 0; i < grouped.length; i++)
                        PieChartSectionData(
                          value: grouped[i].total.milli.toDouble(),
                          color: grouped[i].color,
                          radius: _touched == i ? 34 : 28,
                          showTitle: false,
                          // A 2px surface ring keeps touching arcs separate even
                          // when two neighbours are close in hue.
                          borderSide: BorderSide(
                            color: theme.colorScheme.surface,
                            width: 2,
                          ),
                        ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 180),
                ),
                _CentreReadout(
                  label:
                      focused?.label ??
                      widget.totalLabel ??
                      widget.l10n.dashboardOut,
                  value: widget.formatter.format(
                    focused?.total ?? widget.total,
                  ),
                  share: focused?.share,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),
        for (var i = 0; i < grouped.length; i++)
          _RankRow(
            entry: grouped[i],
            budget: widget.budgets[grouped[i].categoryId],
            formatter: widget.formatter,
            highlighted: _touched == i,
            onTap: () => setState(() => _touched = _touched == i ? null : i),
          ),
      ],
    );
  }

  /// Top slices verbatim, remainder aggregated.
  List<_Slice> _group(
    List<CategorySlice> slices,
    Brightness brightness,
    ThemeData theme,
  ) {
    final head = slices.take(CategoryDonut._maxSlices).toList(growable: false);
    final tail = slices.skip(CategoryDonut._maxSlices).toList(growable: false);

    final result = <_Slice>[
      for (final slice in head)
        _Slice(
          label: slice.category?.name ?? widget.l10n.txnAll,
          icon: CategoryIcons.resolve(slice.category?.icon ?? 'category'),
          color: AppColors.resolveCategoryColor(
            slice.category?.color ?? theme.colorScheme.outline.toARGB32(),
            brightness,
          ),
          total: slice.total,
          share: slice.share,
          changeRatio: slice.changeRatio,
          categoryId: slice.category?.id,
        ),
    ];

    if (tail.isNotEmpty) {
      final total = tail.map((s) => s.total).reduce((a, b) => a + b);
      result.add(
        _Slice(
          label: '${widget.l10n.txnAll} (+${tail.length})',
          icon: Icons.more_horiz,
          color: brightness == Brightness.dark
              ? AppColors.otherSliceDark
              : AppColors.otherSliceLight,
          total: total,
          share: tail.fold<double>(0, (sum, s) => sum + s.share),
          changeRatio: null,
        ),
      );
    }
    return result;
  }
}

class _Slice {
  const _Slice({
    required this.label,
    required this.icon,
    required this.color,
    required this.total,
    required this.share,
    required this.changeRatio,
    this.categoryId,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Money total;
  final double share;
  final double? changeRatio;

  /// Null for the aggregated "Other" row, which spans several categories and so
  /// cannot carry one cap.
  final String? categoryId;
}

class _CentreReadout extends StatelessWidget {
  const _CentreReadout({
    required this.label,
    required this.value,
    required this.share,
  });

  final String label;
  final String value;
  final double? share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          // Text wears text tokens, never the series colour.
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 108,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: theme.textTheme.titleLarge),
          ),
        ),
        if (share != null)
          Text(
            '${(share! * 100).round()}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.entry,
    required this.budget,
    required this.formatter,
    required this.highlighted,
    required this.onTap,
  });

  final _Slice entry;
  final BudgetProgress? budget;
  final MoneyFormatter formatter;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = entry.changeRatio;

    final Widget row = InkWell(
      onTap: onTap,
      child: Container(
        color: highlighted
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : null,
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.sm,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: entry.color,
                borderRadius: const BorderRadius.all(Radius.circular(3)),
              ),
            ),
            const SizedBox(width: Gap.md),
            Icon(
              entry.icon,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                entry.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (change != null) ...<Widget>[
              ChangeChip(ratio: change),
              const SizedBox(width: Gap.sm),
            ],
            Text(
              formatter.format(entry.total),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    final cap = budget;
    if (cap == null) return row;

    // A 3px rule under the row: enough to read "most of the way there" at a
    // glance, not enough to compete with the amount beside it.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        row,
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
          child: Semantics(
            label:
                '${entry.label}: '
                '${(cap.ratio * 100).round()}% of '
                '${formatter.format(cap.cap)}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: cap.ratio.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  cap.isOver ? theme.money.expense : entry.color,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Month-over-month delta.
///
/// Carries an arrow as well as a colour, so the direction survives for a reader
/// who cannot distinguish the two hues.

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 180,
    child: Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}
