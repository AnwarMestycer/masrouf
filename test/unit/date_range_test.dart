import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/time/ym.dart';
import 'package:masrouf/domain/entities/analytics/date_range.dart';

/// Every boundary here was a judgement call, and each one changes what the app
/// tells someone about their month. They are pinned rather than left to a clock.
void main() {
  // Five days into October, the shape the real ledger was in when this was
  // written: 5 days of October against 30 of September.
  final now = DateTime(2026, 10, 5, 14, 30);
  const payday = 28;

  DateRange resolve(RangePreset p) =>
      Ranges.resolve(p, now: now, payday: payday);

  group('this month', () {
    /// A window running to the 31st on the 5th dilutes every per-day figure
    /// read from it by days that have not happened.
    test('stops at today, not at the end of the month', () {
      final r = resolve(RangePreset.thisMonth);
      expect(r.from, DateTime(2026, 10));
      expect(r.to, DateTime(2026, 10, 5));
      expect(r.dayCount, 5);
    });

    /// The whole point. Comparing 5 days of October against 30 of September is
    /// what made the app report a 78% drop during a month of heavier spending.
    test('compares against the same stretch of last month', () {
      final previous = resolve(RangePreset.thisMonth).previous;
      expect(previous.from, DateTime(2026, 9));
      expect(previous.to, DateTime(2026, 9, 5));
      expect(previous.dayCount, 5, reason: 'like for like, or it says nothing');
    });

    test('a short month cannot be overrun', () {
      // 31 days into March has no matching 31 days in February.
      final march = Ranges.resolve(
        RangePreset.thisMonth,
        now: DateTime(2026, 3, 31),
        payday: payday,
      );
      expect(march.dayCount, 31);
      expect(march.previous.to, DateTime(2026, 2, 28));
      expect(march.previous.dayCount, 28);
    });
  });

  group('last month', () {
    test('is the whole previous calendar month', () {
      final r = resolve(RangePreset.lastMonth);
      expect(r.from, DateTime(2026, 9));
      expect(r.to, DateTime(2026, 9, 30));
      expect(r.dayCount, 30);
    });

    test('compares against the month before it', () {
      expect(resolve(RangePreset.lastMonth).previous.from, DateTime(2026, 8));
    });
  });

  group('rolling windows', () {
    test('last 30 days is inclusive of today', () {
      final r = resolve(RangePreset.last30Days);
      expect(r.to, DateTime(2026, 10, 5));
      expect(r.from, DateTime(2026, 9, 6));
      expect(r.dayCount, 30);
    });

    /// A rolling window has no cycle to line up with, so the only honest
    /// comparison is the equal-length span immediately before it.
    test('a rolling window compares against the span right before it', () {
      final previous = resolve(RangePreset.last30Days).previous;
      expect(previous.to, DateTime(2026, 9, 5));
      expect(previous.from, DateTime(2026, 8, 7));
      expect(previous.dayCount, 30);
    });

    test('three and six month windows end today', () {
      expect(resolve(RangePreset.last3Months).to, DateTime(2026, 10, 5));
      expect(resolve(RangePreset.last3Months).from, DateTime(2026, 7, 6));
      expect(resolve(RangePreset.last6Months).from, DateTime(2026, 4, 6));
    });

    test('year to date starts on 1 January', () {
      final r = resolve(RangePreset.yearToDate);
      expect(r.from, DateTime(2026));
      expect(r.to, DateTime(2026, 10, 5));
    });
  });

  group('pay period', () {
    /// Payday is the 28th and today is 5 October, so the period began on
    /// 28 September — the month it belongs to is not the month it starts in.
    test('runs from the most recent payday', () {
      final r = resolve(RangePreset.payPeriod);
      expect(r.from, DateTime(2026, 9, 28));
      expect(r.to, DateTime(2026, 10, 5));
      expect(r.dayCount, 8);
    });

    test('before payday arrives, the period is still last month\'s', () {
      final r = Ranges.resolve(
        RangePreset.payPeriod,
        now: DateTime(2026, 10, 27),
        payday: payday,
      );
      expect(r.from, DateTime(2026, 9, 28));
      expect(r.to, DateTime(2026, 10, 27));
    });

    test('on payday itself the period starts over', () {
      final r = Ranges.resolve(
        RangePreset.payPeriod,
        now: DateTime(2026, 10, 28),
        payday: payday,
      );
      expect(r.from, DateTime(2026, 10, 28));
      expect(r.dayCount, 1);
    });

    test('compares against the same stretch of the previous period', () {
      final previous = resolve(RangePreset.payPeriod).previous;
      expect(previous.from, DateTime(2026, 8, 28));
      expect(previous.to, DateTime(2026, 9, 4));
      expect(previous.dayCount, 8);
    });

    /// A payday on the 31st has to land somewhere in February.
    test('a payday later than the month is clamped', () {
      final r = Ranges.resolve(
        RangePreset.payPeriod,
        now: DateTime(2026, 3, 2),
        payday: 31,
      );
      expect(r.from, DateTime(2026, 2, 28));
    });
  });

  group('the month fast path', () {
    /// A range that is exactly one calendar month can be answered from
    /// monthly_category_totals; anything else has to scan the ledger.
    test('a whole calendar month is recognised', () {
      expect(resolve(RangePreset.lastMonth).wholeMonth, const Ym.of(2026, 9));
    });

    test('a part month is not', () {
      expect(resolve(RangePreset.thisMonth).wholeMonth, isNull);
      expect(resolve(RangePreset.last30Days).wholeMonth, isNull);
    });

    test('a span crossing a boundary is not, even at 30 days', () {
      final r = DateRange(from: DateTime(2026, 9, 2), to: DateTime(2026, 10));
      expect(r.wholeMonth, isNull);
    });
  });

  test('a custom range compares against the span right before it', () {
    final r = DateRange(
      from: DateTime(2026, 9, 10),
      to: DateTime(2026, 9, 19),
    );
    expect(r.dayCount, 10);
    expect(r.previous.from, DateTime(2026, 8, 31));
    expect(r.previous.to, DateTime(2026, 9, 9));
  });

  test('a range covers whole days regardless of the time handed in', () {
    final r = DateRange(from: now, to: now);
    expect(r.from, DateTime(2026, 10, 5));
    expect(r.dayCount, 1);
    expect(r.contains(DateTime(2026, 10, 5, 23, 59)), isTrue);
    expect(r.contains(DateTime(2026, 10, 6)), isFalse);
  });
}
