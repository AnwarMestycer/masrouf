import 'package:meta/meta.dart';

/// A currency the app knows how to format.
///
/// [decimals] is the number of digits shown to the user, which is NOT the same as
/// the storage scale: every amount in this app is stored as an integer count of
/// thousandths regardless of currency (see [Money]). TND genuinely has three
/// (millimes), most others have two.
@immutable
class Currency {
  const Currency({
    required this.code,
    required this.decimals,
    required this.symbol,
  });

  final String code;
  final int decimals;
  final String symbol;

  static const tnd = Currency(code: 'TND', decimals: 3, symbol: 'DT');
  static const eur = Currency(code: 'EUR', decimals: 2, symbol: '€');
  static const usd = Currency(code: 'USD', decimals: 2, symbol: r'$');
  static const gbp = Currency(code: 'GBP', decimals: 2, symbol: '£');

  static const known = <Currency>[tnd, eur, usd, gbp];

  /// Falls back to a two-decimal currency using the code as its own symbol, so an
  /// unrecognised code from the server can still be displayed instead of crashing.
  static Currency fromCode(String code) {
    final upper = code.toUpperCase();
    for (final c in known) {
      if (c.code == upper) return c;
    }
    return Currency(code: upper, decimals: 2, symbol: upper);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Currency && other.code == code);

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}
