import 'package:masrouf/core/money/currency.dart';
import 'package:meta/meta.dart';

/// An exact monetary amount.
///
/// Stored as an integer number of *thousandths* of a currency unit, for every
/// currency uniformly — 1.250 TND and 12.50 USD are `1250` and `12500`. TND needs
/// three decimals (millimes) so three is the floor; using one scale everywhere
/// means addition never has to reconcile differing precisions, and `double` never
/// enters the picture.
@immutable
class Money implements Comparable<Money> {
  const Money(this.milli, this.currency);

  const Money.zero(this.currency) : milli = 0;

  /// Parses a human-typed decimal such as `12`, `12.5`, `12,500`.
  ///
  /// Accepts either separator because the app runs in French and Arabic locales
  /// where the comma is the decimal mark. Returns null on anything unparseable
  /// rather than throwing — callers are validating user input.
  static Money? tryParse(String input, Currency currency) {
    final cleaned = input.trim().replaceAll(RegExp(r'[\s  ]'), '');
    if (cleaned.isEmpty) return null;

    final match = RegExp(r'^(-?)(\d*)(?:[.,](\d*))?$').firstMatch(cleaned);
    if (match == null) return null;

    final whole = match.group(2) ?? '';
    final frac = match.group(3) ?? '';
    if (whole.isEmpty && frac.isEmpty) return null;
    if (frac.length > _scaleDigits) return null;

    final units = whole.isEmpty ? 0 : int.tryParse(whole);
    if (units == null) return null;
    final fracPadded = frac.padRight(_scaleDigits, '0');
    final thousandths = int.parse(fracPadded);

    final magnitude = units * scale + thousandths;
    return Money(match.group(1) == '-' ? -magnitude : magnitude, currency);
  }

  /// Reads the `numeric(18,3)` representation Postgres returns.
  ///
  /// PostgREST serialises `numeric` as a bare JSON number preserving its scale
  /// (`25.500`), which `jsonDecode` turns into a `double`; a whole value may
  /// arrive as an `int`, and an explicit `::text` cast as a String. All three are
  /// handled.
  ///
  /// Routing a double through `toString()` is exact for every amount this app can
  /// hold. The largest is 999,999,999.999 — 999999999999 thousandths, about 2^40,
  /// far inside a double's 2^53 exact-integer range — and the magnitudes stay
  /// between 1e-3 and 1e9, so `toString()` never falls back to exponential
  /// notation. Verified against the live API in `money_test.dart`.
  static Money fromJson(Object? value, Currency currency) {
    if (value == null) return Money.zero(currency);
    if (value is int) return Money(value * scale, currency);
    final parsed = Money.tryParse(value.toString(), currency);
    if (parsed == null) {
      throw FormatException('Not a valid amount: $value');
    }
    return parsed;
  }

  static const int scale = 1000;
  static const int _scaleDigits = 3;

  /// Thousandths of a currency unit. Negative for outflows where a signed amount
  /// is meaningful (net totals, balances); transaction rows store magnitudes.
  final int milli;
  final Currency currency;

  bool get isZero => milli == 0;
  bool get isNegative => milli < 0;
  bool get isPositive => milli > 0;

  Money get abs => Money(milli.abs(), currency);
  Money operator -() => Money(-milli, currency);

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(milli + other.milli, currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(milli - other.milli, currency);
  }

  bool operator <(Money other) {
    _assertSameCurrency(other);
    return milli < other.milli;
  }

  bool operator >(Money other) {
    _assertSameCurrency(other);
    return milli > other.milli;
  }

  bool operator <=(Money other) => !(this > other);
  bool operator >=(Money other) => !(this < other);

  /// Converts into [target] using a manually maintained rate.
  ///
  /// Rounds half-away-from-zero at the thousandth. The rate is a `double` because
  /// it is an approximation by nature; the *result* returns to exact integer
  /// thousandths immediately, so error cannot accumulate across a sum.
  Money convertTo(Currency target, double rateToTarget) {
    if (currency == target && rateToTarget == 1) return this;
    final raw = milli * rateToTarget;
    return Money(raw.abs().round() * (raw.isNegative ? -1 : 1), target);
  }

  /// The wire format for `numeric(18,3)`, e.g. `-1250.500`.
  String toDecimalString() {
    final sign = milli < 0 ? '-' : '';
    final magnitude = milli.abs();
    final whole = magnitude ~/ scale;
    final frac = (magnitude % scale).toString().padLeft(_scaleDigits, '0');
    return '$sign$whole.$frac';
  }

  void _assertSameCurrency(Money other) {
    assert(
      other.currency == currency,
      'Cannot combine ${currency.code} with ${other.currency.code} directly; '
      'convert one side with convertTo() first.',
    );
  }

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return milli.compareTo(other.milli);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Money && other.milli == milli && other.currency == currency);

  @override
  int get hashCode => Object.hash(milli, currency);

  @override
  String toString() => '${toDecimalString()} ${currency.code}';
}
