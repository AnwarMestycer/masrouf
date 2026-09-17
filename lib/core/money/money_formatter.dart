import 'package:intl/intl.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';

/// Formats [Money] for display.
///
/// Built once per locale and cached, because constructing a [NumberFormat] parses
/// the locale's symbol data and is far too expensive to do inside a list item's
/// build method.
class MoneyFormatter {
  MoneyFormatter(this.locale);

  final String locale;

  final Map<String, NumberFormat> _byCurrency = <String, NumberFormat>{};
  final Map<String, NumberFormat> _compactByCurrency = <String, NumberFormat>{};

  /// `1 250,500 DT` in fr, `1,250.500 DT` in en.
  String format(Money money, {bool showSymbol = true}) {
    final currency = money.currency;
    final formatter = _byCurrency.putIfAbsent(
      currency.code,
      () => NumberFormat.decimalPatternDigits(
        locale: locale,
        decimalDigits: currency.decimals,
      ),
    );
    final text = formatter.format(_toDisplayDouble(money));
    return showSymbol ? '$text ${currency.symbol}' : text;
  }

  /// Always carries an explicit sign. Used where inflow/outflow must read at a
  /// glance without relying on colour alone.
  String formatSigned(Money money, {bool showSymbol = true}) {
    final body = format(money.abs, showSymbol: showSymbol);
    if (money.isZero) return body;
    return money.isNegative ? '−$body' : '+$body';
  }

  /// `1,3 k DT` — for axis labels and dense tiles where the exact millime is noise.
  String formatCompact(Money money) {
    final currency = money.currency;
    final formatter = _compactByCurrency.putIfAbsent(
      currency.code,
      () => NumberFormat.compact(locale: locale),
    );
    return '${formatter.format(_toDisplayDouble(money))} ${currency.symbol}';
  }

  /// Both sides of a foreign-currency amount: `12,50 € · 41,250 DT`.
  String formatWithBase(Money original, Money converted) {
    if (original.currency == converted.currency) return format(original);
    return '${format(original)} · ${format(converted)}';
  }

  /// The only place a monetary value becomes a double.
  ///
  /// Safe because it happens at the very end of the pipeline, purely to hand
  /// [NumberFormat] something to render — no arithmetic follows it.
  double _toDisplayDouble(Money money) => money.milli / Money.scale;

  static String symbolOf(Currency currency) => currency.symbol;
}
