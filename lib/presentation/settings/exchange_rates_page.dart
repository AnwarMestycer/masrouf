import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

/// Manual conversion rates.
///
/// There is no rate feed in v1 on purpose: for TND the rate that matters is the
/// one the user's exchange office actually gave them, which no published
/// mid-market feed reflects. Rates here affect display and totals only — each
/// transaction keeps the rate frozen at the moment it was written, so editing a
/// rate never rewrites history.
class ExchangeRatesPage extends ConsumerWidget {
  const ExchangeRatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final base = ref.watch(baseCurrencyProvider);
    final rates = ref.watch(ratesToBaseProvider);

    final others = Currency.known
        .where((c) => c != base)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsExchangeRates)),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Text(
              '1 X = ? ${base.code}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          for (final currency in others)
            _RateTile(
              currency: currency,
              base: base,
              value: rates?[currency.code],
            ),
        ],
      ),
    );
  }
}

class _RateTile extends ConsumerStatefulWidget {
  const _RateTile({
    required this.currency,
    required this.base,
    required this.value,
  });

  final Currency currency;
  final Currency base;
  final double? value;

  @override
  ConsumerState<_RateTile> createState() => _RateTileState();
}

class _RateTileState extends ConsumerState<_RateTile> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value?.toString() ?? '');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final parsed = double.tryParse(_controller.text.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) {
      setState(() => _error = context.l10n.validationRatePositive);
      return;
    }
    setState(() => _error = null);
    await ref
        .read(settingsRepositoryProvider)
        .saveRate(widget.currency, parsed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: Gap.sm,
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(l10n.settingsRateFor(widget.currency.code)),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              // Committed on blur as well as on submit, so a rate typed and then
              // dismissed with the back gesture is not silently lost.
              onTapOutside: (_) => _save(),
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                isDense: true,
                errorText: _error,
                suffixText: widget.base.symbol,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
