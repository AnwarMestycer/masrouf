import 'package:flutter/material.dart';
import 'package:masrouf/core/theme/app_colors.dart';

/// A month-over-month delta, as a signed percentage.
///
/// Shared by the analytics ranked list and the dashboard's category card so one
/// category's change reads identically in both places.
class ChangeChip extends StatelessWidget {
  const ChangeChip({required this.ratio, super.key});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final up = ratio > 0;
    // For spending, up is the bad direction — the opposite of a stock chart.
    final color = up ? theme.money.expense : theme.money.income;
    final percent = (ratio.abs() * 100).round();

    // Below 1% the delta is noise; showing "0%" implies precision that isn't there.
    if (percent < 1) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          up ? Icons.arrow_upward : Icons.arrow_downward,
          size: 12,
          color: color,
        ),
        Text(
          '$percent%',
          style: theme.textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
