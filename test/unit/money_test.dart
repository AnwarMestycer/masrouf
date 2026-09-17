import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';

void main() {
  group('Money.tryParse', () {
    test('reads whole numbers', () {
      expect(Money.tryParse('25', Currency.tnd)?.milli, 25000);
    });

    test('pads a short fraction to the storage scale', () {
      // "2,5" is two and a half dinars, not two dinars and five millimes.
      expect(Money.tryParse('2,5', Currency.tnd)?.milli, 2500);
      expect(Money.tryParse('2.5', Currency.tnd)?.milli, 2500);
    });

    test('reads all three TND decimals', () {
      expect(Money.tryParse('1250,750', Currency.tnd)?.milli, 1250750);
    });

    test('rejects more precision than the scale can hold', () {
      expect(Money.tryParse('1.2345', Currency.tnd), isNull);
    });

    test('rejects junk rather than guessing', () {
      expect(Money.tryParse('', Currency.tnd), isNull);
      expect(Money.tryParse('abc', Currency.tnd), isNull);
      expect(Money.tryParse('1.2.3', Currency.tnd), isNull);
    });

    test('ignores grouping whitespace', () {
      expect(Money.tryParse('1 250,500', Currency.tnd)?.milli, 1250500);
    });
  });

  group('Money arithmetic', () {
    test('is exact where a double would drift', () {
      // 0.1 + 0.2 != 0.3 in binary floating point; in millimes it is exact.
      final a = Money.tryParse('0.1', Currency.tnd)!;
      final b = Money.tryParse('0.2', Currency.tnd)!;
      expect((a + b).milli, Money.tryParse('0.3', Currency.tnd)!.milli);
    });

    test('sums a long run without accumulating error', () {
      var total = const Money.zero(Currency.tnd);
      final third = Money.tryParse('0.333', Currency.tnd)!;
      for (var i = 0; i < 3000; i++) {
        total += third;
      }
      expect(total.milli, 999000);
    });

    test('subtraction can go negative', () {
      const a = Money(1000, Currency.tnd);
      const b = Money(2500, Currency.tnd);
      expect((a - b).milli, -1500);
      expect((a - b).isNegative, isTrue);
    });
  });

  group('Money.toDecimalString', () {
    test('always emits the full scale', () {
      expect(const Money(1250500, Currency.tnd).toDecimalString(), '1250.500');
      expect(const Money(5, Currency.tnd).toDecimalString(), '0.005');
    });

    test('keeps the sign outside the padding', () {
      expect(const Money(-1250, Currency.tnd).toDecimalString(), '-1.250');
    });
  });

  group('Money.fromJson', () {
    test('reads the decimal string Postgres numeric returns', () {
      expect(Money.fromJson('1250.500', Currency.tnd).milli, 1250500);
    });

    test('reads a bare int as whole units', () {
      expect(Money.fromJson(25, Currency.tnd).milli, 25000);
    });

    test('treats null as zero', () {
      expect(Money.fromJson(null, Currency.tnd).isZero, isTrue);
    });

    // PostgREST sends numeric(18,3) as a bare JSON number, so jsonDecode hands
    // these over as doubles. The literals below are the exact wire tokens
    // observed from the live project, not invented ones.
    test('reads the doubles PostgREST actually sends', () {
      expect(Money.fromJson(25.500, Currency.tnd).milli, 25500);
      expect(Money.fromJson(25.000, Currency.tnd).milli, 25000);
      expect(Money.fromJson(0.005, Currency.tnd).milli, 5);
      expect(Money.fromJson(1250.750, Currency.tnd).milli, 1250750);
      expect(Money.fromJson(0.100, Currency.tnd).milli, 100);
      expect(Money.fromJson(3.140, Currency.tnd).milli, 3140);
    });

    test('is exact at the top of the representable range', () {
      // The widest value numeric(18,3) can carry through this app. Well inside a
      // double's exact-integer range once expressed in thousandths.
      expect(Money.fromJson(999999999.999, Currency.tnd).milli, 999999999999);
    });

    test('never receives exponential notation for in-range amounts', () {
      // The failure mode the range analysis rules out: if toString() ever emitted
      // "1e+21" the regex would reject it and the amount would be lost.
      for (final value in <double>[0.001, 0.005, 1.5, 999999999.999]) {
        expect(value.toString(), isNot(contains('e')));
      }
    });

    test('round-trips through the wire format without drift', () {
      for (final milli in <int>[1, 5, 100, 25500, 1250750, 999999999999]) {
        final original = Money(milli, Currency.tnd);
        final wire = original.toDecimalString();
        expect(Money.fromJson(wire, Currency.tnd).milli, milli);
        expect(Money.fromJson(double.parse(wire), Currency.tnd).milli, milli);
      }
    });
  });

  group('Money.convertTo', () {
    test('rounds to the nearest millime', () {
      final eur = Money.tryParse('12.50', Currency.eur)!;
      final tnd = eur.convertTo(Currency.tnd, 3.3);
      expect(tnd.currency, Currency.tnd);
      expect(tnd.milli, 41250);
    });

    test('rounds a negative amount away from zero, not toward it', () {
      const source = Money(-1005, Currency.eur);
      expect(source.convertTo(Currency.tnd, 1.5).milli, -1508);
    });
  });
}
