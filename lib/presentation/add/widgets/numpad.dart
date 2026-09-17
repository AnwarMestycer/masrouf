import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:masrouf/core/theme/spacing.dart';

/// The custom keypad the add flow is built around.
///
/// A purpose-built grid rather than a text field with the system keyboard: it
/// guarantees big, fixed-position targets that never reflow, works identically in
/// RTL, and removes the keyboard show/hide animation that makes a soft-keyboard
/// entry flow feel laggy.
class Numpad extends StatelessWidget {
  const Numpad({
    required this.onDigit,
    required this.onDecimal,
    required this.onBackspace,
    required this.onClear,
    required this.decimalSeparator,
    super.key,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  /// `,` in fr/ar, `.` in en — the key must show what the locale writes.
  final String decimalSeparator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final row in const <List<String>>[
            <String>['1', '2', '3'],
            <String>['4', '5', '6'],
            <String>['7', '8', '9'],
          ])
            _Row(
              children: <Widget>[
                for (final digit in row)
                  _Key(
                    label: digit,
                    onTap: () => onDigit(digit),
                  ),
              ],
            ),
          _Row(
            children: <Widget>[
              _Key(label: decimalSeparator, onTap: onDecimal),
              _Key(label: '0', onTap: () => onDigit('0')),
              _Key(
                icon: Icons.backspace_outlined,
                onTap: onBackspace,
                onLongPress: onClear,
                semanticLabel: 'Backspace',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          for (final child in children) Expanded(child: child),
        ],
      );
}

class _Key extends StatelessWidget {
  const _Key({
    this.label,
    this.icon,
    required this.onTap,
    this.onLongPress,
    this.semanticLabel,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: InkWell(
        onTap: () {
          // Light haptics on every key: the single cheapest thing that makes a
          // custom keypad feel like a real keyboard rather than a set of buttons.
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        onLongPress: onLongPress == null
            ? null
            : () {
                unawaited(HapticFeedback.mediumImpact());
                onLongPress!();
              },
        borderRadius: const BorderRadius.all(Radius.circular(Gap.radiusMd)),
        child: SizedBox(
          height: 62,
          child: Center(
            child: icon != null
                ? Icon(icon, size: 24, color: theme.colorScheme.onSurfaceVariant)
                : Text(
                    label!,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
